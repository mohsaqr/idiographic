# Regenerate the frozen mlVAR 0.7.3 oracle for the 20 real ESM panels.
#
# Run from the package root with:
#   Rscript tests/testthat/fixtures/mlvar-real20/generate-oracles.R
#
# The input CSVs originated in Dynalytics_Desktop/validation/data. They are
# copied into this fixture so the evidence does not depend on a sibling repo.

if (!requireNamespace("mlVAR", quietly = TRUE)) {
  stop("Install mlVAR >= 0.7.3 before regenerating these oracles.")
}
if (!requireNamespace("jsonlite", quietly = TRUE)) {
  stop("Install jsonlite before regenerating these oracles.")
}
if (utils::packageVersion("mlVAR") < "0.7.3") {
  stop("Oracle generation requires mlVAR >= 0.7.3.")
}

args <- commandArgs(trailingOnly = FALSE)
script_arg <- args[grepl("^--file=", args)]
fixture_dir <- if (length(script_arg)) {
  dirname(normalizePath(sub("^--file=", "", script_arg[[1L]])))
} else {
  normalizePath("tests/testthat/fixtures/mlvar-real20")
}

config <- jsonlite::fromJSON(file.path(fixture_dir, "config.json"),
                             simplifyVector = FALSE)
oracle_dir <- file.path(fixture_dir, "oracle")
dir.create(oracle_dir, recursive = TRUE, showWarnings = FALSE)

beep_sources <- c(
  `0032` = "counter",
  `0035` = "creation_time",
  `0036` = "creation_time",
  `0042` = "begin_time_ema"
)

manifest <- vector("list", length(config$datasets))

for (i in seq_along(config$datasets)) {
  spec <- config$datasets[[i]]
  dataset_id <- spec$id
  vars <- unlist(spec$vars, use.names = FALSE)
  data_path <- file.path(fixture_dir, "data",
                         paste0(dataset_id, "-data.csv"))
  data <- utils::read.csv(data_path, stringsAsFactors = FALSE)
  required <- c("id", "day", "beep", vars)
  missing_columns <- setdiff(required, names(data))
  if (length(missing_columns)) {
    stop(dataset_id, " is missing: ", paste(missing_columns, collapse = ", "))
  }

  incomplete <- !stats::complete.cases(data[, required, drop = FALSE])
  complete <- data[!incomplete, required, drop = FALSE]
  complete <- complete[order(complete$id, complete$day, complete$beep), ,
                       drop = FALSE]
  key <- paste(complete$id, complete$day, complete$beep, sep = "|")
  duplicate_keys <- sum(duplicated(key))
  same_block <- c(
    FALSE,
    complete$id[-1L] == complete$id[-nrow(complete)] &
      complete$day[-1L] == complete$day[-nrow(complete)]
  )
  step <- c(NA_real_, diff(complete$beep))
  n_lag_pairs <- sum(same_block & step == 1, na.rm = TRUE)
  n_gap_steps <- sum(same_block & step != 1, na.rm = TRUE)

  message(sprintf("[%02d/20] %s: %d rows, %d variables",
                  i, dataset_id, nrow(data), length(vars)))
  reference <- suppressWarnings(mlVAR::mlVAR(
    data = data,
    vars = vars,
    idvar = "id",
    dayvar = "day",
    beepvar = "beep",
    lags = 1,
    estimator = "lmer",
    temporal = "fixed",
    contemporaneous = "fixed",
    scale = FALSE,
    verbose = FALSE
  ))
  temporal <- reference$results$Beta$mean[, , 1L]
  contemporaneous <- reference$results$Theta$pcor$mean
  between <- reference$results$Omega_mu$pcor$mean
  diag(contemporaneous) <- 0
  diag(between) <- 0
  dimnames(temporal) <- dimnames(contemporaneous) <-
    dimnames(between) <- list(vars, vars)
  between_degenerate <- !any(is.finite(between[upper.tri(between)]))
  beep_source <- unname(beep_sources[dataset_id])
  if (is.na(beep_source)) beep_source <- "beep"

  oracle <- list(
    meta = list(
      dataset_id = dataset_id,
      vars = vars,
      reference = "mlVAR::mlVAR",
      mlvar_version = as.character(utils::packageVersion("mlVAR")),
      lme4_version = as.character(utils::packageVersion("lme4")),
      r_version = paste(R.version$major, R.version$minor, sep = "."),
      arguments = list(
        lags = 1L, estimator = "lmer", temporal = "fixed",
        contemporaneous = "fixed", scale = FALSE
      ),
      n_rows = nrow(data),
      n_complete_rows = nrow(complete),
      n_subjects = length(unique(complete$id)),
      n_lag_pairs = n_lag_pairs,
      missing_rows = sum(incomplete),
      missing_id = sum(is.na(data$id)),
      duplicate_keys = duplicate_keys,
      gap_steps = n_gap_steps,
      between_degenerate = between_degenerate,
      source_md5 = unname(tools::md5sum(data_path)),
      source_note = spec$notes,
      original_beep_source = beep_source
    ),
    temporal = temporal,
    contemporaneous = contemporaneous,
    between = between
  )
  saveRDS(oracle, file.path(oracle_dir, paste0(dataset_id, ".rds")),
          version = 3L, compress = "xz")

  manifest[[i]] <- data.frame(
    dataset_id = dataset_id,
    n_rows = nrow(data),
    n_complete_rows = nrow(complete),
    n_subjects = length(unique(complete$id)),
    n_vars = length(vars),
    n_lag_pairs = n_lag_pairs,
    missing_rows = sum(incomplete),
    missing_id = sum(is.na(data$id)),
    duplicate_keys = duplicate_keys,
    gap_steps = n_gap_steps,
    between_degenerate = between_degenerate,
    original_beep_source = beep_source,
    source_md5 = unname(tools::md5sum(data_path)),
    notes = spec$notes,
    stringsAsFactors = FALSE
  )
}

utils::write.csv(do.call(rbind, manifest),
                 file.path(fixture_dir, "manifest.csv"), row.names = FALSE)
message("Wrote 20 mlVAR oracles and manifest.csv")
