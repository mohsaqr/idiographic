#' Fit pooled, subgroup and person-specific generalized linear models
#'
#' @inheritParams fit_lm
#' @param family GLM family name or family object. Native support covers
#'   `"gaussian"`, `"binomial"`, and `"poisson"`. `"negbin"` fits a negative
#'   binomial via `MASS::glm.nb()`, which is what overdispersed counts need --
#'   Poisson would report standard errors that are too small.
#' @param ... Passed to the underlying fitter.
#' @return An `idiostats_fit`.
#' @examples
#' # `srl` carries some missing values, so na.rm is needed to derive an outcome.
#' srl$high <- ifelse(srl$effort > median(srl$effort, na.rm = TRUE),
#'                    "yes", "no")
#' fit <- fit_glm(srl, y = "high", x = c("efficacy", "planning"), id = "name",
#'                family = "binomial", time = "day")
#' metrics(fit, overall = TRUE)
#' @export
fit_glm <- function(data, y, x, id, family = "binomial", time = NULL,
                    scope = "both", subgroup = NULL, weights = NULL,
                    test_prop = 0.2, min_train = 10L, min_test = 1L, ...) {
  negbin <- identical(family, "negbin")
  fam <- if (negbin) NULL else .idio_family(family)
  label <- if (negbin) "negbin" else fam$family
  task <- if (!negbin && identical(fam$family, "binomial")) {
    "classification"
  } else {
    "regression"
  }

  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, test_prop = test_prop,
                        min_train = min_train, min_test = min_test,
                        task = task, exclude = weights)
  wcol <- .idio_weight_column(prep$data, weights)

  out <- .idio_fit_formula_family(
    prep = prep, y = y, id = id, model = label, estimator = "native",
    family = fam, fit_fun = if (negbin) .idio_negbin_one else .idio_glm_one,
    pred_fun = function(fit, newdata) {
      as.numeric(stats::predict(fit, newdata, type = "response"))
    },
    weights = wcol, ...
  )
  out$spec <- .idio_spec("glm", label, "native", y, prep$x, id,
                         prep$scopes, prep$task, time, prep$groups)
  out
}

.idio_glm_one <- function(formula, data, family, weights = NULL, ...) {
  .idio_weighted_call(stats::glm, formula, data, weights,
                      c(list(family = family), list(...)))
}

# glm.nb estimates the dispersion itself, so it takes no `family`.
.idio_negbin_one <- function(formula, data, weights = NULL, ...) {
  .idio_require("MASS", "negbin")
  .idio_weighted_call(MASS::glm.nb, formula, data, weights, list(...))
}

.idio_family <- function(family) {
  if (inherits(family, "family")) return(family)
  if (!(is.character(family) && length(family) == 1L)) {
    stop("`family` must be a family object or a single family name.",
         call. = FALSE)
  }
  switch(family,
         gaussian = stats::gaussian(),
         binomial = stats::binomial(),
         poisson = stats::poisson(),
         stop("Unsupported family: ", family,
              ". Use gaussian, binomial, poisson, or negbin.", call. = FALSE))
}

#' Map a two-level outcome to 0/1, with a deterministic positive class
#'
#' The positive class is the *last* level, following the R convention that a
#' factor's final level is the success. For a factor that is the user's declared
#' order; for anything else the levels are sorted, so `0/1` gives `1` and
#' `"no"/"yes"` gives `"yes"`.
#'
#' Sorting matters: taking the levels in order of appearance would make the
#' positive class depend on which row happens to come first, silently inverting
#' every probability, coefficient and treatment effect when the data are
#' reordered.
#'
#' @noRd
.idio_binary_outcome <- function(y) {
  yy <- as.character(y[!is.na(y)])
  levels <- if (is.factor(y)) levels(y) else sort(unique(yy))
  levels <- levels[levels %in% yy]
  if (length(levels) != 2L) {
    stop("A binary outcome requires exactly two observed outcome levels.",
         call. = FALSE)
  }
  list(y = as.integer(as.character(y) == levels[2L]),
       levels = levels,
       positive = levels[2L])
}
