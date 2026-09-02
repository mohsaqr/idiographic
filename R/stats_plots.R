#' Plot model metrics
#'
#' Bars for one metric, one bar per model and scope. Defaults to the `.overall`
#' rows, which is the comparison people usually want: pooled versus subgroup
#' versus individual.
#'
#' @param x An idiographic fit.
#' @param metric Metric column to plot. Defaults to `rmse` for regression and
#'   `accuracy` for classification.
#' @param model,scope Optional filters.
#' @param overall Logical. Plot the aggregate rows (default) or every subject.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day", model = c("mean", "ridge", "knn"))
#' plot_metrics(fit)
#' @export
plot_metrics <- function(x, metric = NULL, model = NULL, scope = NULL,
                         overall = TRUE, ...) {
  tab <- metrics(x, model = model, scope = scope, overall = overall)
  if (!nrow(tab)) {
    plot.new()
    title("No metrics available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in metrics(x).", call. = FALSE)
  }

  labs <- if (isTRUE(overall)) {
    paste(tab$scope, tab$model, sep = "\n")
  } else {
    paste(tab$scope, tab$model, tab$subject, sep = "\n")
  }
  op <- par(mar = c(6, 4, 3, 1))
  on.exit(par(op), add = TRUE)
  barplot(tab[[metric]], names.arg = labs, ylab = metric, las = 2,
          cex.names = 0.7, main = paste("Model", metric), ...)
  invisible(tab)
}

#' Plot feature importance
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param n Number of rows/variables to plot.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted importance table.
#' @export
plot_importance <- function(x, model = NULL, scope = NULL, subject = NULL,
                            n = 15, ...) {
  imp <- importance(x, model = model, scope = scope, subject = subject, n = n)
  if (!nrow(imp)) {
    plot.new()
    title("No feature importance available")
    return(invisible(imp))
  }
  labs <- if (length(unique(imp$model)) > 1L) {
    paste(imp$model, imp$variable, sep = ": ")
  } else {
    imp$variable
  }
  op <- par(mar = c(5, 9, 3, 1))
  on.exit(par(op), add = TRUE)
  barplot(rev(imp$importance), names.arg = rev(labs), horiz = TRUE, las = 1,
          xlab = "Importance", main = "Feature importance", ...)
  invisible(imp)
}

#' Plot model diagnostics
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param type Diagnostic plot type: `"residuals"`, `"observed"`, or
#'   `"calibration"`.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the diagnostic table.
#' @export
plot_diagnostics <- function(x, model = NULL, scope = NULL, subject = NULL,
                             type = c("residuals", "observed", "calibration"),
                             ...) {
  type <- match.arg(type)
  diag <- diagnostics(x, model = model, scope = scope, subject = subject)
  if (!nrow(diag)) {
    plot.new()
    title("No diagnostics available")
    return(invisible(diag))
  }
  if (type == "residuals" && "residual" %in% names(diag)) {
    plot(diag$predicted, diag$residual, xlab = "Predicted",
         ylab = "Residual", main = "Residuals vs predicted", pch = 19,
         col = rgb(0.1, 0.3, 0.7, 0.35), ...)
    abline(h = 0, col = "firebrick", lwd = 2)
  } else if (type == "observed" && "predicted" %in% names(diag)) {
    plot(diag$observed, diag$predicted, xlab = "Observed", ylab = "Predicted",
         main = "Observed vs predicted", pch = 19,
         col = rgb(0.1, 0.3, 0.7, 0.35), ...)
    if (is.numeric(diag$observed)) abline(0, 1, col = "firebrick", lwd = 2)
  } else if (type == "calibration" && "probability" %in% names(diag)) {
    obs <- as.integer(diag$observed == diag$predicted)
    plot(diag$probability, obs, xlab = "Predicted probability",
         ylab = "Correct", main = "Classification calibration", pch = 19,
         col = rgb(0.1, 0.3, 0.7, 0.35), ...)
    lines(stats::lowess(diag$probability, obs), col = "firebrick", lwd = 2)
  } else {
    plot.new()
    title("Diagnostic type not available for this fit")
  }
  invisible(diag)
}

#' Plot held-out prediction trajectories
#'
#' One panel per person: what actually happened, and what the model said would
#' happen, over the held-out occasions. This is the plot that shows whether a
#' model tracks a person, which a scatter of everyone pooled together hides.
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param n_subjects Maximum number of people to draw.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day", model = "ridge", scope = "individual")
#' plot_predictions(fit, n_subjects = 4)
#' @export
plot_predictions <- function(x, model = NULL, scope = NULL, subject = NULL,
                             n_subjects = 4L, ...) {
  pred <- predictions(x, model = model, scope = scope, subject = subject)
  if (!nrow(pred)) {
    plot.new()
    title("No predictions available")
    return(invisible(pred))
  }
  .idio_count(n_subjects, "n_subjects")

  who <- utils::head(unique(pred$subject), n_subjects)
  panels <- lapply(who, function(s) pred[pred$subject == s, , drop = FALSE])

  op <- par(mfrow = c(length(who), 1L), mar = c(3, 4, 2, 1))
  on.exit(par(op), add = TRUE)

  numeric_outcome <- is.numeric(pred$observed)
  invisible(lapply(seq_along(panels), function(i) {
    p <- panels[[i]][order(panels[[i]]$row), , drop = FALSE]
    obs <- if (numeric_outcome) p$observed else as.integer(factor(p$observed))
    fitted <- if (numeric_outcome) p$predicted else p$probability
    plot(seq_len(nrow(p)), obs, type = "b", pch = 19, col = "grey30",
         ylim = range(c(obs, fitted), na.rm = TRUE), xlab = "",
         ylab = if (numeric_outcome) "Outcome" else "Class / probability",
         main = paste("Subject", who[i]), ...)
    lines(seq_len(nrow(p)), fitted, col = "firebrick", lwd = 2)
    legend("topleft", c("observed", "predicted"), bty = "n", cex = 0.8,
           col = c("grey30", "firebrick"), lty = 1, lwd = c(1, 2))
  }))

  invisible(pred[pred$subject %in% who, , drop = FALSE])
}

#' Plot per-person performance
#'
#' Sorted bars, one per person, with the aggregate drawn as a reference line.
#' The people whose bars sit the wrong side of that line are the ones the model
#' is failing -- which is the question idiographic work exists to ask.
#'
#' @param x An idiographic fit.
#' @param metric Metric column. Defaults to `rmse`, or `accuracy` when the
#'   outcome is a class.
#' @param model,scope Optional filters.
#' @param n Maximum number of people to draw.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = "efficacy:monitoring", id = "name",
#'               time = "day", model = "ridge")
#' plot_subjects(fit)
#' @export
plot_subjects <- function(x, metric = NULL, model = NULL, scope = NULL,
                          n = NULL, ...) {
  tab <- metrics(x, model = model, scope = scope)
  tab <- tab[tab$subject != ".overall", , drop = FALSE]
  if (!nrow(tab)) {
    plot.new()
    title("No per-subject metrics available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in metrics(x).", call. = FALSE)
  }

  tab <- tab[order(tab[[metric]], decreasing = metric != "rmse"), ,
             drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    tab <- utils::head(tab, n)
  }

  reference <- metrics(x, model = model, scope = scope, overall = TRUE)
  op <- par(mar = c(8, 4, 3, 1))
  on.exit(par(op), add = TRUE)
  barplot(tab[[metric]], names.arg = tab$subject, las = 2, ylab = metric,
          cex.names = 0.7, main = paste("Per-subject", metric), ...)
  if (nrow(reference)) {
    abline(h = mean(reference[[metric]], na.rm = TRUE), col = "firebrick",
           lwd = 2, lty = 2)
  }
  rownames(tab) <- NULL
  invisible(tab)
}

#' Plot subgroups
#'
#' For a [find_subgroups()] result, the stability of each person, grouped by
#' subgroup, with the chance level drawn in: bars near that line are people the
#' method could not place. For a fit with subgroups, the metric per subgroup.
#'
#' @param x An [find_subgroups()] result or a fit built with subgroups.
#' @param metric Metric column, when `x` is a fit.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                     id = "name", k = 2, reps = 10)
#' plot_subgroups(g)
#' @export
plot_subgroups <- function(x, metric = NULL, ...) {
  if (inherits(x, "idiostats_groups")) {
    tab <- groups(x, sort_by = "subgroup")
    tab <- tab[order(tab$subgroup, -tab$stability), , drop = FALSE]
    op <- par(mar = c(8, 4, 3, 1))
    on.exit(par(op), add = TRUE)
    barplot(tab$stability, names.arg = tab$subject, las = 2, ylim = c(0, 1),
            ylab = "Stability", cex.names = 0.7,
            col = as.integer(factor(tab$subgroup)) + 1L,
            main = "Subgroup stability by person", ...)
    abline(h = 1 / x$spec$k, col = "firebrick", lwd = 2, lty = 2)
    legend("topright", legend = sort(unique(tab$subgroup)), bty = "n",
           cex = 0.8, fill = seq_along(unique(tab$subgroup)) + 1L)
    rownames(tab) <- NULL
    return(invisible(tab))
  }

  if (!inherits(x, "idiostats_fit")) {
    stop("plot_subgroups() needs a find_subgroups() or a fit result.",
         call. = FALSE)
  }
  tab <- metrics(x, scope = "subgroup")
  tab <- tab[tab$subject != ".overall", , drop = FALSE]
  if (!nrow(tab)) {
    plot.new()
    title("No subgroup models in this fit")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  agg <- stats::aggregate(tab[[metric]], by = list(subgroup = tab$subgroup),
                          FUN = mean, na.rm = TRUE)
  names(agg)[2L] <- metric
  op <- par(mar = c(5, 4, 3, 1))
  on.exit(par(op), add = TRUE)
  barplot(agg[[metric]], names.arg = agg$subgroup, ylab = metric,
          main = paste("Subgroup", metric), ...)
  invisible(agg)
}
