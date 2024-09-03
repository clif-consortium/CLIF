# mCIDE: minimum Common ICU Data Elements for CLIF

The CLIF format and federated research approach aspires to adhere to the [2023 NIH Data Management and Sharing Policy](https://sharing.nih.gov/data-management-and-sharing-policy/about-data-management-and-sharing-policies/data-management-and-sharing-policy-overview#after) and the [FAIR (Findable Accessible Interoperable Resuable) data principles](https://www.go-fair.org/fair-principles/).

Common Data Element (CDEs) "are data elements (or variables) that are defined and used the same way across multiple studies, to standardize the way data is collected"

We have constructed a minimum set of Common ICU Data Elements (mCIDE) for a CLIF database. CIDEs have the following features

1.  represents a precisely defined clinical entity
2.  limited set of permissible values

`*_category` variables are CIDEs. Whenever possible, we chose CIDEs directly from the [NIH CDE Repository](https://cde.nlm.nih.gov/home).

## Example: mode of mechanical ventilation

**CIDE field**: `mode_category`

**Definition**: Type of mode of mechanical ventilation (inclusive of both non-invasive and invasive)

**Likely location in EHR**: respiratory therapy flowsheet documentation, e.g. "RT RS CONVENTIONAL VENT MODES"

**store source EHR string**: `mode_name`

**Permissible values**:

| Label                            | Definition                                                                                                                                                                    | Typical EHR representations    |
|----------------------------------|-------------------------------------------------------------------------------------------------------------------------------------------------------------------------------|--------------------------------|
| Assist Control-Volume Control    | delivery of `tidal_volume_set` during inspiration at a minimum `resp_rate_set`                                                                                                    | "A/C Volume", "VCV", "CMV"     |
| Pressure Control                 | delivery of `pressure_control_set` during inspiration at a minimum `resp_rate_set`                                                                                                | "PCV", "A/C Pressure"          |
| Pressure Support/CPAP            | delivery of `pressure_support_set` during inspiration. No `resp_rate_set`. Note that `pressure_support_set` can be zero or missing in this mode, i.e. it is inclusive of Continuous Positive Airway Pressure (CPAP) only. | "PS/CPAP"                      |
| Pressure-Regulated Volume Control| adaptive targeting of inspiratory pressure to achieve tidal_volume_set during inspiration at a minimum `resp_rate_set`                                                           | "PRVC"                         |
| SIMV                             | Synchronized intermittent mandatory ventilation. delivery of `tidal_volume_set` during inspiration at a minimum `resp_rate_set`, breaths above the set rate are supported with `pressure_support_set`. | "SIMV - PC PS"                 |
| Other                            | Not well defined by the above, e.g. Neurally Adjusted Ventilatory Assist                                                                                                       | "NAVA"                         |

`*_name` variables are source EHR strings that can be retained in CLIF for research questions that may require them

Full description of each CIDE is available in the [CLIF data dictionary](https://kaveric.github.io/clif-consortium/data-dictionary.html). This folder contains `*_name` -\> `*_category` mapping tables designed to help sites ETL into CLIF and meet the minimum CIDE requirements.
