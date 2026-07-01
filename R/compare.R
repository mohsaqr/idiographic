# ---- Cross-estimator comparison reports ----

#' Compare idiographic estimators on one dataset
#'
#' @description
#' Fits one or more idiographic estimators to the same data and returns a tidy
#' per-method/per-network comparison table. This is a reporting layer: it does
#' not define a new model, and each row is computed from the estimator's own
#' [summary()] method plus common edge-table accessors.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param estimators Character vector naming estimators to fit. Supported values
#'   are `"var"`, `"graphical_var"`, `"mlvar"`, `"usem"`, and `"gimme"`.
#' @param id Character. Name of the person-ID column, or `NULL`.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param estimator_args Named list of per-estimator argument lists, e.g.
#'   `list(graphical_var = list(n_lambda = 8), usem = list(temporal = "ar"))`.
#' @param keep_fits Logical. Store fitted model objects? Default `FALSE`.
#'
#' @return A `model_comparison` object with `$comparison`, `$failures`, and
#'   optionally `$fits`. `$comparison` is a tidy `data.frame` with one row per
#'   method/network.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, day = rep(1:4, each = 15),
#'                 beep = rep(1:15, 4),
#'                 A = rnorm(60), B = rnorm(60), C = rnorm(60))
#' cmp <- compare_idiographic(
#'   d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
#'   estimators = c("var", "graphical_var"),
#'   estimator_args = list(graphical_var = list(n_lambda = 5))
#' )
#' cmp$comparison
#' @export
compare_idiographic <- function(data, vars,
                                estimators = c("var", "graphical_var"),
                                id = NULL, day = NULL, beep = NULL,
                                estimator_args = list(),
                                keep_fits = FALSE) {
  supported <- c("var", "graphical_var", "mlvar", "usem", "gimme")
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.character(estimators), length(estimators) >= 1L)
  .ido_check_flag(keep_fits, "keep_fits")
  bad <- setdiff(estimators, supported)
  if (length(bad) > 0L) {
    stop("Unsupported estimator(s): ", paste(bad, collapse = ", "),
         ". Supported values are: ", paste(supported, collapse = ", "),
         call. = FALSE)
  }
  if (!is.list(estimator_args)) {
    stop("`estimator_args` must be a named list of argument lists.",
         call. = FALSE)
  }

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)

  rows <- list()
  fits <- list()
  failures <- data.frame(method = character(), message = character(),
                         stringsAsFactors = FALSE)

  for (method in estimators) {
    args <- estimator_args[[method]] %||% list()
    if (!is.list(args)) {
      stop("`estimator_args$", method, "` must be a list.", call. = FALSE)
    }
    fit <- tryCatch(
      do.call(.compare_fit_fun(method),
              c(list(data = data, vars = vars, id = id, day = day,
                     beep = beep), args)),
      error = function(e) e
    )
    if (inherits(fit, "error")) {
      failures <- rbind(failures,
                        data.frame(method = method, message = fit$message,
                                   stringsAsFactors = FALSE))
      next
    }
    tab <- .compare_metrics(method, fit)
    rows[[length(rows) + 1L]] <- tab
    if (isTRUE(keep_fits)) fits[[method]] <- fit
  }

  comparison <- if (length(rows)) {
    do.call(rbind, rows)
  } else {
    data.frame(method = character(), network = character(), n_nodes = integer(),
               n_edges = integer(), density = numeric(),
               mean_abs_weight = numeric(), n_positive = integer(),
               n_negative = integer(), n_self = integer(),
               max_abs_weight = numeric(), stringsAsFactors = FALSE)
  }
  rownames(comparison) <- NULL

  out <- list(
    comparison = comparison,
    failures = failures,
    fits = if (isTRUE(keep_fits)) fits else NULL,
    n_success = length(rows),
    n_requested = length(estimators),
    config = list(estimators = estimators, id = id, day = day, beep = beep)
  )
  class(out) <- "model_comparison"
  out
}

#' @noRd
.compare_fit_fun <- function(method) {
  switch(method,
         var = build_var,
         graphical_var = graphical_var,
         mlvar = build_mlvar,
         usem = build_usem,
         gimme = build_gimme)
}

#' @noRd
.compare_metrics <- function(method, fit) {
  sm <- summary(fit)
  ed <- edges(fit, include_self = TRUE)
  extra <- lapply(sm$network, function(net) {
    e <- ed[ed$network == net, , drop = FALSE]
    data.frame(
      n_self = sum(e$from == e$to),
      max_abs_weight = if (nrow(e)) max(abs(e$weight)) else 0,
      stringsAsFactors = FALSE
    )
  })
  out <- cbind(data.frame(method = method, stringsAsFactors = FALSE),
               sm, do.call(rbind, extra))
  rownames(out) <- NULL
  out
}

#' Print method for model comparisons
#'
#' @param x A `model_comparison` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.model_comparison <- function(x, ...) {
  cat("Idiographic Model Comparison\n")
  cat(sprintf("  Requested: %d\n", x$n_requested))
  cat(sprintf("  Successful: %d\n", x$n_success))
  cat(sprintf("  Failures:   %d\n", nrow(x$failures)))
  cat("  Tables:     x$comparison | x$failures\n")
  if (!is.null(x$fits) && length(x$fits) > 0L) {
    cat("  Cograph:    cograph::splot(x$fits[[1]])\n")
    cat("  Matrices:   matrices(x$fits[[1]])\n")
  } else {
    cat("  Fits:       rerun with keep_fits = TRUE for cograph plots\n")
  }
  invisible(x)
}

#' @export
as.data.frame.model_comparison <- function(x, row.names = NULL,
                                           optional = FALSE, ...) {
  x$comparison
}
