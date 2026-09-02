#' Tuning results
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A tidy tuning table.
#' @export
tuning <- function(x, model = NULL, scope = NULL, subject = NULL, n = NULL,
                   ...) {
  UseMethod("tuning")
}

#' @export
tuning.idiostats_fit <- function(x, model = NULL, scope = NULL,
                                 subject = NULL, n = NULL, ...) {
  tab <- x$tuning %||% .idio_empty_tuning()
  if (!is.null(model)) tab <- tab[tab$model %in% model, , drop = FALSE]
  if (!is.null(scope)) tab <- tab[tab$scope %in% scope, , drop = FALSE]
  if (!is.null(subject)) tab <- tab[tab$subject %in% subject, , drop = FALSE]
  if (!is.null(n)) {
    .idio_count(n, "n")
    tab <- utils::head(tab, n)
  }
  rownames(tab) <- NULL
  tab
}

.idio_empty_tuning <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(),
             parameter = character(), value = character(),
             n = integer(), rmse = numeric(), mae = numeric(),
             accuracy = numeric(), brier = numeric(), rank = integer(),
             stringsAsFactors = FALSE)
}

#' Plot tuning results
#'
#' @param x An idiographic fit.
#' @param model,scope,subject Optional filters.
#' @param metric Metric to plot. Defaults to `rmse` when present, otherwise
#'   `accuracy`.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the tuning table.
#' @export
plot_tuning <- function(x, model = NULL, scope = NULL, subject = NULL,
                        metric = NULL, ...) {
  tab <- tuning(x, model = model, scope = scope, subject = subject)
  if (!nrow(tab)) {
    .idio_plot_empty("No tuning results available")
    return(invisible(tab))
  }
  metric <- metric %||% if ("rmse" %in% names(tab) && any(is.finite(tab$rmse))) {
    "rmse"
  } else {
    "accuracy"
  }
  if (!metric %in% names(tab)) {
    stop("`metric` must be one column in tuning(x).", call. = FALSE)
  }
  panels <- interaction(tab$model, tab$scope, drop = TRUE,
                        sep = paste0(" ", "\u00b7", " "))
  panel_levels <- levels(panels)
  n_panels <- length(panel_levels)
  op <- .idio_plot_begin(
    mar = c(4.2, 4.4, 2.2, 1),
    mfrow = c(ceiling(n_panels / 2), min(2, n_panels)),
    oma = c(0, 0, 0.3, 0)
  )
  on.exit(par(op), add = TRUE)

  invisible(lapply(panel_levels, function(panel) {
    shown <- tab[panels == panel, , drop = FALSE]
    value <- suppressWarnings(as.numeric(shown$value))
    if (any(!is.finite(value))) value <- seq_len(nrow(shown))
    ord <- order(value)
    shown <- shown[ord, , drop = FALSE]
    value <- value[ord]
    best <- which.min(shown[[metric]])
    args <- .idio_plot_dots(list(
      x = value, y = shown[[metric]], type = "o", pch = 21,
      bg = .idio_colours[["blue"]], col = .idio_colours[["blue"]],
      lwd = 2, cex = 1.1, xlab = shown$parameter[[1L]],
      ylab = paste("Validation", tolower(.idio_pretty_metric(metric))),
      main = panel, cex.main = 0.92
    ), list(...))
    do.call(graphics::plot, args)
    .idio_plot_grid(x = FALSE, y = TRUE)
    graphics::lines(value, shown[[metric]], col = .idio_colours[["blue"]], lwd = 2)
    graphics::points(value, shown[[metric]], pch = 21,
                     bg = .idio_colours[["blue"]], col = "white", cex = 1.1)
    graphics::points(value[best], shown[[metric]][best], pch = 21,
                     bg = .idio_colours[["orange"]], col = "white", cex = 1.55)
    graphics::text(value[best], shown[[metric]][best], "selected",
                   pos = 3, cex = 0.72, col = .idio_colours[["orange"]])
  }))
  invisible(tab)
}
