# Shared visual language for statistical plots.
#
# The plotting API deliberately stays in base R so that graphics do not add a
# hard package dependency.  These helpers keep the public plotting functions
# visually consistent and leave the user's graphics parameters untouched.

.idio_colours <- c(
  ink = "#243447",
  muted = "#667085",
  grid = "#E3E8EF",
  blue = "#2A6FBB",
  orange = "#E07A3F",
  teal = "#238A7A",
  purple = "#8064A2",
  red = "#C44E52",
  pale_blue = "#DCE9F6"
)

.idio_plot_begin <- function(mar = c(4.2, 4.5, 1.2, 1.0), ...) {
  old <- graphics::par(no.readonly = TRUE)
  graphics::par(
    mar = mar, mgp = c(2.35, 0.65, 0), tcl = -0.25, las = 1,
    bty = "n", family = "sans", col.axis = .idio_colours[["muted"]],
    col.lab = .idio_colours[["ink"]], col.main = .idio_colours[["ink"]],
    cex.axis = 0.88, cex.lab = 0.95, xaxs = "r", yaxs = "r", ...
  )
  old
}

.idio_plot_grid <- function(x = FALSE, y = TRUE) {
  if (isTRUE(x)) {
    graphics::abline(v = graphics::axTicks(1), col = .idio_colours[["grid"]],
                     lwd = 0.8)
  }
  if (isTRUE(y)) {
    graphics::abline(h = graphics::axTicks(2), col = .idio_colours[["grid"]],
                     lwd = 0.8)
  }
}

.idio_plot_empty <- function(label) {
  graphics::plot.new()
  graphics::text(0.5, 0.5, label, col = .idio_colours[["muted"]], cex = 0.95)
}

.idio_plot_dots <- function(defaults, dots) {
  if (!length(dots)) return(defaults)
  named <- names(dots)
  if (is.null(named)) return(c(defaults, dots))
  for (i in seq_along(dots)) {
    if (nzchar(named[[i]])) defaults[[named[[i]]]] <- dots[[i]]
  }
  defaults
}

.idio_pretty_metric <- function(metric) {
  labels <- c(
    rmse = "Root mean square error",
    mae = "Mean absolute error",
    bias = "Mean prediction error",
    r_squared = "Test-set R-squared",
    accuracy = "Accuracy",
    brier = "Brier score",
    log_loss = "Log loss"
  )
  unname(labels[[metric]] %||% gsub("_", " ", metric, fixed = TRUE))
}

.idio_scope_label <- function(x) {
  labels <- c(pooled = "Pooled", subgroup = "Subgroup", individual = "Individual")
  unname(labels[x] %||% x)
}
