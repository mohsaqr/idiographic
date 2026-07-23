#' Graphical VAR Estimation
#'
#' Estimate a graphical vector autoregressive (GVAR) model from time series or
#' panel data. Jointly estimates a sparse temporal network (L1-penalized VAR
#' coefficients) and a sparse contemporaneous network (graphical lasso on
#' residuals) using EBIC model selection over a lambda grid.
#'
#' This is a clean-room reimplementation of the Rothman/Epskamp two-step
#' estimator that is **numerically equivalent to**
#' \code{graphicalVAR::graphicalVAR()}: identical data preparation
#' (global scaling, optional within-person centring, intercept column,
#' lag-1 construction within id/day blocks), identical lambda grids
#' (\code{generate_lambdas}), the coupled MRCE beta-update / glasso kappa-update
#' loop, the unpenalized-likelihood EBIC, and the same tie-broken model
#' selection. The committed end-to-end regression tests use tolerance `1e-6`, covering
#' both well-conditioned and numerically difficult fits. That equivalence claim
#' is limited to
#' `mimic = "current"` and `lags = 1`; multiple lags are an idiographic
#' extension and are labelled as such in the returned equivalence metadata.
#'
#' @param data A data.frame or matrix with columns for variables, and optionally
#'   id, day, beep columns for panel/ESM data. A prepared list containing
#'   numeric matrices `data_c` (current responses) and `data_l` (lagged design,
#'   with or without an intercept column) is also accepted.
#' @param vars Character vector of variable names. May be omitted for prepared
#'   input when `data_c` has column names.
#' @param id Character. Name of the person-ID column. If NULL, assumes single
#'   subject.
#' @param day Character. Name of the day/session column. Default: NULL.
#' @param beep Character. Name of the beep/measurement column. Default: NULL.
#' @param lags Positive integer vector of explicit lags to include. Default: 1.
#' @param n_lambda Integer scalar, or a two-value vector giving the number of
#'   beta and kappa penalties. The latter can be named, for example
#'   `c(beta = 30, kappa = 20)`, or unnamed in beta/kappa order. Default: 50.
#' @param gamma Numeric. EBIC hyperparameter (0 = BIC, higher = sparser).
#'   Default: 0.5.
#' @param scale Logical. Whether to standardize variables. Default: TRUE.
#' @param center_within Logical. Whether to centre within person when more than
#'   one id is present (removes between-person variance). Default: TRUE.
#' @param lambda_min_ratio Numeric scalar, or a two-value beta/kappa vector.
#'   Ratio of min/max lambda unless overridden per-dimension. Default: 0.05.
#' @param lambda_min_kappa,lambda_min_beta Numeric or \code{NULL}. Per-dimension
#'   min/max lambda ratios (matching \code{graphicalVAR}'s \code{lambda_min_kappa}
#'   / \code{lambda_min_beta}). When \code{NULL}, fall back to
#'   \code{lambda_min_ratio}.
#' @param penalize_diagonal Logical. Penalize the autoregressive diagonal in
#'   beta. Default: TRUE (matches \code{graphicalVAR}).
#' @param regularize_mat_beta Optional numeric/logical matrix
#'   (\code{p x p} or \code{p x (p+1)}) of per-element beta penalty multipliers
#'   (matches \code{graphicalVAR}'s \code{regularize_mat_beta}). \code{NULL} uses
#'   \code{penalize_diagonal}.
#' @param regularize_mat_kappa Optional \code{p x p} numeric/logical matrix of
#'   per-element kappa penalty multipliers (matches
#'   \code{graphicalVAR}'s \code{regularize_mat_kappa}). \code{NULL} penalizes all
#'   off-diagonals.
#' @param maxit_in,maxit_out Integer. Max inner (beta) / outer (beta-kappa)
#'   iterations. Defaults 100 (matches \code{maxit.in} / \code{maxit.out}).
#' @param delete_missings Logical. Drop rows with missing current/lagged values.
#'   Default TRUE (matches \code{deleteMissings}).
#' @param likelihood Either \code{"unpenalized"} (default; refit precision for
#'   the EBIC, matching \code{graphicalVAR}) or \code{"penalized"} (use the
#'   regularized kappa directly).
#' @param ebic_tol Numeric. Tolerance for the EBIC tie-break. Default 1e-4.
#' @param mimic Character. Only \code{"current"} is supported. Legacy modes
#'   error explicitly because idiographic does not claim equivalence to them.
#' @param verbose Logical. Emit progress messages. Default FALSE.
#' @param lambda_beta Numeric scalar (or vector), or \code{NULL}. When supplied,
#'   the temporal penalty is pinned to this value instead of being EBIC-selected
#'   over a grid -- matching \code{graphicalVAR}'s \code{lambda_beta} argument
#'   (e.g. \code{lambda_beta = 0.1}). Default \code{NULL} (EBIC grid).
#' @param lambda_kappa Numeric scalar (or vector), or \code{NULL}. As
#'   \code{lambda_beta} but for the contemporaneous (kappa) penalty.
#' @param min_obs Integer or \code{NULL}. Keep only subjects with at least this
#'   many observations (counts taken from \code{data}). Default \code{NULL}.
#' @param subject Optional vector naming the exact subject(s) to analyse.
#'   Default \code{NULL} (all subjects).
#'
#' @return A list of class \code{gvar_result} containing:
#' \describe{
#'   \item{beta}{Temporal coefficient matrix, outcome x (intercept + predictors),
#'     in \code{graphicalVAR}'s convention.}
#'   \item{temporal}{The first requested p x p temporal layer as
#'     \code{[outcome, predictor]}; unchanged for the default lag 1 fit.}
#'   \item{temporal_layers}{Named p x p coefficient matrices for every lag.}
#'   \item{kappa}{Precision matrix (p x p, symmetric).}
#'   \item{PCC}{Partial contemporaneous correlations \code{-cov2cor(kappa)},
#'     diagonal zeroed.}
#'   \item{PDC}{Partial directed correlations.}
#'   \item{contemporaneous}{Alias for \code{PCC}.}
#'   \item{labels}{Variable names.}
#'   \item{n_obs}{Number of valid lag-pair observations.}
#'   \item{lambda_beta, lambda_kappa}{Selected penalties.}
#'   \item{gamma, EBIC}{EBIC gamma used and the selected EBIC.}
#' }
#'
#' @references
#' Epskamp, S., Waldorp, L. J., Mottus, R., & Borsboom, D. (2018).
#' The Gaussian Graphical Model in Cross-Sectional and Time-Series Data.
#' \emph{Multivariate Behavioral Research}, 53(4), 453-480.
#'
#' Rothman, A. J., Levina, E., & Zhu, J. (2010). Sparse multivariate regression
#' with covariance estimation. \emph{JCGS}, 19(4), 947-962.
#'
#' @examples
#' set.seed(1)
#' d <- data.frame(A = rnorm(60), B = rnorm(60))
#' fit <- fit_graphical_var(d, vars = c("A", "B"), n_lambda = 3,
#'                          scale = FALSE)
#' fit$temporal
#' fit$contemporaneous
#'
#' @importFrom stats cov2cor sd
#' @export
fit_graphical_var <- function(data,
                          vars,
                          id = NULL,
                          day = NULL,
                          beep = NULL,
                          lags = 1L,
                          n_lambda = 50L,
                          gamma = 0.5,
                          scale = TRUE,
                          center_within = TRUE,
                          lambda_min_ratio = 0.05,
                          lambda_min_kappa = NULL,
                          lambda_min_beta = NULL,
                          penalize_diagonal = TRUE,
                          lambda_beta = NULL,
                          lambda_kappa = NULL,
                          regularize_mat_beta = NULL,
                          regularize_mat_kappa = NULL,
                          maxit_in = 100L,
                          maxit_out = 100L,
                          delete_missings = TRUE,
                          likelihood = c("unpenalized", "penalized"),
                          ebic_tol = 1e-4,
                          mimic = "current",
                          verbose = FALSE,
                          min_obs = NULL,
                          subject = NULL) {

  lags_missing <- missing(lags)
  vars_missing <- missing(vars) || is.null(vars)
  likelihood <- match.arg(likelihood)
  prepared <- is.list(data) && !is.data.frame(data) &&
    all(c("data_c", "data_l") %in% names(data))
  if (!(prepared || is.data.frame(data) || is.matrix(data))) {
    stop("`data` must be a data frame, matrix, or a prepared list containing ",
         "`data_c` and `data_l`.", call. = FALSE)
  }
  if (!vars_missing && !(is.character(vars) && length(vars) >= 2L &&
                         !anyNA(vars) && !anyDuplicated(vars))) {
    stop("`vars` must contain at least two unique variable names.", call. = FALSE)
  }
  if (!(is.numeric(gamma) && length(gamma) == 1L && is.finite(gamma) &&
        gamma >= 0)) {
    stop("`gamma` must be one finite non-negative number.", call. = FALSE)
  }
  n_lambda <- .gvar_pair_arg(n_lambda, "n_lambda", integer = TRUE,
                             lower = 2, upper = Inf)
  lambda_min_ratio <- .gvar_pair_arg(lambda_min_ratio, "lambda_min_ratio",
                                     lower = 0, upper = 1,
                                     open_lower = TRUE, open_upper = TRUE)
  maxit_in <- .gvar_count(maxit_in, "maxit_in", minimum = 1L)
  maxit_out <- .gvar_count(maxit_out, "maxit_out", minimum = 1L)
  if (!(is.numeric(ebic_tol) && length(ebic_tol) == 1L &&
        is.finite(ebic_tol) && ebic_tol >= 0)) {
    stop("`ebic_tol` must be one finite non-negative number.", call. = FALSE)
  }
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(penalize_diagonal, "penalize_diagonal")
  .ido_check_flag(delete_missings, "delete_missings")
  .ido_check_flag(verbose, "verbose")
  if (!(is.character(mimic) && length(mimic) == 1L && !is.na(mimic))) {
    stop("`mimic` must be the single value \"current\".", call. = FALSE)
  }
  if (!identical(mimic, "current")) {
    stop("Legacy `mimic = \"", mimic, "\"` behavior is not implemented; ",
         "idiographic only claims current-mode equivalence.", call. = FALSE)
  }
  if (prepared && lags_missing) {
    lags <- if (!is.null(data$lags)) data$lags else .gvar_infer_lags(data)
  }
  lags <- .gvar_lags(lags)
  # Per-dimension lambda minima (graphicalVAR's lambda_min_kappa/beta); fall back
  # to the shared lambda_min_ratio.
  lmin_k <- lambda_min_kappa %||% lambda_min_ratio[["kappa"]]
  lmin_b <- lambda_min_beta  %||% lambda_min_ratio[["beta"]]
  .gvar_ratio(lmin_k, "lambda_min_kappa")
  .gvar_ratio(lmin_b, "lambda_min_beta")
  # Fixed-penalty override (matches graphicalVAR's lambda_beta / lambda_kappa):
  # supply a scalar (or vector) to pin that penalty instead of EBIC-selecting it.
  if (!is.null(lambda_beta)) {
    if (!(is.numeric(lambda_beta) && length(lambda_beta) >= 1L &&
          all(is.finite(lambda_beta)) && all(lambda_beta >= 0))) {
      stop("`lambda_beta` must contain finite non-negative numbers.",
           call. = FALSE)
    }
  }
  if (!is.null(lambda_kappa)) {
    if (!(is.numeric(lambda_kappa) && length(lambda_kappa) >= 1L &&
          all(is.finite(lambda_kappa)) && all(lambda_kappa >= 0))) {
      stop("`lambda_kappa` must contain finite non-negative numbers.",
           call. = FALSE)
    }
  }
  # ---- 1. Data preparation ----
  if (prepared) {
    if (!is.null(id) || !is.null(day) || !is.null(beep) ||
        !is.null(min_obs) || !is.null(subject)) {
      stop("`id`, `day`, `beep`, `min_obs`, and `subject` cannot be applied ",
           "to prepared `data_c`/`data_l` input.", call. = FALSE)
    }
    ts <- .gvar_prepared(data, if (vars_missing) NULL else vars, lags,
                         delete_missings)
    vars <- ts$vars
  } else {
    data <- as.data.frame(data)
    if (vars_missing) {
      stop("`vars` is required for a data frame or matrix input.", call. = FALSE)
    }
    if (!all(vars %in% names(data))) {
      stop("Variables not found in data: ",
           paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
    }
    .ido_check_col(id,   "id",   data)
    .ido_check_col(day,  "day",  data)
    .ido_check_col(beep, "beep", data)
    data <- .ido_keep(data, id, min_obs, subject)
    .ido_check_numeric_vars(data, vars)
    if (verbose) message("Preparing lagged data ...")
    ts <- .gvar_tsdata(data, vars, id, day, beep, scale, center_within,
                       delete_missings, lags = lags)
  }
  data_c <- ts$data_c       # n x p   (current)
  data_l <- ts$data_l       # n x (1 + p * number of lags)
  d <- length(vars)
  n <- nrow(data_c)
  if (anyNA(data_c) || anyNA(data_l) ||
      any(!is.finite(data_c)) || any(!is.finite(data_l))) {
    stop("The graphical VAR estimator requires complete finite lag pairs. ",
         "Use `delete_missings = TRUE` or impute the prepared matrices.",
         call. = FALSE)
  }
  if (n < d + 1L) {
    stop("Too few lag pairs (", n, ") for ", d, " variables.", call. = FALSE)
  }
  if (!is.null(regularize_mat_beta)) {
    if (!is.matrix(regularize_mat_beta) ||
        !(is.numeric(regularize_mat_beta) || is.logical(regularize_mat_beta)) ||
        anyNA(regularize_mat_beta) || any(!is.finite(regularize_mat_beta)) ||
        any(regularize_mat_beta < 0)) {
      stop("`regularize_mat_beta` must be a finite, non-negative numeric/logical matrix.",
           call. = FALSE)
    }
    # A simple p x p mask is applied identically to each requested lag.
    if (length(lags) > 1L && identical(dim(regularize_mat_beta), c(d, d))) {
      regularize_mat_beta <- do.call(cbind, rep(list(regularize_mat_beta),
                                                length(lags)))
    }
    expected_beta <- c(d, 1L + d * length(lags))
    if (!identical(dim(regularize_mat_beta), c(d, d * length(lags))) &&
        !identical(dim(regularize_mat_beta), expected_beta)) {
      stop("`regularize_mat_beta` has the wrong dimensions (expected ", d,
           " x ", d * length(lags), " without an intercept, or ", d,
           " x ", 1L + d * length(lags), " with an intercept).",
           call. = FALSE)
    }
    regularize_mat_beta <- regularize_mat_beta * 1
  }
  if (!is.null(regularize_mat_kappa)) {
    if (!is.matrix(regularize_mat_kappa) ||
        !(is.numeric(regularize_mat_kappa) || is.logical(regularize_mat_kappa)) ||
        anyNA(regularize_mat_kappa) || any(!is.finite(regularize_mat_kappa)) ||
        any(regularize_mat_kappa < 0) ||
        !identical(dim(regularize_mat_kappa), c(d, d))) {
      stop("`regularize_mat_kappa` must be a finite, non-negative p x p numeric/logical matrix.",
           call. = FALSE)
    }
    regularize_mat_kappa <- regularize_mat_kappa * 1
  }

  # ---- 2. Lambda grids (matches graphicalVAR::generate_lambdas) ----
  # A fixed lambda_beta / lambda_kappa pins that penalty (EBIC then selects over
  # the other dimension only, or over a single cell if both are fixed). Generate
  # only the grids that are actually needed -- when both penalties are fixed,
  # skip .gvar_genlambda() entirely (it runs an invGlasso/eigen, sometimes a full
  # glasso, that would be discarded).
  need_grid <- is.null(lambda_beta) || is.null(lambda_kappa)
  lams <- if (need_grid) {
    .gvar_genlambda(data_l, data_c, n_lambda[["kappa"]],
                    n_lambda[["beta"]], lmin_k, lmin_b)
  } else {
    list(lambda_beta = NULL, lambda_kappa = NULL)
  }
  if (!is.null(lambda_beta))  lams$lambda_beta  <- lambda_beta
  if (!is.null(lambda_kappa)) lams$lambda_kappa <- lambda_kappa
  grid <- expand.grid(kappa = lams$lambda_kappa, beta = lams$lambda_beta)

  # ---- 3. Fit every (lambda_beta, lambda_kappa) cell ----
  if (verbose) message("Fitting ", nrow(grid), " (lambda_beta, lambda_kappa) ",
                       "cells ...")
  est <- lapply(seq_len(nrow(grid)), function(i) {
    .gvar_rothman(data_l, data_c, grid$beta[i], grid$kappa[i],
                  gamma = gamma, penalize_diagonal = penalize_diagonal,
                  maxit_out = maxit_out, maxit_in = maxit_in,
                  regularize_mat_beta = regularize_mat_beta,
                  regularize_mat_kappa = regularize_mat_kappa,
                  likelihood = likelihood)
  })
  grid$ebic <- vapply(est, function(e) e$EBIC, numeric(1))

  # ---- 4. EBIC selection with graphicalVAR's tie-break ----
  # which() drops cells whose EBIC is NA/NaN (a degenerate (lambda) pairing),
  # so one bad cell can't inject an NA index into the candidate set.
  sel <- .gvar_select_ebic(grid, ebic_tol)
  R <- est[[sel]]

  # ---- 5. Assemble result ----
  beta <- R$beta                       # outcome x (intercept + predictors)
  kappa <- R$kappa
  rownames(beta) <- vars
  colnames(beta) <- colnames(data_l)
  dimnames(kappa) <- list(vars, vars)

  temporal_layers <- setNames(lapply(seq_along(lags), function(i) {
    at <- 1L + (i - 1L) * d + seq_len(d)
    out <- beta[, at, drop = FALSE]
    dimnames(out) <- list(vars, vars)
    out
  }), paste0("lag", lags))
  temporal <- temporal_layers[[1L]]

  pcc <- .gvar_compute_pcc(kappa)
  pdc_layers <- lapply(temporal_layers, .gvar_compute_pdc, kappa = kappa)
  pdc <- pdc_layers[[1L]]
  dimnames(pcc) <- dimnames(pdc) <- list(vars, vars)

  temporal_networks <- setNames(lapply(temporal_layers, function(layer) {
    .ido_wrap(t(layer), method = "relative", directed = TRUE)
  }), if (length(lags) == 1L && identical(lags, 1L)) "temporal" else
       paste0("temporal_lag", lags))

  model <- list(
    beta            = beta,
    temporal        = temporal,
    temporal_layers = temporal_layers,
    PDC_layers      = pdc_layers,
    kappa           = kappa,
    PCC             = pcc,
    PDC             = pdc,
    contemporaneous = pcc,
    labels          = vars,
    lags            = lags,
    n_obs           = n,
    lambda_beta     = grid$beta[sel],
    lambda_kappa    = grid$kappa[sel],
    gamma           = gamma,
    EBIC            = grid$ebic[sel],
    likelihood      = likelihood,
    n_lambda        = n_lambda,
    path            = grid,
    convergence     = R$convergence,
    prepared_input  = prepared,
    equivalence     = list(
      reference = "graphicalVAR",
      mimic = mimic,
      scope = if (identical(lags, 1L)) "current mode, lag 1" else
        "idiographic multi-lag extension; no upstream numerical claim"
    )
  )
  .ido_group_result(
    "gvar_result",
    c(temporal_networks, list(
      contemporaneous = .ido_wrap(pcc, method = "co_occurrence",
                                  directed = FALSE)
    )),
    model
  )
}


# ============================================================
# Internal: argument validation and data preparation
# ============================================================

#' @noRd
.gvar_count <- function(x, arg, minimum = 1L) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) && x == floor(x) &&
        x >= minimum)) {
    stop("`", arg, "` must be one integer >= ", minimum, ".", call. = FALSE)
  }
  as.integer(x)
}

#' Parse a scalar or beta/kappa pair while returning a stable named vector.
#' @noRd
.gvar_pair_arg <- function(x, arg, integer = FALSE, lower = -Inf, upper = Inf,
                           open_lower = FALSE, open_upper = FALSE) {
  if (!(is.numeric(x) && length(x) %in% c(1L, 2L) && all(is.finite(x)))) {
    stop("`", arg, "` must be a numeric scalar or beta/kappa pair.",
         call. = FALSE)
  }
  if (length(x) == 1L) {
    x <- c(beta = x, kappa = x)
  } else if (is.null(names(x)) || (!anyNA(names(x)) && all(names(x) == ""))) {
    names(x) <- c("beta", "kappa")
  } else {
    if (anyNA(names(x)) || any(names(x) == "") ||
        !setequal(names(x), c("beta", "kappa")) ||
        anyDuplicated(names(x))) {
      stop("A named `", arg, "` must contain exactly `beta` and `kappa`.",
           call. = FALSE)
    }
    x <- x[c("beta", "kappa")]
  }
  low_ok <- if (open_lower) x > lower else x >= lower
  high_ok <- if (open_upper) x < upper else x <= upper
  if (!all(low_ok & high_ok) || (integer && any(x != floor(x)))) {
    interval <- paste0(if (open_lower) "(" else "[", lower, ", ", upper,
                       if (open_upper) ")" else "]")
    stop("`", arg, "` values must be ", if (integer) "integers " else "",
         "in ", interval, ".", call. = FALSE)
  }
  if (integer) x <- as.integer(x)
  setNames(x, c("beta", "kappa"))
}

#' @noRd
.gvar_ratio <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0 && x < 1)) {
    stop("`", arg, "` must be one finite number strictly between 0 and 1.",
         call. = FALSE)
  }
  invisible(x)
}

#' @noRd
.gvar_lags <- function(lags) {
  if (!(is.numeric(lags) && length(lags) >= 1L && all(is.finite(lags)) &&
        all(lags == floor(lags)) && all(lags >= 1L))) {
    stop("`lags` must be a non-empty vector of positive integers.",
         call. = FALSE)
  }
  lags <- as.integer(lags)
  if (anyDuplicated(lags)) {
    stop("`lags` must not contain duplicates.", call. = FALSE)
  }
  lags
}

#' Infer lag metadata from a prepared design when the caller supplied only
#' `data_c` and `data_l`.
#' @noRd
.gvar_infer_lags <- function(data) {
  if (!(is.matrix(data$data_c) || is.data.frame(data$data_c)) ||
      !(is.matrix(data$data_l) || is.data.frame(data$data_l))) {
    stop("Prepared `data_c` and `data_l` must be matrices or data frames.",
         call. = FALSE)
  }
  p <- ncol(as.matrix(data$data_c))
  q <- ncol(as.matrix(data$data_l))
  if (p < 2L || q < 1L) {
    stop("Cannot infer `lags` from empty or underspecified prepared matrices.",
         call. = FALSE)
  }
  n_predictors <- if (q %% p == 0L) q else if ((q - 1L) %% p == 0L) q - 1L else
    stop("Cannot infer `lags` from the prepared matrix dimensions; supply ",
         "`lags` explicitly.", call. = FALSE)
  n_lags <- n_predictors %/% p
  if (n_lags < 1L) {
    stop("Prepared `data_l` contains no lagged predictors.", call. = FALSE)
  }

  cn <- colnames(as.matrix(data$data_l))
  if (!is.null(cn) && length(cn) == q) {
    predictor_names <- tail(cn, n_predictors)
    is_labelled <- grepl("_lag[0-9]+$", predictor_names)
    if (all(is_labelled)) {
      labelled <- as.integer(sub(".*_lag([0-9]+)$", "\\1", predictor_names))
      candidate <- labelled[seq.int(1L, length(labelled), by = p)]
      if (length(candidate) == n_lags &&
          identical(labelled, rep(candidate, each = p))) {
        return(candidate)
      }
    }
  }
  seq_len(n_lags)
}

#' Validate and normalize caller-prepared current/lagged matrices.
#' @noRd
.gvar_prepared <- function(data, vars, lags, delete_missings = TRUE) {
  if (!(is.matrix(data$data_c) || is.data.frame(data$data_c)) ||
      !(is.matrix(data$data_l) || is.data.frame(data$data_l))) {
    stop("Prepared `data_c` and `data_l` must be matrices or data frames.",
         call. = FALSE)
  }
  data_c <- as.matrix(data$data_c)
  data_l <- as.matrix(data$data_l)
  if (!is.numeric(data_c) || !is.numeric(data_l)) {
    stop("Prepared `data_c` and `data_l` must be numeric.", call. = FALSE)
  }
  if (nrow(data_c) != nrow(data_l)) {
    stop("Prepared `data_c` and `data_l` must have the same number of rows.",
         call. = FALSE)
  }
  p <- ncol(data_c)
  if (p < 2L) stop("Prepared `data_c` must have at least two columns.",
                   call. = FALSE)
  if (is.null(vars)) {
    vars <- colnames(data_c)
    if (is.null(vars) || any(vars == "")) {
      stop("`vars` is required when prepared `data_c` has no column names.",
           call. = FALSE)
    }
  }
  if (length(vars) != p || anyNA(vars) || any(vars == "") ||
      anyDuplicated(vars)) {
    stop("`vars` must uniquely name every column of prepared `data_c`.",
         call. = FALSE)
  }
  expected <- p * length(lags)
  if (ncol(data_l) == expected) {
    data_l <- cbind(1, data_l)
  } else if (ncol(data_l) != expected + 1L) {
    stop("Prepared `data_l` must have p * length(lags) predictor columns, ",
         "optionally preceded by an intercept.", call. = FALSE)
  }
  if (anyNA(data_l[, 1L]) || any(data_l[, 1L] != 1)) {
    stop("The first column of prepared `data_l` must be an intercept of ones.",
         call. = FALSE)
  }
  colnames(data_c) <- vars
  lag_names <- if (identical(lags, 1L)) vars else
    unlist(lapply(lags, function(lag) paste0(vars, "_lag", lag)),
           use.names = FALSE)
  colnames(data_l) <- c("(Intercept)", lag_names)
  keep <- if (isTRUE(delete_missings)) {
    stats::complete.cases(data_c, data_l) &
      apply(data_c, 1L, function(z) all(is.finite(z))) &
      apply(data_l, 1L, function(z) all(is.finite(z)))
  } else {
    rep(TRUE, nrow(data_c))
  }
  data_c <- data_c[keep, , drop = FALSE]
  data_l <- data_l[keep, , drop = FALSE]
  if (isTRUE(delete_missings) && nrow(data_c) == 0L) {
    stop("No complete lag pairs remain after deleting missing values.",
         call. = FALSE)
  }
  list(data_c = data_c, data_l = data_l, vars = vars, lags = lags)
}

#' Build current/lagged matrices for one or more explicit lags.
#'
#' Global per-variable scaling (always centred), optional within-person
#' centring when >1 id, lag construction within (id, day) blocks, and
#' (when `delete_missings`) deletion of rows with missing current or lagged
#' values. When `beep` is supplied, an absent beep creates a missing lag rather
#' than joining non-consecutive observations.
#' @noRd
.gvar_tsdata <- function(data, vars, id, day, beep, scale, center_within,
                         delete_missings = TRUE, lags = 1L) {
  data <- as.data.frame(data)
  lags <- .gvar_lags(lags)

  # global scale per variable (center always TRUE, scale optional)
  for (v in vars) {
    data[[v]] <- as.numeric(scale(data[[v]], center = TRUE, scale = scale))
  }

  idv  <- if (is.null(id))  rep(1L, nrow(data)) else data[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(data)) else data[[day]]

  # within-person centering (center only) when more than one id
  if (isTRUE(center_within) && length(unique(idv)) > 1L) {
    for (v in vars) {
      m <- stats::ave(data[[v]], idv, FUN = function(z) mean(z, na.rm = TRUE))
      data[[v]] <- data[[v]] - m
    }
  }

  # order by id, day, then beep (or original row order within block)
  key <- if (is.null(beep)) seq_len(nrow(data)) else data[[beep]]
  if (!is.null(beep) && !is.numeric(key)) {
    stop("`beep` must identify a numeric measurement index.", call. = FALSE)
  }
  ord <- order(idv, dayv, key)
  data <- data[ord, , drop = FALSE]
  idv  <- idv[ord]
  dayv <- dayv[ord]
  key <- key[ord]

  Y <- as.matrix(data[, vars, drop = FALSE])

  blk <- paste(idv, dayv, sep = "\r")
  lagged <- lapply(lags, function(lag) {
    source <- rep(NA_integer_, nrow(Y))
    if (is.null(beep)) {
      candidate <- seq_len(nrow(Y)) - lag
      ok <- candidate >= 1L
      ok[ok] <- blk[candidate[ok]] == blk[ok]
      source[ok] <- candidate[ok]
    } else {
      for (ii in split(seq_len(nrow(Y)), blk)) {
        pos <- match(key[ii] - lag, key[ii])
        ok <- !is.na(pos)
        source[ii[ok]] <- ii[pos[ok]]
      }
    }
    out <- matrix(NA_real_, nrow(Y), ncol(Y))
    ok <- !is.na(source)
    out[ok, ] <- Y[source[ok], , drop = FALSE]
    out
  })
  lag <- do.call(cbind, lagged)

  keep <- if (isTRUE(delete_missings)) {
    !(rowSums(is.na(Y)) > 0 | rowSums(is.na(lag)) > 0)
  } else {
    rep(TRUE, nrow(Y))
  }
  lag_names <- if (identical(lags, 1L)) vars else
    unlist(lapply(lags, function(l) paste0(vars, "_lag", l)),
           use.names = FALSE)
  out <- list(data_c = Y[keep, , drop = FALSE],
              data_l = cbind(1, lag[keep, , drop = FALSE]),
              vars = vars, lags = lags)
  colnames(out$data_c) <- vars
  colnames(out$data_l) <- c("(Intercept)", lag_names)
  if (isTRUE(delete_missings) && nrow(out$data_c) == 0L) {
    stop("No complete lag pairs remain after deleting missing values.",
         call. = FALSE)
  }
  out
}


# ============================================================
# Internal: lambda grid (graphicalVAR::generate_lambdas)
# ============================================================

#' @noRd
.gvar_invGlasso <- function(x) {
  if (all(eigen(x, symmetric = TRUE, only.values = TRUE)$values >
          sqrt(.Machine$double.eps))) {
    solve(x)
  } else {
    .glasso_fit(x, 0.05, penalize.diagonal = FALSE)$wi
  }
}

#' @noRd
.gvar_genlambda <- function(X, Y, n_lk, n_lb, lmin_k = 0.05, lmin_b = 0.05) {
  n <- nrow(Y)
  corY <- stats::cov2cor(crossprod(Y) / n)
  lk_max <- max(abs(corY[upper.tri(corY)]))
  if (!is.finite(lk_max) || lk_max <= 0) {
    stop("Cannot build the kappa lambda grid: the current variables are ",
         "degenerate (constant or perfectly collinear after scaling). ",
         "Check for zero-variance variables.", call. = FALSE)
  }
  lam_k <- exp(seq(log(lk_max), log(lmin_k * lk_max), length.out = n_lk))

  Yinv <- .gvar_invGlasso(crossprod(Y))
  lb_max <- max(abs(crossprod(X, Y) %*% Yinv))
  if (!is.finite(lb_max) || lb_max <= 0) {
    stop("Cannot build the beta lambda grid: the lagged predictors are ",
         "degenerate (constant or perfectly collinear).", call. = FALSE)
  }
  lam_b <- exp(seq(log(lb_max), log(lmin_b * lb_max), length.out = n_lb))

  list(lambda_kappa = lam_k, lambda_beta = lam_b)
}

#' Select the minimum-EBIC cell, preferring lower kappa then lower beta within
#' the requested absolute tolerance.
#' @noRd
.gvar_select_ebic <- function(grid, ebic_tol = 1e-4) {
  ok <- is.finite(grid$ebic) & is.finite(grid$kappa) & is.finite(grid$beta)
  if (!any(ok)) {
    stop("No finite EBIC value was produced by the lambda grid.", call. = FALSE)
  }
  min_ebic <- min(grid$ebic[ok])
  cand <- which(ok & abs(grid$ebic - min_ebic) <= ebic_tol)
  cand <- cand[grid$kappa[cand] == min(grid$kappa[cand])]
  cand <- cand[grid$beta[cand] == min(grid$beta[cand])]
  cand[[1L]]
}


# ============================================================
# Internal: Rothman/MRCE joint estimator (graphicalVAR::Rothmana)
# ============================================================

#' @noRd
.gvar_soft <- function(z, g) sign(z) * pmax(abs(z) - g, 0)

#' MRCE beta-update (coordinate descent), equivalent to graphicalVAR's Beta_C.
#'
#' Minimises (1/n) tr{ kappa (Y - XB)'(Y - XB) } + sum lambda_mat * |B|.
#' @noRd
.gvar_beta <- function(kappa, beta, X, Y, lambda_mat,
                       convergence = 1e-4, maxit = 100L, details = FALSE) {
  n <- nrow(X); nX <- ncol(X); nY <- ncol(Y)
  Sxx <- crossprod(X)
  Sxy <- crossprod(X, Y)
  Om  <- kappa
  B <- beta
  U <- Sxy - Sxx %*% B
  converged <- FALSE
  for (it in seq_len(maxit)) {
    B_old <- B
    for (cc in seq_len(nY)) {
      for (r in seq_len(nX)) {
        den <- Sxx[r, r] * Om[cc, cc]
        z   <- B[r, cc] + sum(U[r, ] * Om[, cc]) / den
        b   <- .gvar_soft(z, lambda_mat[r, cc] * n / den)
        delta <- b - B[r, cc]
        if (delta != 0) {
          B[r, cc] <- b
          U[, cc] <- U[, cc] - Sxx[, r] * delta
        }
      }
    }
    if (sum(abs(B - B_old)) < convergence * sum(abs(B))) {
      converged <- TRUE
      break
    }
  }
  if (isTRUE(details)) {
    list(beta = B, iterations = it, converged = converged)
  } else {
    B
  }
}

#' kappa-update: graphical lasso on the residual covariance.
#'
#' `regularize_mat_kappa` (a `p x p` logical/0-1 mask, default penalise all
#' off-diagonals) maps to glasso's element-wise penalty `regularize_mat_kappa *
#' lambda_kappa`, matching graphicalVAR::Kappa.
#' @noRd
.gvar_kappa <- function(beta, X, Y, lambda_kappa, regularize_mat_kappa = NULL) {
  n <- nrow(Y)
  R <- Y - X %*% beta
  SigmaR <- crossprod(R) / n
  if (is.null(regularize_mat_kappa)) {
    # Scalar penalty, off-diagonal only (default mask penalises off-diagonals).
    wi <- .glasso_fit(SigmaR, rho = lambda_kappa, penalize.diagonal = FALSE)$wi
  } else {
    # Element-wise penalty matrix. Pass penalize.diagonal = TRUE so the matrix's
    # diagonal (diag(Rho)) is honoured -- matching glasso(SigmaR, mask*lambda).
    # The default mask has a 0 diagonal, so this reduces to the scalar case.
    rho <- regularize_mat_kappa * lambda_kappa
    wi <- .glasso_fit(SigmaR, rho = rho, penalize.diagonal = TRUE)$wi
  }
  (wi + t(wi)) / 2
}

#' Build the beta penalty matrix (graphicalVAR::Rothmana lambda_mat logic).
#' @noRd
.gvar_lambda_mat <- function(lambda_beta, nX, nY, penalize_diagonal,
                             regularize_mat_beta) {
  if (is.null(regularize_mat_beta)) {
    lambda_mat <- matrix(lambda_beta, nX, nY)
    if (!penalize_diagonal) {
      # beta is (intercept + p * L) x p. Each lag block has its own AR
      # diagonal, at predictor row 1 + (lag - 1) * p + outcome.
      predictor_rows <- seq_len(nX - 1L)
      outcome <- ((predictor_rows - 1L) %% nY) + 1L
      lambda_mat[cbind(predictor_rows + 1L, outcome)] <- 0
    }
  } else {
    lambda_mat <- lambda_beta * t(regularize_mat_beta)
    if (nrow(lambda_mat) == nX - 1L) {
      # Intercept is beta's FIRST row (data_l = cbind(1, lag...)), so the
      # unpenalised intercept row must be PREPENDED, not appended -- matching
      # graphicalVAR's Rothmana (rbind(0, t(M))). Appending it instead shifts
      # every predictor penalty down one row.
      lambda_mat <- rbind(0, lambda_mat)
    }
    if (nrow(lambda_mat) != nX || ncol(lambda_mat) != nY) {
      stop("`regularize_mat_beta` has the wrong dimensions (expected ",
           nY, " x ", nY, " or ", nY, " x ", nX, ").", call. = FALSE)
    }
  }
  lambda_mat[1L, ] <- 0                          # intercept column never penalised
  lambda_mat
}

#' One (lambda_beta, lambda_kappa) cell: alternate beta/kappa, then EBIC.
#' @noRd
.gvar_rothman <- function(X, Y, lambda_beta, lambda_kappa, gamma,
                          penalize_diagonal = TRUE,
                          convergence = 1e-4,
                          maxit_out = 100L, maxit_in = 100L,
                          regularize_mat_beta = NULL,
                          regularize_mat_kappa = NULL,
                          likelihood = c("unpenalized", "penalized")) {
  likelihood <- match.arg(likelihood)
  n <- nrow(X); nX <- ncol(X); nY <- ncol(Y)

  lambda_mat <- .gvar_lambda_mat(lambda_beta, nX, nY, penalize_diagonal,
                                 regularize_mat_beta)

  beta_ridge <- solve(crossprod(X) + lambda_beta * diag(nX), crossprod(X, Y))
  beta <- matrix(0, nX, nY)
  it <- 0L
  converged_outer <- FALSE
  inner_iterations <- integer()
  converged_inner <- logical()
  repeat {
    it <- it + 1L
    kappa <- .gvar_kappa(beta, X, Y, lambda_kappa, regularize_mat_kappa)
    beta_old <- beta
    beta_fit <- .gvar_beta(kappa, beta, X, Y, lambda_mat, convergence,
                           maxit_in, details = TRUE)
    beta <- beta_fit$beta
    inner_iterations <- c(inner_iterations, beta_fit$iterations)
    converged_inner <- c(converged_inner, beta_fit$converged)
    if (sum(abs(beta - beta_old)) < convergence * sum(abs(beta_ridge))) {
      converged_outer <- TRUE
      break
    }
    if (it >= maxit_out) break
  }

  WS <- (crossprod(Y) - crossprod(Y, X %*% beta) -
           crossprod(beta, crossprod(X, Y)) +
           crossprod(beta, crossprod(X) %*% beta)) / n
  WS <- (WS + t(WS)) / 2

  if (likelihood == "unpenalized") {
    # Refit precision on the residual covariance with kappa's zero-pattern fixed.
    zi <- which(kappa == 0, arr.ind = TRUE)
    refit <- if (nrow(zi) == 0L) .glasso_fit(WS, rho = 0) else
      .glasso_fit(WS, rho = 0, zero = zi)
    lik1 <- determinant(refit$wi)$modulus[1]
    lik2 <- sum(diag(refit$wi %*% WS))
  } else {
    # Penalised likelihood: use the regularised kappa directly.
    lik1 <- determinant(kappa)$modulus[1]
    lik2 <- sum(diag(kappa %*% WS))
  }

  pdO <- sum(kappa[upper.tri(kappa)] != 0)
  pdB <- sum(beta[lambda_mat != 0] != 0)
  LLk <- (n / 2) * (lik1 - lik2)
  ebic <- -2 * LLk + log(n) * (pdO + pdB) +
    (pdO + pdB) * 4 * gamma * log(2 * nY)

  list(
    beta = t(beta),
    kappa = kappa,
    EBIC = as.numeric(ebic),
    convergence = list(
      outer_converged = converged_outer,
      outer_iterations = it,
      inner_converged = converged_inner,
      inner_iterations = inner_iterations,
      maxit_out = maxit_out,
      maxit_in = maxit_in
    )
  )
}


# ============================================================
# Internal: PCC and PDC (graphicalVAR::computePCC / computePDC)
# ============================================================

#' @noRd
.gvar_compute_pcc <- function(kappa) {
  pcc <- -stats::cov2cor(kappa)
  diag(pcc) <- 0
  (pcc + t(pcc)) / 2
}

#' @noRd
.gvar_compute_pdc <- function(beta, kappa) {
  if (ncol(beta) == nrow(beta) + 1L) beta <- beta[, -1L, drop = FALSE]
  sigma <- solve(kappa)
  denom <- sqrt(diag(sigma) %o% diag(kappa) + beta^2)
  denom[denom == 0] <- 1
  t(beta / denom)
}


# ============================================================
# S3 Methods
# ============================================================

#' Print Method for gvar_result
#'
#' @param x A \code{gvar_result} object.
#' @param digits Number of digits used for printed network matrices.
#' @param ... Additional arguments (ignored).
#'
#' @return The input object, invisibly.
#'
#' @export
print.gvar_result <- function(x, digits = 2, ...) {
  d <- length(x$labels)
  temporal_layers <- x$temporal_layers %||% list(lag1 = x$temporal)
  n_temp <- sum(vapply(temporal_layers, function(z) sum(z != 0), integer(1)))
  n_contemp <- sum(x$PCC[upper.tri(x$PCC)] != 0)

  cat("Graphical VAR Result\n")
  cat(sprintf("  Variables:      %d (%s)\n", d, paste(x$labels, collapse = ", ")))
  cat(sprintf("  Lags:           %s\n", paste(x$lags %||% 1L, collapse = ", ")))
  cat(sprintf("  Observations:   %d\n", x$n_obs))
  cat(sprintf("  Temporal edges: %d / %d\n", n_temp,
              d * d * length(temporal_layers)))
  cat(sprintf("  Contemp edges:  %d / %d\n", n_contemp, d * (d - 1) / 2))
  cat(sprintf("  EBIC:           %.2f (gamma=%.2f)\n", x$EBIC, x$gamma))
  cat(sprintf("  Lambda:         beta=%.4f, kappa=%.4f\n",
              x$lambda_beta, x$lambda_kappa))
  .ido_print_networks(x, digits = digits)
  temporal_name <- if (length(temporal_layers) == 1L &&
                       identical(x$lags %||% 1L, 1L)) "temporal" else
    paste0("temporal_lag", (x$lags %||% 1L)[1L])
  cat(paste0("\n  plot(x) | plot(x, layer = \"", temporal_name, "\")"),
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' Coerce a gvar_result to plottable netobjects
#'
#' Returns the temporal lag layer(s) and contemporaneous network as netobjects,
#' so each renders directly with \code{cograph::splot()} (or any netobject verb)
#' without the caller transposing matrices or dropping intercept columns. The
#' temporal network is oriented \code{[from = predictor(t-1), to = outcome(t)]}.
#'
#' @param x A \code{gvar_result}.
#' @param ... Ignored.
#' @return A \code{netobject_group}: a named list with \code{$temporal} for a
#'   lag-1 model, or one `temporal_lagN` element per multi-lag model, plus
#'   \code{$contemporaneous}.
#' @export
as_netobject.gvar_result <- function(x, ...) {
  .ido_network_group(x)
}

#' Summary Method for gvar_result
#'
#' @param object A \code{gvar_result} object.
#' @param ... Additional arguments (ignored).
#'
#' @return A tidy \code{data.frame} of per-network metrics: one row per network
#'   (\code{temporal}, \code{contemporaneous}) with \code{n_nodes},
#'   \code{n_edges}, \code{density}, \code{mean_abs_weight}, \code{n_positive},
#'   \code{n_negative}. Use \code{edges(object)} / \code{coefs(object)} for the
#'   estimates and \code{nodes(object)} for node strengths.
#'
#' @export
summary.gvar_result <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
