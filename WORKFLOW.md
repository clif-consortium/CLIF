# CLIF Project Workflow Documentation

This document outlines the standardized workflow for Extract, Transform, Load (ETL) processes and project execution within the CLIF consortium. Adhering to these guidelines ensures consistency, data quality, and efficient collaboration across all participating sites.

---

## Table of Contents

1. [ETL Workflow](#etl-workflow)
   - [Table Schema Approval](#table-schema-approval)
   - [ETL Best Practices](#etl-best-practices)
   - [Data Quality Checks](#data-quality-checks)
2. [Project Workflow](#project-workflow)
   - [Project Proposal and Sign-Up](#project-proposal-and-sign-up)
   - [Repository Setup](#repository-setup)
   - [Environment Configuration](#environment-configuration)
   - [Data Privacy and Security](#data-privacy-and-security)
   - [Project Code Structure](#project-code-structure)
3. [Additional Guidelines](#additional-guidelines)
   - [Communication and Collaboration](#communication-and-collaboration)
   - [Documentation Standards](#documentation-standards)
   - [Version Control](#version-control)
  

---

## ETL Workflow

### Table Schema Approval

- **Point of Contact (POC) Responsibility**:
  - Before initiating the ETL process, the table schema must be reviewed and approved by the respective POC.
  - The POC is responsible for addressing all issues related to their assigned table.
  - They should collaborate with other consortium members as needed to resolve queries and close issues promptly.

### ETL Best Practices

- **Data Mapping**:
  - Accurately map raw Electronic Health Record (EHR) data fields to the corresponding CLIF format fields.
  - Ensure consistency in data types and formats across all tables. Refer to the most updated version of the [CLIF data dictionary ](https://clif-consortium.github.io/website/data-dictionary.html)
  - Refer to the official CLIF minimum Common ICU Data Elements (mCIDE) [here](https://github.com/clif-consortium/CLIF/tree/main/mCIDE)

- **Source Data MetaData**:
  - Document the description of source metadata. This includes:
        - source name (site specific CRDW, or EPIC Clarity/ Caboodle); 
        - cohort details- number of unique encounters, number of hospitals;
        - data range;
        - number of ICU beds;

### Data Quality Checks

- **Validation**:
  - After ETL, validate the data against the approved schema to ensure all fields are correctly populated.
  - Check for adherence to expected data types, formats, and value ranges. Refer to this [directory](https://github.com/clif-consortium/CLIF/tree/main/outlier-handling) for approved thresholds to handle outliers.

- **Quality Control (QC)**:
  - Perform QC checks to identify inconsistencies, anomalies, or outliers.
  - Review variable distributions and assess data completeness and missingness patterns.

- **Approval for Analysis**:
  - Submit the transformed and validated tables for final approval by the site PI before proceeding to analysis.

---

## Project Workflow

### Project Proposal and Sign-Up

- **Proposal Submission**:
  - Share a detailed project proposal outlining:
    - Required CLIF tables.
    - Cohort requirements.
    - Analysis plan and objectives.
  - Use the standardized proposal template provided by the consortium.

- **Participation Sign-Up**:
  - Allocate 5-7 days for consortium sites to review the proposal and sign up to participate.
  - Encourage feedback and discussions to address any concerns or suggestions.

### Repository Setup

- **Template Utilization**:
  - Use the [project template repository](https://github.com/clif-consortium/project-template/blob/main/README.md) to create project-specific repositories.
  - Ensure the repository follows the standardized structure for consistency across projects.

- **Collaborator Addition**:
  - Add all participating site members and relevant stakeholders as collaborators to the repository.
  - Assign appropriate access permissions based on roles.

### Environment Configuration

- **Environment File Creation**:
  - Create an environment file (e.g., `environment.yml` for Conda or `requirements.txt` for pip or `renv` for R) specifying all dependencies.
  - Include specific version numbers to ensure reproducibility.

- **Setup Instructions**:
  - Provide clear instructions in the repository's README on how to set up the environment.
  - Mention any platform-specific considerations or prerequisites.

### Data Privacy and Security

- **Protected Health Information (PHI)**:
  - **Do not share any PHI** in analysis scripts or as part of project outputs.
  - Ensure all data handling complies with HIPAA and other relevant regulations.

- **Data Sharing Restrictions**:
  - Patient-level data should not be shared across consortium sites.
  - Only share aggregated results that have been reviewed to prevent potential re-identification.

### Project Code Structure

The project code should be organized into three main components:

1. **Quality Control (QC) Scripts**:
   - **Purpose**: Verify that required tables, variables, and mCIDE categories are available and correctly formatted.
   - **Actions**:
     - Confirm variable data types align with expectations.
     - Assess data distributions for anomalies.
     - Evaluate missingness and address accordingly.

2. **Cohort Identification Script**:
   - **Purpose**: Define and identify the cohort of encounters required for analysis.
   - **Output**: A list of `hospitalization_id`s corresponding to the selected cohort.
   - **Actions**:
     - Apply inclusion and exclusion criteria as per the analysis plan.
     - Document the cohort selection process for transparency.

3. **Analysis Script(s)**:
   - **Purpose**: Execute project-specific analyses.
   - **Structure**:
     - Can consist of one or multiple scripts/modules.
     - Should be modular to facilitate testing and reuse.
   - **Actions**:
     - Implement statistical models, visualizations, and other analytical methods.
     - Include comments and documentation for clarity.

---

## Additional Guidelines

### Communication and Collaboration

- **Regular Meetings**:
  - Discuss project updates during the recurring CLIF WG Meetings on Thursdays 2 pm CST. If required, schedule periodic meetings to discuss progress, challenges, and next steps.
  - Create a project specific channel on CLIF Slack Workspace to facilitate communication.

- **Issue Tracking**:
  - Utilize the repository's issue tracker for reporting bugs, feature requests, or questions.
  - Assign issues to specific team members and set appropriate labels and milestones.

- **Documentation**:
  - Maintain up-to-date documentation within the repository, including a detailed README and wiki pages if necessary.

### Documentation Standards

- **Code Documentation**:
  - Include docstrings and inline comments in scripts and functions.

- **Project Documentation**:
  - Update the repository's README with:
    - Project overview and objectives.
    - Setup instructions.
    - How to run scripts and interpret outputs.
  - Provide a changelog to document updates and revisions.

### Version Control

- **Git Practices**:
  - Commit changes frequently with clear, descriptive messages.
  - Use branches for developing new features or making significant changes.
  - Merge branches only after thorough testing and code review.

- **Code Reviews**:
  - Encourage peer reviews to ensure code quality and knowledge sharing. Choose another site to run the code before releasing the code to the entire consortium.
  - Use pull requests to facilitate discussions around changes.

---


**For any questions or clarifications, please email clif_consortium@uchicago.edu.**
