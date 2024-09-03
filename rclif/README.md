## Relational CLIF (RCLIF)

Save RCLIF flat files in your format of preference. We suggest you use the parquet file format. 
Adopt the following naming convention for seamless integration with CLIF project coding scripts: 

RCLIF Tables
* clif_patient_encounters.parquet
* clif_limited_identifiers.parquet
* clif_patient_demographics.parquet
* clif_encounter_demographics_dispo.parquet
* clif_admission_diagnosis.parquet
* clif_vitals.parquet
* clif_scores.parquet
* clif_labs.parquet
* clif_microbiology.parquet
* clif_sensitivity.parquet
* clif_respiratory_support.parquet
* clif_ecmo_mcs.parquet
* clif_medication_orders.parquet
* clif_medication_admin_continuous.parquet
* clif_medication_admin_continuous.parquet
* clif_procedures.parquet
* clif_adt.parquet
* clif_prone.parquet
* clif_dialysis.parquet
* clif_intake_output.parquet

Notes: 
1. Please be careful not to push any data files to your remote github repository. 
2. Please ensure that the above tables have schema outlined in the CLIF data dictionary. Refer the sample_RCLIF repository for reference.
