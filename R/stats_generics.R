#' Tidy model metrics
#'
#' @param x An idiostats fit.
#' @param model,scope,subject Optional filters.
#' @param overall Logical. If `TRUE`, return only overall rows.
#' @param sort_by Optional metric/column to sort by.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows to return.
#' @param ... Ignored.
#' @return A data frame.
#' @export
metrics <- function(x, model = NULL, scope = NULL, subject = NULL, n = NULL,
                    overall = FALSE, sort_by = NULL, decreasing = FALSE,
                    ...) UseMethod("metrics")

#' @export
metrics.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                  subject = NULL, n = NULL, overall = FALSE,
                                  sort_by = NULL, decreasing = FALSE, ...) {
  .idio_filter_table(x$metrics, model = model, scope = scope,
                     subject = subject, overall = overall, sort_by = sort_by,
                     decreasing = decreasing, n = n)
}

#' Tidy held-out predictions
#'
#' @param x An idiostats fit.
#' @param model,scope,subject Optional filters.
#' @param overall Logical. If `TRUE`, return only overall rows when present.
#' @param sort_by Optional column to sort by.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows to return.
#' @param ... Ignored.
#' @return A data frame.
#' @export
predictions <- function(x, model = NULL, scope = NULL, subject = NULL,
                        n = NULL, overall = FALSE, sort_by = NULL,
                        decreasing = FALSE, ...) UseMethod("predictions")

#' @export
predictions.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                      subject = NULL, n = NULL,
                                      overall = FALSE, sort_by = NULL,
                                      decreasing = FALSE, ...) {
  .idio_filter_table(x$predictions, model = model, scope = scope,
                     subject = subject, overall = overall, sort_by = sort_by,
                     decreasing = decreasing, n = n)
}

#' @param model,scope,subject Optional filters for consolidated model fits.
#' @param n Optional maximum number of returned rows.
#' @param overall Return only aggregate rows when available?
#' @param sort_by Optional output column used for sorting.
#' @param decreasing Sort in descending order?
#' @rdname coefs
#' @export
coefs.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                subject = NULL, n = NULL, overall = FALSE,
                                sort_by = NULL, decreasing = FALSE, ...) {
  .idio_filter_table(x$coefs, model = model, scope = scope,
                     subject = subject, overall = overall, sort_by = sort_by,
                     decreasing = decreasing, n = n)
}

#' Best overall model row
#'
#' @param x An idiostats fit.
#' @param scope Optional scope filter.
#' @param ... Ignored.
#' @return One-row data frame with the best `.overall` metric row.
#' @export
best_model <- function(x, scope = NULL, ...) UseMethod("best_model")

#' @export
best_model.idiostats_fit <- function(x, scope = NULL, ...) {
  tab <- metrics(x, scope = scope, overall = TRUE)
  if (!nrow(tab)) return(tab)
  if ("rmse" %in% names(tab)) {
    return(tab[which.min(tab$rmse), , drop = FALSE])
  }
  if ("accuracy" %in% names(tab)) {
    return(tab[which.max(tab$accuracy), , drop = FALSE])
  }
  tab[1L, , drop = FALSE]
}

.idio_filter_table <- function(tab, model = NULL, scope = NULL, subject = NULL,
                               subgroup = NULL, overall = FALSE,
                               sort_by = NULL, decreasing = FALSE, n = NULL) {
  if (!is.null(model) && "model" %in% names(tab)) {
    tab <- tab[tab$model %in% model, , drop = FALSE]
  }
  if (!is.null(scope) && "scope" %in% names(tab)) {
    tab <- tab[tab$scope %in% scope, , drop = FALSE]
  }
  if (!is.null(subject) && "subject" %in% names(tab)) {
    tab <- tab[tab$subject %in% subject, , drop = FALSE]
  }
  if (!is.null(subgroup) && "subgroup" %in% names(tab)) {
    tab <- tab[tab$subgroup %in% subgroup, , drop = FALSE]
  }
  if (isTRUE(overall) && "subject" %in% names(tab)) {
    tab <- tab[tab$subject == ".overall", , drop = FALSE]
  }
  if (!is.null(sort_by)) {
    if (!(is.character(sort_by) && length(sort_by) == 1L &&
          sort_by %in% names(tab))) {
      stop("`sort_by` must be one column name in the output table.",
           call. = FALSE)
    }
    tab <- tab[order(tab[[sort_by]], decreasing = decreasing), , drop = FALSE]
  }
  if (!is.null(n)) {
    .idio_count(n, "n")
    tab <- utils::head(tab, n)
  }
  rownames(tab) <- NULL
  tab
}

#' @export
print.idiostats_fit <- function(x, ...) {
  cat("Idiostats Fit\n")
  cat(sprintf("  Method:      %s\n", x$spec$method))
  cat(sprintf("  Outcome:     %s (%s)\n", x$spec$y, x$spec$task))
  cat(sprintf("  Predictors:  %d (%s)\n", length(x$spec$x),
              paste(x$spec$x, collapse = ", ")))
  cat(sprintf("  ID:          %s\n", x$spec$id))
  cat(sprintf("  Scope:       %s\n", paste(x$spec$scope, collapse = " + ")))
  cat(sprintf("  Models:      %s [%s]\n",
              paste(unique(x$spec$model), collapse = ", "),
              paste(unique(x$spec$estimator), collapse = ", ")))
  if (!is.null(x$spec$groups)) {
    cat(sprintf("  Subgroups:   %d\n",
                length(unique(as.character(x$spec$groups)))))
  }
  if (!is.null(x$spec$folds)) {
    cat(sprintf("  Folds:       %d (initial = %d, assess = %d, step = %d)\n",
                x$spec$folds, x$spec$initial, x$spec$assess, x$spec$step))
  }
  cat(sprintf("  Subjects:    %d\n", length(unique(x$predictions$subject))))
  cat(sprintf("  Predictions: %d\n", nrow(x$predictions)))
  overall <- x$metrics[x$metrics$subject == ".overall", , drop = FALSE]
  if (nrow(overall) > 0L && "rmse" %in% names(overall)) {
    best <- overall[which.min(overall$rmse), , drop = FALSE]
    cat(sprintf("  Best RMSE:   %.4f (%s/%s)\n", best$rmse,
                best$scope, best$model))
  } else if (nrow(overall) > 0L && "accuracy" %in% names(overall)) {
    best <- overall[which.max(overall$accuracy), , drop = FALSE]
    cat(sprintf("  Best acc.:   %.4f (%s/%s)\n", best$accuracy,
                best$scope, best$model))
  }
  if (nrow(x$failures)) {
    cat(sprintf("  Failures:    %d (see $failures)\n", nrow(x$failures)))
  }
  cat("  Use metrics(), predictions(), coefs(), compare()\n")
  invisible(x)
}

#' Compare idiostats fits
#'
#' @param ... One or more idiostats fits.
#' @return A tidy data frame formed from each fit's overall metrics.
#' @export
compare <- function(...) {
  fits <- list(...)
  if (!length(fits)) {
    return(data.frame())
  }
  rows <- lapply(seq_along(fits), function(i) {
    fit <- fits[[i]]
    if (!inherits(fit, "idiostats_fit")) {
      stop("compare() only accepts idiostats fits.", call. = FALSE)
    }
    m <- metrics(fit)
    m <- m[m$subject == ".overall", , drop = FALSE]
    if (!nrow(m)) return(NULL)
    data.frame(fit = i, method = fit$spec$method, m, row.names = NULL)
  })
  out <- do.call(rbind, rows[!vapply(rows, is.null, logical(1))])
  rownames(out) <- NULL
  out
}
