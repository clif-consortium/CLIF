# Temperature trajectory subphenotypes

## Objective
Retrospective multi-hospital study using the CLIF framework to analyse the hospital wide differences in subphenotypes' independent relationships with hospital mortality and bloodstream infection using multivariable models. The models are published in an existing study - [Temperature Trajectory Subphenotypes in Oncology Patients with Neutropenia and Suspected Infection](https://pubmed.ncbi.nlm.nih.gov/36449534/)

## RCLIF Tables required

* **patient_demographics** (`encounter_id`, `race`, `ethnicity`, `sex`)
* **encounter_demographics_dispo** (`encounter_id`, `age_at_admission`, `disposition_category`)
* **limited_identifiers** (`encounter_id`, `admission_dttm`)
* **adt** (`encounter_id`, `location_category`, `in_dttm`, `out_dttm`)
* **respiratory_support** (`encounter_id`, `recorded_dttm`, `device_category`)
* **vitals** (`encounter_id`, `recorded_dttm`, `vital_category`, `vital_value`) 
    * `vital_category` must include  `temp_c`


Follow the schema laid out in the [RCLIF ERD](https://github.com/kaveriC/CLIF-1.0/tree/main/sample_RCLIF) for each of these tables. The naming convention for input files is provided [here](https://github.com/kaveriC/CLIF-1.0/tree/main/rclif)

## Setup instructions

**Step 1.** Run the `outlier_handler.R` script to replace outliers with NAs. This script is available in the rclif_qc directory. If you run the outlier scripts, then use the `_clean` version for `labs`, `vitals` and `encounter_demographics_dispo` tables.

**Step 2.** Run the `ICU_cohort_id_script.R` script to generate the `ICU_cohort.csv` that is used as an input to the analysis script.

**Step 3.** Run the `temp_traj_analysis.R` analysis script. The `ICU_cohort.csv` file generated from the cohort identification script is used as an input in this analysis script. This script generates and saves aggregate results in the current directory. 