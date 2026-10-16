# Within-person versus between-person correlations: the group-to-individual
# generalizability comparison of Fisher, Medaglia and Jeronimus (2018).

#' Compare within-person and between-person correlations
#'
#' Computes two distributions of correlations for every pair of variables,
#' following Fisher, Medaglia and Jeronimus (2018):
#'
#' * **within persons** (intraindividual): one correlation per person,
#'   computed across that person's occasions;
#' * **between persons** (interindividual): one correlation per occasion,
#'   computed across persons. Each person's series is ordered by `time`; the
#'   first observations of all persons form the first cross-sectional data
#'   set, the second observations form the second, and so on.
#'
#' If group-level results generalise to individuals, the two distributions
#' have similar means and similar spreads. A within-person spread that is
#' several times larger than the between-person spread indicates that the
#' group correlation describes few individuals well.
#'
#' With `lag_adjust = TRUE`, within-person correlations are computed on
#' residuals after regressing each variable on its own lag-1 value and the
#' lag-1 value of the other variable, which removes first-order temporal
#' dependence. The original authors repeated this step until the Durbin-Watson
#' test was non-significant; a single first-order adjustment is used here.
#' Between-person correlations are always computed from the observed values.
#'
#' @param data Long-format data frame.
#' @param id Person identifier column.
#' @param vars Variables to correlate (at least two).
#' @param time Optional column giving the order of occasions within persons.
#' @param lag_adjust Remove first-order temporal dependence before computing
#'   within-person correlations.
#' @param min_n Minimum number of complete pairs for a correlation to be
#'   computed, within a person or across persons at one occasion.
#' @return A data frame of class `idiographic_level_correlations`, one row per
#'   correlation, with columns `level` (`"within"` or `"between"`), `unit`
#'   (the person for `"within"`, the occasion number for `"between"`), `x`,
#'   `y`, `n` (complete pairs), and `r`. Summaries per pair are returned by
#'   [summary()] and by `as.data.frame(x, what = "summary")`.
#' @references Fisher, A. J., Medaglia, J. D., & Jeronimus, B. F. (2018). Lack
#'   of group-to-individual generalizability is a threat to human subjects
#'   research. *Proceedings of the National Academy of Sciences, 115*(27),
#'   E6106-E6115. \doi{10.1073/pnas.1711978115}
#' @examples
#' lv <- correlate_levels(srl, id = "name", vars = c("efficacy", "effort"),
#'                        time = "day")
#' summary(lv)
#' @export
correlate_levels <- function(data, id, vars, time = NULL, lag_adjust = FALSE,
                             min_n = 10L) {
  stopifnot(
    "`lag_adjust` must be TRUE or FALSE" =
      is.logical(lag_adjust) && length(lag_adjust) == 1L && !is.na(lag_adjust)
  )
  .idio_count(min_n, "min_n")
  prep <- .idio_describe_prepare(data, vars, id, time)
  if (length(prep$vars) < 2L) {
    stop("`vars` must name at least two columns to correlate.", call. = FALSE)
  }
  pairs <- utils::combn(prep$vars, 2L, simplify = FALSE)
  values <- \(v, i) as.numeric(prep$data[[v]][i])

  within <- do.call(rbind, lapply(names(prep$order), \(person) {
    i <- prep$order[[person]]
    do.call(rbind, lapply(pairs, \(p) {
      a <- values(p[1L], i)
      b <- values(p[2L], i)
      if (lag_adjust) {
        adjusted <- .idio_lag_residuals(a, b)
        a <- adjusted$a
        b <- adjusted$b
      }
      .idio_level_row("within", person, p, a, b, min_n)
    }))
  }))

  # Occasion t collects the t-th observation of every person who has one.
  occasion <- integer(nrow(prep$data))
  invisible(lapply(prep$order, \(i) occasion[i] <<- seq_along(i)))
  between <- do.call(rbind, lapply(sort(unique(occasion)), \(t) {
    i <- which(occasion == t)
    do.call(rbind, lapply(pairs, \(p) {
      .idio_level_row("between", as.character(t), p, values(p[1L], i),
                      values(p[2L], i), min_n)
    }))
  }))

  out <- rbind(within, between)
  out <- out[is.finite(out$r), , drop = FALSE]
  rownames(out) <- NULL
  structure(out, class = c("idiographic_level_correlations", "data.frame"),
            id = id, lag_adjust = lag_adjust)
}

#' One correlation row, or NULL when it cannot be computed
#' @noRd
.idio_level_row <- function(level, unit, pair, a, b, min_n) {
  keep <- is.finite(a) & is.finite(b)
  n <- sum(keep)
  r <- NA_real_
  if (n >= max(min_n, 3L) && stats::sd(a[keep]) > 0 && stats::sd(b[keep]) > 0) {
    r <- stats::cor(a[keep], b[keep])
  }
  data.frame(level = level, unit = unit, x = pair[1L], y = pair[2L],
             n = as.integer(n), r = r, stringsAsFactors = FALSE)
}

#' Residuals of a and b after first-order auto- and cross-lagged regression
#' @noRd
.idio_lag_residuals <- function(a, b) {
  n <- length(a)
  lagged <- \(v) c(NA_real_, v[-n])
  resid_of <- function(outcome, own, other) {
    frame <- data.frame(outcome = outcome, own = lagged(own),
                        other = lagged(other))
    out <- rep(NA_real_, n)
    complete <- stats::complete.cases(frame)
    if (sum(complete) < 4L) return(out)
    out[complete] <- stats::residuals(
      stats::lm(outcome ~ own + other, data = frame[complete, , drop = FALSE]))
    out
  }
  list(a = resid_of(a, a, b), b = resid_of(b, b, a))
}

#' @export
summary.idiographic_level_correlations <- function(object, ...) {
  tab <- as.data.frame.data.frame(object)
  keys <- unique(tab[c("x", "y")])
  out <- do.call(rbind, lapply(seq_len(nrow(keys)), \(k) {
    pair <- tab[tab$x == keys$x[k] & tab$y == keys$y[k], , drop = FALSE]
    w <- pair$r[pair$level == "within"]
    b <- pair$r[pair$level == "between"]
    stat <- \(v, f) if (length(v)) f(v) else NA_real_
    sd_or_na <- \(v) if (length(v) > 1L) stats::sd(v) else NA_real_
    data.frame(
      x = keys$x[k], y = keys$y[k],
      n_within = length(w), mean_within = stat(w, mean),
      median_within = stat(w, stats::median), sd_within = sd_or_na(w),
      n_between = length(b), mean_between = stat(b, mean),
      median_between = stat(b, stats::median), sd_between = sd_or_na(b),
      stringsAsFactors = FALSE
    )
  }))
  out$mean_difference <- out$mean_within - out$mean_between
  out$sd_ratio <- ifelse(out$sd_between > sqrt(.Machine$double.eps),
                         out$sd_within / out$sd_between, NA_real_)
  rownames(out) <- NULL
  out
}

#' Tidy tables from a within/between correlation comparison
#'
#' @param x A [correlate_levels()] result.
#' @param row.names,optional Ignored.
#' @param what `"correlations"` (one row per correlation) or `"summary"`
#'   (one row per pair of variables, as [summary()]).
#' @param ... Ignored.
#' @return A `data.frame`.
#' @export
as.data.frame.idiographic_level_correlations <- function(
    x, row.names = NULL, optional = FALSE,
    what = c("correlations", "summary"), ...) {
  what <- match.arg(what)
  if (what == "summary") return(summary(x))
  out <- as.data.frame.data.frame(x)
  attr(out, "id") <- NULL
  attr(out, "lag_adjust") <- NULL
  out
}

#' @export
print.idiographic_level_correlations <- function(x, ...) {
  s <- summary(x)
  cat("WITHIN- VERSUS BETWEEN-PERSON CORRELATIONS\n")
  .idio_print_info(rbind(
    c("Grouping", attr(x, "id") %||% "-"),
    c("Lag adjusted", if (isTRUE(attr(x, "lag_adjust"))) "yes (within only)"
                      else "no")
  ))
  cat("\n")
  .idio_print_block(
    cbind(s$x, s$y,
          sprintf("%d", s$n_within), .idio_num(s$mean_within, 2L),
          .idio_num(s$sd_within, 2L),
          sprintf("%d", s$n_between), .idio_num(s$mean_between, 2L),
          .idio_num(s$sd_between, 2L), .idio_num(s$sd_ratio, 2L)),
    c("x", "y", "persons", "mean", "SD", "occasions", "mean", "SD",
      "SD ratio"),
    n_left = 2L
  )
  cat("\n  within: one r per person;  between: one r per occasion\n")
  cat("  SD ratio = within SD / between SD\n")
  invisible(x)
}

#' Plot within-person against between-person correlations
#'
#' One panel per pair of variables, after Fisher, Medaglia and Jeronimus
#' (2018). Each panel shows the distribution of within-person correlations
#' (one per person) and of between-person correlations (one per occasion) as
#' kernel density curves, so that distributions based on different numbers of
#' correlations share one scale. Ticks along the baseline mark the individual
#' within-person correlations and a vertical stem marks each mean. The two
#' levels differ in line type (within solid, between dashed) as well as in
#' colour, and the key reports the standard deviation of each distribution.
#'
#' @param x A [correlate_levels()] result.
#' @param x_var,y_var Optional: plot only pairs involving these variables.
#' @param ... Ignored.
#' @return Invisibly, the summary table (one row per plotted pair).
#' @examples
#' lv <- correlate_levels(srl, id = "name", vars = c("efficacy", "effort"),
#'                        time = "day")
#' plot_levels(lv)
#' @export
plot_levels <- function(x, x_var = NULL, y_var = NULL, ...) {
  if (!inherits(x, "idiographic_level_correlations")) {
    stop("plot_levels() needs a correlate_levels() result.", call. = FALSE)
  }
  tab <- as.data.frame(x)
  if (!is.null(x_var)) tab <- tab[tab$x %in% x_var | tab$y %in% x_var, ,
                                  drop = FALSE]
  if (!is.null(y_var)) tab <- tab[tab$x %in% y_var | tab$y %in% y_var, ,
                                  drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("No correlations to plot")
    return(invisible(summary(x)[0L, , drop = FALSE]))
  }
  keys <- unique(tab[c("x", "y")])
  n_panels <- nrow(keys)
  colours <- c(within = "#D55E00", between = "#0072B2")
  labels <- c(within = "Within persons", between = "Between persons")
  line_types <- c(within = 1, between = 2)

  xlim <- c(max(-1, min(tab$r) - 0.1), min(1, max(tab$r) + 0.1))
  densities <- lapply(seq_len(n_panels), \(k) {
    pair <- tab[tab$x == keys$x[k] & tab$y == keys$y[k], , drop = FALSE]
    r <- split(pair$r, pair$level)
    lapply(r[c("within", "between")], \(v) {
      d <- stats::density(v, from = xlim[1L], to = xlim[2L], n = 256L)
      list(r = v, x = d$x, y = d$y)
    })
  })
  y_max <- max(vapply(densities, \(dd) max(dd$within$y, dd$between$y),
                      numeric(1)))

  op <- .idio_plot_begin(mar = c(3.6, 1.2, 2.4, 1.2))
  on.exit(graphics::par(op), add = TRUE)
  layout <- if (n_panels <= 3L) c(1L, n_panels) else rev(grDevices::n2mfrow(n_panels))
  graphics::par(mfrow = layout)
  sentence <- \(s) paste0(toupper(substring(s, 1, 1)), substring(s, 2))
  sd_text <- \(v) sub("^(-?)0", "\\1", sprintf("%.2f", stats::sd(v)))

  invisible(lapply(seq_len(n_panels), \(k) {
    dd <- densities[[k]]
    graphics::plot(NA, xlim = xlim, ylim = c(-0.06, 1.18) * y_max,
                   axes = FALSE, xlab = "", ylab = "",
                   main = sentence(sprintf("%s & %s", keys$x[k], keys$y[k])),
                   font.main = 1, cex.main = 1, col.main = .idio_colours[["ink"]])
    graphics::axis(1, at = pretty(xlim), col = NA,
                   col.ticks = .idio_colours[["grid"]])
    graphics::mtext("Correlation", side = 1, line = 2.3, cex = 0.8,
                    col = .idio_colours[["ink"]])
    graphics::abline(v = pretty(xlim), col = .idio_colours[["grid"]], lwd = 0.7)
    graphics::segments(xlim[1L], 0, xlim[2L], 0, col = .idio_colours[["muted"]],
                       lwd = 0.8)
    invisible(lapply(c("between", "within"), \(level) {
      d <- dd[[level]]
      graphics::polygon(c(d$x, rev(d$x)), c(d$y, rep(0, length(d$y))),
                        col = grDevices::adjustcolor(colours[[level]], 0.18),
                        border = NA)
      graphics::lines(d$x, d$y, col = colours[[level]], lwd = 1.8,
                      lty = line_types[[level]])
      m <- mean(d$r)
      graphics::segments(m, 0, m, stats::approx(d$x, d$y, m)$y,
                         col = colours[[level]], lwd = 1.4,
                         lty = line_types[[level]])
    }))
    # One tick per person below the baseline.
    graphics::segments(dd$within$r, -0.05 * y_max, dd$within$r, -0.01 * y_max,
                       col = grDevices::adjustcolor(colours[["within"]], 0.7),
                       lwd = 1)
    # Key in the empty upper-left corner; line type as well as colour
    # separates the two levels.
    graphics::legend(
      "topleft", bty = "n", cex = 0.78, seg.len = 1.6, inset = c(0, -0.02),
      legend = c(sprintf("%s  SD %s", labels[["within"]], sd_text(dd$within$r)),
                 sprintf("%s  SD %s", labels[["between"]], sd_text(dd$between$r))),
      col = colours, lty = line_types, lwd = 1.8,
      text.col = .idio_colours[["ink"]]
    )
  }))
  out <- summary(x)
  out <- out[paste(out$x, out$y) %in% paste(keys$x, keys$y), , drop = FALSE]
  rownames(out) <- NULL
  invisible(out)
}
