# ---- Ordinary least-squares Vector Autoregression (VAR) ----

#' Build an ordinary least-squares VAR network
#'
#' @description
#' Fits a transparent VAR(1) baseline from intensive longitudinal data using
#' ordinary least squares: current variables are regressed on an intercept and
#' lag-1 predictors. The lag construction, scaling, within-person centring,
#' and day-boundary behaviour match [fit_graphical_var()], but no regularization or
#' EBIC model selection is applied.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param id Character. Name of the person-ID column, or `NULL` for a single
#'   series.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param lags Integer. Only `1` is supported.
#' @param scale Logical. Whether to standardize variables before lagging.
#'   Default `TRUE`.
#' @param center_within Logical. Whether to centre within person when more than
#'   one id is present. Default `TRUE`.
#' @param delete_missings Logical. Drop incomplete current/lagged rows. Default
#'   `TRUE`.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations.
#' @param subject Optional vector naming the subject(s) to analyse.
#'
#' @return A `var_result` object with temporal OLS coefficients, residual
#'   covariance, residual precision, contemporaneous partial correlations, and
#'   tidy access through [edges()], [coefs()], [nodes()], and [summary()].
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
#' fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")
#' edges(fit)
#' @export
fit_var <- function(data, vars, id = NULL, day = NULL, beep = NULL,
                      lags = 1L,
                      scale = TRUE,
                      center_within = TRUE,
                      delete_missings = TRUE,
                      min_obs = NULL,
                      subject = NULL) {
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  if (!(length(lags) == 1L && lags == 1L)) {
    stop("fit_var() supports lags = 1 only.", call. = FALSE)
  }
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(delete_missings, "delete_missings")

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

  ts <- .gvar_tsdata(data, vars, id, day, beep, scale, center_within,
                     delete_missings)
  X <- ts$data_l
  Y <- ts$data_c
  n <- nrow(Y)
  p <- length(vars)
  if (n <= p + 1L) {
    stop("Too few lag pairs (", n, ") for ", p, " variables.", call. = FALSE)
  }

  fit <- stats::lm.fit(x = X, y = Y)
  if (fit$rank < ncol(X) || anyNA(fit$coefficients)) {
    stop("Lagged VAR design is rank-deficient; remove duplicated/collinear ",
         "variables or use fit_graphical_var() regularization.", call. = FALSE)
  }
  beta <- t(fit$coefficients)
  rownames(beta) <- vars
  colnames(beta) <- colnames(X)
  temporal <- beta[, -1L, drop = FALSE]
  dimnames(temporal) <- list(vars, vars)

  residuals <- Y - X %*% fit$coefficients
  residual_cov <- stats::cov(residuals)
  dimnames(residual_cov) <- list(vars, vars)
  kappa <- .var_precision(residual_cov)
  dimnames(kappa) <- list(vars, vars)
  pcc <- -stats::cov2cor(kappa)
  diag(pcc) <- 0
  pcc <- (pcc + t(pcc)) / 2
  pdc <- .gvar_compute_pdc(beta, kappa)
  dimnames(pdc) <- list(vars, vars)

  model <- list(
    beta = beta,
    temporal = temporal,
    residual_cov = residual_cov,
    kappa = kappa,
    PCC = pcc,
    PDC = pdc,
    contemporaneous = pcc,
    labels = vars,
    n_obs = n,
    df_residual = fit$df.residual,
    rank = fit$rank,
    scale = scale,
    center_within = center_within
  )
  .ido_group_result(
    "var_result",
    list(
      temporal = .ido_wrap(t(temporal), method = "relative", directed = TRUE),
      contemporaneous = .ido_wrap(pcc, method = "co_occurrence",
                                  directed = FALSE)
    ),
    model
  )
}

#' Fit an ordinary least-squares VAR for every subject
#'
#' Applies [fit_var()] to each subject separately, returning one transparent
#' person-specific OLS VAR result per individual. This is the unregularized
#' companion to [fit_graphical_var_each()] and is useful as an equivalence baseline
#' for checking lag construction, scaling, and temporal coefficient direction.
#'
#' @inheritParams fit_var
#' @param id Character. Name of the person-ID column; required.
#' @param ... Further arguments passed to [fit_var()].
#' @return A named list of `var_result` objects (class `var_list`), one element
#'   per subject, named by subject id. Subjects that cannot be fit are dropped
#'   with a warning.
#' @examples
#' set.seed(1)
#' d <- data.frame(
#'   id = rep(1:3, each = 40),
#'   day = rep(1, 120),
#'   beep = rep(seq_len(40), 3),
#'   A = rnorm(120), B = rnorm(120), C = rnorm(120)
#' )
#' fits <- fit_var_each(d, vars = c("A", "B", "C"), id = "id",
#'                        day = "day", beep = "beep")
#' fits[["1"]]
#' @export
fit_var_each <- function(data, vars, id, day = NULL, beep = NULL,
                           min_obs = NULL, ...) {
  stopifnot(is.data.frame(data), is.character(vars), length(vars) >= 2L,
            is.character(id), length(id) == 1L, id %in% names(data))

  data <- .ido_keep(data, id, min_obs)
  ids <- unique(data[[id]])

  fits <- lapply(ids, function(s) {
    tryCatch(
      fit_var(data, vars = vars, id = id, day = day, beep = beep,
                subject = s, ...),
      error = function(e) NULL
    )
  })
  names(fits) <- as.character(ids)

  failed <- vapply(fits, is.null, logical(1))
  if (any(failed)) {
    warning(sum(failed), " subject(s) could not be fit and were dropped: ",
            paste(names(fits)[failed], collapse = ", "), call. = FALSE)
    fits <- fits[!failed]
  }
  structure(fits, class = "var_list")
}

#' @noRd
.var_precision <- function(S) {
  ev <- eigen(S, symmetric = TRUE, only.values = TRUE)$values
  if (all(is.finite(ev)) && min(ev) > sqrt(.Machine$double.eps)) {
    solve(S)
  } else {
    .ido_pseudoinverse(S)
  }
}

#' @export
as_netobject.var_result <- function(x, ...) {
  .ido_network_group(x)
}

#' @rdname edges
#' @export
edges.var_result <- function(x, sort_by = "weight", include_self = FALSE,
                             network = NULL, n = NULL, ...) {
  edges(as_netobject(x), sort_by = sort_by, include_self = include_self,
        network = network, n = n)
}

#' @rdname coefs
#' @export
coefs.var_result <- function(x, ...) {
  .tidy_over_group(as_netobject(x), function(net, nm) {
    .tidy_net_long(net, nm, keep_zeros = TRUE)
  })
}

#' @rdname nodes
#' @export
nodes.var_result <- function(x, ...) {
  nodes(as_netobject(x), ...)
}

#' @export
as.data.frame.var_result <- function(x, row.names = NULL, optional = FALSE,
                                     ...) {
  edges(x, ...)
}

#' Summary method for ordinary VAR fits
#'
#' @param object A `var_result` object.
#' @param ... Ignored.
#' @return A tidy per-network metrics `data.frame`.
#' @export
summary.var_result <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}

#' Print method for ordinary VAR fits
#'
#' @param x A `var_result` object.
#' @param digits Number of digits used for printed network matrices.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.var_result <- function(x, digits = 2, ...) {
  cat("OLS VAR Result\n")
  cat(sprintf("  Variables:      %d (%s)\n",
              length(x$labels), paste(x$labels, collapse = ", ")))
  cat(sprintf("  Observations:   %d\n", x$n_obs))
  cat(sprintf("  Temporal edges: %d / %d\n",
              sum(x$temporal != 0), length(x$temporal)))
  cat(sprintf("  Contemp edges:  %d / %d\n",
              sum(x$PCC[upper.tri(x$PCC)] != 0),
              length(x$labels) * (length(x$labels) - 1) / 2))
  .ido_print_networks(x, digits = digits)
  cat("\n  plot(x) | plot(x, layer = \"temporal\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' Print a list of per-subject ordinary VARs
#'
#' @param x A `var_list`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.var_list <- function(x, ...) {
  if (length(x) == 0L) {
    cat("Idiographic OLS VARs\n")
    cat("  Subjects:       0 (none could be fit)\n")
    return(invisible(x))
  }
  n_obs <- vapply(x, function(g) g$n_obs, integer(1))
  temporal_edges <- vapply(x, function(g) sum(g$temporal != 0), integer(1))
  cat("Idiographic OLS VARs\n")
  cat(sprintf("  Subjects:       %d\n", length(x)))
  cat(sprintf("  Variables:      %d\n", length(x[[1L]]$labels)))
  cat(sprintf("  Lag pairs:      median %g (range %d-%d)\n",
              stats::median(n_obs), min(n_obs), max(n_obs)))
  cat(sprintf("  Temporal edges: median %g (range %d-%d)\n",
              stats::median(temporal_edges), min(temporal_edges),
              max(temporal_edges)))
  cat(sprintf("  Access:         x[[\"%s\"]] | cograph::splot(x[[\"%s\"]])\n",
              names(x)[1L], names(x)[1L]))
  invisible(x)
}

#' @export
summary.var_list <- function(object, ...) {
  .ido_stack_subject_tables(object, summary, ...)
}

#' @export
as.data.frame.var_list <- function(x, row.names = NULL, optional = FALSE, ...) {
  coefs(x, ...)
}
