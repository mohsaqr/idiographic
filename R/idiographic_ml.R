# ---- Idiographic supervised machine-learning models ----

#' Fit idiographic supervised machine-learning models
#'
#' @description
#' Fits train/test supervised prediction models in an idiographic design: each
#' subject can receive a model trained only on that subject's earlier rows, and
#' the same held-out rows can also be scored by a pooled model trained on all
#' subjects' earlier rows. This mirrors individualized modelling designs where
#' person-specific prediction is compared against a nomothetic pooled baseline.
#'
#' The implementation is dependency-free beyond base R. Regression supports
#' mean baseline, ordinary least squares, ridge, lasso, elastic net, principal
#' component regression, k-nearest neighbours, and a one-split regression tree.
#' Binary classification supports majority baseline, logistic regression,
#' ridge/lasso/elastic-net logistic regression, linear discriminant analysis,
#' Gaussian naive Bayes, k-nearest neighbours, and a one-split classification
#' tree. Predictors are standardized using training rows only.
#'
#' @param data A `data.frame` or matrix.
#' @param outcome Character. Name of the outcome column.
#' @param predictors Character vector of predictor columns.
#' @param id Character. Name of the subject/person ID column.
#' @param day,beep Optional ordering columns. Rows are ordered by `id`, `day`,
#'   and `beep` before the last rows for each subject are held out.
#' @param task `"auto"`, `"regression"`, or `"classification"`. Auto treats a
#'   numeric outcome as regression and a two-level non-numeric outcome as binary
#'   classification.
#' @param model `NULL` for the task default, `"all"` for all native models for
#'   the selected task, or a character vector of simple model names. Regression
#'   models are `"mean"`, `"linear"`, `"ridge"`, `"lasso"`, `"elastic"`,
#'   `"pcr"`, `"knn"`, and `"tree"`. Classification models are `"majority"`,
#'   `"logistic"`, `"ridge"`, `"lasso"`, `"elastic"`, `"lda"`, `"bayes"`,
#'   `"knn"`, and `"tree"`.
#' @param estimator `NULL` for each model's default estimator, or a named
#'   character vector/list mapping model names to estimator names. The native
#'   base-R estimator is `"native"`. This is where package-specific backends
#'   belong when the same model can be estimated more than one way.
#' @param compare Which models to fit: `"both"` (default), `"individual"`, or
#'   `"pooled"`.
#' @param test_prop Proportion of each subject's ordered rows held out from the
#'   end of the series. Default `0.2`.
#' @param min_train Minimum complete training rows required for a model. Default
#'   `10`.
#' @param min_test Minimum held-out rows required per subject. Default `1`.
#' @param lambda Ridge penalty for `model = "ridge"`. The intercept is not
#'   penalized. Also used by lasso and elastic-net models. Default `1`.
#' @param alpha Elastic-net mixing value in `[0, 1]`; `0` is ridge and `1` is
#'   lasso. Default `0.5`.
#' @param k Number of neighbours for `model = "knn"`. Default `5`.
#' @param n_components Number of principal components for `model = "pcr"`.
#'   Default uses `min(5, n_predictors, n_train - 1)`.
#' @param max_iter Maximum iterations for coordinate-descent penalized models.
#'   Default `100`.
#' @param tol Convergence tolerance for iterative models. Default `1e-6`.
#' @param standardize Logical. Standardize predictors using training-set means
#'   and SDs? Default `TRUE`.
#' @param keep_fits Logical. Store fitted internal model objects? Default
#'   `FALSE`.
#' @param ... Optional model controls using the same names as the explicit
#'   tuning arguments (`lambda`, `alpha`, `k`, `n_components`, `max_iter`, or
#'   `tol`). Unknown names are rejected.
#'
#' @return An `idioml_result` with `$predictions`, `$metrics`, `$coefficients`,
#'   `$failures`, and optionally `$fits`.
#' @examples
#' set.seed(1)
#' d <- data.frame(
#'   id = rep(1:4, each = 40),
#'   beep = rep(seq_len(40), 4),
#'   x1 = rnorm(160),
#'   x2 = rnorm(160)
#' )
#' d$y <- 0.4 * d$x1 - 0.2 * d$x2 + rep(c(-1, 0, 1, 0.5), each = 40) +
#'   rnorm(160, sd = 0.4)
#' fit <- fit_ml(d, outcome = "y", predictors = c("x1", "x2"),
#'               id = "id", beep = "beep",
#'               model = c("linear", "ridge", "knn"))
#' fit$metrics
#' coefs(fit)
#' @export
fit_ml <- function(data, outcome, predictors, id,
                   day = NULL, beep = NULL,
                   task = c("auto", "regression", "classification"),
                   model = NULL,
                   estimator = NULL,
                   compare = c("both", "individual", "pooled"),
                   test_prop = 0.2,
                   min_train = 10L,
                   min_test = 1L,
                   lambda = 1,
                   alpha = 0.5,
                   k = 5L,
                   n_components = NULL,
                   max_iter = 100L,
                   tol = 1e-6,
                   standardize = TRUE,
                   keep_fits = FALSE,
                   ...) {
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(outcome), length(outcome) == 1L)
  stopifnot(is.character(id), length(id) == 1L)
  task <- match.arg(task)
  compare <- match.arg(compare)
  extra <- list(...)
  for (nm in names(extra)) {
    if (!nm %in% c("lambda", "alpha", "k", "n_components", "max_iter", "tol")) {
      stop("Unknown model argument in `...`: ", nm, call. = FALSE)
    }
  }
  lambda <- extra$lambda %||% lambda
  alpha <- extra$alpha %||% alpha
  k <- extra$k %||% k
  n_components <- extra$n_components %||% n_components
  max_iter <- extra$max_iter %||% max_iter
  tol <- extra$tol %||% tol
  .ido_check_flag(standardize, "standardize")
  .ido_check_flag(keep_fits, "keep_fits")
  .idioml_check_count(min_train, "min_train")
  .idioml_check_count(min_test, "min_test")
  .idioml_check_count(k, "k")
  .idioml_check_count(max_iter, "max_iter")
  if (!(is.numeric(test_prop) && length(test_prop) == 1L &&
        is.finite(test_prop) && test_prop > 0 && test_prop < 1)) {
    stop("`test_prop` must be a single finite number between 0 and 1.",
         call. = FALSE)
  }
  if (!(is.numeric(lambda) && length(lambda) == 1L && is.finite(lambda) &&
        lambda >= 0)) {
    stop("`lambda` must be a single finite number >= 0.", call. = FALSE)
  }
  if (!(is.numeric(alpha) && length(alpha) == 1L && is.finite(alpha) &&
        alpha >= 0 && alpha <= 1)) {
    stop("`alpha` must be a single finite number between 0 and 1.",
         call. = FALSE)
  }
  if (!(is.numeric(tol) && length(tol) == 1L && is.finite(tol) && tol > 0)) {
    stop("`tol` must be a single finite number > 0.", call. = FALSE)
  }
  if (!is.null(n_components)) .idioml_check_count(n_components, "n_components")

  data <- as.data.frame(data)
  predictors <- .idioml_resolve_predictors(data, predictors,
                                           exclude = c(outcome, id, day, beep))
  needed <- unique(c(outcome, predictors, id, day, beep))
  missing <- setdiff(needed, names(data))
  if (length(missing) > 0L) {
    stop("Column(s) not found in data: ", paste(missing, collapse = ", "),
         call. = FALSE)
  }
  if (outcome %in% predictors) {
    stop("`outcome` cannot also appear in `predictors`.", call. = FALSE)
  }
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  bad_pred <- predictors[!vapply(data[predictors], is.numeric, logical(1))]
  if (length(bad_pred) > 0L) {
    stop("Predictor(s) must be numeric: ", paste(bad_pred, collapse = ", "),
         call. = FALSE)
  }

  task <- .idioml_resolve_task(data[[outcome]], task)
  model_plan <- .idioml_resolve_model(model, task, estimator)
  y_info <- .idioml_outcome_info(data[[outcome]], task)
  data$.idioml_row <- seq_len(nrow(data))
  ord <- .idioml_order(data, id, day, beep)
  data <- data[ord, , drop = FALSE]
  data$.idioml_subject <- as.character(data[[id]])
  roles <- .idioml_roles(data, id, test_prop, min_train, min_test,
                         outcome, predictors)

  failures <- roles$failures
  data$.idioml_role <- roles$role
  scopes <- switch(compare,
                   both = c("individual", "pooled"),
                   individual = "individual",
                   pooled = "pooled")
  pred_list <- list()
  coef_list <- list()
  fit_list <- list()

  control <- list(lambda = lambda, alpha = alpha, k = as.integer(k),
                  n_components = n_components,
                  max_iter = as.integer(max_iter), tol = tol)

  for (i_model in seq_len(nrow(model_plan))) {
    model_name <- model_plan$model[i_model]
    estimator_name <- model_plan$estimator[i_model]
    algorithm <- model_plan$algorithm[i_model]
    if ("individual" %in% scopes) {
      subjects <- unique(data$.idioml_subject[data$.idioml_role != "skip"])
      for (subject in subjects) {
        rows <- data$.idioml_subject == subject
        tr <- data[rows & data$.idioml_role == "train", , drop = FALSE]
        te <- data[rows & data$.idioml_role == "test", , drop = FALSE]
        fit <- tryCatch(
          .idioml_fit_one(tr, outcome, predictors, task, algorithm, y_info,
                          control, standardize),
          error = function(e) e
        )
        if (inherits(fit, "error")) {
          failures <- rbind(failures, data.frame(
            model_scope = "individual", model = model_name,
            estimator = estimator_name,
            subject = subject, message = fit$message,
            stringsAsFactors = FALSE
          ))
          next
        }
        pred <- tryCatch(
          .idioml_predict_table(fit, te, "individual", model_name,
                                estimator_name, subject, outcome, predictors,
                                task, y_info),
          error = function(e) e
        )
        if (inherits(pred, "error")) {
          failures <- rbind(failures, data.frame(
            model_scope = "individual", model = model_name,
            estimator = estimator_name,
            subject = subject, message = pred$message,
            stringsAsFactors = FALSE
          ))
          next
        }
        pred_list[[length(pred_list) + 1L]] <- pred
        coef_list[[length(coef_list) + 1L]] <- .idioml_coef_table(
          fit, "individual", model_name, estimator_name, subject
        )
        if (isTRUE(keep_fits)) {
          fit_list[[paste0("individual:", model_name, ":", estimator_name,
                           ":", subject)]] <- fit
        }
      }
    }

    if ("pooled" %in% scopes) {
      tr <- data[data$.idioml_role == "train", , drop = FALSE]
      te <- data[data$.idioml_role == "test", , drop = FALSE]
      fit <- tryCatch(
        .idioml_fit_one(tr, outcome, predictors, task, algorithm, y_info,
                        control, standardize),
        error = function(e) e
      )
      if (inherits(fit, "error")) {
        failures <- rbind(failures, data.frame(
          model_scope = "pooled", model = model_name,
          estimator = estimator_name,
          subject = ".pooled", message = fit$message,
          stringsAsFactors = FALSE
        ))
        next
      }
      pred <- tryCatch(
        .idioml_predict_table(fit, te, "pooled", model_name, estimator_name,
                              ".pooled", outcome, predictors, task, y_info),
        error = function(e) e
      )
      if (inherits(pred, "error")) {
        failures <- rbind(failures, data.frame(
          model_scope = "pooled", model = model_name,
          estimator = estimator_name,
          subject = ".pooled", message = pred$message,
          stringsAsFactors = FALSE
        ))
        next
      }
      pred_list[[length(pred_list) + 1L]] <- pred
      coef_list[[length(coef_list) + 1L]] <- .idioml_coef_table(
        fit, "pooled", model_name, estimator_name, ".pooled"
      )
      if (isTRUE(keep_fits)) {
        fit_list[[paste0("pooled:", model_name, ":", estimator_name)]] <- fit
      }
    }
  }

  if (length(pred_list) == 0L) {
    stop("No idiographic ML models produced predictions.", call. = FALSE)
  }
  predictions <- do.call(rbind, pred_list)
  rownames(predictions) <- NULL
  coefficients <- do.call(rbind, coef_list)
  rownames(coefficients) <- NULL
  metrics <- .idioml_metrics(predictions, task, y_info$positive)

  out <- list(
    predictions = predictions,
    metrics = metrics,
    coefficients = coefficients,
    failures = failures,
    fits = if (isTRUE(keep_fits)) fit_list else NULL,
    task = task,
    model = unique(model_plan$model),
    estimators = model_plan,
    outcome = outcome,
    predictors = predictors,
    positive = y_info$positive,
    n_subjects = length(unique(data$.idioml_subject)),
    config = list(id = id, day = day, beep = beep, compare = compare,
                  test_prop = test_prop, min_train = min_train,
                  min_test = min_test, lambda = lambda, alpha = alpha,
                  k = as.integer(k), n_components = n_components,
                  max_iter = as.integer(max_iter), tol = tol,
                  standardize = standardize)
  )
  class(out) <- "idioml_result"
  out
}

#' @rdname fit_ml
#' @export
fit_idiographic_ml <- fit_ml

#' @rdname fit_ml
#' @export
fit_individualized_ml <- fit_ml

#' @noRd
.idioml_check_count <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) &&
        x >= 1L && x == as.integer(x))) {
    stop("`", arg, "` must be a single finite whole number >= 1.",
         call. = FALSE)
  }
}

#' @noRd
.idioml_resolve_task <- function(y, task) {
  if (task != "auto") return(task)
  if (is.numeric(y)) "regression" else "classification"
}

#' @noRd
.idioml_resolve_predictors <- function(data, predictors, exclude = character()) {
  if (inherits(predictors, "formula")) {
    trm <- attr(stats::terms(predictors), "term.labels")
    predictors <- trm
  } else if (is.data.frame(predictors) || is.matrix(predictors)) {
    predictors <- names(as.data.frame(predictors))
    if (is.null(predictors)) {
      stop("Predictor data frame/matrix must have column names.", call. = FALSE)
    }
  } else if (is.numeric(predictors)) {
    if (any(!is.finite(predictors)) || any(predictors != as.integer(predictors))) {
      stop("Numeric `predictors` must be whole-number column positions.",
           call. = FALSE)
    }
    if (any(predictors < 1L | predictors > ncol(data))) {
      stop("Numeric `predictors` contain column positions outside `data`.",
           call. = FALSE)
    }
    predictors <- names(data)[as.integer(predictors)]
  } else if (is.character(predictors)) {
    predictors <- unlist(lapply(predictors, .idioml_expand_predictor_token,
                                data = data), use.names = FALSE)
  } else {
    stop("`predictors` must be column names, numeric column positions, a ",
         "formula, or a data frame/matrix with named columns.", call. = FALSE)
  }
  predictors <- unique(as.character(predictors))
  predictors <- setdiff(predictors, exclude)
  if (length(predictors) == 0L) {
    stop("No predictors selected.", call. = FALSE)
  }
  missing <- setdiff(predictors, names(data))
  if (length(missing) > 0L) {
    stop("Predictor column(s) not found in data: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  predictors
}

#' @noRd
.idioml_expand_predictor_token <- function(token, data) {
  if (length(token) != 1L || is.na(token) || !nzchar(token)) return(character())
  if (token %in% names(data)) return(token)
  if (!grepl(":", token, fixed = TRUE)) return(token)
  parts <- strsplit(token, ":", fixed = TRUE)[[1L]]
  if (length(parts) != 2L || !all(parts %in% names(data))) return(token)
  i <- match(parts[1L], names(data))
  j <- match(parts[2L], names(data))
  names(data)[seq.int(i, j)]
}

#' @noRd
.idioml_resolve_model <- function(model, task, estimator) {
  if (is.null(model)) {
    model <- if (identical(task, "regression")) {
      "linear"
    } else {
      "logistic"
    }
  }
  if (!(is.character(model) && length(model) >= 1L)) {
    stop("`model` must be NULL, 'all', or a character vector of model names.",
         call. = FALSE)
  }
  catalog <- .idioml_model_catalog(task)
  if (identical(model, "all")) {
    selected <- catalog
  } else {
    canonical <- .idioml_canonical_model(model, task)
    bad <- setdiff(canonical, catalog$model)
    if (length(bad) > 0L) {
      stop("For task = '", task, "', `model` must be one of: ",
           paste(catalog$model, collapse = ", "), ". Unsupported: ",
           paste(bad, collapse = ", "), ".", call. = FALSE)
    }
    selected <- catalog[match(unique(canonical), catalog$model), ,
                        drop = FALSE]
  }
  est <- .idioml_resolve_estimator(selected$model, estimator)
  selected$estimator <- est
  unsupported <- selected$estimator != selected$default_estimator
  if (any(unsupported)) {
    stop("Unsupported estimator for model(s): ",
         paste(paste0(selected$model[unsupported], " = ",
                      selected$estimator[unsupported]), collapse = ", "),
         ". Currently available estimator: native.", call. = FALSE)
  }
  selected[, c("model", "estimator", "algorithm"), drop = FALSE]
}

#' @noRd
.idioml_canonical_model <- function(model, task) {
  aliases <- if (identical(task, "regression")) {
    c(linear_regression = "linear",
      ridge_regression = "ridge",
      lasso_regression = "lasso",
      elastic_net = "elastic")
  } else {
    c(logistic_regression = "logistic",
      ridge_logistic = "ridge",
      lasso_logistic = "lasso",
      elastic_net_logistic = "elastic",
      naive_bayes = "bayes")
  }
  out <- unname(aliases[model])
  out[is.na(out)] <- model[is.na(out)]
  out
}

#' @noRd
.idioml_resolve_estimator <- function(models, estimator) {
  if (is.null(estimator)) return(rep("native", length(models)))
  if (is.list(estimator)) estimator <- unlist(estimator, use.names = TRUE)
  if (!(is.character(estimator) && length(estimator) >= 1L)) {
    stop("`estimator` must be NULL, a single estimator name, or a named ",
         "character vector/list mapping model names to estimator names.",
         call. = FALSE)
  }
  if (is.null(names(estimator)) || all(names(estimator) == "")) {
    if (length(estimator) != 1L) {
      stop("Unnamed `estimator` must be a single value.", call. = FALSE)
    }
    return(rep(estimator, length(models)))
  }
  bad <- setdiff(names(estimator), models)
  if (length(bad) > 0L) {
    stop("`estimator` names must match selected model names. Unknown: ",
         paste(bad, collapse = ", "), call. = FALSE)
  }
  out <- rep("native", length(models))
  names(out) <- models
  out[names(estimator)] <- estimator
  unname(out)
}

#' @noRd
.idioml_model_catalog <- function(task) {
  if (identical(task, "regression")) {
    data.frame(
      model = c("mean", "linear", "ridge", "lasso", "elastic", "pcr", "knn",
                "tree"),
      default_estimator = "native",
      algorithm = c("mean", "linear", "ridge", "lasso", "elastic_net",
                    "pcr", "knn", "stump"),
      stringsAsFactors = FALSE
    )
  } else {
    data.frame(
      model = c("majority", "logistic", "ridge", "lasso", "elastic", "lda",
                "bayes", "knn", "tree"),
      default_estimator = "native",
      algorithm = c("majority", "logistic", "ridge_logistic",
                    "lasso_logistic", "elastic_net_logistic", "lda",
                    "naive_bayes", "knn", "stump"),
      stringsAsFactors = FALSE
    )
  }
}

#' @noRd
.idioml_outcome_info <- function(y, task) {
  if (identical(task, "regression")) {
    if (!is.numeric(y)) {
      stop("Regression requires a numeric outcome.", call. = FALSE)
    }
    return(list(levels = NULL, positive = NA_character_))
  }
  yy <- y[!is.na(y)]
  lev <- if (is.factor(y)) levels(y) else unique(as.character(yy))
  lev <- lev[lev %in% as.character(yy)]
  if (length(lev) != 2L) {
    stop("Classification requires a binary outcome with exactly two observed ",
         "levels.", call. = FALSE)
  }
  list(levels = lev, positive = lev[2L])
}

#' @noRd
.idioml_order <- function(data, id, day, beep) {
  keys <- list(data[[id]])
  if (!is.null(day)) keys[[length(keys) + 1L]] <- data[[day]]
  if (!is.null(beep)) keys[[length(keys) + 1L]] <- data[[beep]]
  keys[[length(keys) + 1L]] <- data$.idioml_row
  do.call(order, keys)
}

#' @noRd
.idioml_roles <- function(data, id, test_prop, min_train, min_test,
                          outcome, predictors) {
  role <- rep("skip", nrow(data))
  failures <- data.frame(model_scope = character(), model = character(),
                         estimator = character(),
                         subject = character(),
                         message = character(), stringsAsFactors = FALSE)
  subjects <- unique(data$.idioml_subject)
  needed <- c(outcome, predictors)
  for (subject in subjects) {
    idx <- which(data$.idioml_subject == subject)
    n <- length(idx)
    n_test <- max(as.integer(min_test), ceiling(n * test_prop))
    n_test <- min(n_test, n - 1L)
    if (!is.finite(n_test) || n_test < min_test) {
      failures <- rbind(failures, data.frame(
        model_scope = "split", model = ".split", estimator = ".split",
        subject = subject,
        message = "Too few rows to create a train/test split.",
        stringsAsFactors = FALSE
      ))
      next
    }
    train_idx <- idx[seq_len(n - n_test)]
    test_idx <- idx[(n - n_test + 1L):n]
    train_complete <- stats::complete.cases(data[train_idx, needed, drop = FALSE])
    test_complete <- stats::complete.cases(data[test_idx, needed, drop = FALSE])
    if (sum(train_complete) < min_train || sum(test_complete) < min_test) {
      failures <- rbind(failures, data.frame(
        model_scope = "split", model = ".split", estimator = ".split",
        subject = subject,
        message = paste0("Insufficient complete rows (train = ",
                         sum(train_complete), ", test = ", sum(test_complete),
                         ")."),
        stringsAsFactors = FALSE
      ))
      next
    }
    role[train_idx[train_complete]] <- "train"
    role[test_idx[test_complete]] <- "test"
  }
  list(role = role, failures = failures)
}

#' @noRd
.idioml_fit_one <- function(train, outcome, predictors, task, model, y_info,
                            control, standardize) {
  needed <- c(outcome, predictors)
  train <- train[stats::complete.cases(train[, needed, drop = FALSE]), ,
                 drop = FALSE]
  if (nrow(train) == 0L) {
    stop("No complete training rows.", call. = FALSE)
  }
  x_raw <- as.matrix(train[, predictors, drop = FALSE])
  pars <- .idioml_scale_params(x_raw, standardize)
  x <- .idioml_apply_scale(x_raw, pars)
  X <- cbind("(Intercept)" = 1, x)
  if (identical(task, "regression")) {
    y <- as.numeric(train[[outcome]])
    fit <- .idioml_fit_regression(X, x, y, predictors, model, control)
  } else {
    y <- as.integer(as.character(train[[outcome]]) == y_info$positive)
    if (length(unique(y)) < 2L) {
      stop("Training rows contain only one outcome class.", call. = FALSE)
    }
    fit <- .idioml_fit_classification(X, x, y, predictors, model, y_info,
                                      control)
  }
  fit$predictors <- predictors
  fit$outcome <- outcome
  fit$task <- task
  fit$model <- model
  fit$scale <- pars
  fit$levels <- y_info$levels
  fit$positive <- y_info$positive
  fit$n_train <- nrow(train)
  fit
}

#' @noRd
.idioml_scale_params <- function(x, standardize) {
  center <- colMeans(x, na.rm = TRUE)
  scale <- apply(x, 2L, stats::sd, na.rm = TRUE)
  if (!isTRUE(standardize)) {
    center[] <- 0
    scale[] <- 1
  }
  bad <- !is.finite(scale) | scale == 0
  scale[bad] <- 1
  center[!is.finite(center)] <- 0
  list(center = center, scale = scale)
}

#' @noRd
.idioml_apply_scale <- function(x, pars) {
  sweep(sweep(x, 2L, pars$center, "-"), 2L, pars$scale, "/")
}

#' @noRd
.idioml_linear_beta <- function(X, y, lambda) {
  penalty <- diag(ncol(X))
  penalty[1L, 1L] <- 0
  XtX <- crossprod(X) + lambda * penalty
  Xty <- crossprod(X, y)
  as.numeric(.ido_pseudoinverse(XtX) %*% Xty)
}

#' @noRd
.idioml_fit_regression <- function(X, x, y, predictors, model, control) {
  if (identical(model, "mean")) {
    return(list(type = "constant", constant = mean(y),
                coef = c("(Intercept)" = mean(y))))
  }
  if (identical(model, "linear")) {
    beta <- .idioml_linear_beta(X, y, 0)
    names(beta) <- colnames(X)
    return(list(type = "linear", beta = beta, coef = beta))
  }
  if (identical(model, "ridge")) {
    beta <- .idioml_linear_beta(X, y, control$lambda)
    names(beta) <- colnames(X)
    return(list(type = "linear", beta = beta, coef = beta))
  }
  if (model %in% c("lasso", "elastic_net")) {
    alpha <- if (identical(model, "lasso")) 1 else control$alpha
    beta <- .idioml_gaussian_cd(X, y, lambda = control$lambda, alpha = alpha,
                                max_iter = control$max_iter, tol = control$tol)
    names(beta) <- colnames(X)
    return(list(type = "linear", beta = beta, coef = beta))
  }
  if (identical(model, "pcr")) {
    pcr <- .idioml_pcr_fit(x, y, predictors, control$n_components)
    return(c(list(type = "pcr"), pcr))
  }
  if (identical(model, "knn")) {
    return(list(type = "knn", x_train = x, y_train = y, k = control$k,
                coef = c(k = control$k)))
  }
  if (identical(model, "stump")) {
    stump <- .idioml_stump_fit(x, y, predictors, task = "regression")
    return(c(list(type = "stump"), stump))
  }
  stop("Unsupported regression model: ", model, call. = FALSE)
}

#' @noRd
.idioml_fit_classification <- function(X, x, y, predictors, model, y_info,
                                       control) {
  if (identical(model, "majority")) {
    prob <- mean(y)
    cls <- if (prob >= 0.5) y_info$positive else y_info$levels[1L]
    return(list(type = "constant", constant = prob, class = cls,
                coef = c(probability = prob)))
  }
  if (identical(model, "logistic")) {
    beta <- .idioml_logistic_glm_beta(X, y)
    names(beta) <- colnames(X)
    return(list(type = "linear_logit", beta = beta, coef = beta))
  }
  if (model %in% c("ridge_logistic", "lasso_logistic",
                   "elastic_net_logistic")) {
    alpha <- switch(model,
                    ridge_logistic = 0,
                    lasso_logistic = 1,
                    elastic_net_logistic = control$alpha)
    beta <- .idioml_logistic_cd(X, y, lambda = control$lambda, alpha = alpha,
                                max_iter = control$max_iter, tol = control$tol)
    names(beta) <- colnames(X)
    return(list(type = "linear_logit", beta = beta, coef = beta))
  }
  if (identical(model, "lda")) {
    lda <- .idioml_lda_fit(x, y, predictors)
    return(c(list(type = "lda"), lda))
  }
  if (identical(model, "naive_bayes")) {
    nb <- .idioml_nb_fit(x, y, predictors)
    return(c(list(type = "naive_bayes"), nb))
  }
  if (identical(model, "knn")) {
    return(list(type = "knn", x_train = x, y_train = y, k = control$k,
                coef = c(k = control$k)))
  }
  if (identical(model, "stump")) {
    stump <- .idioml_stump_fit(x, y, predictors, task = "classification")
    return(c(list(type = "stump"), stump))
  }
  stop("Unsupported classification model: ", model, call. = FALSE)
}

#' @noRd
.idioml_soft_threshold <- function(z, gamma) {
  sign(z) * pmax(abs(z) - gamma, 0)
}

#' @noRd
.idioml_gaussian_cd <- function(X, y, lambda, alpha, max_iter, tol) {
  n <- nrow(X)
  p <- ncol(X)
  beta <- .idioml_linear_beta(X, y, lambda * (1 - alpha))
  if (lambda == 0) return(beta)
  for (iter in seq_len(max_iter)) {
    old <- beta
    for (j in seq_len(p)) {
      r <- y - as.numeric(X %*% beta) + X[, j] * beta[j]
      zj <- sum(X[, j]^2) / n
      pj <- sum(X[, j] * r) / n
      if (j == 1L) {
        beta[j] <- if (zj > 0) pj / zj else 0
      } else {
        beta[j] <- .idioml_soft_threshold(pj, lambda * alpha) /
          (zj + lambda * (1 - alpha))
      }
    }
    if (max(abs(beta - old)) < tol) break
  }
  beta
}

#' @noRd
.idioml_logistic_glm_beta <- function(X, y) {
  fit <- suppressWarnings(stats::glm.fit(x = X, y = y,
                                         family = stats::binomial()))
  beta <- fit$coefficients
  beta[is.na(beta)] <- 0
  beta
}

#' @noRd
.idioml_logistic_cd <- function(X, y, lambda, alpha, max_iter, tol) {
  beta <- .idioml_logistic_glm_beta(X, y)
  beta[!is.finite(beta)] <- 0
  for (iter in seq_len(max_iter)) {
    eta <- as.numeric(X %*% beta)
    mu <- pmin(pmax(stats::plogis(eta), 1e-5), 1 - 1e-5)
    w <- mu * (1 - mu)
    z <- eta + (y - mu) / w
    Xw <- X * sqrt(w)
    zw <- z * sqrt(w)
    old <- beta
    beta <- .idioml_gaussian_cd(Xw, zw, lambda = lambda, alpha = alpha,
                                max_iter = 25L, tol = tol)
    if (max(abs(beta - old)) < tol) break
  }
  beta
}

#' @noRd
.idioml_pcr_fit <- function(x, y, predictors, n_components) {
  sv <- svd(x)
  max_comp <- min(ncol(x), nrow(x) - 1L, length(sv$d))
  if (max_comp < 1L) stop("PCR needs at least one component.", call. = FALSE)
  q <- n_components %||% min(5L, max_comp)
  q <- min(as.integer(q), max_comp)
  scores <- sv$u[, seq_len(q), drop = FALSE] %*% diag(sv$d[seq_len(q)], q, q)
  Xp <- cbind("(Intercept)" = 1, scores)
  beta_pc <- .idioml_linear_beta(Xp, y, 0)
  names(beta_pc) <- c("(Intercept)", paste0("PC", seq_len(q)))
  list(rotation = sv$v[, seq_len(q), drop = FALSE],
       beta_pc = beta_pc,
       n_components = q,
       coef = beta_pc)
}

#' @noRd
.idioml_lda_fit <- function(x, y, predictors) {
  x0 <- x[y == 0, , drop = FALSE]
  x1 <- x[y == 1, , drop = FALSE]
  m0 <- colMeans(x0)
  m1 <- colMeans(x1)
  S <- stats::cov(rbind(sweep(x0, 2L, m0, "-"), sweep(x1, 2L, m1, "-")))
  if (!is.matrix(S)) S <- matrix(S, nrow = length(predictors))
  inv <- .ido_pseudoinverse(S)
  w <- as.numeric(inv %*% (m1 - m0))
  b <- -0.5 * as.numeric(t(m1 + m0) %*% w) + qlogis(mean(y))
  coef <- c("(Intercept)" = b, stats::setNames(w, predictors))
  list(beta = coef, coef = coef)
}

#' @noRd
.idioml_nb_fit <- function(x, y, predictors) {
  means <- rbind(colMeans(x[y == 0, , drop = FALSE]),
                 colMeans(x[y == 1, , drop = FALSE]))
  vars <- rbind(apply(x[y == 0, , drop = FALSE], 2L, stats::var),
                apply(x[y == 1, , drop = FALSE], 2L, stats::var))
  vars[!is.finite(vars) | vars <= 0] <- 1e-6
  dimnames(means) <- dimnames(vars) <- list(c("class0", "class1"), predictors)
  prior <- mean(y)
  coef <- c(prior_positive = prior)
  list(means = means, vars = vars, prior = prior, coef = coef)
}

#' @noRd
.idioml_stump_fit <- function(x, y, predictors, task) {
  best <- list(score = Inf, variable = predictors[1L], threshold = median(x[, 1L]),
               left = mean(y), right = mean(y))
  for (j in seq_along(predictors)) {
    vals <- sort(unique(x[, j]))
    if (length(vals) < 2L) next
    cuts <- (utils::head(vals, -1L) + utils::tail(vals, -1L)) / 2
    if (length(cuts) > 50L) cuts <- stats::quantile(cuts, seq(0, 1, length.out = 50),
                                                    names = FALSE)
    for (cut in unique(cuts)) {
      left_idx <- x[, j] <= cut
      if (!any(left_idx) || all(left_idx)) next
      left <- mean(y[left_idx])
      right <- mean(y[!left_idx])
      pred <- ifelse(left_idx, left, right)
      score <- if (identical(task, "classification")) {
        mean((y - pmin(pmax(pred, 0), 1))^2)
      } else {
        mean((y - pred)^2)
      }
      if (is.finite(score) && score < best$score) {
        best <- list(score = score, variable = predictors[j], threshold = cut,
                     left = left, right = right)
      }
    }
  }
  coef <- c(threshold = best$threshold, left = best$left, right = best$right)
  names(coef)[1L] <- paste0("threshold:", best$variable)
  list(variable = best$variable, threshold = best$threshold,
       left = best$left, right = best$right, coef = coef)
}

#' @noRd
.idioml_predict_values <- function(fit, newdata) {
  miss <- setdiff(fit$predictors, names(newdata))
  if (length(miss) > 0L) {
    stop("Predictor column(s) missing from newdata: ",
         paste(miss, collapse = ", "), call. = FALSE)
  }
  x <- as.matrix(newdata[, fit$predictors, drop = FALSE])
  keep <- stats::complete.cases(x)
  out <- rep(NA_real_, nrow(newdata))
  if (any(keep)) {
    xs <- .idioml_apply_scale(x[keep, , drop = FALSE], fit$scale)
    out[keep] <- .idioml_predict_matrix(fit, xs)
  }
  out
}

#' @noRd
.idioml_predict_matrix <- function(fit, xs) {
  if (identical(fit$type, "constant")) {
    return(rep(fit$constant, nrow(xs)))
  }
  if (identical(fit$type, "linear")) {
    X <- cbind("(Intercept)" = 1, xs)
    return(as.numeric(X %*% fit$beta))
  }
  if (identical(fit$type, "linear_logit")) {
    X <- cbind("(Intercept)" = 1, xs)
    return(stats::plogis(as.numeric(X %*% fit$beta)))
  }
  if (identical(fit$type, "pcr")) {
    scores <- xs %*% fit$rotation
    X <- cbind("(Intercept)" = 1, scores)
    return(as.numeric(X %*% fit$beta_pc))
  }
  if (identical(fit$type, "knn")) {
    return(.idioml_knn_predict(xs, fit$x_train, fit$y_train, fit$k, fit$task))
  }
  if (identical(fit$type, "lda")) {
    X <- cbind("(Intercept)" = 1, xs)
    return(stats::plogis(as.numeric(X %*% fit$beta)))
  }
  if (identical(fit$type, "naive_bayes")) {
    return(.idioml_nb_predict(xs, fit))
  }
  if (identical(fit$type, "stump")) {
    j <- match(fit$variable, fit$predictors)
    pred <- ifelse(xs[, j] <= fit$threshold, fit$left, fit$right)
    if (identical(fit$task, "classification")) pmin(pmax(pred, 0), 1) else pred
  } else {
    stop("Unsupported fitted model type: ", fit$type, call. = FALSE)
  }
}

#' @noRd
.idioml_knn_predict <- function(x_new, x_train, y_train, k, task) {
  k <- min(as.integer(k), nrow(x_train))
  vapply(seq_len(nrow(x_new)), function(i) {
    d <- rowSums((t(t(x_train) - x_new[i, ]))^2)
    idx <- order(d)[seq_len(k)]
    if (identical(task, "classification")) mean(y_train[idx]) else mean(y_train[idx])
  }, numeric(1))
}

#' @noRd
.idioml_nb_predict <- function(xs, fit) {
  vapply(seq_len(nrow(xs)), function(i) {
    ll0 <- log(1 - fit$prior) +
      sum(stats::dnorm(xs[i, ], fit$means[1L, ], sqrt(fit$vars[1L, ]),
                       log = TRUE))
    ll1 <- log(fit$prior) +
      sum(stats::dnorm(xs[i, ], fit$means[2L, ], sqrt(fit$vars[2L, ]),
                       log = TRUE))
    m <- max(ll0, ll1)
    exp(ll1 - m) / (exp(ll0 - m) + exp(ll1 - m))
  }, numeric(1))
}

#' @noRd
.idioml_predict_table <- function(fit, test, model_scope, model, estimator,
                                  subject, outcome, predictors, task, y_info) {
  needed <- c(outcome, predictors)
  test <- test[stats::complete.cases(test[, needed, drop = FALSE]), ,
               drop = FALSE]
  if (nrow(test) == 0L) {
    stop("No complete test rows.", call. = FALSE)
  }
  subject_col <- if ("pooled" == model_scope) test$.idioml_subject else subject
  pred <- .idioml_predict_values(fit, test)
  if (identical(task, "regression")) {
    observed <- as.numeric(test[[outcome]])
    residual <- observed - pred
    out <- data.frame(
      model_scope = model_scope,
      model = model,
      estimator = estimator,
      subject = as.character(subject_col),
      original_row = test$.idioml_row,
      observed = observed,
      predicted = pred,
      residual = residual,
      abs_error = abs(residual),
      squared_error = residual^2,
      stringsAsFactors = FALSE
    )
  } else {
    observed_class <- as.character(test[[outcome]])
    predicted_class <- ifelse(pred >= 0.5, y_info$positive, y_info$levels[1L])
    out <- data.frame(
      model_scope = model_scope,
      model = model,
      estimator = estimator,
      subject = as.character(subject_col),
      original_row = test$.idioml_row,
      observed_class = observed_class,
      predicted_class = predicted_class,
      probability = pred,
      correct = observed_class == predicted_class,
      brier = (as.integer(observed_class == y_info$positive) - pred)^2,
      stringsAsFactors = FALSE
    )
  }
  rownames(out) <- NULL
  out
}

#' @noRd
.idioml_coef_table <- function(fit, model_scope, model, estimator, subject) {
  coef <- fit$coef %||% numeric(0)
  data.frame(model_scope = model_scope,
             model = model,
             estimator = estimator,
             subject = subject,
             term = names(coef),
             estimate = as.numeric(coef),
             stringsAsFactors = FALSE)
}

#' @noRd
.idioml_metrics <- function(predictions, task, positive = NA_character_) {
  specs <- unique(predictions[c("model", "estimator")])
  rows <- list()
  for (i in seq_len(nrow(specs))) {
    model <- specs$model[i]
    estimator <- specs$estimator[i]
    pa <- predictions[predictions$model == model &
                        predictions$estimator == estimator, , drop = FALSE]
    scopes <- unique(pa$model_scope)
    for (scope in scopes) {
      ps <- pa[pa$model_scope == scope, , drop = FALSE]
      subjects <- c(sort(unique(ps$subject)), ".overall")
      for (subject in subjects) {
        p <- if (identical(subject, ".overall")) ps else
          ps[ps$subject == subject, , drop = FALSE]
        if (nrow(p) == 0L) next
        rows[[length(rows) + 1L]] <- if (identical(task, "regression")) {
          .idioml_regression_metrics(p, scope, model, estimator, subject)
        } else {
          .idioml_classification_metrics(p, scope, model, estimator, subject,
                                         positive)
        }
      }
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @noRd
.idioml_regression_metrics <- function(p, scope, model, estimator, subject) {
  denom <- sum((p$observed - mean(p$observed))^2)
  r2 <- if (denom > 0) 1 - sum(p$squared_error) / denom else NA_real_
  data.frame(model_scope = scope, model = model, estimator = estimator,
             subject = subject,
             n = nrow(p),
             mae = mean(p$abs_error), rmse = sqrt(mean(p$squared_error)),
             bias = mean(p$residual), r_squared = r2,
             stringsAsFactors = FALSE)
}

#' @noRd
.idioml_classification_metrics <- function(p, scope, model, estimator,
                                           subject, positive) {
  eps <- sqrt(.Machine$double.eps)
  prob <- pmin(pmax(p$probability, eps), 1 - eps)
  correct <- as.integer(p$observed_class == p$predicted_class)
  y <- as.integer(p$observed_class == positive)
  data.frame(model_scope = scope, model = model, estimator = estimator,
             subject = subject,
             n = nrow(p),
             accuracy = mean(correct), brier = mean(p$brier),
             log_loss = -mean(ifelse(y == 1L, log(prob), log(1 - prob))),
             stringsAsFactors = FALSE)
}

#' Print method for idiographic ML fits
#'
#' @param x An `idioml_result`.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.idioml_result <- function(x, ...) {
  cat("Idiographic Machine-Learning Result\n")
  cat(sprintf("  Task:          %s\n", x$task))
  cat(sprintf("  Algorithms:    %d (%s)\n", length(x$model),
              paste(x$model, collapse = ", ")))
  cat(sprintf("  Outcome:       %s\n", x$outcome))
  cat(sprintf("  Predictors:    %d (%s)\n", length(x$predictors),
              paste(x$predictors, collapse = ", ")))
  cat(sprintf("  Subjects:      %d\n", x$n_subjects))
  cat(sprintf("  Predictions:   %d\n", nrow(x$predictions)))
  overall <- x$metrics[x$metrics$subject == ".overall", , drop = FALSE]
  if (nrow(overall) > 0L) {
    for (i in seq_len(nrow(overall))) {
      if (identical(x$task, "regression")) {
        cat(sprintf("  %s/%s[%s] RMSE:   %.4f\n", overall$model_scope[i],
                    overall$model[i], overall$estimator[i], overall$rmse[i]))
      } else {
        cat(sprintf("  %s/%s[%s] accuracy: %.4f\n", overall$model_scope[i],
                    overall$model[i], overall$estimator[i],
                    overall$accuracy[i]))
      }
    }
  }
  cat("  Tables:        x$predictions | x$metrics | coefs(x)\n")
  invisible(x)
}

#' Summary method for idiographic ML fits
#'
#' @param object An `idioml_result`.
#' @param ... Ignored.
#' @return The metrics table.
#' @export
summary.idioml_result <- function(object, ...) {
  object$metrics
}

#' @rdname coefs
#' @export
coefs.idioml_result <- function(x, ...) {
  x$coefficients
}

#' @export
as.data.frame.idioml_result <- function(x, row.names = NULL,
                                        optional = FALSE, ...) {
  x$predictions
}

#' Predict from an idiographic ML result
#'
#' @param object An `idioml_result`.
#' @param newdata Optional new data. If `NULL`, the stored test-set predictions
#'   are returned.
#' @param scope `"pooled"` or `"individual"`.
#' @param model Fitted model name to use. Default is the first fitted model.
#' @param estimator Fitted estimator/backend for `model`. Default is that
#'   model's first fitted estimator.
#' @param type `"response"` for numeric predictions/probabilities or `"class"`
#'   for classification labels.
#' @param ... Ignored.
#' @return A data.frame of predictions.
#' @export
predict.idioml_result <- function(object, newdata = NULL,
                                  scope = c("pooled", "individual"),
                                  model = NULL,
                                  estimator = NULL,
                                  type = c("response", "class"), ...) {
  scope <- match.arg(scope)
  type <- match.arg(type)
  if (is.null(newdata)) return(object$predictions)
  if (is.null(object$fits) || length(object$fits) == 0L) {
    stop("Refit with keep_fits = TRUE to predict new data.", call. = FALSE)
  }
  if (is.null(model)) model <- object$model[1L]
  if (!(is.character(model) && length(model) == 1L &&
        model %in% object$model)) {
    stop("`model` must be one fitted model: ",
         paste(object$model, collapse = ", "), call. = FALSE)
  }
  available <- object$estimators[object$estimators$model == model, ,
                                 drop = FALSE]
  if (is.null(estimator)) estimator <- available$estimator[1L]
  if (!(is.character(estimator) && length(estimator) == 1L &&
        estimator %in% available$estimator)) {
    stop("`estimator` must be one fitted estimator for model '", model,
         "': ", paste(available$estimator, collapse = ", "), call. = FALSE)
  }
  newdata <- as.data.frame(newdata)
  id_col <- object$config$id
  if (!id_col %in% names(newdata)) {
    stop("newdata must contain the id column '", id_col, "'.", call. = FALSE)
  }
  out <- data.frame(
    model_scope = scope,
    model = model,
    estimator = estimator,
    subject = as.character(newdata[[id_col]]),
    original_row = seq_len(nrow(newdata)),
    stringsAsFactors = FALSE
  )
  pred <- rep(NA_real_, nrow(newdata))
  if (identical(scope, "pooled")) {
    fit <- object$fits[[paste0("pooled:", model, ":", estimator)]]
    if (is.null(fit)) stop("No pooled fit was stored.", call. = FALSE)
    pred <- .idioml_predict_values(fit, newdata)
  } else {
    for (subject in unique(out$subject)) {
      fit <- object$fits[[paste0("individual:", model, ":", estimator, ":",
                                 subject)]]
      if (is.null(fit)) next
      idx <- out$subject == subject
      pred[idx] <- .idioml_predict_values(fit, newdata[idx, , drop = FALSE])
    }
  }
  if (identical(object$task, "classification")) {
    out$probability <- pred
    out$predicted_class <- ifelse(pred >= 0.5, object$positive,
                                  setdiff(object$fits[[1L]]$levels,
                                          object$positive)[1L])
    if (identical(type, "class")) return(out[c("model_scope", "subject",
                                               "model", "estimator",
                                               "original_row",
                                               "predicted_class")])
  } else {
    out$predicted <- pred
  }
  out
}
