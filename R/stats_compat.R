# Compatibility bridges for the consolidated statistical and network APIs.

#' Fit person-specific machine-learning models
#'
#' `fit_ml()` supports both historical `idiographic` calls using
#' `outcome`/`predictors` and the consolidated panel-model API using `y`/`x`.
#' Calls that name `y` or `x` use the consolidated result contract; existing
#' positional and `outcome`/`predictors` calls retain their original behavior.
#'
#' @param data A data frame or matrix.
#' @param outcome,predictors Historical `idiographic` outcome and predictor
#'   arguments.
#' @param id Person identifier column.
#' @param day,beep Optional historical ordering columns.
#' @param task Outcome task: `"auto"`, `"regression"`, or `"classification"`.
#' @param model One or more model names.
#' @param estimator Optional implementation backend.
#' @param compare Historical scope selector: `"both"`, `"individual"`, or
#'   `"pooled"`.
#' @param test_prop Proportion of each person's ordered rows used for testing.
#' @param min_train,min_test Minimum training and test rows.
#' @param lambda,alpha Penalized-model controls.
#' @param k Number of neighbours for nearest-neighbour models.
#' @param n_components Number of principal components for the historical API.
#' @param max_iter,tol Iteration limit and convergence tolerance.
#' @param standardize Use training-only predictor standardization?
#' @param keep_fits Retain fitted backend objects?
#' @param ... Arguments passed to the selected implementation.
#' @param y,x Consolidated outcome and predictor selectors. Supply both.
#'
#' @return An `idioml_result` for historical calls or an `idiostats_fit` for
#'   consolidated `y`/`x` calls.
#' @export
fit_ml <- function(data, outcome, predictors, id,
                   day = NULL, beep = NULL,
                   task = c("auto", "regression", "classification"),
                   model = NULL, estimator = NULL,
                   compare = c("both", "individual", "pooled"),
                   test_prop = 0.2, min_train = 10L, min_test = 1L,
                   lambda = 1, alpha = 0.5, k = 5L,
                   n_components = NULL, max_iter = 100L, tol = 1e-6,
                   standardize = TRUE, keep_fits = FALSE, ...,
                   y, x) {
  dots <- list(...)
  panel_only <- c(
    "time", "scope", "subgroup", "valid_prop", "ncomp", "mtry",
    "num_trees", "cost", "tune", "grid", "rounds", "learn_rate", "df",
    "span", "nterms", "cp", "size", "decay", "tau", "alpha_split"
  )
  panel_call <- !missing(y) || !missing(x) ||
    any(names(dots) %in% panel_only)
  if (panel_call) {
    if (missing(y) && missing(x)) {
      if (missing(outcome) || missing(predictors)) {
        stop("Supply `y` and `x`, or positional outcome and predictors.",
             call. = FALSE)
      }
      y <- outcome
      x <- predictors
    } else if (missing(y) || missing(x)) {
      stop("Supply both `y` and `x` for the consolidated fit_ml() API.",
           call. = FALSE)
    }
    if (missing(id)) stop("Supply `id`.", call. = FALSE)
    panel_args <- list(data = data, y = y, x = x, id = id,
                       test_prop = test_prop, min_train = min_train,
                       min_test = min_test, lambda = lambda, alpha = alpha,
                       k = k)
    if (!missing(model)) panel_args$model <- model
    if (!missing(estimator)) panel_args$estimator <- estimator
    return(do.call(.fit_ml_stats, c(panel_args, dots)))
  }

  if (missing(outcome) || missing(predictors) || missing(id)) {
    stop("Supply `outcome`, `predictors`, and `id`, or supply `y`, `x`, and `id`.",
         call. = FALSE)
  }
  legacy_args <- list(
    data = data, outcome = outcome, predictors = predictors, id = id,
    day = day, beep = beep, task = task, model = model,
    estimator = estimator, compare = compare, test_prop = test_prop,
    min_train = min_train, min_test = min_test, lambda = lambda,
    alpha = alpha, k = k, n_components = n_components,
    max_iter = max_iter, tol = tol, standardize = standardize,
    keep_fits = keep_fits
  )
  do.call(.fit_ml_legacy, c(legacy_args, dots))
}
