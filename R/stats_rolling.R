#' Rolling-origin validation for ordered repeated measures
#'
#' Instead of one hold-out block per person, the origin walks forward: train on
#' each person's first `initial` rows and predict the next `assess`, then move
#' the origin on by `step` and repeat. Every fold trains only on the past, so
#' the result is a forecast, not a fit.
#'
#' Predictions gain a `fold` column. Metrics pool across folds, so `metrics()`
#' answers "how well does this model forecast this person over time" rather than
#' "how well did it do on one arbitrary split".
#'
#' @inheritParams fit_lm
#' @param method Which family to fit each fold with: `"lm"`, `"glm"`, or
#'   `"ml"`.
#' @param initial Rows each person trains on in the first fold. Defaults to
#'   whatever leaves room for `folds` folds.
#' @param assess Rows predicted per fold.
#' @param step How far the origin moves between folds. Defaults to `assess`
#'   (contiguous, non-overlapping test blocks).
#' @param folds Number of folds.
#' @param tune Logical. Tune each fold on a validation block carved from that
#'   fold's training rows, so no fold's test rows influence its own settings.
#' @param valid_prop Proportion of each fold's training rows used for tuning.
#' @param ... Passed to the underlying fitter, e.g. `model` or `family`.
#' @return An `idiographic_fit` whose `predictions` carry a `fold` column.
#' @examples
#' fit <- fit_rolling(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'                    time = "day", method = "ml", model = "ridge", folds = 3)
#' metrics(fit, overall = TRUE)
#' @export
fit_rolling <- function(data, y, x, id, method = c("lm", "glm", "ml"),
                        time = NULL, scope = "both", subgroup = NULL,
                        initial = NULL, assess = 1L, step = NULL, folds = 5L,
                        min_train = 10L, tune = FALSE, valid_prop = 0.2, ...) {
  method <- match.arg(method)
  .idio_count(assess, "assess")
  .idio_count(folds, "folds")
  step <- step %||% assess
  .idio_count(step, "step")

  check <- .idio_check_data(data, y, id)
  n_min <- min(table(as.character(check[[id]])))
  span <- (folds - 1L) * step + assess
  initial <- initial %||% (n_min - span)

  # Report an unsatisfiable schedule in the caller's terms, before the generic
  # whole-number check turns a negative `initial` into a cryptic message.
  if (initial < min_train || initial + span > n_min) {
    stop("This rolling schedule does not fit: ", folds, " folds of ", assess,
         " row(s) every ", step, " need ", max(initial, min_train) + span,
         " rows per person, but the shortest person has ", n_min,
         " and `min_train` is ", min_train,
         ". Reduce `folds`, `assess`, or `step`.", call. = FALSE)
  }
  .idio_count(initial, "initial")

  origins <- initial + (seq_len(folds) - 1L) * step

  per_fold <- lapply(seq_along(origins), function(f) {
    .idio_rolling_fold(data, y, x, id, method, time, scope, subgroup,
                       origin = origins[f], assess = assess, fold = f,
                       min_train = min_train, tune = tune,
                       valid_prop = if (isTRUE(tune)) valid_prop else 0, ...)
  })

  ok <- !vapply(per_fold, is.null, logical(1))
  if (!any(ok)) stop("No rolling fold produced predictions.", call. = FALSE)
  per_fold <- per_fold[ok]

  first <- per_fold[[1L]]
  preds <- do.call(rbind, lapply(per_fold, `[[`, "predictions"))
  rownames(preds) <- NULL
  coefs <- do.call(rbind, lapply(per_fold, `[[`, "coefs"))
  rownames(coefs) <- NULL
  tune_tab <- do.call(rbind, lapply(per_fold, `[[`, "tuning"))
  if (is.null(tune_tab)) tune_tab <- .idio_empty_tuning()
  rownames(tune_tab) <- NULL
  failures <- do.call(rbind, lapply(per_fold, `[[`, "failures"))

  mets <- if (first$spec$task == "classification") {
    .idio_classification_metrics(preds, first$y_info$positive)
  } else {
    .idio_regression_metrics(preds)
  }

  spec <- first$spec
  spec$method <- paste0("rolling/", method)
  spec$folds <- length(per_fold)
  spec$initial <- initial
  spec$assess <- assess
  spec$step <- step

  structure(list(
    spec = spec,
    fits = unlist(lapply(per_fold, `[[`, "fits"), recursive = FALSE),
    predictions = preds, metrics = mets, coefs = coefs, tuning = tune_tab,
    failures = failures
  ), class = c("idiographic_fit", "idiostats_fit"))
}

#' Fit one rolling fold, returning its raw pieces
#' @noRd
.idio_rolling_fold <- function(data, y, x, id, method, time, scope, subgroup,
                               origin, assess, fold, min_train, tune = FALSE,
                               valid_prop = 0, ...) {
  roles_fun <- function(d, y, x, id) {
    .idio_rolling_roles(d, y, x, id, origin, assess, min_train, valid_prop)
  }
  fit <- tryCatch(
    .idio_fit_one_fold(data, y, x, id, method, time, scope, subgroup,
                       roles_fun, tune = tune, ...),
    error = function(e) e
  )
  if (inherits(fit, "error")) return(NULL)

  fit$predictions$fold <- fold
  if (nrow(fit$coefs)) fit$coefs$fold <- fold
  if (nrow(fit$tuning)) fit$tuning$fold <- fold
  names(fit$fits) <- paste0("fold", fold, ":", names(fit$fits))
  fit
}

#' Dispatch one fold to the right engine
#' @noRd
.idio_fit_one_fold <- function(data, y, x, id, method, time, scope, subgroup,
                               roles_fun, model = NULL, family = "binomial",
                               estimator = "native", tune = FALSE, grid = NULL,
                               lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                               mtry = NULL, num_trees = 500L, cost = 1, ...) {
  task <- switch(method,
                 lm = "regression",
                 glm = if (identical(.idio_family(family)$family, "binomial")) {
                   "classification"
                 } else {
                   "regression"
                 },
                 ml = "auto")

  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, task = task, roles_fun = roles_fun)

  if (method == "ml") {
    models <- .idio_ml_models(model %||% "all", prep$task, estimator)
    control <- .idio_ml_control(lambda, alpha, k, ncomp, mtry, num_trees, cost,
                                length(prep$x))
    run <- .idio_ml_run(prep, y, id, models, estimator, control, tune, grid)
    out <- .idio_assemble(run$results, prep$failures, prep$task, prep$y_info,
                          spec = NULL, tuning = run$tuning)
    out$spec <- .idio_spec("ml", models, estimator, y, prep$x, id, prep$scopes,
                           prep$task, time, prep$groups)
  } else if (method == "lm") {
    out <- .idio_fit_formula_family(
      prep = prep, y = y, id = id, model = "lm", estimator = "native",
      family = NULL, fit_fun = .idio_lm_one,
      pred_fun = function(fit, newdata) as.numeric(stats::predict(fit, newdata))
    )
    out$spec <- .idio_spec("lm", "lm", "native", y, prep$x, id, prep$scopes,
                           "regression", time, prep$groups)
  } else {
    fam <- .idio_family(family)
    out <- .idio_fit_formula_family(
      prep = prep, y = y, id = id, model = fam$family, estimator = "native",
      family = fam, fit_fun = .idio_glm_one,
      pred_fun = function(fit, newdata) {
        as.numeric(stats::predict(fit, newdata, type = "response"))
      }
    )
    out$spec <- .idio_spec("glm", fam$family, "native", y, prep$x, id,
                           prep$scopes, prep$task, time, prep$groups)
  }

  out$y_info <- prep$y_info
  out
}

#' Roles for one rolling origin: train on the past, test on the next block
#'
#' When tuning, the tail of each fold's training rows becomes that fold's
#' validation block, so candidate selection still never touches the test rows.
#'
#' @noRd
.idio_rolling_roles <- function(data, y, x, id, origin, assess, min_train,
                                valid_prop = 0) {
  needed <- c(y, x)
  ids <- as.character(data[[id]])
  # Position of each row within its person, on the already-ordered data.
  pos <- stats::ave(seq_along(ids), ids, FUN = seq_along)
  complete <- stats::complete.cases(data[needed])

  n_valid <- if (valid_prop > 0) {
    min(as.integer(ceiling(origin * valid_prop)), origin - min_train)
  } else {
    0L
  }
  if (!is.finite(n_valid) || n_valid < 0L) n_valid <- 0L
  train_end <- origin - n_valid

  role <- rep("skip", nrow(data))
  role[pos <= train_end & complete] <- "train"
  if (n_valid > 0L) {
    role[pos > train_end & pos <= origin & complete] <- "valid"
  }
  role[pos > origin & pos <= origin + assess & complete] <- "test"

  n_train <- tapply(role == "train", ids, sum)
  n_test <- tapply(role == "test", ids, sum)
  short <- names(n_train)[n_train < min_train | n_test[names(n_train)] < 1L]

  failures <- if (length(short)) {
    role[ids %in% short] <- "skip"
    do.call(rbind, lapply(short, .idio_split_failure,
                          message = "Too few complete rows for this fold."))
  } else {
    .idio_empty_failures()
  }

  list(role = role, failures = failures)
}
