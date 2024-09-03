packages <- c("duckdb", "lubridate", "tidyverse", "dplyr", "readr", "arrow", "fst", "lightgbm", "caret", "Metrics", "ROCR", "pROC", "ggplot2","PRROC", "reshape2")

install_if_missing <- function(package) {
  if (!require(package, character.only = TRUE)) {
    install.packages(package, dependencies = TRUE)
    library(package, character.only = TRUE)
  }
}

sapply(packages, install_if_missing)

con <- duckdb::dbConnect(duckdb::duckdb(), dbdir = ":memory:")

tables_location <- "C:/Users/vchaudha/OneDrive - rush.edu/CLIF-1.0-main" 
site <-'RUSH'
file_type <- '.csv'

# Check if the output directory exists; if not, create it
if (!dir.exists("output")) {
  dir.create("output")
}

read_data <- function(file_path) {
  if (grepl("\\.csv$", file_path)) {
    return(read.csv(file_path))
  } else if (grepl("\\.parquet$", file_path)) {
    return(arrow::read_parquet(file_path))
  } else if (grepl("\\.fst$", file_path)) {
    return(fst::read.fst(file_path))
  } else {
    stop("Unsupported file format")
  }
}

# Read data using the function and assign to variables
location <- read_data(paste0(tables_location, "/rclif/clif_adt", file_type))
encounter <- read_data(paste0(tables_location, "/rclif/clif_encounter_demographics_dispo_clean", file_type))
limited <- read_data(paste0(tables_location, "/rclif/clif_limited_identifiers", file_type))
demog <- read_data(paste0(tables_location, "/rclif/clif_patient_demographics", file_type))

# First join operation
join <- location %>%
  select(encounter_id, location_category, in_dttm, out_dttm) %>%
  left_join(limited %>% select(encounter_id, admission_dttm), by = "encounter_id")

# Second join operation to get 'icu_data'
icu_data <- join %>%
  left_join(encounter %>% select(encounter_id, age_at_admission, disposition), by = "encounter_id") %>%
  mutate(
    admission_dttm = ymd_hms(admission_dttm), # Convert to POSIXct, adjust the function as per your date format
    in_dttm = ymd_hms(in_dttm), # Convert to POSIXct, adjust the function as per your date format
    out_dttm = ymd_hms(out_dttm)
  )

# Filter rows where location is ICU and in_dttm is within 48 hours of admission_dttm

icu_48hr_check <- icu_data %>%
  filter(location_category == "ICU",
         in_dttm >= admission_dttm,
         in_dttm <= admission_dttm + lubridate::hours(48),
         lubridate::year(admission_dttm) >= 2020,
         lubridate::year(admission_dttm) <= 2021,
         age_at_admission >= 18,
         !is.na(age_at_admission)) %>%
  distinct(encounter_id) %>%
  pull(encounter_id)
  
# Filter icu_data to only include rows with encounter_ids in icu_48hr_check and within 72 hours of admission
icu_data <- icu_data %>%
  filter(encounter_id %in% icu_48hr_check,
         in_dttm <= admission_dttm + hours(72)) %>%
  arrange(in_dttm) %>%
  mutate(RANK = rank(in_dttm, ties.method = "first")) %>%
  arrange(encounter_id, in_dttm) %>%
  group_by(encounter_id) %>%
  mutate(RANK = rank(in_dttm, ties.method = "first"))

  # Compute minimum rank for ICU locations
min_icu <- icu_data %>%
  filter(location_category == "ICU") %>%
  group_by(encounter_id) %>%
  summarize(min_icu = min(RANK))

# Merge the minimum ICU rank back into the original dataset
icu_data <- icu_data %>%
  left_join(min_icu, by = "encounter_id")

# Filter based on rank being at least the minimum ICU rank
icu_data <- icu_data %>%
  filter(RANK >= min_icu) %>%
  arrange(in_dttm)

# Change 'OR' to 'ICU' in location_category
icu_data <- icu_data %>%
  mutate(location_category = ifelse(location_category == "OR", "ICU", location_category))

# Create a new group_id based on changes in location_category
icu_data <- icu_data %>%
  group_by(encounter_id) %>%
  mutate(group_id = cumsum(location_category != lag(location_category, default = first(location_category)))) %>%
  ungroup()

icu_data <- icu_data %>%
  group_by(encounter_id, location_category, group_id) %>%
  summarize(
    min_in_dttm = min(in_dttm),
    max_out_dttm = max(out_dttm),
    admission_dttm = first(admission_dttm),
    age = first(age_at_admission),
    dispo = first(disposition),
    .groups = 'drop'
  )

# Compute minimum group_id for each encounter_id where location_category is 'ICU'
min_icu <- icu_data %>%
  filter(location_category == "ICU") %>%
  group_by(encounter_id) %>%
  summarize(min_icu = min(group_id), .groups = 'drop')

# Merge the minimum ICU group_id back into the original dataset
icu_data <- left_join(icu_data, min_icu, by = "encounter_id")

# Filter based on group_id matching min_icu and duration condition
icu_data <- icu_data %>%
  filter(min_icu == group_id,
         interval(min_in_dttm, max_out_dttm) >= dhours(24)) %>%
  arrange(min_in_dttm)

  # Add 24 hours to the 'min_in_dttm' column
icu_data <- icu_data %>%
  mutate(after_24hr = min_in_dttm + hours(24))

# Select specific columns
icu_data <- icu_data %>%
  select(encounter_id, min_in_dttm, after_24hr,max_out_dttm, age, dispo)

# Merge with demographic data and select specific columns
icu_data <- icu_data %>%
  left_join(demog, by = "encounter_id") %>%
  select(encounter_id, min_in_dttm, after_24hr,max_out_dttm, age, dispo, sex, ethnicity, race)

# Remove rows with missing 'sex' and create new variables
icu_data <- icu_data %>%
  filter(!is.na(sex)) %>%
  mutate(
    isfemale = as.integer(tolower(sex) == "female"),
    isdeathdispo = as.integer(grepl("dead|expired|death|died", dispo, ignore.case = TRUE))
  )

# Define race and ethnicity mappings using case_when
icu_data <- icu_data %>%
  mutate(
    race = case_when(
      race == "White" ~ "White",
      race == "Black or African American" ~ "Black",
      race == "Asian" ~ "Asian",
      race %in% c("Other", "Unknown", "Did Not Encounter", "Refusal", 
                  "American Indian or Alaska Native", 
                  "Native Hawaiian or Other Pacific Islander") ~ "Others",
      TRUE ~ "Others"  # Default case for NA and any other unexpected values
    ),
    ethnicity = case_when(
      ethnicity == "Not Hispanic or Latino" ~ "Not Hispanic or Latino",
      ethnicity == "Hispanic or Latino" ~ "Hispanic or Latino",
      ethnicity %in% c("Did Not Encounter", "Refusal", "*Unspecified") ~ "Not Hispanic or Latino",
      TRUE ~ "Not Hispanic or Latino"  # Default case for NA and any other unexpected values
    )
  )

# Calculate the difference in hours
icu_data$ICU_stay_hrs <- as.numeric(difftime(icu_data$max_out_dttm, icu_data$min_in_dttm, units = "secs")) / 3600


rm( encounter, limited, demog)
gc()  # invokes garbage collection
### vitals
vitals <- read_data(paste0(tables_location, "/rclif/clif_vitals_clean", file_type))
duckdb_register(con, "vitals", vitals)
duckdb_register(con, "icu_data", icu_data)
vitals <- dbGetQuery(con, "SELECT 
        encounter_id,
        CAST(recorded_dttm AS datetime) AS recorded_dttm,
        CAST(vital_value AS float) AS vital_value,
        vital_category 
    FROM 
        vitals
    WHERE 
        vital_category IN ('weight_kg', 'pulse', 'sbp', 'dbp', 'temp_c','height_inches') 
        AND encounter_id IN (SELECT DISTINCT encounter_id FROM icu_data);")
duckdb_unregister(con, "vitals")       
pivoted_data <- vitals %>%
  group_by(encounter_id, recorded_dttm, vital_category) %>%
  summarise(first_vital_value = first(vital_value), .groups = 'drop') %>%
  pivot_wider(
    names_from = vital_category,
    values_from = first_vital_value
  ) %>%  as.data.frame

rm(vitals)
gc()  # invokes garbage collection
pivoted_data <- pivoted_data %>%
  mutate(
    height_meters = height_inches * 0.0254,
    bmi = weight_kg / (height_meters ^ 2)
  ) %>%  as.data.frame

# Merge vitals data with icu_data
icu_data_agg <- icu_data %>%
  left_join(pivoted_data, by = "encounter_id") %>%  as.data.frame

# Filter records based on time conditions
icu_data_agg <- icu_data_agg %>%
  filter(recorded_dttm >= min_in_dttm & recorded_dttm <= after_24hr) %>%
  arrange(recorded_dttm) %>%
  select(-recorded_dttm)  %>%  as.data.frame

duckdb_register(con, "icu_data_agg", icu_data_agg)
# Aggregate data
icu_data_agg <- tbl(con, "icu_data_agg") %>% 
  group_by(encounter_id) %>%
  summarize(
    min_bmi = min(bmi, na.rm = TRUE),
    max_bmi = max(bmi, na.rm = TRUE),
    avg_bmi = mean(bmi, na.rm = TRUE),
    min_weight_kg = min(weight_kg, na.rm = TRUE), 
    max_weight_kg = max(weight_kg, na.rm = TRUE),
    avg_weight_kg = mean(weight_kg, na.rm = TRUE),
    min_pulse = min(pulse, na.rm = TRUE),
    max_pulse = max(pulse, na.rm = TRUE),
    avg_pulse = mean(pulse, na.rm = TRUE),
    min_sbp = min(sbp, na.rm = TRUE),
    max_sbp = max(sbp, na.rm = TRUE),
    avg_sbp = mean(sbp, na.rm = TRUE),
    min_dbp = min(dbp, na.rm = TRUE),
    max_dbp = max(dbp, na.rm = TRUE),
    avg_dbp = mean(dbp, na.rm = TRUE),
    min_temp_c = min(temp_c, na.rm = TRUE),
    max_temp_c = max(temp_c, na.rm = TRUE),
    avg_temp_c = mean(temp_c, na.rm = TRUE),
    .groups = "drop"  # Avoid auto-grouping in subsequent operations
  ) %>% collect() %>%   as.data.frame

# Merge aggregated data back into the original icu_data
icu_data <- left_join(icu_data, icu_data_agg, by = "encounter_id")

duckdb_unregister(con, "icu_data_agg")
rm(icu_data_agg,pivoted_data)
gc()  # invokes garbage collection
### labs
labs <- read_data(paste0(tables_location, "/rclif/clif_labs_clean", file_type))
duckdb_register(con, "labs", labs)
labs <- dbGetQuery(con, "
 SELECT 
        encounter_id,
        CAST(lab_order_dttm AS datetime) AS lab_order_dttm,
        TRY_CAST(lab_value AS float) AS lab_value,
        lab_category 
    FROM 
        labs
    WHERE 
      ((lab_category='monocyte'               and lab_type_name='standard') OR
        (lab_category='lymphocyte'              and lab_type_name='standard') OR
        (lab_category='basophil'                and lab_type_name='standard') OR
        (lab_category='neutrophil'              and lab_type_name='standard') OR
        (lab_category='albumin'                 and lab_type_name='standard') OR
        (lab_category='ast'                     and lab_type_name='standard') OR
        (lab_category='total_protein'           and lab_type_name='standard') OR
        (lab_category='alkaline_phosphatase'    and lab_type_name='standard') OR
        (lab_category='bilirubin_total'         and lab_type_name='standard') OR
        (lab_category='bilirubin_conjugated'    and lab_type_name='standard') OR
        (lab_category='calcium'                 and lab_type_name='standard') OR
        (lab_category='chloride'                and lab_type_name='standard') OR
        (lab_category='potassium'               and lab_type_name='standard') OR
        (lab_category='sodium'                  and lab_type_name='standard') OR
        (lab_category='glucose_serum'           and lab_type_name='standard') OR
        (lab_category='hemoglobin'              and lab_type_name='standard') OR
        (lab_category='platelet_count'          and lab_type_name='standard') OR
        (lab_category='wbc'                     and lab_type_name='standard'))
        AND encounter_id IN (SELECT DISTINCT encounter_id FROM icu_data);
")

pivoted_data <- labs  %>%
  group_by(encounter_id, lab_order_dttm, lab_category) %>%
  summarise(first_lab_value = first(lab_value), .groups = 'drop') %>%
  pivot_wider(
    names_from = lab_category,
    values_from = first_lab_value
  )  %>% 
  as.data.frame

icu_data_agg <- left_join(icu_data, pivoted_data, by = "encounter_id")

icu_data_agg <- filter(icu_data_agg, lab_order_dttm >= min_in_dttm & lab_order_dttm <= after_24hr) %>% 
  as.data.frame
duckdb_register(con, "icu_data_agg", icu_data_agg)

Lab_variables <- c('albumin', 'alkaline_phosphatase',
       'ast', 'basophil', 'bilirubin_conjugated', 'bilirubin_total', 'calcium',
       'chloride', 'hemoglobin', 'lymphocyte', 'monocyte', 'glucose_serum', 
       'neutrophil', 'potassium', 'sodium', 'total_protein','platelet_count', 
       'wbc')

icu_data_agg <- tbl(con, "icu_data_agg") %>% 
  group_by(encounter_id) %>%
  summarise(across(all_of(Lab_variables), list(
    min = ~min(., na.rm = TRUE), 
    max = ~max(., na.rm = TRUE), 
    mean = ~mean(., na.rm = TRUE)
  ), .names = "{.col}_{.fn}")) %>%
  ungroup() %>% collect() %>%   as.data.frame # Ensure no residual grouping

duckdb_unregister(con, "icu_data_agg")

# Merge aggregated data back into the original icu_data
icu_data <- left_join(icu_data, icu_data_agg, by = "encounter_id") %>%   as.data.frame

rm(icu_data_agg,pivoted_data,labs)
gc() 
### Model
dim(icu_data)

model_col <- c('isfemale', 'age', 'min_bmi', 'max_bmi', 'avg_bmi',
               'min_weight_kg', 'max_weight_kg', 'avg_weight_kg', 'min_pulse',
               'max_pulse', 'avg_pulse', 'min_sbp', 'max_sbp', 'avg_sbp', 'min_dbp',
               'max_dbp', 'avg_dbp', 'min_temp_c', 'max_temp_c', 'avg_temp_c',
               'albumin_min', 'albumin_max', 'albumin_mean',
               'alkaline_phosphatase_min', 'alkaline_phosphatase_max',
               'alkaline_phosphatase_mean', 'ast_min', 'ast_max', 'ast_mean',
               'basophil_min', 'basophil_max', 'basophil_mean',
               'bilirubin_conjugated_min', 'bilirubin_conjugated_max',
               'bilirubin_conjugated_mean', 'bilirubin_total_min',
               'bilirubin_total_max', 'bilirubin_total_mean', 'calcium_min',
               'calcium_max', 'calcium_mean', 'chloride_min', 'chloride_max',
               'chloride_mean', 'glucose_serum_min', 'glucose_serum_max',
               'glucose_serum_mean', 'hemoglobin_min', 'hemoglobin_max',
               'hemoglobin_mean', 'lymphocyte_min', 'lymphocyte_max',
               'lymphocyte_mean', 'monocyte_min', 'monocyte_max', 'monocyte_mean',
               'neutrophil_min', 'neutrophil_max', 'neutrophil_mean',
               'platelet_count_min', 'platelet_count_max', 'platelet_count_mean',
               'potassium_min', 'potassium_max', 'potassium_mean', 'sodium_min',
               'sodium_max', 'sodium_mean', 'total_protein_min', 'total_protein_max',
               'total_protein_mean', 'wbc_min', 'wbc_max', 'wbc_mean')


model_file_path <- sprintf("%s/projects/Mortality_model/models/lgbm_model_20240628-092136.txt", tables_location)

# Load the model
model <- lgb.load(model_file_path)
#### Feature Distribution
generate_facetgrid_histograms <- function(data, category_column, value_column) {
  p <- ggplot(data, aes_string(x = value_column)) +
    geom_histogram(bins = 30, fill = 'blue', color = 'black') +
    facet_wrap(as.formula(paste('~', category_column)), scales = 'free') +
    labs(x = value_column, y = 'Frequency') +
    theme(strip.text = element_text(face = 'bold', size = 10),
          plot.title = element_text(hjust = 0.5, size = 16))

  p <- p + ggtitle(paste('Histograms of', value_column, 'by', category_column))
  
  print(p)
}


# Important features list
imp_features_split <- c(
  "age", "min_pulse", "max_pulse", "max_temp_c", "max_sbp", "glucose_serum_min",
  "avg_temp_c", "sodium_max", "min_dbp", "platelet_count_min", "min_temp_c",
  "min_sbp", "avg_sbp", "avg_pulse", "wbc_min", "glucose_serum_mean",
  "alkaline_phosphatase_max", "hemoglobin_min", "ast_max", "avg_dbp"
)

# Assuming icu_data is your data frame and output_directory, site_name are defined
data_unstack <- melt(icu_data[imp_features_split], variable.name = 'imp_features_split', value.name = 'value')

# Generate the facet grid histograms
generate_facetgrid_histograms(data_unstack, 'imp_features_split', 'value')

data_summary <- data_unstack %>%
  group_by(imp_features_split) %>%
  summarise(count = n(), 
            mean = mean(value, na.rm = TRUE),
            std = sd(value, na.rm = TRUE), 
            min = min(value, na.rm = TRUE), 
            `25%` = quantile(value, 0.25, na.rm = TRUE), 
            `50%` = median(value, na.rm = TRUE), 
            `75%` = quantile(value, 0.75, na.rm = TRUE), 
            max = max(value, na.rm = TRUE))

data_summary_t <- data_summary %>%
  pivot_longer(cols = -imp_features_split, names_to = 'statistic', values_to = 'value') %>%
  pivot_wider(names_from = imp_features_split, values_from = value)

write.csv(data_summary_t, sprintf("output/imp_features_split_stats_%s.csv", site), row.names = FALSE)


data_summary_t

# Important features list
imp_features_gain <- c(
  "albumin_min", "min_pulse", "ast_mean", "sodium_max", "age", "min_dbp", 
  "min_sbp", "max_pulse", "avg_temp_c", "ast_max", "max_temp_c", "max_sbp", 
  "platelet_count_min", "min_temp_c", "glucose_serum_min", "glucose_serum_max", 
  "wbc_mean", "wbc_min", "albumin_mean", "glucose_serum_mean"
)

# Unstack the data
data_unstack <- melt(icu_data[imp_features_gain], variable.name = 'imp_features_gain', value.name = 'value')

# Generate and display the histograms
generate_facetgrid_histograms(data_unstack, 'imp_features_gain', 'value')

# Perform summarization on data_unstack
data_summary <- data_unstack %>%
  group_by(imp_features_gain) %>%
  summarise(count = n(), 
            mean = mean(value, na.rm = TRUE),
            std = sd(value, na.rm = TRUE), 
            min = min(value, na.rm = TRUE), 
            `25%` = quantile(value, 0.25, na.rm = TRUE), 
            `50%` = median(value, na.rm = TRUE), 
            `75%` = quantile(value, 0.75, na.rm = TRUE), 
            max = max(value, na.rm = TRUE))

# Transpose the data_summary
data_summary_t <- data_summary %>%
  pivot_longer(cols = -imp_features_gain, names_to = 'statistic', values_to = 'value') %>%
  pivot_wider(names_from = imp_features_gain, values_from = value)

# Save the transposed summary statistics to a CSV file
write.csv(data_summary_t, sprintf("output/imp_features_gain_stats_%s.csv", site), row.names = FALSE)
data_summary
### Probablity table
X_test <- as.matrix(icu_data[model_col])
y_test <- factor(icu_data$isdeathdispo)  
y_pred_proba <- predict(model, X_test)
y_pred_class <- as.numeric(y_pred_proba > 0.208)
icu_data$pred_proba <- y_pred_proba

site_label <- y_test
site_proba <- y_pred_proba
site_name <- rep(site, length(site_label))
prob_df_lgbm <- data.frame(site_label, site_proba, site_name)
# write.csv(prob_df_lgbm, file = paste0("output/Model_probabilities_", site, ".csv"), row.names = FALSE)
head(prob_df_lgbm)
# Do Not share this file
### Metrics

# Ensure y_test is numeric
y_test <- as.numeric(as.character(y_test))
predicted_probabilities <- as.numeric(as.character(y_pred_proba))

# Function to calculate metrics
calculate_metrics <- function(predicted_probabilities, predicted_classes, y_test) {
  conf_matrix <- confusionMatrix(as.factor(predicted_classes), as.factor(y_test))
  
  accuracy <- conf_matrix$overall['Accuracy']
  roc_auc <- pROC::auc(pROC::roc(y_test, predicted_probabilities))
  
  tp <- sum(predicted_classes == 1 & y_test == 1, na.rm = TRUE)
  fp <- sum(predicted_classes == 1 & y_test == 0, na.rm = TRUE)
  fn <- sum(predicted_classes == 0 & y_test == 1, na.rm = TRUE)
  tn <- sum(predicted_classes == 0 & y_test == 0, na.rm = TRUE)
  
  recall <- ifelse((tp + fn) > 0, tp / (tp + fn), 0)
  precision <- ifelse((tp + fp) > 0, tp / (tp + fp), 0)
  brier_score <- mean((predicted_probabilities - y_test)^2, na.rm = TRUE)
  
  return(c(accuracy, recall, precision, roc_auc, brier_score))
}

# Bootstrapping to calculate 95% confidence intervals
set.seed(123)
n_iterations <- 1000
metrics <- matrix(NA, ncol = 5, nrow = n_iterations)
colnames(metrics) <- c("Accuracy", "Recall", "Precision", "ROC AUC", "Brier Score Loss")

for (i in 1:n_iterations) {
  sample_indices <- sample(1:length(y_test), replace = TRUE)
  y_test_sample <- y_test[sample_indices]
  predicted_probabilities_sample <- predicted_probabilities[sample_indices]
  predicted_classes_sample <- as.integer(predicted_probabilities_sample >= 0.208)
  
  metrics[i, ] <- calculate_metrics(predicted_probabilities_sample, predicted_classes_sample, y_test_sample)
}

# Calculate mean and 95% confidence intervals
mean_metrics <- apply(metrics, 2, mean, na.rm = TRUE)
ci_lower <- apply(metrics, 2, function(x) quantile(x, 0.025, na.rm = TRUE))
ci_upper <- apply(metrics, 2, function(x) quantile(x, 0.975, na.rm = TRUE))

# Combine results into a data frame
results_metric <- data.frame(
  Metric = c('Accuracy', 'Recall', 'Precision', 'ROC AUC', 'Brier Score Loss'),
  Value = mean_metrics,
  CI_Lower = ci_lower,
  CI_Upper = ci_upper,
  SiteName = rep(site, 5)
)

# Export to CSV
write.csv(results_metric, sprintf("output/result_metrics_2_%s.csv", site), row.names = FALSE)

# Print the results
results_metric
#### model fairness test accross 'race', 'ethnicity', 'sex'

calculate_metrics <- function(data, true_col, pred_prob_col, subgroup_cols, threshold = 0.208) {
  results <- list()
  total_count <- nrow(data)
  
  for (subgroup_col in subgroup_cols) {
    # Filter out rows with NA in the current subgroup column
    filtered_data <- data %>% filter(!is.na(.data[[subgroup_col]])) %>% drop_na(.data[[true_col]], .data[[pred_prob_col]])
    
    # Loop over unique groups in the subgroup column
    for (group in unique(filtered_data[[subgroup_col]])) {
      subgroup_data <- filtered_data %>% filter(.data[[subgroup_col]] == group)
      group_count <- nrow(subgroup_data)
      proportion <- group_count / total_count
      
      # Check if there are at least two distinct classes and no NA in predictor
      if (length(unique(subgroup_data[[true_col]])) > 1 && sum(!is.na(subgroup_data[[pred_prob_col]])) == nrow(subgroup_data)) {
        # Calculate AUC
        pred <- prediction(subgroup_data[[pred_prob_col]], subgroup_data[[true_col]])
        auc <- performance(pred, "auc")@y.values[[1]]
        # Calculate confusion matrix
        cm <- table(factor(subgroup_data[[true_col]], levels = c(0, 1)),
                    factor(as.numeric(subgroup_data[[pred_prob_col]] > threshold), levels = c(0, 1)))
        tn <- cm[1, 1]
        fp <- cm[1, 2]
        fn <- cm[2, 1]
        tp <- cm[2, 2]
        
        sensitivity <- ifelse((tp + fn) != 0, tp / (tp + fn), 0)
        specificity <- ifelse((tn + fp) != 0, tn / (tn + fp), 0)
        ppv <- ifelse((tp + fp) != 0, tp / (tp + fp), 0)
        npv <- ifelse((tn + fn) != 0, tn / (tn + fn), 0)
        recall <- sensitivity
        acc <- ifelse((tp + fn + tn + fp) != 0, (tp + tn) / (tp + fn + tn + fp), 0)
        bri <- mean((subgroup_data[[pred_prob_col]] - subgroup_data[[true_col]])^2)

        result <- list(
          Subgroup = subgroup_col, Group = group,TP=tp,TN=tn,FP=fp,FN=fn, AUC = auc, PPV = ppv, Sensitivity = sensitivity,
          Specificity = specificity, NPV = npv, Recall = recall, Accuracy = acc,Brier = bri,
          GroupCount = group_count, TotalCount = total_count, Proportion = proportion
        )
      } else {
        result <- list(
          Subgroup = subgroup_col, Group = group,TP='NA',TN='NA',FP='NA',FN='NA', AUC = 'Not defined', PPV = 'Not applicable', Sensitivity = 'Not applicable',
          Specificity = 'Not applicable', NPV = 'Not applicable', Recall = 'Not applicable', Accuracy = 'Not applicable',Brier = 'NA',
          GroupCount = group_count, TotalCount = total_count, Proportion = proportion
        )
      }
      
      results <- c(results, list(result))
    }
  }
  
  # Convert the list of results to a data frame
  results_df <- do.call(rbind, lapply(results, as.data.frame))
  return(results_df)
}

# Example usage
result_df <- calculate_metrics(icu_data, 'isdeathdispo', 'pred_proba', c('race', 'ethnicity', 'sex'))
write.csv(result_df, file = paste0("output/fairness_test_", site, ".csv"), row.names = FALSE)

result_df
### Site Thr Analysis
top_n_percentile <- function(target_var, pred_proba, site_name) {
  # Generating thresholds from 99% to 1%
  thr_list <- seq(0.99, 0.01, by = -0.01)
  results <- data.frame(N_Percentile = character(),
                        Thr_Value = numeric(),
                        TN = integer(),
                        FP = integer(),
                        FN = integer(),
                        TP = integer(),
                        Sensitivity = numeric(),
                        Specificity = numeric(),
                        PPV = numeric(),
                        NPV = numeric(),
                        Recall = numeric(),
                        Accuracy = numeric(),
                        Site_Name = character(),
                        stringsAsFactors = FALSE)
  
  for (thr in thr_list) {
    prob <- data.frame(target_var = target_var, pred_proba = pred_proba)
    thr_value <- quantile(prob$pred_proba, thr)
    prob$pred_proba_bin <- ifelse(prob$pred_proba >= thr_value, 1, 0)
    
    cm <- table(factor(prob$target_var, levels = c(0, 1)),
                factor(prob$pred_proba_bin, levels = c(0, 1)))
    tn <- cm[1, 1]
    fp <- cm[1, 2]
    fn <- cm[2, 1]
    tp <- cm[2, 2]
    
    sensitivity <- tp / (tp + fn)
    specificity <- tn / (tn + fp)
    ppv <- tp / (tp + fp)
    npv <- tn / (tn + fn)
    recall <- tp / (tp + fn)
    acc <- (tp + tn) / sum(cm)
    n_prec <- paste0("Top ", round((1 - thr) * 100, 0), "%")
    
    # Define each row as a dataframe before appending
    row <- data.frame(N_Percentile = n_prec,
                      Thr_Value = thr_value,
                      TN = tn,
                      FP = fp,
                      FN = fn,
                      TP = tp,
                      Sensitivity = sensitivity,
                      Specificity = specificity,
                      PPV = ppv,
                      NPV = npv,
                      Recall = recall,
                      Accuracy = acc,
                      Site_Name = site_name,
                      stringsAsFactors = FALSE)
    results <- rbind(results, row)
  }
  return(results)
}

# Usage example (you need to define y_test, y_pred_proba, and site_name)
topn <- top_n_percentile(y_test, y_pred_proba, site)

write.csv(topn, file =  paste0("output/Top_N_percentile_PPV_", site, ".csv"), row.names = FALSE)
head(topn,5)

#### Rush THR Top N
thr<-0.208
# Define column names
col <- c('Thr_Value', 'TN', 'FP', 'FN', 'TP', 'Sensitivity', 'Specificity', 'PPV', 'NPV', 'Recall', 'Accuracy', 'Site_Name')

# Create an empty data frame with the specified columns
results <- data.frame(matrix(ncol = length(col), nrow = 0))
colnames(results) <- col

# Create a data frame with target_var and pred_proba
prob <- data.frame(target_var = y_test, pred_proba = y_pred_proba)

# Create pred_proba_bin based on the threshold
prob$pred_proba_bin <- ifelse(prob$pred_proba >= thr, 1, 0)

# Calculate confusion matrix
cm <- table(factor(prob$target_var, levels = c(0, 1)),
            factor(prob$pred_proba_bin, levels = c(0, 1)))
tn <- cm[1, 1]
fp <- cm[1, 2]
fn <- cm[2, 1]
tp <- cm[2, 2]

# Calculate metrics
sensitivity <- tp / (tp + fn)
specificity <- tn / (tn + fp)
ppv <- tp / (tp + fp)
npv <- tn / (tn + fn)
recall <- tp / (tp + fn)
acc <- (tp + tn) / sum(cm)

# Define each row as a dataframe before appending
row <- data.frame(Thr_Value = thr,
                  TN = tn,
                  FP = fp,
                  FN = fn,
                  TP = tp,
                  Sensitivity = sensitivity,
                  Specificity = specificity,
                  PPV = ppv,
                  NPV = npv,
                  Recall = recall,
                  Accuracy = acc,
                  Site_Name = site_name,
                  stringsAsFactors = FALSE)

# Append the row to the results data frame
results <- rbind(results, row)
write.csv(head(results,1), file =  paste0("output/Top_N_percentile_atRushThr_", site, ".csv"), row.names = FALSE)
head(results,1)
create_calibration_data <- function(y_test, y_pred_proba, n_bins = 10) {

  df <- data.frame(y_test = y_test, y_pred_proba = y_pred_proba)

  df$bin <- cut(df$y_pred_proba, breaks = n_bins, labels = FALSE, include.lowest = TRUE)

  calibration_data <- df %>%
    group_by(bin) %>%
    summarise(
      predicted_prob = mean(y_pred_proba),
      actual_prob = mean(y_test),
      n = n(),
      .groups = 'drop'
    ) %>%
    mutate(
      se = sqrt((actual_prob * (1 - actual_prob)) / n),
      lower_ci = actual_prob - 1.96 * se,
      upper_ci = actual_prob + 1.96 * se,
      site=site
    )
  
  return(calibration_data)
}


calibration_data <- create_calibration_data(as.numeric(y_test), y_pred_proba)

write.csv(calibration_data, file = paste0("output/calibration_data_", site, ".csv"), row.names = FALSE)

ggplot(calibration_data, aes(x = predicted_prob, y = actual_prob)) +
  geom_point() +
  geom_errorbar(aes(ymin = lower_ci, ymax = upper_ci), width = 0.02) +
  geom_smooth(method = "loess", se = FALSE) +
  labs(x = "Predicted Probability", y = "Actual Probability") +
  ggtitle("Calibration Plot with Confidence Intervals") +
  theme_minimal()

calibration_data
### AUC & PR curve
y_test <- factor(y_test, levels = c(0, 1))


roc_obj <- roc(y_test, y_pred_proba, levels = c(0, 1), direction = "<")
roc_auc <- auc(roc_obj)

pr_obj <- pr.curve(scores.class0 = y_pred_proba, weights.class0 = as.numeric(as.character(y_test)), curve = TRUE)
pr_auc <- pr_obj$auc.integral


roc_thresholds <- roc_obj$thresholds
if (length(roc_obj$sensitivities) != length(roc_thresholds)) {
  roc_thresholds <- c(roc_thresholds, 1)
}

roc_data <- data.frame(fpr = 1 - roc_obj$specificities, 
                       tpr = roc_obj$sensitivities, 
                       roc_thresholds = roc_thresholds,
                       site=site)
pr_data <- data.frame(precision = pr_obj$curve[,2], 
                      recall = pr_obj$curve[,1], 
                      pr_thresholds = pr_obj$curve[,3],
                      site=site)

write.csv(roc_data, file = paste0('output/roc_curve_data_', site, '.csv'), row.names = FALSE)
write.csv(pr_data, file = paste0('output/pr_curve_data_', site, '.csv'), row.names = FALSE)

par(mfrow = c(1, 2))

plot(roc_obj, col = 'blue', lwd = 2, main = 'Receiver Operating Characteristic (ROC) Curve', xlab = 'False Positive Rate', ylab = 'True Positive Rate')
abline(a = 0, b = 1, col = 'gray', lty = 2)
legend('bottomright', legend = paste('ROC curve (area =', round(roc_auc, 2), ')'), col = 'blue', lwd = 2)

plot(pr_obj$curve[,1], pr_obj$curve[,2], type = 'l', col = 'blue', lwd = 2, xlab = 'Recall', ylab = 'Precision', main = 'Precision-Recall (PR) Curve')
legend('bottomleft', legend = paste('PR curve (area =', round(pr_auc, 2), ')'), col = 'blue', lwd = 2)
