# ---- Mplus-backed mlVAR ------------------------------------------------------

#' Build an Mplus-backed multilevel VAR network
#'
#' @description
#' Runs the Mplus Bayesian estimator exposed by `mlVAR::mlVAR(estimator =
#' "Mplus")` and converts the returned posterior summaries into idiographic's
#' network/tidy accessors. This is a true Mplus backend: Mplus must be installed
#' and discoverable by `MplusAutomation::detectMplus()`.
#'
#' @param data A `data.frame` containing the panel data.
#' @param vars Character vector of variable column names to model.
#' @param id Character string naming the person-ID column.
#' @param day Character string naming the day/session column, or `NULL`.
#'   Mplus estimation in `mlVAR` does not directly support `day`; when supplied
#'   it is passed through so `mlVAR` can prepare the row order, but `mlVAR` will
#'   warn about the Mplus limitation.
#' @param beep Character string naming the measurement-occasion column, or
#'   `NULL`.
#' @param lags Integer lag order. The Mplus backend currently supports `1`.
#' @param temporal,contemporaneous Random-effect structure passed to `mlVAR`.
#'   Supported Mplus values are `"fixed"`, `"correlated"`, `"orthogonal"`, and
#'   `"default"`.
#' @param nCores Number of Mplus processors/chains.
#' @param scale,scaleWithin Standardization options passed to `mlVAR`.
#' @param MplusSave Logical. Keep Mplus input/output files in the working
#'   directory? Default `TRUE`.
#' @param MplusName File stem for Mplus input/output files.
#' @param iterations Mplus `BITERATIONS` string, e.g. `"(2000)"`.
#' @param chains Number of Mplus chains. Defaults to `nCores`.
#' @param signs Optional sign matrix for contemporaneous random effects.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations before fitting.
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @param workdir Directory in which Mplus files should be written/run. Default
#'   uses the current working directory.
#' @param verbose Logical. Show progress from `mlVAR`/Mplus.
#' @param ... Additional arguments passed to `mlVAR::mlVAR()`.
#'
#' @return A `net_mplus` object, also inheriting from `net_mlvar`, with temporal,
#'   contemporaneous, and between networks plus Mplus metadata in attributes.
#'   The original `mlVAR`/Mplus object is available as `attr(x, "mplus")`.
#' @examplesIf requireNamespace("mlVAR", quietly = TRUE) && requireNamespace("MplusAutomation", quietly = TRUE)
#' \dontrun{
#' fit <- fit_mlvar_mplus(
#'   data, vars = c("A", "B", "C"), id = "id", beep = "time",
#'   temporal = "fixed", contemporaneous = "fixed",
#'   MplusName = "my_mplus_mlvar"
#' )
#' edges(fit)
#' attr(fit, "mplus")$output$summaries
#' }
#' @seealso [fit_mlvar()]
#' @export
fit_mlvar_mplus <- function(data, vars, id,
                              day = NULL, beep = NULL,
                              lags = 1L,
                              temporal = c("fixed", "correlated", "orthogonal",
                                           "default"),
                              contemporaneous = c("fixed", "correlated",
                                                  "orthogonal", "default"),
                              nCores = 1L,
                              scale = TRUE,
                              scaleWithin = FALSE,
                              MplusSave = TRUE,
                              MplusName = "mlVAR_mplus",
                              iterations = "(2000)",
                              chains = nCores,
                              signs,
                              min_obs = NULL,
                              subject = NULL,
                              workdir = NULL,
                              verbose = TRUE,
                              ...) {
  temporal <- match.arg(temporal)
  contemporaneous <- match.arg(contemporaneous)
  stopifnot(is.data.frame(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.character(id), length(id) == 1L)
  stopifnot(is.numeric(lags), length(lags) == 1L, lags == 1L)
  stopifnot(is.numeric(nCores), length(nCores) == 1L, nCores >= 1L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(scaleWithin, "scaleWithin")
  .ido_check_flag(MplusSave, "MplusSave")
  .ido_check_flag(verbose, "verbose")
  if (!(is.character(MplusName) && length(MplusName) == 1L && nzchar(MplusName))) {
    stop("`MplusName` must be a non-empty file stem.", call. = FALSE)
  }
  if (!(is.character(iterations) && length(iterations) == 1L)) {
    stop("`iterations` must be a single Mplus BITERATIONS string.", call. = FALSE)
  }

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  data <- .ido_keep(data, id, min_obs, subject)
  .ido_check_numeric_vars(data, vars)

  mplus_command <- .mlvar_mplus_detect()

  if (!is.null(workdir)) {
    if (!(is.character(workdir) && length(workdir) == 1L)) {
      stop("`workdir` must be NULL or a single directory path.", call. = FALSE)
    }
    dir.create(workdir, recursive = TRUE, showWarnings = FALSE)
    old_wd <- getwd()
    setwd(workdir)
    on.exit(setwd(old_wd), add = TRUE)
  }

  args <- list(
    data = data,
    vars = vars,
    idvar = id,
    lags = lags,
    estimator = "Mplus",
    temporal = temporal,
    contemporaneous = contemporaneous,
    nCores = nCores,
    verbose = verbose,
    scale = scale,
    scaleWithin = scaleWithin,
    MplusSave = MplusSave,
    MplusName = MplusName,
    iterations = iterations,
    chains = chains,
    ...
  )
  if (!is.null(day)) args$dayvar <- day
  if (!is.null(beep)) args$beepvar <- beep
  if (!missing(signs)) args$signs <- signs

  fit <- tryCatch(.mlvar_mplus_call(args), error = function(e) {
    files <- Sys.glob(paste0(MplusName, ".*"))
    msg <- conditionMessage(e)
    if (length(files) > 0L) {
      msg <- paste0(msg, "\nMplus files written: ",
                    paste(normalizePath(files, mustWork = FALSE),
                          collapse = ", "))
    }
    stop(msg, call. = FALSE)
  })

  .mlvar_mplus_to_idiographic(fit, vars, config = list(
    engine = "mplus", estimator = "Mplus", lags = 1L,
    id = id, day = day, beep = beep, temporal = temporal,
    contemporaneous = contemporaneous, scale = scale,
    scaleWithin = scaleWithin, MplusName = MplusName,
    iterations = iterations, chains = chains,
    mplus_command = mplus_command
  ))
}

# Small indirections make the licensed-runtime boundary executable in tests:
# the package suite can prove every argument is forwarded and every returned
# mlVAR layer is converted without pretending that Mplus itself is installed.
# A licensed integration job still exercises these same two functions.
#' @keywords internal
#' @noRd
.mlvar_mplus_detect <- function() {
  if (!requireNamespace("mlVAR", quietly = TRUE)) {
    stop("Package 'mlVAR' is required for fit_mlvar_mplus().",
         call. = FALSE)
  }
  if (!requireNamespace("MplusAutomation", quietly = TRUE)) {
    stop("Package 'MplusAutomation' is required for fit_mlvar_mplus().",
         call. = FALSE)
  }
  command <- tryCatch(MplusAutomation::detectMplus(),
                      error = function(e) NULL)
  if (is.null(command)) {
    stop("Mplus was not found by MplusAutomation::detectMplus(). ",
         "Install Mplus or add its executable to PATH.", call. = FALSE)
  }
  command
}

#' @keywords internal
#' @noRd
.mlvar_mplus_call <- function(args) {
  do.call(mlVAR::mlVAR, args)
}

#' @keywords internal
#' @noRd
.mlvar_mplus_to_idiographic <- function(fit, vars, config = list()) {
  if (!inherits(fit, "mlVAR") || !identical(fit$input$estimator, "Mplus")) {
    stop("Expected an mlVAR object fitted with estimator = 'Mplus'.",
         call. = FALSE)
  }
  d <- length(vars)
  beta_arr <- fit$results$Beta$mean
  beta <- if (length(dim(beta_arr)) == 3L) beta_arr[, , 1L, drop = TRUE] else beta_arr
  beta <- as.matrix(beta)
  dimnames(beta) <- list(vars, vars)

  get_mat <- function(x, fallback = NULL) {
    if (!is.null(x) && !is.null(x$mean)) return(as.matrix(x$mean))
    if (!is.null(fallback)) return(fallback)
    matrix(0, d, d)
  }
  theta <- get_mat(fit$results$Theta$pcor)
  omega <- get_mat(fit$results$Omega_mu$pcor)
  dimnames(theta) <- dimnames(omega) <- list(vars, vars)
  diag(theta) <- 0
  diag(omega) <- 0

  coefs <- .mlvar_mplus_coefs(fit, vars)

  nets <- list(
    temporal = .ido_wrap(beta, method = "mlvar_mplus_temporal",
                         directed = TRUE),
    contemporaneous = .ido_wrap(theta, method = "mlvar_mplus_contemporaneous",
                                directed = FALSE),
    between = .ido_wrap(omega, method = "mlvar_mplus_between",
                        directed = FALSE)
  )
  attr(nets, "coefs") <- coefs
  attr(nets, "n_obs") <- fit$output$summaries$Observations %||% nrow(fit$data)
  id_col <- config$id %||% names(fit$data)[ncol(fit$data)]
  attr(nets, "n_subjects") <- if (id_col %in% names(fit$data)) {
    length(unique(fit$data[[id_col]]))
  } else {
    NA_integer_
  }
  attr(nets, "lag") <- 1L
  attr(nets, "standardize") <- config$scale %||% NA
  attr(nets, "scale") <- config$scale %||% NA
  attr(nets, "scaleWithin") <- config$scaleWithin %||% NA
  attr(nets, "mplus") <- fit
  attr(nets, "config") <- config
  attr(nets, "group_col") <- "network_type"
  class(nets) <- c("net_mplus", "net_mlvar", "cograph_group",
                   "netobject_group")
  nets
}

#' @keywords internal
#' @noRd
.mlvar_mplus_coefs <- function(fit, vars) {
  B <- fit$results$Beta
  arr <- B$mean
  if (length(dim(arr)) == 3L) arr <- arr[, , 1L, drop = TRUE]
  rows <- expand.grid(outcome = vars, predictor = vars,
                      stringsAsFactors = FALSE)
  pull <- function(slot) {
    x <- B[[slot]]
    if (is.null(x)) return(rep(NA_real_, nrow(rows)))
    if (length(dim(x)) == 3L) x <- x[, , 1L, drop = TRUE]
    as.numeric(x[cbind(match(rows$outcome, vars),
                       match(rows$predictor, vars))])
  }
  data.frame(
    outcome = rows$outcome,
    predictor = rows$predictor,
    beta = as.numeric(arr[cbind(match(rows$outcome, vars),
                                match(rows$predictor, vars))]),
    posterior_sd = pull("SD"),
    lower = pull("lower"),
    upper = pull("upper"),
    p = pull("P"),
    significant = {
      lo <- pull("lower"); hi <- pull("upper")
      !is.na(lo) & !is.na(hi) & (lo > 0 | hi < 0)
    },
    stringsAsFactors = FALSE
  )
}

#' @export
print.net_mplus <- function(x, digits = 2, ...) {
  coef_df <- attr(x, "coefs")
  d <- nrow(x$temporal$weights)
  n_sig <- sum(coef_df$significant, na.rm = TRUE)
  cat(sprintf("Mplus mlVAR result: %d subjects, %d observations, %d variables\n",
              attr(x, "n_subjects"), attr(x, "n_obs"), d))
  cat(sprintf("  Temporal credible intervals excluding 0: %d / %d\n",
              n_sig, nrow(coef_df)))
  cfg <- attr(x, "config")
  if (!is.null(cfg$mplus_command)) {
    cat(sprintf("  Mplus command:  %s\n", cfg$mplus_command))
  }
  .ido_print_networks(x, digits = digits)
  cat("\n  attr(x, \"mplus\") for raw Mplus/mlVAR output",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' @export
coefs.net_mplus <- function(x, ...) {
  attr(x, "coefs")
}
