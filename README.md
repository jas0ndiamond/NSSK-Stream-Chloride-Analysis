# NSSK Stream Chloride Analysis

This analysis describes the occurrence and severity of road salt contamination events in freshwater streams of North Vancouver, BC. It is part of the [Road Salt and Pacific Salmon Success Project](https://www.theroadsaltproject.com), which aims to describe the effects of road salt contamination on streams across the Vancouver Lower Mainland, BC. 

Original analysis code by [Clare L. Kilgour](https://github.com/clarekilgour).

---

## Overview

**[BRIEF DESCRIPTION OF THE MONITORING CONTEXT — E.G. WATERSHED, TIME PERIOD, REGULATORY BACKGROUND]**

**[BRIEF DESCRIPTION OF WHAT THE ANALYSIS PRODUCES — E.G. PULSE DETECTION, EXCEEDANCE RISK, SUMMARY PLOTS]**

## Methodology

This analysis uses high-frequency specific conductance data from water quality data loggers installed in Wagg Creek. The specific conductance data is used to estimate chloride concentrations using a conversion equation developed based on ion measurements in grab samples collected at a proximate local stream (Stoney Creek; R. U. Kistritz Consultants Ltd., 2016). The calculated chloride concentrations are compared to the provincial guidelines for chloride (Chronic = 150 mg/L Cl-, Acute = 600 mg/L Cl-). 

Pulses of road salt inputs were identified using each of the provincial guidelines as thresholds. The start of a pulse was identified when the calculated chloride concentration exceeded the guideline of interest for more than one hour. The pulse ended when the specific conductance readings again dropped below the water quality guideline of interest. Consecutive exceedances of the given guideline that are separated by less than one hour were considered one pulse. 

**[DISCUSS 5-in-30 SIMULATION, PROBABILITY OF EXCEEDANCE]**

Further details about the methods of the analysis can be found in Kilgour et al. (2025).

## Setup

See [SETUP.md](SETUP.md) for installation instructions for Mac, Unix, and Windows.

## Running the Analysis

See [RUN.md](RUN.md) for instructions on running headlessly with `Rscript` or interactively in RStudio.

## Input

Input is an CSV export of the [DFO PSEC Community Stream Monitoring (CoSMo)](https://datastream.org/en-ca/dataset/4c8d3691-99e5-4fa9-ad09-da077baa37c5) dataset (DOI: [10.25976/0gvo-9d12](https://doi.org/10.25976/0gvo-9d12)). CoSMo is a collaborative initiative collecting long-term water quality data for resource management and stewardship across southwest British Columbia, led by Fisheries and Oceans Canada (DFO) Pacific Science Enterprise Centre (PSEC).

This analysis uses monitoring locations WAGG01 and WAGG03 (Wagg Creek). The following columns must be present in the input CSV:

| Column | Description |
|---|---|
| `MonitoringLocationID` | Site identifier — analysis filters to `WAGG01` and `WAGG03` |
| `MonitoringLocationName` | Human-readable site name |
| `MonitoringLocationLatitude` | Site latitude |
| `MonitoringLocationLongitude` | Site longitude |
| `MonitoringLocationType` | Location type (e.g. `River/Stream`) |
| `ActivityType` | Measurement activity type |
| `ActivityMediaName` | Sample medium (e.g. `Surface Water`) |
| `ActivityStartDate` | Measurement date (`YYYY-MM-DD`) |
| `ActivityStartTime` | Measurement time (`HH:MM:SS`) |
| `SampleCollectionEquipmentName` | Instrument used |
| `CharacteristicName` | Parameter name — analysis uses `Specific conductance` and `Temperature, water` |
| `ResultValue` | Measured value |

## Outputs

Each run produces a parent output directory containing the following resources:

| Path | Contents |
|---|---|
| `02 Data/Wagg.csv` | Filtered monitoring data for WAGG01 and WAGG03 |
| `02 Data/WaggSTAPulses.csv` | Detected short-term acute pulse events |
| `02 Data/WaggLTCPulses.csv` | Detected long-term chronic pulse events |
| `03 Outputs/WaggSurfaceWaterChloride2022-25.png` | Conductance and chloride time series |
| `03 Outputs/WaggSurfaceWaterChloride2021-25CircledPulses.png` | Time series with pulse events marked |
| `03 Outputs/WaggPulseTypes.png` | Pulse counts by month and type |
| `03 Outputs/WAGG01PulseSummaryTable.png` | Pulse summary table — WAGG01 |
| `03 Outputs/WAGG03PulseSummaryTable.png` | Pulse summary table — WAGG03 |
| `03 Outputs/OddsofLTCExceedbyMonthTraceWagg.png` | Monthly exceedance risk overlay |
| `combined_results.csv` | Bootstrap exceedance results by location and month |

## Further Reading

- [Kilgour et al. 2025. Tracking road salt contamination through community monitoring: Annual surface water chloride trends in streams of an urban area, the Vancouver Lower Mainland, B.C., Canada.](https://link.springer.com/article/10.1007/s00244-025-01156-3) 
- [Winter et al. 2026. The effects of pulse exposures to road salt at various stages of early development in rainbow trout (_Oncorhychus mykiss_)](https://www.sciencedirect.com/science/article/pii/S1532045625002157)
- [Winter et al. 2026. Road salt creates a slippery slope for Pacific salmon: environmentally realistic salt pulses have lethal and sublethal effects on developing coho salmon (_Oncorhynchus kisutch_)](https://www.sciencedirect.com/science/article/pii/S0166445X26000330)

## License

MIT — see [LICENSE](LICENSE).
