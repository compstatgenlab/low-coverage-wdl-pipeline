# Low-coverage imputation WDL pipeline

Short WDL workflows to impute low-coverage sequencing data with GLIMPSE2.

## Contents
- `bcf_imputation.wdl` — Runs imputation for a single chromosome by scattering over chunk definitions; tasks: ImputeChunk (GLIMPSE2_phase) and Ligate (GLIMPSE2_ligate); outputs a per-chromosome BCF (`.bcf` + `.bcf.csi`) and logs/timings.
- `launch_imputation.wdl` — Master workflow that launches the single-chromosome workflow across a set of chromosomes and aggregates the per-chromosome outputs.
- `*.json` — Example inputs files for single-chromosome and whole-genome runs.

## Environment
- Validated on whole-genome runs in Google Cloud using the Cromwell workflow engine.
- Reference panel and other inputs can be provided as `gs://` paths.
- Tasks automatically fetch a Google Cloud OAuth token from the instance metadata server (GCS_OAUTH_TOKEN) so tools can stream from GCS without pre-downloading files.

## Docker requirements
The runtime image must contain:
- [GLIMPSE2](https://github.com/odelaneau/GLIMPSE) (GLIMPSE2_phase, GLIMPSE2_ligate, compiled inside the docker)
- `htslib` built with libcurl support (for authenticated HTTP/GCS streaming)
- `bcftools` (for indexing/concat, as needed)
- `curl` (metadata + remote access), `jq` (parse OAuth token), `time` (GNU time for timing)
- Standard GNU utilities used in commands: `coreutils`, `grep`, `sed`, `awk`, etc.

## Example usage (Cromwell)
Single chromosome:
- Inputs file: `bcf_imputation.json`
- Run: `java -jar cromwell.jar run bcf_imputation.wdl --inputs bcf_imputation.json`

Whole genome:
- Inputs file: `launch_imputation.json`
- Run: `java -jar cromwell.jar run launch_imputation.wdl --inputs launch_imputation.json`

Outputs are written as `<output_prefix>_chr<chr>.bcf` (+ `.bcf.csi`) with accompanying log and timing files.
