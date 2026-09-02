#' Fit pooled, subgroup and person-specific linear models
#'
#' Fits a linear model at every requested scope and returns them in one tidy
#' object, so pooled and person-specific results are directly comparable.
#'
#' @param data Data frame.
#' @param y Outcome column name.
#' @param x Predictors: names, numeric positions, `a:b` range, formula, or data frame.
#' @param id Person/unit ID column.
#' @param time Optional ordering column.
#' @param scope `"both"` (pooled + individual), `"pooled"`, `"individual"`,
#'   `"subgroup"`, or `"all"` (pooled + subgroup + individual).
#' @param subgroup Optional subgroup mapping: an [find_subgroups()] result, a
#'   grouping column in `data`, or a named vector of labels per person.
#' @param test_prop Proportion of each person's ordered rows held out.
#' @param min_train Minimum complete training rows per person.
#' @param min_test Minimum complete held-out rows per person.
#' @param estimator `"native"` for `stats::lm()`, or `"robust"` for an
#'   M-estimator (`MASS::rlm()`) that is not dragged around by outliers.
#' @param weights Optional column name in `data` holding case weights.
#' @param ... Passed to the underlying fitter.
#' @return An `idiostats_fit`.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day")
#' metrics(fit, overall = TRUE)
#'
#' # A few wild days should not decide a person's slope.
#' robust <- fit_lm(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'                  time = "day", estimator = "robust")
#' metrics(robust, overall = TRUE)
#' @export
fit_lm <- function(data, y, x, id, time = NULL, scope = "both",
                   subgroup = NULL, estimator = "native", weights = NULL,
                   test_prop = 0.2, min_train = 10L, min_test = 1L, ...) {
  estimator <- match.arg(estimator, c("native", "robust"))
  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, test_prop = test_prop,
                        min_train = min_train, min_test = min_test,
                        task = "regression", exclude = weights)

  fit_fun <- if (estimator == "robust") .idio_rlm_one else .idio_lm_one
  wcol <- .idio_weight_column(prep$data, weights)

  out <- .idio_fit_formula_family(
    prep = prep, y = y, id = id, model = "lm", estimator = estimator,
    family = NULL, fit_fun = fit_fun,
    pred_fun = function(fit, newdata) as.numeric(stats::predict(fit, newdata)),
    weights = wcol, ...
  )
  out$spec <- .idio_spec("lm", "lm", estimator, y, prep$x, id, prep$scopes,
                         "regression", time, prep$groups)
  out
}

# `lm()` and friends evaluate a `weights` *expression* in the formula's
# environment, not ours -- there, `data` and `weights` resolve to base::data and
# stats::weights. Embedding the vector value in the call sidesteps the lookup.
.idio_weighted_call <- function(fun, formula, data, weights, extra) {
  args <- c(list(formula = formula, data = data), extra)
  if (!is.null(weights)) args$weights <- data[[weights]]
  do.call(fun, args)
}

.idio_lm_one <- function(formula, data, weights = NULL, ...) {
  .idio_weighted_call(stats::lm, formula, data, weights, list(...))
}

# MASS::rlm defaults to maxit = 20, which is not enough on real panels
# (Grunfeld and Produc both warn "failed to converge in 20 steps"). Give the
# M-estimator room to converge unless the caller says otherwise.
.idio_rlm_one <- function(formula, data, weights = NULL, maxit = 100L, ...) {
  .idio_require("MASS", "robust")
  .idio_weighted_call(MASS::rlm, formula, data, weights,
                      c(list(maxit = maxit), list(...)))
}

#' Validate an optional weights column and return its name
#' @noRd
.idio_weight_column <- function(data, weights) {
  if (is.null(weights)) return(NULL)
  if (!(is.character(weights) && length(weights) == 1L &&
        weights %in% names(data))) {
    stop("`weights` must be one column name in `data`.", call. = FALSE)
  }
  w <- data[[weights]]
  if (!is.numeric(w) || any(w < 0, na.rm = TRUE)) {
    stop("`weights` must be a non-negative numeric column.", call. = FALSE)
  }
  weights
}
