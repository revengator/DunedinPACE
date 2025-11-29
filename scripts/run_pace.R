#!/usr/bin/env Rscript
suppressPackageStartupMessages({
  library(optparse)
  library(DunedinPACE)
})

# Command line options definition
option_list <- list(
  make_option(c("-i", "--input"), type="character", help="Path to file with betas (RDS/RData/CSV/TSV)", metavar="FILE"),
  make_option(c("-o", "--output"), type="character", default="/output/dunedinpace.tsv", help="Output path (TSV). [default: %default]"),
  make_option(c("-p", "--proportionOfProbesRequired"), type="double", default=NA, help="Minimum proportion of probes present (0-1). If EPICv2 is detected, 0.7 will be used automatically."),
  make_option(c("--sep"), type="character", default="auto", help="Separator for plain text: auto, comma, tab, semicolon. [default: %default]"),
  make_option(c("--rowname-column"), type="integer", default=1L, help="Column (1-index) with probe IDs if file is CSV/TSV. If 0, won't move columns to rownames. [default: %default]"),
  make_option(c("--transpose"), action="store_true", default=FALSE, help="Transpose matrix when loading (use if you have samples in rows and probes in columns)."),
  make_option(c("--na"), type="character", default="NA", help="String to treat as NA in CSV/TSV. [default: %default]")
)

parser <- OptionParser(option_list=option_list, usage = "%prog -i <betas.(rds|rda|csv|tsv)> [-o output.tsv]")
opts <- parse_args(parser)

if (is.null(opts$input)) {
  print_help(parser)
  quit(status = 2)
}

# Flexible input reading
read_any <- function(path, sep = "auto", rowname_col = 1L, na_str = "NA") {
  stopifnot(file.exists(path))
  ext <- tolower(tools::file_ext(path))
  if (ext %in% c("rds")) {
    obj <- readRDS(path)
  } else if (ext %in% c("rda", "rdata")) {
    e <- new.env(parent=emptyenv())
    nm <- load(path, envir=e)
    if (length(nm) < 1) stop("RData file contains no objects")
    obj <- e[[nm[[1]]]]
  } else if (ext %in% c("csv", "tsv", "txt")) {
    sep_resolved <- switch(sep,
      auto = if (ext == "tsv") "\t" else if (ext == "csv") "," else NULL,
      comma = ",",
      tab = "\t",
      semicolon = ";",
      NULL
    )
    if (is.null(sep_resolved)) {
      # simple detection based on first line
      first_line <- readLines(path, n=1L, warn=FALSE)
      sep_resolved <- if (grepl("\t", first_line)) "\t" else if (grepl(";", first_line)) ";" else ","
    }
    df <- utils::read.table(path, header=TRUE, sep=sep_resolved, quote="\"", comment.char="", check.names=FALSE, na.strings=c(na_str, "NA", ""))
    if (rowname_col > 0) {
      if (rowname_col > ncol(df)) stop("rowname-column out of range")
      rn <- as.character(df[[rowname_col]])
      df[[rowname_col]] <- NULL
      rownames(df) <- rn
    }
    obj <- as.data.frame(df, check.names = FALSE, stringsAsFactors = FALSE)
  } else {
    stop("Unsupported extension: ", ext)
  }
  obj
}

# Load data
data <- read_any(opts$input, sep=opts$sep, rowname_col=as.integer(opts$rowname_column), na_str=opts$na)

# If it's SummarizedExperiment, extract assay
if (inherits(data, "SummarizedExperiment")) {
  data <- SummarizedExperiment::assay(data)
}

# Convert to numeric matrix (rows = probes, columns = samples)
if (is.data.frame(data)) {
  rn <- rownames(data)
  mat <- as.matrix(data)
  storage.mode(mat) <- "double"
  rownames(mat) <- rn
} else if (is.matrix(data)) {
  mat <- data
  storage.mode(mat) <- "double"
} else {
  stop("Input object not recognized. Expected data.frame or matrix with betas")
}

if (isTRUE(opts$transpose)) {
  mat <- t(mat)
}

if (is.null(rownames(mat)) || any(is.na(rownames(mat)) | rownames(mat) == "")) {
  stop("Beta matrix must have probe rownames (Illumina IDs cg##########)")
}

# Run PACE
proportion <- if (is.na(opts$proportionOfProbesRequired)) 0.8 else as.numeric(opts$proportionOfProbesRequired)
res_list <- PACEProjector(betas = mat, proportionOfProbesRequired = proportion)

# Combine results to matrix (samples x models)
model_names <- names(res_list)
all_samples <- unique(unlist(lapply(res_list, names)))
res_mat <- do.call(cbind, lapply(res_list, function(v) {
  v[match(all_samples, names(v))]
}))
colnames(res_mat) <- model_names
rownames(res_mat) <- all_samples

# Sort by sample name
ord <- order(rownames(res_mat))
res_mat <- res_mat[ord, , drop=FALSE]

# Save to TSV
out_dir <- dirname(opts$output)
if (!dir.exists(out_dir)) dir.create(out_dir, recursive=TRUE, showWarnings=FALSE)
utils::write.table(res_mat, file = opts$output, sep = "\t", quote = FALSE, row.names = TRUE, col.names = NA)

cat(sprintf("Done. Results written to %s\n", opts$output))

# Quick summary to console
summary_df <- data.frame(model = colnames(res_mat),
                         n = colSums(!is.na(res_mat)),
                         mean = apply(res_mat, 2, function(x) mean(x, na.rm=TRUE)),
                         sd = apply(res_mat, 2, function(x) stats::sd(x, na.rm=TRUE)))
print(summary_df)
