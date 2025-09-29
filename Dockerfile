# Base with Bioconductor (includes R and toolchain) to install preprocessCore and SummarizedExperiment
FROM bioconductor/bioconductor_docker:RELEASE_3_18

# Avoid prompts during installations
ENV DEBIAN_FRONTEND=noninteractive

# Set CRAN and adjust default options
RUN echo 'options(repos = c(CRAN = "https://cloud.r-project.org"))' >> /usr/local/lib/R/etc/Rprofile.site \
    && echo 'options(Ncpus = max(1L, parallel::detectCores() - 1L))' >> /usr/local/lib/R/etc/Rprofile.site

# Install useful system dependencies (locales and compression)
RUN apt-get update && apt-get install -y --no-install-recommends \
    locales \
    ca-certificates \
    && rm -rf /var/lib/apt/lists/* \
    && sed -i 's/# en_US.UTF-8 UTF-8/en_US.UTF-8 UTF-8/' /etc/locale.gen \
    && locale-gen en_US.UTF-8
ENV LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8

# Install R dependencies required by the package and execution script
# - Bioconductor: preprocessCore, SummarizedExperiment
# - CRAN: optparse
RUN R -q -e 'install.packages(c("optparse"))' \
    && R -q -e 'if (!requireNamespace("BiocManager", quietly=TRUE)) install.packages("BiocManager"); BiocManager::install(c("preprocessCore","SummarizedExperiment"), ask=FALSE, update=FALSE)'

# Copy metadata first to leverage layer cache when rebuilding
WORKDIR /usr/local/src/DunedinPACE
COPY DESCRIPTION NAMESPACE ./

# Copy rest of the package and install it in the system library
COPY . /usr/local/src/DunedinPACE
RUN R CMD INSTALL /usr/local/src/DunedinPACE

# Copy execution script and prepare to use it as default entry point
COPY scripts/run_pace.R /usr/local/bin/run_pace.R
RUN chmod +x /usr/local/bin/run_pace.R

# Default directories for data exchange
RUN mkdir -p /data /output
VOLUME ["/data","/output"]

# Execute the script; flags can be passed (see README)
ENTRYPOINT ["Rscript","/usr/local/bin/run_pace.R"]
CMD ["--help"]
