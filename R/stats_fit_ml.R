#' Fit idiographic machine-learning models
#'
#' Fits one or more machine-learning models at every requested scope. Native
#' models need no dependencies; optional backends are selected with `estimator`.
#'
#' Validation is an ordered hold-out: the final rows of each person are the test
#' set. When `tune = TRUE` a further validation block is carved from the tail of
#' the training rows, candidates are scored on it, and the winning setting is
#' refit on train + validation before predicting the test rows. Test rows are
#' therefore never used to choose a setting.
#'
#' @inheritParams fit_lm
#' @param model Model name(s), or `"all"` for every model the estimator offers.
#'   Native regression: `"mean"`, `"linear"`, `"ridge"`, `"lasso"`, `"elastic"`,
#'   `"pcr"`, `"knn"`, `"tree"`. Native classification: `"majority"`,
#'   `"logistic"`, `"ridge"`, `"lasso"`, `"elastic"`, `"lda"`, `"bayes"`,
#'   `"knn"`, `"tree"`.
#' @param estimator Implementation backend: `"native"` (default, base R only),
#'   `"glmnet"` (`ridge`/`lasso`/`elastic`), `"ranger"` (`forest`), or `"e1071"`
#'   (`svm`, `bayes`). Non-native backends are installed on first use.
#' @param valid_prop Proportion of the training rows reserved for tuning when
#'   `tune = TRUE`.
#' @param lambda Penalty for `ridge`, `lasso`, and `elastic`.
#' @param alpha Elastic-net mixing for `elastic` (1 = lasso, 0 = ridge).
#' @param k Neighbours for `knn`.
#' @param ncomp Components for `pcr`.
#' @param mtry Predictors sampled per split for `forest`. Defaults to
#'   `sqrt(p)`.
#' @param num_trees Trees for `forest`.
#' @param cost Cost for `svm`.
#' @param tune Logical. Tune each tunable model on the validation block.
#' @param grid Optional named list overriding tuning grids, for example
#'   `list(ridge = list(lambda = c(0.1, 1)), knn = list(k = c(3, 5)))`.
#' @param ... Ignored.
#' @return An `idiographic_fit`.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day", model = c("ridge", "knn"), tune = TRUE)
#' metrics(fit, overall = TRUE)
#' best_model(fit)
#' @noRd
.fit_ml_stats <- function(data, y, x, id, model = "all", estimator = "auto",
                   time = NULL, scope = "both", subgroup = NULL,
                   test_prop = 0.2, min_train = 10L, min_test = 1L,
                   valid_prop = 0.2, lambda = 1, alpha = 0.5, k = 5L,
                   ncomp = 2L, mtry = NULL, num_trees = 500L, cost = 1,
                   tune = FALSE, grid = NULL, ...) {
  # The registry knows which backends exist, so the list is not duplicated here.
  if (!(is.character(estimator) && length(estimator) == 1L &&
        (estimator == "auto" || estimator %in% .idio_registry()$estimator))) {
    stop("`estimator` must be \"auto\" or one of: ",
         paste(sort(unique(.idio_registry()$estimator)), collapse = ", "), ".",
         call. = FALSE)
  }

  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, test_prop = test_prop,
                        min_train = min_train, min_test = min_test,
                        valid_prop = if (isTRUE(tune)) valid_prop else 0,
                        task = "auto")

  models <- .idio_ml_models(model, prep$task, estimator)
  control <- .idio_ml_control(lambda, alpha, k, ncomp, mtry, num_trees, cost,
                              length(prep$x))
  .idio_check_grid(grid)

  run <- .idio_ml_run(prep, y, id, models, estimator, control, tune, grid)

  out <- .idio_assemble(run$results, prep$failures, prep$task, prep$y_info,
                        data = prep$data,
                        spec = NULL, tuning = run$tuning)
  backends <- unique(vapply(models, function(m) {
    .idio_resolve_model(m, prep$task, estimator)$estimator
  }, character(1)))
  out$spec <- .idio_spec("ml", models, backends, y, prep$x, id, prep$scopes,
                         prep$task, time, prep$groups)
  out
}

#' A malformed grid is a user error, so reject it before any model is fitted
#' rather than letting it surface as a per-person failure.
#' @noRd
.idio_check_grid <- function(grid) {
  if (is.null(grid)) return(invisible(NULL))
  if (!is.list(grid) || is.null(names(grid))) {
    stop("`grid` must be a named list, e.g. list(ridge = list(lambda = 1)).",
         call. = FALSE)
  }
  invisible(Map(function(model, params) {
    if (!is.list(params) || is.null(names(params))) {
      stop("Tuning grid for ", model, " must be a named list of parameters.",
           call. = FALSE)
    }
    Map(function(parameter, values) {
      values <- suppressWarnings(as.numeric(values))
      if (!length(values[is.finite(values)])) {
        stop("Tuning grid for ", model, "$", parameter,
             " must contain finite numeric values.", call. = FALSE)
      }
    }, names(params), params)
  }, names(grid), grid))
}

.idio_ml_control <- function(lambda, alpha, k, ncomp, mtry, num_trees, cost,
                             p) {
  list(lambda = lambda, alpha = alpha, k = as.integer(k),
       ncomp = as.integer(ncomp), cost = cost,
       num_trees = as.integer(num_trees),
       mtry = as.integer(mtry %||% max(1L, floor(sqrt(p)))),
       # Defaults for the wider algorithm set. Each is the single tunable of
       # one model, so a caller who never tunes still gets a sensible fit.
       rounds = 100L, learn_rate = 0.1, df = 4L, span = 0.75,
       nterms = 1L, cp = 0.01, size = 3L, decay = 0.01, tau = 0.5,
       alpha_split = 0.05)
}

#' Fit every (model, unit) job for a prepared data set
#'
#' Shared by [fit_ml()] and [fit_rolling()]; each job is independent.
#'
#' @noRd
.idio_ml_run <- function(prep, y, id, models, estimator, control, tune, grid) {
  # "auto" is a request, not an answer: the tables must name the backend that
  # actually fitted the model.
  resolved <- vapply(models, function(m) {
    .idio_resolve_model(m, prep$task, estimator)$estimator
  }, character(1))
  jobs <- unlist(lapply(models, function(m) {
    lapply(prep$units, function(u) list(model = m, unit = u))
  }), recursive = FALSE)

  done <- lapply(jobs, function(job) {
    backend <- unname(resolved[[job$model]])
    res <- .idio_ml_fit_tuned(prep, job$unit, job$model, backend, y, id,
                              control, tune, grid)
    if (inherits(res, "error")) {
      return(.idio_tag_error(res, job$unit, job$model, backend))
    }
    res$best$key <- .idio_unit_key(job$unit, job$model)
    res
  })

  failed <- vapply(done, inherits, logical(1), "error")
  results <- c(lapply(done[!failed], `[[`, "best"), as.list(done[failed]))

  tune_tab <- do.call(rbind, lapply(done[!failed], `[[`, "tuning"))
  if (is.null(tune_tab)) tune_tab <- .idio_empty_tuning()
  rownames(tune_tab) <- NULL

  list(results = results, tuning = tune_tab)
}

#' Fit one model on one unit, tuning it first when asked
#' @noRd
.idio_ml_fit_tuned <- function(prep, unit, model, estimator, y, id, control,
                               tune, grid) {
  tryCatch({
    train <- .idio_unit_rows(prep$data, unit, "train")
    valid <- .idio_unit_rows(prep$data, unit, "valid")
    test <- .idio_unit_rows(prep$data, unit, "test")
    full <- .idio_unit_rows(prep$data, unit, c("train", "valid"))
    if (!nrow(full) || !nrow(test)) {
      stop("No training or test rows for this unit.", call. = FALSE)
    }

    if (!isTRUE(tune)) {
      best <- .idio_ml_fit_eval(full, test, prep$x, y, id, unit, model,
                                estimator, prep$task, prep$y_info, control)
      if (inherits(best, "error")) stop(conditionMessage(best), call. = FALSE)
      return(list(best = best, tuning = .idio_empty_tuning()))
    }

    if (!nrow(valid)) {
      stop("No validation rows available for tuning this unit.", call. = FALSE)
    }
    candidates <- .idio_ml_candidates(model, estimator, prep$task, grid,
                                      control, nrow(train), length(prep$x))

    # Score every candidate on the validation block only.
    scored <- lapply(candidates, function(cand) {
      res <- .idio_ml_fit_eval(train, valid, prep$x, y, id, unit, model,
                               estimator, prep$task, prep$y_info, cand$control)
      if (inherits(res, "error")) return(NULL)
      list(cand = cand,
           metric = .idio_ml_tuning_metric(res$pred, prep$task, prep$y_info))
    })
    scored <- scored[!vapply(scored, is.null, logical(1))]
    if (!length(scored)) {
      stop("No tuning candidate could be evaluated.", call. = FALSE)
    }

    tune_tab <- .idio_tuning_rows(scored, unit, model, estimator)
    score <- if (prep$task == "regression") tune_tab$rmse else tune_tab$brier
    winner <- scored[[which.min(score)]]$cand

    # Refit the winner on train + validation, then predict the untouched test.
    best <- .idio_ml_fit_eval(full, test, prep$x, y, id, unit, model, estimator,
                              prep$task, prep$y_info, winner$control)
    if (inherits(best, "error")) stop(conditionMessage(best), call. = FALSE)
    best$fit$tuned <- winner

    list(best = best, tuning = .idio_rank_tuning(tune_tab, prep$task))
  }, error = function(e) e)
}

.idio_ml_fit_eval <- function(train, test, x, y, id, unit, model, estimator,
                              task, y_info, control) {
  tryCatch({
    fit <- .idio_ml_fit(train, y, x, model, task, control, estimator)
    pred <- .idio_ml_predict(fit, test[x])
    list(
      fit = fit,
      pred = .idio_prediction_rows(pred, test, y, id, unit, model, estimator,
                                   task, y_info),
      coefs = .idio_coef_rows(fit$coef %||% numeric(0), unit, model, estimator)
    )
  }, error = function(e) e)
}

.idio_ml_candidates <- function(model, estimator, task, grid, control, n_train,
                                p) {
  fixed <- list(.idio_ml_candidate(control, ".fixed",
                                   .idio_default_value(model, control)))
  spec <- .idio_tunable(model, estimator, control, n_train, p)
  if (is.null(spec)) return(fixed)

  values <- .idio_grid_values(grid, model, spec$parameter, spec$values)
  values <- spec$clean(values)
  if (!length(values)) return(fixed)

  lapply(values, function(v) {
    .idio_ml_candidate(utils::modifyList(control,
                                         stats::setNames(list(v),
                                                         spec$parameter)),
                       spec$parameter, v)
  })
}

#' What each model tunes, and the default grid for it
#' @noRd
.idio_tunable <- function(model, estimator, control, n_train, p) {
  int_clean <- function(hi) {
    function(v) unique(pmax(1L, pmin(as.integer(v), hi)))
  }
  num_clean <- function(v) unique(v[is.finite(v) & v >= 0])

  if (model %in% c("ridge", "lasso", "elastic")) {
    values <- if (estimator == "glmnet") {
      c(0.001, 0.01, 0.05, 0.1, 0.5, 1, 2)
    } else {
      c(0, 0.01, 0.1, 0.5, 1, 2, 5, 10)
    }
    return(list(parameter = "lambda", values = values, clean = num_clean))
  }
  if (model == "knn") {
    return(list(parameter = "k", values = c(1, 3, 5, 7, 9, 15),
                clean = int_clean(n_train)))
  }
  if (model == "pcr") {
    return(list(parameter = "ncomp", values = seq_len(p),
                clean = int_clean(min(p, n_train - 1L))))
  }
  if (model == "forest") {
    return(list(parameter = "mtry", values = seq_len(p),
                clean = int_clean(p)))
  }
  if (model %in% c("svm", "ksvm")) {
    return(list(parameter = "cost", values = c(0.25, 0.5, 1, 2, 4, 8),
                clean = num_clean))
  }
  if (model %in% c("boost", "xgboost", "glmboost")) {
    return(list(parameter = "rounds", values = c(25, 50, 100, 200, 400),
                clean = int_clean(2000L)))
  }
  if (model == "spline") {
    return(list(parameter = "df", values = c(2, 3, 4, 5, 7),
                clean = int_clean(20L)))
  }
  if (model == "loess") {
    return(list(parameter = "span", values = c(0.3, 0.5, 0.75, 1),
                clean = num_clean))
  }
  if (model == "ppr") {
    return(list(parameter = "nterms", values = seq_len(min(p, 4L)),
                clean = int_clean(max(1L, p))))
  }
  if (model == "cart") {
    return(list(parameter = "cp", values = c(0.001, 0.005, 0.01, 0.05, 0.1),
                clean = num_clean))
  }
  if (model == "mlp") {
    return(list(parameter = "size", values = c(1, 2, 3, 5, 8),
                clean = int_clean(50L)))
  }
  if (model == "multinom") {
    return(list(parameter = "decay", values = c(0, 0.001, 0.01, 0.1, 1),
                clean = num_clean))
  }
  if (model == "gam") {
    return(list(parameter = "k", values = c(3, 5, 8, 10),
                clean = int_clean(30L)))
  }
  if (model %in% c("ctree", "mob")) {
    return(list(parameter = "alpha", values = c(0.01, 0.05, 0.1, 0.25),
                clean = num_clean))
  }
  if (model %in% c("rf", "extratrees")) {
    return(list(parameter = "mtry", values = seq_len(p),
                clean = int_clean(p)))
  }
  if (model == "pls") {
    return(list(parameter = "ncomp", values = seq_len(p),
                clean = int_clean(min(p, n_train - 1L))))
  }
  NULL
}

.idio_ml_candidate <- function(control, parameter, value) {
  list(control = control, parameter = parameter, value = as.character(value))
}

.idio_default_value <- function(model, control) {
  switch(model,
         ridge = , lasso = , elastic = control$lambda,
         knn = control$k,
         pcr = control$ncomp,
         forest = control$mtry,
         svm = control$cost,
         ".default")
}

.idio_grid_values <- function(grid, model, parameter, default) {
  values <- if (!is.null(grid) && !is.null(grid[[model]]) &&
                !is.null(grid[[model]][[parameter]])) {
    grid[[model]][[parameter]]
  } else {
    default
  }
  values <- as.numeric(values)
  values <- values[is.finite(values)]
  if (!length(values)) {
    stop("Tuning grid for ", model, "$", parameter,
         " must contain finite numeric values.", call. = FALSE)
  }
  unique(values)
}

.idio_tuning_rows <- function(scored, unit, model, estimator) {
  do.call(rbind, lapply(scored, function(s) {
    data.frame(
      scope = unit$scope, model = model, estimator = estimator,
      subject = if (unit$scope == "individual") unit$subject else ".overall",
      subgroup = unit$subgroup,
      parameter = s$cand$parameter, value = s$cand$value,
      n = s$metric$n, rmse = s$metric$rmse, mae = s$metric$mae,
      accuracy = s$metric$accuracy, brier = s$metric$brier,
      rank = NA_integer_, stringsAsFactors = FALSE
    )
  }))
}

.idio_ml_tuning_metric <- function(pred, task, y_info) {
  if (task == "regression") {
    residual <- pred$observed - pred$predicted
    return(list(n = nrow(pred), rmse = sqrt(mean(residual^2)),
                mae = mean(abs(residual)), accuracy = NA_real_,
                brier = NA_real_))
  }
  y <- as.integer(pred$observed == y_info$positive)
  list(n = nrow(pred), rmse = NA_real_, mae = NA_real_,
       accuracy = mean(pred$observed == pred$predicted),
       brier = mean((y - pred$probability)^2))
}

.idio_rank_tuning <- function(tab, task) {
  score <- if (task == "regression") tab$rmse else tab$brier
  tab <- tab[order(score, na.last = TRUE), , drop = FALSE]
  tab$rank <- seq_len(nrow(tab))
  rownames(tab) <- NULL
  tab
}
