# ---- Rolling one-step forecast validation ----

#' Validate one-step forecasts from idiographic VAR models (experimental)
#'
#' @description
#' **Experimental.** The rolling-origin design follows standard time-series
#' cross-validation practice, but unlike the estimators in this package it has
#' no external reference implementation to validate against, and its
#' interface, defaults, and reported metrics may change in a future release.
#'
#' Performs rolling-origin one-step prediction from [fit_var()] or
#' [fit_graphical_var()]. Each split fits the estimator on earlier blocks and
#' predicts current variables in the next block from their lag-1 values. Scaling
#' and within-person centring parameters are learned from the training split
#' only, then applied to the assessment split before prediction.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param estimator `"var"` (default) for [fit_var()] or `"graphical_var"`
#'   for [fit_graphical_var()].
#' @param id Character. Name of the person-ID column, or `NULL`.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param initial Integer number of ordered blocks in the first training split.
#'   Default uses 60 percent of blocks, leaving at least one assessment block.
#' @param assess Integer number of blocks to assess per split. Default `1`.
#' @param step Integer number of blocks to advance between splits. Default `1`.
#' @param n_splits Optional maximum number of rolling splits.
#' @param block_size Integer or `NULL`. Consecutive block length used only when
#'   neither `id` nor `day` is supplied. Defaults to `floor(sqrt(nrow(data)))`.
#' @param scale Logical. Whether to standardize using training-split means and
#'   SDs. Default `TRUE`.
#' @param center_within Logical. Whether to centre within person using
#'   training-split person means when more than one id is present. Default
#'   `TRUE`.
#' @param delete_missings Logical. Drop incomplete current/lagged assessment
#'   rows. Default `TRUE`.
#' @param keep_fits Logical. Store fitted split models? Default `FALSE`.
#' @param ... Further arguments passed to the estimator.
#'
#' @return A `forecast_result` with `$predictions`, `$metrics`, `$splits`,
#'   `$failures`, and optionally `$fits`.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, day = rep(1:5, each = 12),
#'                 beep = rep(1:12, 5),
#'                 A = rnorm(60), B = rnorm(60), C = rnorm(60))
#' fc <- validate_forecast(d, vars = c("A", "B", "C"), id = "id",
#'                         day = "day", beep = "beep",
#'                         initial = 3, n_splits = 2, scale = FALSE)
#' fc$metrics
#' @export
validate_forecast <- function(data, vars,
                              estimator = c("var", "graphical_var"),
                              id = NULL, day = NULL, beep = NULL,
                              initial = NULL,
                              assess = 1L,
                              step = 1L,
                              n_splits = NULL,
                              block_size = NULL,
                              scale = TRUE,
                              center_within = TRUE,
                              delete_missings = TRUE,
                              keep_fits = FALSE,
                              ...) {
  estimator <- match.arg(estimator)
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(delete_missings, "delete_missings")
  .ido_check_flag(keep_fits, "keep_fits")
  .forecast_check_count(assess, "assess")
  .forecast_check_count(step, "step")
  if (!is.null(initial)) .forecast_check_count(initial, "initial")
  if (!is.null(n_splits)) .forecast_check_count(n_splits, "n_splits")
  if (!is.null(block_size)) .forecast_check_count(block_size, "block_size")

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)

  blocks <- .forecast_blocks(data, id, day, beep, block_size)
  split_plan <- .forecast_splits(blocks, initial, assess, step, n_splits)
  fits <- vector("list", nrow(split_plan))
  preds <- vector("list", nrow(split_plan))
  failures <- data.frame(split = integer(), message = character(),
                         stringsAsFactors = FALSE)

  for (i in seq_len(nrow(split_plan))) {
    train_blocks <- seq_len(split_plan$train_end[i])
    test_blocks <- seq.int(split_plan$test_start[i], split_plan$test_end[i])
    train_idx <- unlist(blocks$indices[train_blocks], use.names = FALSE)
    test_idx <- unlist(blocks$indices[test_blocks], use.names = FALSE)
    train <- data[train_idx, , drop = FALSE]
    test <- data[test_idx, , drop = FALSE]

    fit <- tryCatch(
      .forecast_fit(estimator, train, vars, id, day, beep, scale,
                    center_within, delete_missings, ...),
      error = function(e) e
    )
    if (inherits(fit, "error")) {
      failures <- rbind(failures,
                        data.frame(split = i, message = fit$message,
                                   stringsAsFactors = FALSE))
      next
    }
    design <- tryCatch(
      .forecast_design(train, test, vars, id, day, beep, scale,
                       center_within, delete_missings),
      error = function(e) e
    )
    if (inherits(design, "error")) {
      failures <- rbind(failures,
                        data.frame(split = i, message = design$message,
                                   stringsAsFactors = FALSE))
      next
    }
    yhat <- design$data_l %*% t(fit$beta)
    colnames(yhat) <- vars
    preds[[i]] <- .forecast_prediction_table(i, design, yhat, vars)
    if (isTRUE(keep_fits)) fits[[i]] <- fit
  }

  preds <- preds[!vapply(preds, is.null, logical(1))]
  if (length(preds) == 0L) {
    stop("No forecast splits produced predictions.", call. = FALSE)
  }
  predictions <- do.call(rbind, preds)
  rownames(predictions) <- NULL
  metrics <- .forecast_metrics(predictions)

  out <- list(
    predictions = predictions,
    metrics = metrics,
    splits = split_plan,
    failures = failures,
    fits = if (isTRUE(keep_fits)) fits else NULL,
    n_success = length(preds),
    n_splits = nrow(split_plan),
    config = list(estimator = estimator, id = id, day = day, beep = beep,
                  scale = scale, center_within = center_within,
                  delete_missings = delete_missings,
                  block_size = blocks$block_size)
  )
  class(out) <- "forecast_result"
  out
}

#' @noRd
.forecast_check_count <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) &&
        x >= 1L && x == as.integer(x))) {
    stop("`", arg, "` must be a single finite whole number >= 1.",
         call. = FALSE)
  }
}

#' @noRd
.forecast_blocks <- function(data, id, day, beep, block_size) {
  n <- nrow(data)
  idv <- if (is.null(id)) rep(1L, n) else data[[id]]
  dayv <- if (is.null(day)) rep(1L, n) else data[[day]]
  beepv <- if (is.null(beep)) seq_len(n) else data[[beep]]
  ord <- order(dayv, idv, beepv)

  if (!is.null(id) && !is.null(day)) {
    key <- paste(data[[day]], data[[id]], sep = "\r")
  } else if (!is.null(day)) {
    key <- paste(data[[day]], sep = "\r")
  } else if (!is.null(id)) {
    key <- paste(data[[id]], sep = "\r")
  } else {
    if (is.null(block_size)) block_size <- max(2L, floor(sqrt(n)))
    key <- paste(ceiling(seq_len(n) / block_size), sep = "\r")
  }
  if (is.null(block_size)) block_size <- NA_integer_
  key <- key[ord]
  idx <- ord
  first <- !duplicated(key)
  keys <- key[first]
  indices <- lapply(keys, function(k) idx[key == k])
  names(indices) <- keys
  list(indices = indices, block_size = block_size)
}

#' @noRd
.forecast_splits <- function(blocks, initial, assess, step, n_splits) {
  n_blocks <- length(blocks$indices)
  if (n_blocks < 2L) {
    stop("Forecast validation requires at least two ordered blocks.",
         call. = FALSE)
  }
  if (is.null(initial)) {
    initial <- max(1L, min(n_blocks - 1L, floor(0.6 * n_blocks)))
  }
  if (initial >= n_blocks) {
    stop("`initial` must leave at least one assessment block.", call. = FALSE)
  }
  train_end <- seq.int(initial, n_blocks - assess, by = step)
  if (length(train_end) == 0L) {
    stop("No rolling splits can be formed; reduce `initial` or `assess`.",
         call. = FALSE)
  }
  if (!is.null(n_splits)) train_end <- utils::head(train_end, n_splits)
  out <- data.frame(
    split = seq_along(train_end),
    train_start = 1L,
    train_end = as.integer(train_end),
    test_start = as.integer(train_end + 1L),
    test_end = as.integer(train_end + assess),
    stringsAsFactors = FALSE
  )
  out[out$test_end <= n_blocks, , drop = FALSE]
}

#' @noRd
.forecast_fit <- function(estimator, data, vars, id, day, beep, scale,
                          center_within, delete_missings, ...) {
  if (identical(estimator, "var")) {
    fit_var(data, vars = vars, id = id, day = day, beep = beep,
              scale = scale, center_within = center_within,
              delete_missings = delete_missings, ...)
  } else {
    fit_graphical_var(data, vars = vars, id = id, day = day, beep = beep,
                  scale = scale, center_within = center_within,
                  delete_missings = delete_missings, ...)
  }
}

#' @noRd
.forecast_design <- function(train, test, vars, id, day, beep, scale,
                             center_within, delete_missings) {
  train <- as.data.frame(train)
  test <- as.data.frame(test)
  pars <- lapply(vars, function(v) {
    z <- suppressWarnings(as.numeric(train[[v]]))
    s <- stats::sd(z, na.rm = TRUE)
    list(mean = mean(z, na.rm = TRUE),
         sd = if (isTRUE(scale)) s else 1)
  })
  names(pars) <- vars
  for (v in vars) {
    s <- pars[[v]]$sd
    if (!is.finite(s) || s == 0) {
      stop("Cannot forecast variable '", v,
           "' because the training split has zero/non-finite variance.",
           call. = FALSE)
    }
    train[[v]] <- (as.numeric(train[[v]]) - pars[[v]]$mean) / s
    test[[v]] <- (as.numeric(test[[v]]) - pars[[v]]$mean) / s
  }

  id_train <- if (is.null(id)) rep(1L, nrow(train)) else train[[id]]
  id_test <- if (is.null(id)) rep(1L, nrow(test)) else test[[id]]
  if (isTRUE(center_within) && length(unique(id_train)) > 1L) {
    for (v in vars) {
      means <- tapply(train[[v]], id_train, mean, na.rm = TRUE)
      train[[v]] <- train[[v]] - as.numeric(means[as.character(id_train)])
      adj <- means[as.character(id_test)]
      adj[is.na(adj)] <- 0
      test[[v]] <- test[[v]] - as.numeric(adj)
    }
  }

  train$.forecast_role <- "train"
  test$.forecast_role <- "test"
  train$.forecast_original_row <- as.integer(rownames(train))
  test$.forecast_original_row <- as.integer(rownames(test))
  combined <- rbind(train, test)
  idv <- if (is.null(id)) rep(1L, nrow(combined)) else combined[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(combined)) else combined[[day]]
  key <- if (is.null(beep)) combined$.forecast_original_row else combined[[beep]]
  ord <- order(idv, dayv, key)
  combined <- combined[ord, , drop = FALSE]
  idv <- idv[ord]
  dayv <- dayv[ord]
  beepv <- key[ord]

  Y <- as.matrix(combined[, vars, drop = FALSE])
  blk <- paste(idv, dayv, sep = "\r")
  same <- c(FALSE, blk[-1L] == blk[-length(blk)])
  lag <- matrix(NA_real_, nrow(Y), ncol(Y))
  lag[same, ] <- Y[which(same) - 1L, , drop = FALSE]
  is_test <- combined$.forecast_role == "test"
  keep <- if (isTRUE(delete_missings)) {
    is_test & !(rowSums(is.na(Y)) > 0 | rowSums(is.na(lag)) > 0)
  } else {
    is_test
  }
  data_l <- cbind(1, lag[keep, , drop = FALSE])
  colnames(data_l) <- c("(Intercept)", vars)
  list(data_c = Y[keep, , drop = FALSE],
       data_l = data_l,
       meta = data.frame(original_row = combined$.forecast_original_row[keep],
                         subject = as.character(idv[keep]),
                         day = as.character(dayv[keep]),
                         beep = beepv[keep],
                         stringsAsFactors = FALSE))
}

#' @noRd
.forecast_prediction_table <- function(split, design, yhat, vars) {
  rows <- lapply(seq_along(vars), function(j) {
    data.frame(
      split = split,
      design$meta,
      variable = vars[j],
      observed = design$data_c[, j],
      predicted = yhat[, j],
      residual = design$data_c[, j] - yhat[, j],
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  out$abs_error <- abs(out$residual)
  out$squared_error <- out$residual^2
  rownames(out) <- NULL
  out
}

#' @noRd
.forecast_metrics <- function(predictions) {
  vars <- unique(predictions$variable)
  rows <- lapply(vars, function(v) {
    p <- predictions[predictions$variable == v, , drop = FALSE]
    data.frame(variable = v,
               n = nrow(p),
               mae = mean(p$abs_error),
               rmse = sqrt(mean(p$squared_error)),
               bias = mean(p$residual),
               stringsAsFactors = FALSE)
  })
  total <- data.frame(variable = ".overall",
                      n = nrow(predictions),
                      mae = mean(predictions$abs_error),
                      rmse = sqrt(mean(predictions$squared_error)),
                      bias = mean(predictions$residual),
                      stringsAsFactors = FALSE)
  out <- rbind(do.call(rbind, rows), total)
  rownames(out) <- NULL
  out
}

#' Print method for forecast validation results
#'
#' @param x A `forecast_result` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.forecast_result <- function(x, ...) {
  cat("Idiographic Forecast Validation\n")
  cat(sprintf("  Estimator:      %s\n", x$config$estimator))
  cat(sprintf("  Successful:     %d / %d\n", x$n_success, x$n_splits))
  cat(sprintf("  Predictions:    %d\n", nrow(x$predictions)))
  overall <- x$metrics[x$metrics$variable == ".overall", , drop = FALSE]
  cat(sprintf("  RMSE:           %.4f\n", overall$rmse))
  cat("  Tables:         x$predictions | x$metrics | x$splits\n")
  invisible(x)
}

#' @export
as.data.frame.forecast_result <- function(x, row.names = NULL,
                                          optional = FALSE, ...) {
  x$predictions
}

#' @export
summary.forecast_result <- function(object, ...) object$metrics
