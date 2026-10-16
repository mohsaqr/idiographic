# Plots for the descriptive results: describe_persons() and correlate_persons().

# Okabe-Ito colours cycled over categories; each category also gets its own
# point shape so the distinction never rests on colour alone.
.idio_category_colours <- c("#0072B2", "#E69F00", "#009E73", "#CC79A7",
                            "#56B4E9", "#D55E00", "#F0E442", "#000000")
.idio_category_shapes <- c(21, 24, 22, 23, 25)

#' Horizontal interval plot: one row per estimate with its confidence interval
#' @noRd
.idio_forest <- function(estimate, low, high, labels, xlab,
                         colour = .idio_colours[["blue"]], reference = 0) {
  at <- seq_along(estimate)
  limits <- range(c(low, high, reference), na.rm = TRUE)
  pad <- diff(limits) * 0.08
  if (!is.finite(pad) || pad < sqrt(.Machine$double.eps)) pad <- 0.1
  op <- .idio_plot_begin(mar = c(4.2, max(7, 0.5 * max(nchar(labels))), 1, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::plot(estimate, at, type = "n", xlim = limits + c(-pad, pad),
                 ylim = c(0.5, length(at) + 0.5), yaxt = "n",
                 xlab = xlab, ylab = "")
  .idio_plot_grid(x = TRUE, y = FALSE)
  graphics::abline(v = reference, col = .idio_colours[["muted"]], lty = 2)
  graphics::segments(low, at, high, at, col = colour, lwd = 2)
  graphics::points(estimate, at, pch = 21, bg = colour, col = "white",
                   cex = 1.3)
  graphics::axis(2, at = at, labels = labels, tick = FALSE, las = 1,
                 col.axis = .idio_colours[["ink"]])
}

#' Plot person-level spread against day-to-day change
#'
#' One point per person and variable. The horizontal axis is how widely a
#' person's values spread around their own mean (standard deviation); the
#' vertical axis is how much they change from one occasion to the next
#' (RMSSD). A point high on the vertical axis belongs to someone whose values
#' jump around; a point far right but low belongs to someone who drifts
#' slowly across a wide range. Variables are told apart by both colour and
#' point shape, and each point is labelled with the person when there are few
#' enough points to read.
#'
#' @param x A [describe_persons()] result.
#' @param stat_x,stat_y Columns of the result to put on each axis.
#' @param subject,variable Optional filters: only these people or variables.
#' @param label Label points with the person's name. `NULL` (default) labels
#'   when at most 30 points are drawn.
#' @param ... Passed to [graphics::plot()].
#' @return Invisibly, the plotted table (one row per point).
#' @examples
#' d <- describe_persons(srl, id = "name", vars = c("efficacy", "effort"),
#'                       time = "day")
#' plot_descriptives(d, subject = c("Aisha", "Alice", "Bob"))
#' @export
plot_descriptives <- function(x, stat_x = "sd", stat_y = "rmssd",
                              subject = NULL, variable = NULL, label = NULL,
                              ...) {
  if (!inherits(x, "idiostats_descriptives")) {
    stop("plot_descriptives() needs a describe_persons() result.",
         call. = FALSE)
  }
  tab <- as.data.frame(x)
  stopifnot(
    "`stat_x` must be a column of the result" = stat_x %in% names(tab),
    "`stat_y` must be a column of the result" = stat_y %in% names(tab)
  )
  if (!is.null(subject)) tab <- tab[tab$subject %in% subject, , drop = FALSE]
  if (!is.null(variable)) {
    tab <- tab[tab$variable %in% variable, , drop = FALSE]
  }
  tab <- tab[is.finite(tab[[stat_x]]) & is.finite(tab[[stat_y]]), ,
             drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("Nothing to plot")
    return(invisible(tab))
  }

  vars <- unique(tab$variable)
  slot <- ((match(tab$variable, vars) - 1L) %% length(.idio_category_shapes)) + 1L
  colour <- rep_len(.idio_category_colours, length(vars))[match(tab$variable, vars)]
  shape <- .idio_category_shapes[slot]
  label <- label %||% (nrow(tab) <= 30L)

  pad <- \(v) range(v) + c(-1, 1) * max(diff(range(v)) * 0.1, 0.01)
  op <- .idio_plot_begin(mar = c(4.2, 4.8, 1.2, 1))
  on.exit(graphics::par(op), add = TRUE)
  args <- .idio_plot_dots(list(
    x = tab[[stat_x]], y = tab[[stat_y]], type = "n",
    xlim = pad(tab[[stat_x]]) + c(0, if (label) diff(pad(tab[[stat_x]])) * 0.15 else 0),
    ylim = pad(tab[[stat_y]]),
    xlab = .idio_describe_label(stat_x), ylab = .idio_describe_label(stat_y)
  ), list(...))
  do.call(graphics::plot, args)
  .idio_plot_grid(x = TRUE, y = TRUE)
  graphics::points(tab[[stat_x]], tab[[stat_y]], pch = shape, bg = colour,
                   col = "white", cex = 1.5)
  if (label) {
    graphics::text(tab[[stat_x]], tab[[stat_y]], labels = tab$subject,
                   pos = 4, offset = 0.6, cex = 0.75,
                   col = .idio_colours[["ink"]], xpd = TRUE)
  }
  if (length(vars) > 1L) {
    graphics::legend("topleft", legend = vars, pch = unique(shape),
                     pt.bg = unique(colour), col = "white", pt.cex = 1.3,
                     bty = "n", text.col = .idio_colours[["ink"]],
                     inset = c(0, -0.06), xpd = TRUE, horiz = TRUE)
  }
  invisible(tab)
}

.idio_describe_label <- function(stat) {
  labels <- c(
    sd = "Spread around the person's mean (SD)",
    rmssd = "Change between occasions (RMSSD)",
    mean = "Person mean", median = "Person median",
    autocor = "Lag-1 autocorrelation", n = "Observations"
  )
  unname(labels[stat] %||% stat)
}

#' Plot within-person correlations with their confidence intervals
#'
#' One row per person and variable pair, showing the correlation and its 95%
#' confidence interval. Rows are sorted so the strongest positive
#' correlations are at the top. An interval that crosses the dashed zero line
#' means the data cannot tell whether the two variables move together or in
#' opposite directions for that person.
#'
#' @param x A [correlate_persons()] result.
#' @param subject Optional filter: only these people.
#' @param sort_by Column to sort rows by; `NULL` keeps the result's order.
#' @param ... Ignored.
#' @return Invisibly, the plotted table (one row per correlation).
#' @examples
#' r <- correlate_persons(srl, id = "name",
#'                        vars = c("efficacy", "effort", "monitoring"))
#' plot_correlations(r, subject = c("Aisha", "Alice"))
#' @export
plot_correlations <- function(x, subject = NULL, sort_by = "r", ...) {
  if (!inherits(x, "idiostats_correlations")) {
    stop("plot_correlations() needs a correlate_persons() result.",
         call. = FALSE)
  }
  tab <- as.data.frame(x)
  if (!is.null(subject)) tab <- tab[tab$subject %in% subject, , drop = FALSE]
  tab <- tab[is.finite(tab$r), , drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("No correlations to plot")
    return(invisible(tab))
  }
  if (!is.null(sort_by) && sort_by %in% names(tab)) {
    tab <- tab[order(tab[[sort_by]], tab$subject, tab$x, tab$y), ,
               drop = FALSE]
  }
  labels <- sprintf("%s: %s & %s", tab$subject, tab$x, tab$y)
  .idio_forest(tab$r, tab$conf_low, tab$conf_high, labels,
               xlab = "Within-person correlation (95% CI)")
  rownames(tab) <- NULL
  invisible(tab)
}

#' Plot person-specific time series
#'
#' One panel per person, showing one or more variables over time. Variables
#' are distinguished by line type as well as colour. A horizontal reference
#' marks zero, which is the person's own mean after person-centring or
#' decomposition with [preprocess_panel()].
#'
#' @param data Long-format data frame.
#' @param id Person identifier column.
#' @param time Column giving the order of occasions.
#' @param vars Variables to draw.
#' @param subject Persons to draw; defaults to the first person in `data`.
#' @param reference Horizontal reference line: `"zero"`, `"mean"` (each
#'   variable's mean for that person), or `"none"`.
#' @param ... Ignored.
#' @return Invisibly, the plotted rows (one row per person and occasion).
#' @examples
#' prepared <- preprocess_panel(srl, id = "name", time = "day",
#'                              vars = "efficacy", decompose = TRUE)
#' plot_series(prepared, id = "name", time = "day", vars = "efficacy_within",
#'             subject = "Aisha")
#' @export
plot_series <- function(data, id, time, vars, subject = NULL,
                        reference = c("zero", "mean", "none"), ...) {
  reference <- match.arg(reference)
  stopifnot(
    "`data` must be a data frame" = is.data.frame(data),
    "`id` must be one column of `data`" =
      is.character(id) && length(id) == 1L && id %in% names(data),
    "`time` must be one column of `data`" =
      is.character(time) && length(time) == 1L && time %in% names(data),
    "`vars` must be numeric columns of `data`" =
      is.character(vars) && all(vars %in% names(data)) &&
      all(vapply(data[vars], is.numeric, logical(1)))
  )
  key <- as.character(data[[id]])
  subject <- as.character(subject %||% key[1L])
  unknown <- setdiff(subject, key)
  if (length(unknown)) {
    stop("No such person in `", id, "`: ", paste(unknown, collapse = ", "),
         ".", call. = FALSE)
  }
  rows <- data[key %in% subject, c(id, time, vars), drop = FALSE]
  rows <- rows[order(as.character(rows[[id]]), rows[[time]]), , drop = FALSE]
  colours <- rep_len(.idio_category_colours, length(vars))
  line_types <- rep_len(c(1, 2, 3, 4), length(vars))

  op <- .idio_plot_begin(mar = c(3.6, 4.2, 2.2, 1))
  on.exit(graphics::par(op), add = TRUE)
  graphics::par(mfrow = c(length(subject), 1L))
  ylim <- range(unlist(rows[vars]), na.rm = TRUE)
  invisible(lapply(subject, \(person) {
    own <- rows[as.character(rows[[id]]) == person, , drop = FALSE]
    graphics::plot(NA, xlim = range(own[[time]], na.rm = TRUE), ylim = ylim,
                   xlab = "", ylab = if (length(vars) == 1L) vars else "Value",
                   main = person, font.main = 1, cex.main = 1)
    graphics::mtext(time, side = 1, line = 2.2, cex = 0.8,
                    col = .idio_colours[["ink"]])
    .idio_plot_grid(x = FALSE, y = TRUE)
    invisible(Map(\(v, colour, lty) {
      if (reference != "none") {
        level <- if (reference == "zero") 0 else mean(own[[v]], na.rm = TRUE)
        graphics::abline(h = level, col = .idio_colours[["muted"]], lty = 3)
      }
      graphics::lines(own[[time]], own[[v]], col = colour, lty = lty,
                      lwd = 1.4)
    }, vars, colours, line_types))
    if (length(vars) > 1L) {
      graphics::legend("topright", legend = vars, col = colours,
                       lty = line_types, lwd = 1.4, bty = "n", cex = 0.78,
                       horiz = TRUE, text.col = .idio_colours[["ink"]])
    }
  }))
  rownames(rows) <- NULL
  invisible(rows)
}
