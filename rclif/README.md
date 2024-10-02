## Relational CLIF (RCLIF)

Save RCLIF flat files in your format of preference. We suggest you use the parquet file format. 
Adopt the following naming convention for seamless integration with CLIF project coding scripts: 

RCLIF Tables
* clif_patient.parquet
* clif_hospitalization.parquet
* clif_adt.parquet
* clif_admission_diagnosis.parquet
* clif_position.parquet
* clif_vitals.parquet
* clif_patient_assessments.parquet
* clif_labs.parquet
* clif_microbiology_culture.parquet
* clif_microbiology_nonculture.parquet
* clif_sensitivity.parquet
* clif_respiratory_support.parquet
* clif_ecmo_mcs.parquet
* clif_medication_orders.parquet
* clif_medication_admin_continuous.parquet
* clif_medication_admin_continuous.parquet
* clif_procedures.parquet
* clif_position.parquet
* clif_dialysis.parquet
* clif_intake_output.parquet
* clif_therapy_details.parquet

Notes: 
1. Please be careful not to push any data files to your remote github repository. 
2. Please ensure that the above tables have schema outlined in the [CLIF data dictionary](https://clif-consortium.github.io/website/data-dictionary.html). 
