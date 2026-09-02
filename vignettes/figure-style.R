# Figure defaults shared by the statistical vignettes. The palette is
# colour-vision-deficiency safe and remains distinguishable in greyscale.
fig_col <- c(
  ink = "#243447", muted = "#667085", grid = "#E3E8EF",
  blue = "#2A6FBB", orange = "#E07A3F", teal = "#238A7A",
  purple = "#8064A2", red = "#C44E52", pale_blue = "#DCE9F6"
)

figure_begin <- function(mar = c(4.2, 4.5, 1.0, 1.0), ...) {
  graphics::par(
    mar = mar, mgp = c(2.35, 0.65, 0), tcl = -0.25, las = 1, bty = "n",
    family = "sans", col.axis = fig_col[["muted"]],
    col.lab = fig_col[["ink"]], cex.axis = 0.88, cex.lab = 0.95, ...
  )
}

figure_grid <- function(x = FALSE, y = TRUE) {
  if (x) graphics::abline(v = graphics::axTicks(1), col = fig_col[["grid"]])
  if (y) graphics::abline(h = graphics::axTicks(2), col = fig_col[["grid"]])
}

forest_plot <- function(estimate, low, high, labels,
                        xlab = "Estimate (95% CI)", colour = fig_col[["blue"]]) {
  at <- seq_along(estimate)
  limits <- range(c(low, high, 0), na.rm = TRUE)
  pad <- diff(limits) * 0.08
  if (!is.finite(pad) || pad == 0) pad <- 0.1
  figure_begin(c(4.2, max(7, 0.52 * max(nchar(labels))), 1, 1))
  plot(estimate, at, xlim = limits + c(-pad, pad),
       ylim = c(0.5, length(at) + 0.5), yaxt = "n", pch = 21,
       bg = colour, col = "white", cex = 1.3, xlab = xlab, ylab = "")
  figure_grid(x = TRUE, y = FALSE)
  abline(v = 0, col = fig_col[["orange"]], lty = 2, lwd = 1.5)
  segments(low, at, high, at, col = colour, lwd = 2)
  segments(low, at - 0.07, low, at + 0.07, col = colour)
  segments(high, at - 0.07, high, at + 0.07, col = colour)
  points(estimate, at, pch = 21, bg = colour, col = "white", cex = 1.3)
  axis(2, at = at, labels = labels, tick = FALSE, las = 1,
       col.axis = fig_col[["ink"]])
}
