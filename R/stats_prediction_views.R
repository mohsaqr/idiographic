#' Compare prediction errors on paired observations
#'
#' Compares each person's model with its pooled counterpart or with a mean
#' baseline at the same scope. Only pairs evaluated on identical observations
#' are compared. Positive gain indicates improvement over the reference.
#'
#' @param x An idiographic fit.
#' @param reference `"pooled"` or `"mean"`.
#' @param metric A metric column, such as `"rmse"` or `"accuracy"`.
#' @param model,scope,subject Optional filters for the models being compared.
#' @return A data frame with one row per paired person/model comparison,
#'   including `value`, `reference_value`, and `gain`.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = "efficacy", id = "name",
#'               time = "day", scope = "both", model = c("mean", "ridge"))
#' compare_predictions(fit, reference = "pooled", model = "ridge")
#' @export
compare_predictions <- function(x, reference = c("pooled", "mean"),
                                metric = "rmse", model = NULL,
                                scope = "individual", subject = NULL) {
  reference <- match.arg(reference)
  target <- metrics(x, model = model, scope = scope, subject = subject)
  target <- target[target$subject != ".overall", , drop = FALSE]
  if (!metric %in% c("rmse", "mae", "brier", "log_loss", "accuracy", "r_squared") ||
      !metric %in% names(target) || !is.numeric(target[[metric]])) {
    stop("`metric` must identify a numeric metric column.", call. = FALSE)
  }
  if (reference == "pooled" && any(target$scope == "pooled")) {
    stop("Choose individual or subgroup models to compare with pooled models.",
         call. = FALSE)
  }
  reference_rows <- if (reference == "pooled") {
    metrics(x, model = model, scope = "pooled", subject = subject)
  } else metrics(x, model = "mean", scope = scope, subject = subject)
  reference_rows <- reference_rows[reference_rows$subject != ".overall", , drop = FALSE]
  keys <- if (reference == "pooled") c("subject", "model", "estimator") else {
    c("subject", "scope", "subgroup")
  }
  if (anyDuplicated(reference_rows[keys])) {
    stop("Reference models must be unique for each comparison.", call. = FALSE)
  }
  ref <- reference_rows[c(keys, metric)]
  names(ref)[names(ref) == metric] <- "reference_value"
  out <- merge(target, ref, by = keys, all.x = TRUE, sort = TRUE)
  if (any(!is.finite(out$reference_value))) {
    stop("Every requested model needs a finite matching reference metric.", call. = FALSE)
  }
  pred <- predictions(x)
  check_rows <- function(i) {
    row <- out[i, , drop = FALSE]
    p <- pred[pred$subject == row$subject & pred$model == row$model &
                pred$estimator == row$estimator & pred$scope == row$scope &
                pred$subgroup == row$subgroup, , drop = FALSE]
    r <- if (reference == "pooled") {
      pred[pred$subject == row$subject & pred$model == row$model &
             pred$estimator == row$estimator & pred$scope == "pooled", , drop = FALSE]
    } else pred[pred$subject == row$subject & pred$model == "mean" &
                  pred$scope == row$scope & pred$subgroup == row$subgroup, , drop = FALSE]
    fields <- intersect(c("row", "fold", "observed"), names(pred))
    p <- p[do.call(order, p[fields]), fields, drop = FALSE]
    r <- r[do.call(order, r[fields]), fields, drop = FALSE]
    rownames(p) <- rownames(r) <- NULL
    if (!nrow(p) || !identical(p, r)) {
      stop("Models and references must use identical test observations: ",
           row$subject, " / ", row$model, ".", call. = FALSE)
    }
  }
  invisible(lapply(seq_len(nrow(out)), check_rows))
  out$metric <- metric
  out$value <- out[[metric]]
  out$reference <- reference
  lower_better <- metric %in% c("rmse", "mae", "brier", "log_loss")
  out$gain <- if (lower_better) out$reference_value - out$value else {
    out$value - out$reference_value
  }
  out <- out[c("subject", "scope", "subgroup", "model", "estimator", "n",
               "metric", "value", "reference", "reference_value", "gain")]
  rownames(out) <- NULL
  out
}

#' Summarise predictor importance across people
#'
#' Summaries use equal weight for each person. Top-feature frequency retains
#' all ties at the requested rank. Pooled and individual means are returned
#' separately rather than averaged together.
#'
#' @param x An idiographic fit or a table returned by [importance()].
#' @param by `"mean"` for mean importance or `"frequency"` for top-feature counts.
#' @param model,scope,subject Optional filters.
#' @param top_n Number of highest-ranked features for frequency summaries.
#' @param method,repeats Passed to [importance()] when `x` is a fitted object.
#' @return A data frame with one row per scope, model, estimator, subgroup and
#'   predictor. Includes `n_subjects`; frequencies also include `count` and `percent`.
#' @examples
#' fit <- fit_ml(srl, y = "effort", x = c("efficacy", "monitoring"),
#'               id = "name", model = "ridge", scope = "individual")
#' summarize_importance(fit, by = "frequency", top_n = 1)
#' @export
summarize_importance <- function(x, by = c("mean", "frequency"), model = NULL,
                                scope = NULL, subject = NULL, top_n = 5L,
                                method = c("coefficient", "permutation"),
                                repeats = 5L) {
  by <- match.arg(by)
  method <- match.arg(method)
  .idio_count(top_n, "top_n")
  tab <- .idio_importance_data(x, model, scope, subject, method, repeats)
  keys <- c("scope", "model", "estimator", "subgroup", "variable")
  empty <- tab[FALSE, keys, drop = FALSE]
  empty$n_subjects <- integer()
  if (by == "mean") empty$importance <- numeric() else {
    empty$count <- integer()
    empty$percent <- numeric()
  }
  if (!nrow(tab)) return(empty)
  if (anyDuplicated(tab[c(keys, "subject")])) {
    stop("Importance must contain one row per person, model, and predictor.", call. = FALSE)
  }
  if (by == "frequency") {
    unit <- interaction(tab[c("scope", "model", "estimator", "subgroup", "subject")],
                        drop = TRUE, lex.order = TRUE)
    tab$selected <- ave(-tab$importance, unit,
                         FUN = function(z) rank(z, ties.method = "min")) <= top_n
  }
  groups <- split(tab, interaction(tab[keys], drop = TRUE, lex.order = TRUE))
  result <- lapply(groups, function(part) {
    row <- part[1L, keys, drop = FALSE]
    row$n_subjects <- length(unique(part$subject))
    if (by == "mean") row$importance <- mean(part$importance) else {
      row$count <- sum(part$selected)
      row$percent <- 100 * row$count / row$n_subjects
    }
    row
  })
  out <- do.call(rbind, result)
  rownames(out) <- NULL
  out
}

# Private helpers keep preparation and graphic layout out of examples.
.idio_importance_data <- function(x, model = NULL, scope = NULL, subject = NULL,
                                   method = "coefficient", repeats = 5L) {
  tab <- if (is.data.frame(x)) x else {
    importance(x, model = model, scope = scope, subject = subject,
               method = method, repeats = repeats)
  }
  needed <- c("scope", "model", "estimator", "subject", "subgroup", "variable", "importance")
  if (!all(needed %in% names(tab)) || !is.numeric(tab$importance)) {
    stop("`x` must be a fit or a table returned by importance().", call. = FALSE)
  }
  if (any(!is.finite(tab$importance))) {
    stop("Importance values must be finite.", call. = FALSE)
  }
  .idio_filter_table(tab, model = model, scope = scope, subject = subject)
}

.idio_fold_metrics <- function(x) {
  pred <- predictions(x)
  if (!"fold" %in% names(pred)) {
    stop("Fold metrics require a rolling fit with a `fold` column.", call. = FALSE)
  }
  pieces <- lapply(split(pred, pred$fold), function(part) {
    tab <- if (x$spec$task == "classification") {
      .idio_classification_metrics(part, x$y_info$positive)
    } else .idio_regression_metrics(part)
    tab$fold <- part$fold[1L]
    tab
  })
  out <- do.call(rbind, pieces)
  rownames(out) <- NULL
  out
}

.idio_density_curves <- function(value, group, lower = -Inf, upper = Inf,
                                  bandwidth = NULL, xlim = NULL) {
  keep <- is.finite(value) & !is.na(group)
  value <- value[keep]
  group <- as.character(group[keep])
  if (!length(value)) stop("No finite values for density estimation.", call. = FALSE)
  if (is.finite(lower) && is.finite(upper)) {
    stop("Density reflection supports one finite boundary at a time.", call. = FALSE)
  }
  if (is.null(bandwidth)) {
    bandwidth <- if (length(value) > 1L) stats::bw.nrd0(value) else 1
  }
  if (!is.finite(bandwidth) || bandwidth <= 0) {
    stop("Density bandwidth must be positive and finite.", call. = FALSE)
  }
  limits <- c(if (is.finite(lower)) lower else min(value) - 3 * bandwidth,
              if (is.finite(upper)) upper else max(value) + 3 * bandwidth)
  if (!is.null(xlim)) limits <- xlim
  groups <- split(value, group)
  result <- lapply(names(groups), function(label) {
    z <- groups[[label]]
    reflected <- if (is.finite(lower)) c(z, 2 * lower - z) else if (
      is.finite(upper)) c(z, 2 * upper - z) else z
    curve <- stats::density(reflected, bw = bandwidth,
                            from = limits[1L], to = limits[2L], n = 512)
    if (is.finite(lower) || is.finite(upper)) curve$y <- 2 * curve$y
    data.frame(group = label, value = curve$x, density = curve$y,
               bandwidth = bandwidth)
  })
  do.call(rbind, result)
}

.idio_density_ridges <- function(value, group, xlab, colour = .idio_colours[["blue"]],
                                  lower = -Inf, upper = Inf, main = "",
                                  bandwidth = NULL, xlim = NULL, ...) {
  curves <- .idio_density_curves(value, group, lower, upper, bandwidth, xlim)
  labels <- unique(curves$group)
  at <- rev(seq_along(labels))
  peak <- max(curves$density)
  args <- .idio_plot_dots(list(x = NA, xlim = range(curves$value),
    ylim = c(0.6, length(labels) + 1), xlab = xlab, ylab = "", yaxt = "n", main = main),
    list(...))
  do.call(graphics::plot, args)
  .idio_plot_grid(x = TRUE)
  if (min(curves$value) < 0 && max(curves$value) > 0) {
    graphics::abline(v = 0, col = .idio_colours[["muted"]], lty = 2)
  }
  invisible(lapply(seq_along(labels), function(i) {
    curve <- curves[curves$group == labels[i], , drop = FALSE]
    height <- 0.8 * curve$density / peak
    graphics::polygon(c(curve$value, rev(curve$value)),
      c(at[i] + height, rep(at[i], length(height))),
      col = grDevices::adjustcolor(colour, 0.35), border = NA)
    graphics::lines(curve$value, at[i] + height, col = colour, lwd = 1.5)
    marks <- value[group == labels[i] & is.finite(value)]
    graphics::segments(marks, at[i] - 0.09, marks, at[i] + 0.03, col = colour)
  }))
  graphics::axis(2, at = at, labels = labels, tick = FALSE, las = 1)
  invisible(curves)
}

.idio_plot_metric_view <- function(x, metric, model, scope, type, ...) {
  tab <- metrics(x, model = model, scope = scope,
                 by = if (type == "time") "fold" else "person")
  tab <- tab[tab$subject != ".overall", , drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("No person-level metrics available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab)) "rmse" else "accuracy"
  if (!all(metric %in% names(tab))) stop("Unknown metric column.", call. = FALSE)
  if (type == "time") return(.idio_plot_metric_time(tab, metric, ...))
  panels <- expand.grid(metric = metric, scope = unique(tab$scope),
                        stringsAsFactors = FALSE)
  op <- .idio_plot_begin(mar = c(4.2, 5.5, 2.2, 1),
    mfrow = c(ceiling(nrow(panels) / 2), min(2, nrow(panels))))
  on.exit(graphics::par(op), add = TRUE)
  invisible(lapply(seq_len(nrow(panels)), function(i) {
    measure <- panels$metric[i]
    part <- tab[tab$scope == panels$scope[i], , drop = FALSE]
    values <- part[[measure]]
    if (!any(is.finite(values))) {
      .idio_plot_empty(paste("No finite", measure, "values"))
      return(NULL)
    }
    group <- if (length(unique(part$estimator)) > 1L) {
      paste(part$model, part$estimator, sep = " / ")
    } else part$model
    colour <- if (measure == "r_squared") .idio_colours[["teal"]] else .idio_colours[["blue"]]
    title <- paste(.idio_scope_label(panels$scope[i]), .idio_pretty_metric(measure))
    if (type == "density") {
      .idio_density_ridges(values, group, xlab = .idio_pretty_metric(measure),
        lower = if (measure %in% c("rmse", "mae", "brier", "log_loss")) 0 else -Inf,
        upper = if (measure == "r_squared") 1 else Inf,
        colour = colour, main = title, ...)
    } else {
      args <- .idio_plot_dots(list(x = split(values, group), horizontal = TRUE,
        outline = FALSE, col = "white", border = .idio_colours[["muted"]],
        ylim = range(c(0, values), na.rm = TRUE), ylab = "",
        xlab = .idio_pretty_metric(measure), main = title, las = 1), list(...))
      do.call(graphics::boxplot, args)
      if (measure == "r_squared") graphics::abline(v = 0, lty = 2, col = .idio_colours[["orange"]])
      graphics::stripchart(split(values, group), vertical = FALSE, method = "stack",
                          add = TRUE, pch = 21, bg = colour, col = "white", cex = 0.85)
    }
  }))
  invisible(tab)
}

.idio_plot_metric_time <- function(tab, metric, ...) {
  if (length(metric) != 1L) stop("Time plots require one metric.", call. = FALSE)
  subjects <- sort(unique(tab$subject))
  series <- unique(tab[c("model", "estimator", "scope")])
  models <- unique(paste(series$model, series$estimator, sep = " / "))
  colours <- rep(unname(.idio_colours[c("blue", "teal", "orange", "purple", "red", "pale_blue")]),
                 length.out = length(models))
  styles <- c(individual = 1, pooled = 2, subgroup = 3)
  op <- .idio_plot_begin(mar = c(3.5, 3.8, 2.2, 0.8),
    mfrow = c(ceiling(length(subjects) / 3), min(3, length(subjects))),
    oma = c(0, 0, 3, 0))
  on.exit(graphics::par(op), add = TRUE)
  invisible(lapply(subjects, function(subject) {
    part <- tab[tab$subject == subject, , drop = FALSE]
    args <- .idio_plot_dots(list(x = 1, type = "n", xlim = range(tab$fold),
      ylim = range(c(0, tab[[metric]]), na.rm = TRUE) * 1.05,
      xaxt = "n", xlab = "Evaluation period", ylab = .idio_pretty_metric(metric),
      main = subject), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(y = TRUE)
    graphics::axis(1, at = sort(unique(tab$fold)))
    invisible(lapply(seq_len(nrow(series)), function(i) {
      key <- series[i, , drop = FALSE]
      shown <- part[part$model == key$model & part$estimator == key$estimator &
                      part$scope == key$scope, , drop = FALSE]
      shown <- shown[order(shown$fold), , drop = FALSE]
      col <- colours[match(paste(key$model, key$estimator, sep = " / "), models)]
      graphics::lines(shown$fold, shown[[metric]], type = "o", pch = 16,
                       col = col, lty = styles[[key$scope]])
    }))
  }))
  colour_names <- rep(c("Blue", "Teal", "Orange", "Purple", "Red", "Light blue"),
                      length.out = length(models))
  labels <- paste(paste0(colour_names, ": ", models), collapse = " | ")
  graphics::mtext(paste0(labels, " | Solid: idiographic | Dashed: pooled"),
    outer = TRUE, side = 3, line = 1, cex = 0.75)
  invisible(tab)
}

.idio_plot_prediction_comparison <- function(x, metric, model, scope, n,
                                              reference, type, ...) {
  metric <- metric %||% "rmse"
  tab <- compare_predictions(x, reference = reference, metric = metric,
                             model = model, scope = scope %||% "individual")
  if (!nrow(tab)) {
    .idio_plot_empty("No paired predictions available")
    return(invisible(tab))
  }
  panel <- interaction(tab[c("model", "estimator", "scope", "subgroup")],
                       drop = TRUE, lex.order = TRUE)
  parts <- split(tab, panel)
  if (!is.null(n)) {
    .idio_count(n, "n")
    parts <- lapply(parts, utils::head, n)
    tab <- do.call(rbind, parts)
    rownames(tab) <- NULL
  }
  if (type == "density") {
    op <- .idio_plot_begin(mar = c(4.2, 6, 2.2, 1))
    on.exit(graphics::par(op), add = TRUE)
    .idio_density_ridges(tab$gain, paste(tab$model, tab$scope),
      xlab = paste("Improvement in", metric, "over", reference),
      main = "Variation in the benefit of individual models",
      colour = .idio_colours[["teal"]], ...)
    return(invisible(tab))
  }
  op <- .idio_plot_begin(mar = c(4, 4.8, 2.4, 1),
    mfrow = c(ceiling(length(parts) / 2), min(2, length(parts))))
  on.exit(graphics::par(op), add = TRUE)
  invisible(lapply(parts, function(shown) {
    shown <- shown[order(shown$subject), , drop = FALSE]
    at <- seq_len(nrow(shown))
    gain_plot <- reference == "pooled"
    values <- if (gain_plot) shown$gain else shown$value
    limits <- if (gain_plot) range(c(0, tab$gain)) * 1.1 else {
      range(c(0, tab$value, tab$reference_value)) * 1.05
    }
    args <- .idio_plot_dots(list(x = values, y = at, xlim = limits,
      ylim = c(0.5, nrow(shown) + 0.5), yaxt = "n", ylab = "", type = "n",
      xlab = if (gain_plot) paste("Improvement in", metric, "over pooled") else metric,
      main = paste(shown$model[1L], shown$scope[1L])), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = TRUE)
    if (gain_plot) {
      graphics::abline(v = 0, lty = 2, col = .idio_colours[["muted"]])
      graphics::segments(0, at, shown$gain, at, col = .idio_colours[["grid"]], lwd = 3)
      graphics::points(shown$gain, at, pch = 21, col = "white",
        bg = ifelse(shown$gain >= 0, .idio_colours[["teal"]], .idio_colours[["orange"]]))
    } else {
      graphics::segments(shown$reference_value, at, shown$value, at,
                         col = .idio_colours[["muted"]])
      graphics::points(shown$reference_value, at, pch = 1, col = .idio_colours[["muted"]])
      graphics::points(shown$value, at, pch = 21, bg = .idio_colours[["blue"]], col = "white")
    }
    graphics::axis(2, at = at, labels = shown$subject, tick = FALSE, las = 1)
  }))
  invisible(tab)
}

.idio_plot_importance_view <- function(imp, type, n, method, ...) {
  if (!nrow(imp)) {
    .idio_plot_empty("No importance available")
    return(invisible(imp))
  }
  if (!is.null(n)) .idio_count(n, "n")
  if (type == "frequency") {
    imp <- summarize_importance(imp, by = "frequency", top_n = n %||% 5L)
  } else if (type == "comparison") {
    imp <- summarize_importance(imp, by = "mean")
  }
  keys <- if (type == "comparison") c("model", "estimator") else {
    c("model", "estimator", "scope", "subgroup", if (type == "person") "subject")
  }
  parts <- split(imp, interaction(imp[keys], drop = TRUE, lex.order = TRUE))
  ncols <- min(if (type == "person") 3 else 2, length(parts))
  op <- .idio_plot_begin(mar = c(4.2, 5.5, 2.4, 1),
    mfrow = c(ceiling(length(parts) / ncols), ncols))
  on.exit(graphics::par(op), add = TRUE)
  limits <- if (type == "frequency") c(0, 105) else {
    range(c(0, imp$importance)) * 1.08
  }
  bandwidth <- if (type == "density") stats::bw.nrd0(imp$importance) else NULL
  density_limits <- if (type == "density") {
    range(imp$importance) + c(-3, 3) * bandwidth
  } else NULL
  dots <- list(...)
  if (!is.null(dots$xlim)) {
    limits <- density_limits <- dots$xlim
    dots$xlim <- NULL
  }
  label <- if (method == "permutation") "Increase in test RMSE" else "Importance"
  plotted <- lapply(parts, function(part) {
    title <- paste(part$model[1L], if (type == "person") part$subject[1L] else {
      if (type != "comparison") part$scope[1L] else ""
    })
    if (type == "density") {
      do.call(.idio_density_ridges, c(list(value = part$importance, group = part$variable,
        xlab = label, main = title, bandwidth = bandwidth, xlim = density_limits), dots))
    } else if (type == "boxplot") {
      args <- .idio_plot_dots(list(x = split(part$importance, part$variable),
        horizontal = TRUE, outline = FALSE, ylim = limits, las = 1, ylab = "",
        col = "white", border = .idio_colours[["muted"]], main = title, xlab = label), dots)
      do.call(graphics::boxplot, args)
      graphics::abline(v = 0, lty = 2, col = .idio_colours[["muted"]])
      graphics::stripchart(split(part$importance, part$variable), vertical = FALSE,
        method = "stack", add = TRUE, pch = 21, bg = .idio_colours[["teal"]],
        col = "white", cex = 0.85)
    } else if (type == "comparison") {
      .idio_importance_comparison_panel(part, limits, title, label, dots)
    } else {
      if (type == "person") {
        part <- part[order(-part$importance, part$variable), , drop = FALSE]
        if (!is.null(n)) part <- utils::head(part, n)
      }
      values <- if (type == "frequency") part$percent else part$importance
      at <- if (type == "person") rev(seq_len(nrow(part))) else seq_len(nrow(part))
      args <- .idio_plot_dots(list(x = values, y = at, xlim = limits,
        ylim = c(0.5, nrow(part) + 0.5), yaxt = "n", ylab = "", type = "n",
        xlab = if (type == "frequency") "Learners with predictor in top features (%)" else label,
        main = title), dots)
      do.call(graphics::plot, args)
      .idio_plot_grid(x = TRUE)
      graphics::abline(v = 0, col = .idio_colours[["muted"]], lty = 2)
      graphics::segments(0, at, values, at, col = .idio_colours[["blue"]], lwd = 2)
      graphics::points(values, at, pch = 21, bg = .idio_colours[["blue"]], col = "white")
      graphics::axis(2, at = at, labels = part$variable, tick = FALSE, las = 1)
    }
    part
  })
  out <- do.call(rbind, plotted)
  rownames(out) <- NULL
  invisible(out)
}

.idio_importance_comparison_panel <- function(part, limits, title, label, dots) {
  pooled <- part[part$scope == "pooled", , drop = FALSE]
  individual <- part[part$scope == "individual", , drop = FALSE]
  if (anyDuplicated(pooled$variable) || anyDuplicated(individual$variable) ||
      !nrow(pooled) || !setequal(pooled$variable, individual$variable)) {
    stop("Importance comparison requires one pooled and individual mean per predictor.",
         call. = FALSE)
  }
  paired <- merge(pooled, individual, by = "variable", suffixes = c(".pooled", ".individual"))
  at <- seq_len(nrow(paired))
  args <- .idio_plot_dots(list(x = paired$importance.individual, y = at, xlim = limits,
    ylim = c(0.5, nrow(paired) + 1.8), yaxt = "n", ylab = "", type = "n",
    xlab = paste("Mean", tolower(label)), main = title), dots)
  do.call(graphics::plot, args)
  .idio_plot_grid(x = TRUE)
  graphics::segments(paired$importance.pooled, at, paired$importance.individual, at,
                     col = .idio_colours[["muted"]])
  graphics::points(paired$importance.pooled, at, pch = 22, bg = .idio_colours[["orange"]], col = "white")
  graphics::points(paired$importance.individual, at, pch = 21, bg = .idio_colours[["teal"]], col = "white")
  graphics::axis(2, at = at, labels = paired$variable, tick = FALSE, las = 1)
  graphics::legend("topright", c("Pooled", "Idiographic mean"), pch = c(22, 21),
    pt.bg = unname(.idio_colours[c("orange", "teal")]), bty = "n", cex = 0.8)
  invisible(part)
}
