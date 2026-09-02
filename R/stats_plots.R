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
    .idio_plot_empty("No metrics available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in metrics(x).", call. = FALSE)
  }

  labs <- if (isTRUE(overall)) {
    paste(vapply(tab$scope, .idio_scope_label, character(1)), tab$model,
          sep = paste0(" ", "\u00b7", " "))
  } else {
    paste(tab$subject, tab$model, sep = paste0(" ", "\u00b7", " "))
  }
  lower_better <- metric %in% c("rmse", "mae", "brier", "log_loss")
  ord <- order(tab[[metric]], decreasing = lower_better, na.last = TRUE)
  tab <- tab[ord, , drop = FALSE]
  labs <- labs[ord]
  scope_colours <- c(
    pooled = .idio_colours[["blue"]],
    subgroup = .idio_colours[["orange"]],
    individual = .idio_colours[["teal"]]
  )
  point_colours <- unname(scope_colours[tab$scope])
  point_colours[is.na(point_colours)] <- .idio_colours[["blue"]]
  at <- seq_len(nrow(tab))
  xmax <- max(c(0, tab[[metric]]), na.rm = TRUE)
  pad <- if (xmax > 0) xmax * 0.12 else 1

  op <- .idio_plot_begin(mar = c(4.2, max(7, 0.55 * max(nchar(labs))), 1, 1.3))
  on.exit(par(op), add = TRUE)
  plot_args <- .idio_plot_dots(list(
    x = tab[[metric]], y = at, xlim = c(0, xmax + pad),
    ylim = c(0.5, length(at) + 0.5), yaxt = "n", pch = 21,
    bg = point_colours, col = "white", cex = 1.45,
    xlab = .idio_pretty_metric(metric), ylab = ""
  ), list(...))
  do.call(graphics::plot, plot_args)
  .idio_plot_grid(x = TRUE, y = FALSE)
  graphics::segments(0, at, tab[[metric]], at,
                     col = .idio_colours[["pale_blue"]], lwd = 3)
  graphics::points(tab[[metric]], at, pch = plot_args$pch,
                   bg = plot_args$bg, col = plot_args$col, cex = plot_args$cex)
  graphics::axis(2, at = at, labels = labs, las = 1, tick = FALSE,
                 col.axis = .idio_colours[["ink"]])
  graphics::text(tab[[metric]] + pad * 0.12, at,
                 labels = formatC(tab[[metric]], digits = 3, format = "fg"),
                 pos = 4, cex = 0.78, col = .idio_colours[["muted"]])
  rownames(tab) <- NULL
  invisible(tab)
}

#' Plot feature importance
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param n Number of rows/variables to plot.
#' @param method Importance method. `"coefficient"` uses absolute fitted
#'   coefficients where available; `"permutation"` measures the increase in
#'   held-out prediction error after shuffling a predictor.
#' @param repeats Number of shuffles per predictor for permutation importance.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted importance table.
#' @export
plot_importance <- function(x, model = NULL, scope = NULL, subject = NULL,
                            n = 15, method = c("coefficient", "permutation"),
                            repeats = 5L, ...) {
  method <- match.arg(method)
  imp <- importance(x, model = model, scope = scope, subject = subject, n = NULL,
                    method = method, repeats = repeats)
  if (!nrow(imp)) {
    .idio_plot_empty("No feature importance available")
    return(invisible(imp))
  }
  if (is.null(subject) && length(unique(imp$subject)) > 1L) {
    imp <- stats::aggregate(
      importance ~ scope + model + estimator + subgroup + variable,
      imp, mean, na.rm = TRUE
    )
    imp$subject <- ".overall"
  }
  imp <- imp[order(-imp$importance), , drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    imp <- utils::head(imp, n)
  }
  labs <- if (length(unique(imp$model)) > 1L) {
    paste(imp$model, imp$variable, sep = ": ")
  } else {
    imp$variable
  }
  ord <- order(imp$importance, na.last = TRUE)
  imp <- imp[ord, , drop = FALSE]
  labs <- labs[ord]
  at <- seq_len(nrow(imp))
  xmax <- max(c(0, imp$importance), na.rm = TRUE)
  pad <- if (xmax > 0) xmax * 0.1 else 1
  op <- .idio_plot_begin(mar = c(4.2, max(7, 0.55 * max(nchar(labs))), 1, 1))
  on.exit(par(op), add = TRUE)
  plot_args <- .idio_plot_dots(list(
    x = imp$importance, y = at, xlim = c(0, xmax + pad),
    ylim = c(0.5, length(at) + 0.5), yaxt = "n", pch = 21,
    bg = .idio_colours[["teal"]], col = "white", cex = 1.4,
    xlab = if (method == "permutation") "Increase in prediction error" else "Importance",
    ylab = ""
  ), list(...))
  do.call(graphics::plot, plot_args)
  .idio_plot_grid(x = TRUE, y = FALSE)
  graphics::segments(0, at, imp$importance, at,
                     col = grDevices::adjustcolor(.idio_colours[["teal"]], 0.25),
                     lwd = 3)
  graphics::points(imp$importance, at, pch = plot_args$pch,
                   bg = plot_args$bg, col = plot_args$col, cex = plot_args$cex)
  graphics::axis(2, at = at, labels = labs, las = 1, tick = FALSE,
                 col.axis = .idio_colours[["ink"]])
  rownames(imp) <- NULL
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
    .idio_plot_empty("No diagnostics available")
    return(invisible(diag))
  }
  op <- .idio_plot_begin()
  on.exit(par(op), add = TRUE)
  if (type == "residuals" && "residual" %in% names(diag)) {
    args <- .idio_plot_dots(list(x = diag$predicted, y = diag$residual,
      xlab = "Predicted value", ylab = "Residual", pch = 21,
      bg = grDevices::adjustcolor(.idio_colours[["blue"]], 0.55),
      col = "white", cex = 1.05), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = TRUE, y = TRUE)
    graphics::abline(h = 0, col = .idio_colours[["orange"]], lwd = 1.8)
  } else if (type == "observed" && "predicted" %in% names(diag)) {
    args <- .idio_plot_dots(list(x = diag$observed, y = diag$predicted,
      xlab = "Observed value", ylab = "Predicted value", pch = 21,
      bg = grDevices::adjustcolor(.idio_colours[["blue"]], 0.55),
      col = "white", cex = 1.05), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = TRUE, y = TRUE)
    if (is.numeric(diag$observed)) {
      graphics::abline(0, 1, col = .idio_colours[["orange"]], lwd = 1.8)
    }
  } else if (type == "calibration" && "probability" %in% names(diag)) {
    positive <- x$y_info$positive %||% diag$predicted[which.max(diag$probability)]
    observed <- as.integer(diag$observed == positive)
    breaks <- unique(stats::quantile(diag$probability,
                                     probs = seq(0, 1, length.out = 8),
                                     na.rm = TRUE, names = FALSE))
    if (length(breaks) < 3L) breaks <- seq(0, 1, length.out = 6)
    bin <- cut(diag$probability, breaks = breaks, include.lowest = TRUE)
    calibration <- stats::aggregate(
      cbind(probability = diag$probability, observed = observed),
      by = list(bin = bin), FUN = mean, na.rm = TRUE)
    calibration <- calibration[is.finite(calibration$probability) &
                                 is.finite(calibration$observed), , drop = FALSE]
    args <- .idio_plot_dots(list(x = calibration$probability,
      y = calibration$observed, xlim = c(0, 1), ylim = c(0, 1),
      xlab = "Mean predicted probability", ylab = "Observed event proportion",
      type = "o", pch = 21, bg = .idio_colours[["blue"]], col = .idio_colours[["blue"]],
      lwd = 2, cex = 1.25), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = TRUE, y = TRUE)
    graphics::abline(0, 1, col = .idio_colours[["muted"]], lwd = 1.2, lty = 2)
  } else {
    .idio_plot_empty("Diagnostic type not available for this fit")
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
    .idio_plot_empty("No predictions available")
    return(invisible(pred))
  }
  .idio_count(n_subjects, "n_subjects")

  who <- utils::head(unique(pred$subject), n_subjects)
  panels <- lapply(who, function(s) pred[pred$subject == s, , drop = FALSE])

  op <- .idio_plot_begin(mar = c(2.7, 4.2, 2.1, 1),
                         mfrow = c(length(who), 1L), oma = c(2.2, 0, 0, 0))
  on.exit(par(op), add = TRUE)

  numeric_outcome <- is.numeric(pred$observed)
  invisible(lapply(seq_along(panels), function(i) {
    p <- panels[[i]][order(panels[[i]]$row), , drop = FALSE]
    obs <- if (numeric_outcome) p$observed else as.integer(factor(p$observed))
    fitted <- if (numeric_outcome) p$predicted else p$probability
    plot(seq_len(nrow(p)), obs, type = "o", pch = 21,
         bg = .idio_colours[["ink"]], col = .idio_colours[["ink"]],
         ylim = range(c(obs, fitted), na.rm = TRUE), xlab = "",
         ylab = if (numeric_outcome) "Outcome" else "Class / probability",
         main = who[i], cex.main = 0.95, ...)
    .idio_plot_grid(x = FALSE, y = TRUE)
    lines(seq_len(nrow(p)), fitted, col = .idio_colours[["orange"]], lwd = 2.2)
    points(seq_len(nrow(p)), obs, pch = 21, bg = .idio_colours[["ink"]],
           col = "white", cex = 0.9)
    if (i == 1L) {
      legend("topright", c("Observed", "Predicted"), bty = "n", cex = 0.8,
             col = c(.idio_colours[["ink"]], .idio_colours[["orange"]]),
             lty = 1, lwd = c(1.2, 2.2))
    }
  }))
  graphics::mtext("Held-out occasion", side = 1, outer = TRUE,
                  line = 0.6, col = .idio_colours[["ink"]], cex = 0.9)

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
    .idio_plot_empty("No per-subject metrics available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in metrics(x).", call. = FALSE)
  }

  lower_better <- metric %in% c("rmse", "mae", "brier", "log_loss")
  tab <- tab[order(tab[[metric]], decreasing = lower_better), ,
             drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    tab <- utils::head(tab, n)
  }

  reference <- metrics(x, model = model, scope = scope, overall = TRUE)
  at <- seq_len(nrow(tab))
  xmax <- max(c(tab[[metric]], reference[[metric]]), na.rm = TRUE)
  op <- .idio_plot_begin(mar = c(4.2, 7, 1, 1))
  on.exit(par(op), add = TRUE)
  args <- .idio_plot_dots(list(x = tab[[metric]], y = at,
    xlim = c(0, xmax * 1.07), ylim = c(0.5, length(at) + 0.5), yaxt = "n",
    pch = 21, bg = .idio_colours[["blue"]], col = "white", cex = 1.25,
    xlab = .idio_pretty_metric(metric), ylab = ""), list(...))
  do.call(graphics::plot, args)
  .idio_plot_grid(x = TRUE, y = FALSE)
  graphics::axis(2, at = at, labels = tab$subject, tick = FALSE, las = 1,
                 col.axis = .idio_colours[["ink"]])
  if (nrow(reference)) {
    ref <- mean(reference[[metric]], na.rm = TRUE)
    graphics::abline(v = ref, col = .idio_colours[["orange"]], lwd = 1.8, lty = 2)
    graphics::text(ref, length(at) + 0.35, "Overall", pos = 2, cex = 0.75,
                   col = .idio_colours[["orange"]], xpd = TRUE)
  }
  graphics::points(tab[[metric]], at, pch = args$pch, bg = args$bg,
                   col = args$col, cex = args$cex)
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
    levels <- sort(unique(tab$subgroup))
    colours <- rep(c("#E69F00", "#56B4E9", "#009E73", "#F0E442",
                     "#0072B2", "#D55E00", "#CC79A7", "#999999"),
                   length.out = length(levels))
    at <- seq_len(nrow(tab))
    op <- .idio_plot_begin(mar = c(4.2, 7, 1, 1))
    on.exit(par(op), add = TRUE)
    args <- .idio_plot_dots(list(x = tab$stability, y = at,
      xlim = c(0, 1), ylim = c(0.5, length(at) + 0.5), yaxt = "n",
      pch = 21, bg = colours[match(tab$subgroup, levels)], col = "white",
      cex = 1.3, xlab = "Assignment stability", ylab = ""), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = TRUE, y = FALSE)
    graphics::axis(2, at = at, labels = tab$subject, tick = FALSE, las = 1,
                   col.axis = .idio_colours[["ink"]])
    graphics::abline(v = 1 / x$spec$k, col = .idio_colours[["orange"]],
                     lwd = 1.8, lty = 2)
    graphics::points(tab$stability, at, pch = args$pch, bg = args$bg,
                     col = args$col, cex = args$cex)
    graphics::legend("bottomright", legend = paste("Subgroup", levels),
                     bty = "n", cex = 0.78, pch = 21, pt.bg = colours,
                     col = "white")
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
    .idio_plot_empty("No subgroup models in this fit")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  agg <- stats::aggregate(tab[[metric]], by = list(subgroup = tab$subgroup),
                          FUN = mean, na.rm = TRUE)
  names(agg)[2L] <- metric
  at <- seq_len(nrow(agg))
  op <- .idio_plot_begin(mar = c(4.2, 6.5, 1, 1))
  on.exit(par(op), add = TRUE)
  args <- .idio_plot_dots(list(x = agg[[metric]], y = at, yaxt = "n",
    ylim = c(0.5, length(at) + 0.5), pch = 21,
    bg = .idio_colours[["blue"]], col = "white", cex = 1.3,
    xlab = .idio_pretty_metric(metric), ylab = ""), list(...))
  do.call(graphics::plot, args)
  .idio_plot_grid(x = TRUE, y = FALSE)
  graphics::axis(2, at = at, labels = paste("Subgroup", agg$subgroup),
                 tick = FALSE, las = 1, col.axis = .idio_colours[["ink"]])
  graphics::points(agg[[metric]], at, pch = args$pch, bg = args$bg,
                   col = args$col, cex = args$cex)
  invisible(agg)
}
