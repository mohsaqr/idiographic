.idio_formula <- function(y, x) {
  stats::as.formula(paste(y, "~", paste(x, collapse = " + ")))
}

#' Fit one formula-based model per unit
#'
#' Shared engine for `fit_lm()` and `fit_glm()`. The estimator is injected as
#' `fit_fun` / `pred_fun`, so the two wrappers differ only in what they pass in.
#'
#' @noRd
.idio_fit_formula_family <- function(prep, y, id, model, estimator, family,
                                     fit_fun, pred_fun, ...) {
  form <- .idio_formula(y, prep$x)

  results <- lapply(prep$units, function(unit) {
    train <- .idio_unit_rows(prep$data, unit, c("train", "valid"))
    test <- .idio_unit_rows(prep$data, unit, "test")
    res <- .idio_fit_eval_one(
      train, test, form, y, id, unit = unit, model = model,
      estimator = estimator, fit_fun = fit_fun, pred_fun = pred_fun,
      task = prep$task, y_info = prep$y_info, family = family, ...
    )
    if (inherits(res, "error")) return(.idio_tag_error(res, unit, model,
                                                       estimator))
    res$key <- .idio_unit_key(unit, model)
    res
  })

  .idio_assemble(results, prep$failures, prep$task, prep$y_info, spec = NULL,
                 data = prep$data)
}

.idio_fit_eval_one <- function(train, test, form, y, id, unit, model, estimator,
                               fit_fun, pred_fun, task, y_info, family, ...) {
  tryCatch({
    if (!nrow(train) || !nrow(test)) {
      stop("No training or test rows for this unit.", call. = FALSE)
    }
    fit <- if (is.null(family)) {
      fit_fun(form, train, ...)
    } else {
      fit_fun(form, train, family = family, ...)
    }
    pred <- pred_fun(fit, test)
    out_pred <- .idio_prediction_rows(pred, test, y, id, unit, model, estimator,
                                      task, y_info)
    out_coef <- .idio_tidy_coef(fit, unit, model, estimator)
    list(fit = fit, pred = out_pred, coefs = out_coef)
  }, error = function(e) e)
}

#' Build the tidy prediction rows for one fitted unit
#'
#' `subject` is the real person ID of each row even for pooled and subgroup
#' models -- that is what makes their performance comparable person by person.
#'
#' @noRd
.idio_prediction_rows <- function(pred, test, y, id, unit, model, estimator,
                                  task, y_info, fold = NULL) {
  base <- data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = as.character(test[[id]]), subgroup = unit$subgroup,
    row = test$.idio_row, stringsAsFactors = FALSE
  )
  out <- if (task == "classification") {
    data.frame(
      base,
      observed = ifelse(test[[y]] == 1L, y_info$positive, y_info$levels[1L]),
      predicted = ifelse(pred >= 0.5, y_info$positive, y_info$levels[1L]),
      probability = as.numeric(pred), stringsAsFactors = FALSE
    )
  } else {
    obs <- as.numeric(test[[y]])
    data.frame(
      base, observed = obs, predicted = as.numeric(pred),
      residual = obs - as.numeric(pred), stringsAsFactors = FALSE
    )
  }
  if (!is.null(fold)) out$fold <- fold
  out
}

.idio_tidy_coef <- function(fit, unit, model, estimator) {
  sm <- tryCatch(summary(fit)$coefficients, error = function(e) NULL)
  if (is.null(sm) || !nrow(sm)) {
    return(.idio_empty_coefs(unit, model, estimator))
  }
  data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = unit$subject, subgroup = unit$subgroup, term = rownames(sm),
    estimate = sm[, 1L],
    std_error = if (ncol(sm) >= 2L) sm[, 2L] else NA_real_,
    statistic = if (ncol(sm) >= 3L) sm[, 3L] else NA_real_,
    p_value = if (ncol(sm) >= 4L) sm[, 4L] else NA_real_,
    stringsAsFactors = FALSE
  )
}

#' Tidy coefficient rows from a bare named numeric vector
#' @noRd
.idio_coef_rows <- function(coef, unit, model, estimator) {
  if (!length(coef)) return(.idio_empty_coefs(unit, model, estimator))
  data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = unit$subject, subgroup = unit$subgroup, term = names(coef),
    estimate = as.numeric(coef), std_error = NA_real_, statistic = NA_real_,
    p_value = NA_real_, stringsAsFactors = FALSE
  )
}

# Every column must be zero-length: mixing scalars with character() would make
# data.frame() recycle to one row and then error on the length mismatch.
.idio_empty_coefs <- function(unit, model, estimator) {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(), term = character(),
             estimate = numeric(), std_error = numeric(),
             statistic = numeric(), p_value = numeric(),
             stringsAsFactors = FALSE)
}

.idio_failure <- function(scope, model, estimator, subject, message) {
  data.frame(scope = scope, model = model, estimator = estimator,
             subject = subject, message = message, stringsAsFactors = FALSE)
}

.idio_spec <- function(method, model, estimator, y, x, id, scope, task, time,
                       groups = NULL) {
  list(method = method, model = model, estimator = estimator, y = y, x = x,
       id = id, scope = scope, task = task, time = time, groups = groups)
}
