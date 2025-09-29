# DunedinPACE Docker Guide

This repository is a fork that adds a Docker-based execution option to the original DunedinPACE project:

- https://github.com/danbelsky/DunedinPACE

All original license terms remain unchanged.


---

## Quick start

Prerequisites: Docker installed and running.

1) Build the image (first time)

```sh
# From the repository root
docker build -t dunedinpace:local .
# On Apple Silicon (M1/M2), if you see a platform error:
# docker build --platform linux/amd64 -t dunedinpace:local .
```

2) Run on the included example dataset

```sh
mkdir -p output
docker run --rm \
  -v "$PWD/data":/data \
  -v "$PWD/output":/output \
  dunedinpace:local \
  -i /data/example_betas.rda \
  -o /output/dunedinpace.tsv
# If you built linux/amd64 on Apple Silicon and want to enforce it at runtime:
# docker run --rm --platform linux/amd64 -v "$PWD/data":/data -v "$PWD/output":/output \
#   dunedinpace:local -i /data/example_betas.rda -o /output/dunedinpace.tsv
```

3) Run on your data (RDS / CSV / TSV)

```sh
# RDS with a matrix/data.frame (rows = probes, cols = samples)
docker run --rm -v "$PWD":/data -v "$PWD/output":/output \
  dunedinpace:local -i /data/my_betas.rds -o /output/dunedinpace.tsv

# CSV with comma; first column = probe IDs (rowname)
docker run --rm -v "$PWD":/data -v "$PWD/output":/output \
  dunedinpace:local -i /data/betas.csv --sep comma --rowname-column 1 -o /output/dunedinpace.tsv

# TSV with tab and samples in rows (transpose on load)
docker run --rm -v "$PWD":/data -v "$PWD/output":/output \
  dunedinpace:local -i /data/betas.tsv --sep tab --rowname-column 1 --transpose -o /output/dunedinpace.tsv
```

How it works

- Entry point: `Rscript /usr/local/bin/run_pace.R` (pass flags as above).
- Volumes: mount inputs at `/data`, results are written to `/output`.
- Output: TSV with models in columns and samples in rows; default path is `/output/dunedinpace.tsv`.

Common flags

- `-i, --input`: input file (.rds, .rda/.RData, .csv, .tsv, .txt)
- `-o, --output`: output TSV path (default `/output/dunedinpace.tsv`)
- `-p, --proportionOfProbesRequired`: minimum non-missing proportion (0–1). If EPICv2 is detected, it is set to 0.7
  automatically.
- `--sep`: for text files: `auto`, `comma`, `tab`, `semicolon`
- `--rowname-column`: 1-based column index with probe IDs in CSV/TSV (use 0 to keep as-is)
- `--transpose`: set if your samples are in rows and probes in columns

Notes

- EPICv2 detection is automatic (based on replicate suffixes in row names); the proportion threshold is lowered to 0.7
  accordingly.
- Ensure row names are Illumina probe IDs (cg##########). Missing values should be coded as `NA`.
- The first build downloads CRAN/Bioconductor dependencies and requires internet access.

## Interactive Shell Access

To explore model data, run interactive R commands, or develop Python versions, you can access a shell inside the
container:

### Interactive bash shell access

```sh
docker run --rm -it \
  -v "$PWD":/data \
  -v "$PWD/output":/output \
  --entrypoint /bin/bash \
  dunedinpace:local
```

### Direct interactive R access

```sh
docker run --rm -it \
  -v "$PWD":/data \
  -v "$PWD/output":/output \
  --entrypoint R \
  dunedinpace:local
```

### Examples of useful commands inside the container

Once inside the shell, you can run:

```r
# Load the DunedinPACE library
library(DunedinPACE)

# Examine the structure of the models
load('/usr/local/src/DunedinPACE/R/sysdata.rda')
str(mPACE_Models)

# View available model names
names(mPACE_Models)

# Examine number of probes per model
sapply(mPACE_Models$model_probes, length)

# View the first probes of the DunedinPACE model
head(mPACE_Models$model_probes$DunedinPACE)

# Export model data to CSV files
write.csv(mPACE_Models$model_probes$DunedinPACE, '/output/model_probes.csv')
write.csv(mPACE_Models$model_weights$DunedinPACE, '/output/model_weights.csv')
```

## Troubleshooting

- Platform errors on Apple Silicon: build and/or run with `--platform linux/amd64`.
- Memory: large cohorts may need more RAM; increase resources in Docker Desktop settings.
- Row names missing: include probe IDs as row names (or set `--rowname-column` when using CSV/TSV).
- NA parsing: set `--na` to include any additional missing-value strings in CSV/TSV.
