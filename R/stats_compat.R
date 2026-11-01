# Compatibility bridges for the consolidated statistical and network APIs.

#' Fit person-specific machine-learning models
#'
#' `fit_ml()` supports both historical `idiographic` calls using
#' `outcome`/`predictors` and the consolidated panel-model API using `y`/`x`.
#' Calls that name `y` or `x`, or that pass a consolidated control such as
#' `time`, `scope`, `subgroup` or `tune`, use the consolidated result
#' contract; existing positional and `outcome`/`predictors` calls retain their
#' original behaviour.
#'
#' @details
#' Both interfaces evaluate prediction on an ordered hold-out: the last
#' `ceiling(test_prop * n)` rows of each person are the test set and are never
#' used for estimation. In the consolidated interface, `tune = TRUE` carves a
#' further validation block (`valid_prop`) from the tail of the training rows,
#' scores the candidate settings on it, and refits the winning setting on the
#' training and validation rows before predicting the test rows.
#'
#' Consolidated controls passed through `...` are `time` (ordering column),
#' `scope` (`"pooled"`, `"subgroup"`, `"individual"`, `"both"` or `"all"`),
#' `subgroup` (as in [fit_lm()]), `valid_prop`, `ncomp` (`pcr`), `mtry` and
#' `num_trees` (`forest`), `cost` (`svm`), `tune` and `grid` (a named list of
#' tuning grids, e.g. `list(knn = list(k = c(3, 5)))`). [models()] lists every
#' model name with its estimator, package and tuned parameter. Native models
#' need only base R. When an optional backend package is missing, an
#' interactive session offers to install it after confirmation; otherwise the
#' call stops with an error that names the package.
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
#' @param ... Arguments passed to the selected implementation; in the
#'   consolidated interface, the controls listed in Details.
#' @param y,x Consolidated outcome and predictor selectors. Supply both.
#'
#' @return For consolidated calls, an `idiographic_fit` (also of class
#'   `idiostats_fit`). Its tables are read with accessors: [metrics()] (one
#'   row per scope, model, estimator and person, plus `.overall` rows, with
#'   `rmse`, `mae`, `bias` and `r_squared` for regression), [predictions()]
#'   (one row per held-out occasion and model), [coefs()], [importance()],
#'   [tuning()] and [failures()].
#'
#'   For historical calls, an `idioml_result`. `as.data.frame()` returns its
#'   held-out predictions, `summary()` its metrics (one row per
#'   `model_scope`, model, estimator and person), [coefs()] its coefficients
#'   (one row per `model_scope`, model, person and term) and [predict()]
#'   predictions for new rows.
#' @examples
#' # Consolidated interface: pooled and person-specific models, tidy results.
#' fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day", scope = "both", model = c("mean", "ridge"))
#' metrics(fit, overall = TRUE)
#' best_model(fit)
#'
#' # Tune the number of neighbours on a validation block before testing.
#' tuned <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'                 time = "day", scope = "pooled", model = "knn", tune = TRUE)
#' tuning(tuned)
#'
#' # Historical interface (outcome, predictors, id).
#' legacy <- fit_ml(srl, "effort", c("efficacy", "planning"), "name",
#'                  model = "ridge")
#' legacy
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

#' Fit machine learning with the consolidated scoped result contract
#'
#' `fit_ml_panel()` is the unambiguous positional entry point for code migrated
#' from `idiostats`. It always returns the consolidated scoped result used by
#' `metrics()`, `predictions()`, `tuning()`, and the result-view functions.
#' Named `fit_ml(data, y = ..., x = ..., id = ...)` calls are equivalent.
#'
#' @param data A data frame or matrix.
#' @param y Outcome column name.
#' @param x Predictor selector.
#' @param id Person identifier column.
#' @param ... Consolidated ML controls; see [fit_ml()].
#'
#' @return An `idiographic_fit` retaining the `idiostats_fit` compatibility
#'   class.
#' @examples
#' fit <- fit_ml_panel(srl, "effort", "efficacy:monitoring", "name",
#'                     time = "day", scope = "pooled", model = "ridge")
#' metrics(fit, overall = TRUE)
#' @export
fit_ml_panel <- function(data, y, x, id, ...) {
  .fit_ml_stats(data = data, y = y, x = x, id = id, ...)
}
