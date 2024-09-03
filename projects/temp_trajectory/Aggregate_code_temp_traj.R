library(tidyverse)
install.packages("radiant.data")
library(radiant.data)
install.packages("remotes")
library(flipTime)

result_path <- "/Users/kavenchhikara/Desktop/CLIF/CLIF-1.0/projects/temp_trajectory/results"
umn <- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_UMN.csv"))
jh <-read_csv(paste0(result_path, "/df_temptraj_72_post_icu_JHU.csv"))
nw <- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_NU.csv"))
eu <- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_EU.csv"))
ucmc<- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_UCMC.csv"))
rush<- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_RUSH.csv"))
ohsu <- read_csv(paste0(result_path, "/df_temptraj_72_post_icu_ohsu.csv"))

eu$Site <- 'Emory University'
umn$Site <- 'University of Minnesota'
nw$Site <- 'Northwestern University'
jh$Site <- 'John Hopkins University'
ucmc$Site <- 'University of Chicago'
ohsu$Site <- 'Oregon Health & Science University'
rush$Site<- 'Rush University'


#### Aggregate Forrest Plot Data Pre-processing
combined_data <- bind_rows(eu, umn, jh, ucmc, nw, rush, ohsu)

graph_aggregate <- combined_data %>%
  mutate(order = case_when(
    Features == "HSR" ~ 1,
    Features == "HFR" ~ 2,
    Features == "HT" ~ 4,
    TRUE ~ NA_integer_ # Ensuring other features have NA assigned correctly
  )) %>%
  rbind(c("NT", 1, NA, NA, "Mechanical ventilation", 1, 1, "All Sites", 3)) %>%
  rbind(c("NT", 1, NA, NA, "Mortality", 1, 1, "All Sites",3)) %>%
  mutate(order = factor(order, levels = c(1, 2, 3, 4))) %>%
  mutate(`Odds ratio` = as.numeric(`Odds ratio`),
         upper = as.numeric(upper),
         lower = as.numeric(lower))

#### Forrest Plot
ggplot(graph_aggregate, aes(x = Site, y = `Odds ratio`, color = Features)) + 
  geom_point(position = position_dodge(width = 0.5), size = 3) + 
  geom_errorbar(aes(ymin = lower, ymax = upper), width = 0,
                position = position_dodge(width = 0.5)) +
  theme_classic() + xlab("") +
  scale_color_manual(values = c( "#336600","#FF9900",  "#0000FF", "#990000"),
                     name = "", 
                     labels = c("HFR", "HSR", "HT", "NT"),
                     guide = guide_legend()) +
  geom_hline(yintercept = 1.0) +
  coord_flip() +   
  facet_wrap(~ outcome)

#### Per Hour Data Processing

umn_perhour <- read_csv(paste0(result_path,"/table_temp_traj_cohort_UMN.csv"))
jh_perhour <- read_csv(paste0(result_path,"/table_temp_traj_cohort_JHU.csv"))
nw_perhour <- read_csv(paste0(result_path,"/table_temp_traj_cohort_NU.csv"))
eu_perhour <- read_csv(paste0(result_path,"/table_temp_traj_cohort_EU.csv"))
ucmc_perhour<- read_csv(paste0(result_path,"/table_temp_traj_cohort_UCMC.csv"))
rush_perhour<- read_csv(paste0(result_path,"/table_temp_traj_cohort_RUSH.csv"))
ohsu_perhour<- read_csv(paste0(result_path,"/table_temp_traj_cohort_ohsu.csv"))

# Need to add Michigan to this mapping
eu_perhour$Site <- 'Emory University'
umn_perhour$Site <- 'University of Minnesota'
nw_perhour$Site <- 'Northwestern University'
jh_perhour$Site <- 'John Hopkins University'
ucmc_perhour$Site <- 'University of Chicago'
ohsu_perhour$Site <- 'Oregon Health & Science University'
rush_perhour$Site<- 'Rush University'

# Combine the datasets 
combined_perhour_data <- bind_rows(nw_perhour, umn_perhour,eu_perhour, 
                                   jh_perhour, ucmc_perhour, rush_perhour, ohsu_perhour)%>%
  rename("Trajectory"="group") %>%
  mutate(Site = factor(Site, levels = c("Emory University",
                                        "Johns Hopkins University",
                                        "Northwestern University",
                                        "Oregon Health & Science University",
                                        "University of Chicago",
                                        "University of Michigan",
                                        "Rush University",
                                        "University of Minnesota")))

#### Average Temp per Hour Plot Across Sites
ggplot(combined_perhour_data, aes(x = hour, y = avg_temperature, color = Trajectory, linetype = Site, group = interaction(Trajectory, Site))) +
  geom_line() +  # This adds the line connecting the points
  scale_x_continuous(breaks = seq(0, 72, by = 12), limits = c(0, 72)) +  # X-Axis from 0 to 72 hours
  scale_color_manual(values = c("NT" = "#990000", "HFR" = "#336600", "HSR" = "#FF9900", "HT" = "#0000FF")) +  # Manually set colors
  labs(
    title = "Average Temperature Trend by Trajectory and Site",
    x = "Hour",
    y = "Average Temperature",
    color = "Trajectory",
    linetype = "Site"
  ) +
  theme_minimal() +  # Minimal theme to keep the focus on the data
  theme(
    axis.text.x = element_text(angle = 45, hjust = 1),  # Adjust text angle and position
    plot.title = element_text(hjust = 0.5)  # Center the plot title
  )
