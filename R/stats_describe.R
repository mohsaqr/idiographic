# Person-level descriptive statistics.
#
# The layer every idiographic analysis starts from and this package was
# missing: how much data does each person have, where do they sit, how much do
# they move, and how much does each occasion carry over into the next.
#
# The distinction that matters here is between `sd` and `rmssd`. Both are
# "variability", and they are not the same thing: `sd` is how spread out a
# person's scores are overall, `rmssd` is how far they travel from one occasion
# to the next. Someone drifting slowly from 20 to 80 over a term has a large
# `sd` and a small `rmssd`; someone oscillating between 45 and 55 every day has
# the reverse. Reporting only `sd` hides that difference entirely.

#' Describe each person's series
#'
#' One row per person per variable: how much data they contributed, where they
#' sit, how much they move, and how strongly each occasion carries into the
#' next.
#'
#' \describe{
#'   \item{`n`, `missing`}{Usable and missing occasions -- the compliance
#'     question, asked per person rather than for the sample as a whole.}
#'   \item{`mean`, `sd`}{Level and overall dispersion.}
#'   \item{`rmssd`}{Root mean square successive difference: the average
#'     occasion-to-occasion *change*. This is a different quantity from `sd`,
#'     and the pair is more informative than either alone -- a slow drift gives
#'     a large `sd` with a small `rmssd`, and rapid oscillation gives the
#'     reverse.}
#'   \item{`autocor`}{Lag-1 autocorrelation, the usual measure of inertia or
#'     carry-over: how much of where a person is now is explained by where they
#'     just were.}
#'   \item{`pac`}{Probability of acute change (`detail = "full"`): how often
#'     this person's occasion-to-occasion change clears a bar set by the whole
#'     sample -- by default the 90th percentile of everyone's changes. `rmssd`
#'     says how *large* the changes are and is dominated by a few big swings;
#'     `pac` says how *often* a large one happens and is not. Jahng, Wood and
#'     Trull (2008) recommend the pair together. Being sample-relative, `pac`
#'     is not comparable across datasets unless `pac_cutoff` is supplied.}
#'   \item{`span`, `gap_median`, `gap_max`}{Only when `time` is given. How long
#'     the person was observed and how far apart their occasions were. Worth
#'     reading before trusting any lag: `gap_max` far above `gap_median` means
#'     "the previous occasion" is not a constant amount of time.}
#' }
#'
#' Successive differences and the autocorrelation are computed on **adjacent
#' occasions in time order within each person**, using only pairs where both
#' values are present. They are never taken across a person boundary.
#'
#' @param data Data frame of repeated measures.
#' @param vars Columns to describe (any [fit_lm()] selector). Defaults to every
#'   numeric column other than `id` and `time`.
#' @param id Person/unit ID column.
#' @param time Optional ordering column. Supply it: without it, "successive"
#'   means the order the rows happen to be in.
#' @param subject Optional person(s) to describe. Defaults to everyone.
#' @param detail `"basic"` (the default) or `"full"`, which adds distribution
#'   shape, floor/ceiling occupancy, the probability of acute change, the
#'   person's linear trend, and the longest run of identical consecutive values.
#' @param pac_quantile Quantile of the pooled successive changes that defines
#'   an "acute" one. The convention is 0.9.
#' @param pac_cutoff Use this change size instead of a quantile of the data.
#'   Supply it to reproduce a published cutoff, or to make `pac` comparable
#'   across datasets.
#' @param pac_direction Whether an acute change means any large change
#'   (`"absolute"`), or specifically a large rise or fall.
#' @param variable Optional variable(s) to keep.
#' @param sort_by Optional column of the result to sort by, e.g. `"rmssd"`.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows to keep.
#' @return A `data.frame` of one row per person per variable, with class
#'   `idiostats_descriptives`.
#' @examples
#' describe_persons(srl, "name", time = "day", vars = c("effort", "efficacy"))
#'
#' # One person, or the most volatile few -- without reaching into the result.
#' describe_persons(srl, "name", time = "day", subject = "Aisha")
#' describe_persons(srl, "name", time = "day", variable = "effort",
#'                  sort_by = "rmssd", decreasing = TRUE, n = 5)
#' @export
describe_persons <- function(data, id, vars = NULL, time = NULL,
                             subject = NULL, detail = c("basic", "full"),
                             pac_quantile = 0.9, pac_cutoff = NULL,
                             pac_direction = c("absolute", "increase",
                                               "decrease"),
                             variable = NULL, sort_by = NULL,
                             decreasing = FALSE, n = NULL) {
  detail <- match.arg(detail)
  pac_direction <- match.arg(pac_direction)
  if (!(is.numeric(pac_quantile) && length(pac_quantile) == 1L &&
        pac_quantile > 0 && pac_quantile < 1)) {
    stop("`pac_quantile` must be a number between 0 and 1.", call. = FALSE)
  }
  # The acute-change cutoff is a property of the SAMPLE, so it is taken from
  # every person before any `subject` filter is applied -- otherwise asking
  # about one person would silently change what "acute" means.
  cutoffs <- if (detail == "full") {
    .idio_pac_cutoffs(data, id, time, vars, pac_quantile, pac_cutoff,
                      pac_direction)
  } else {
    NULL
  }
  prep <- .idio_describe_prepare(data, vars, id, time, subject)
  rows <- lapply(prep$vars, function(v) {
    # Floor and ceiling mean the SCALE's bounds, so they are taken across
    # everyone rather than from each person's own range -- a person pinned at
    # the bottom would otherwise look like they were spanning it.
    bounds <- range(prep$data[[v]], na.rm = TRUE)
    do.call(rbind, lapply(prep$order, function(i) {
      .idio_describe_one(prep$data[[v]][i], prep$time[i],
                         prep$key[i][1L], v, detail, bounds,
                         cutoffs[[v]] %||% NA_real_, pac_direction)
    }))
  })
  out <- do.call(rbind, rows)
  out <- out[order(out$variable, out$subject), , drop = FALSE]
  if (is.null(time)) out <- out[setdiff(names(out),
                                        c("span", "gap_median", "gap_max"))]
  out <- .idio_arrange(out, variable, sort_by, decreasing, n)
  structure(out, class = c("idiostats_descriptives", "data.frame"),
            id = id, time = time)
}

#' Shared setup: resolve columns, split rows by person, order them in time
#' @noRd
.idio_describe_prepare <- function(data, vars, id, time, subject = NULL) {
  if (!(is.data.frame(data) || is.matrix(data))) {
    stop("`data` must be a data frame or matrix.", call. = FALSE)
  }
  data <- as.data.frame(data)
  if (!(is.character(id) && length(id) == 1L && id %in% names(data))) {
    stop("`id` must be one ID column name in `data`.", call. = FALSE)
  }
  if (!is.null(time) &&
      !(is.character(time) && length(time) == 1L && time %in% names(data))) {
    stop("`time` must be NULL or one column name in `data`.", call. = FALSE)
  }
  vars <- if (is.null(vars)) {
    numeric_cols <- names(data)[vapply(data, is.numeric, logical(1))]
    setdiff(numeric_cols, c(id, time))
  } else {
    .idio_resolve_x(data, vars, exclude = id, soft_exclude = time)
  }
  if (!length(vars)) stop("No columns to describe.", call. = FALSE)

  key <- as.character(data[[id]])
  if (!is.null(subject)) {
    wanted <- as.character(subject)
    missing <- setdiff(wanted, unique(key))
    if (length(missing)) {
      stop("No such person in `", id, "`: ", paste(missing, collapse = ", "),
           ".", call. = FALSE)
    }
    data <- data[key %in% wanted, , drop = FALSE]
    key <- key[key %in% wanted]
  }
  tt <- if (is.null(time)) {
    seq_len(nrow(data))
  } else {
    .idio_time_numeric(data[[time]], time)
  }
  # Row indices per person, already in time order, so every later calculation
  # can treat them as a series.
  order_by_person <- lapply(split(seq_len(nrow(data)), key), function(i) {
    i[order(tt[i])]
  })
  list(data = data, vars = vars, key = key, time = tt,
       order = order_by_person)
}

#' Can the structured print method still work on this table?
#'
#' `[.data.frame` keeps the class while dropping columns and attributes, so a
#' subsetted result arrives here looking like the real thing and is not. Rather
#' than fail on a missing column, fall back to printing it as the plain data
#' frame it has become.
#'
#' @noRd
.idio_printable <- function(tab, required) {
  nrow(tab) > 0L && all(required %in% names(tab))
}

#' Filter, sort and truncate a descriptive table
#'
#' Sorting and truncation belong in arguments, not in bracket code on the
#' caller's side -- which is the whole reason these verbs take `sort_by` and
#' `n` rather than expecting the result to be subsetted.
#'
#' @noRd
.idio_arrange <- function(tab, variable, sort_by, decreasing, n) {
  if (!is.null(variable)) {
    unknown <- setdiff(variable, unique(tab$variable))
    if (length(unknown)) {
      stop("No such variable: ", paste(unknown, collapse = ", "), ".",
           call. = FALSE)
    }
    tab <- tab[tab$variable %in% variable, , drop = FALSE]
  }
  if (!is.null(sort_by)) {
    if (!(is.character(sort_by) && length(sort_by) == 1L &&
          sort_by %in% names(tab))) {
      stop("`sort_by` must name one column of the result: ",
           paste(names(tab), collapse = ", "), ".", call. = FALSE)
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

#' The acute-change cutoff for every variable, pooled over all people
#'
#' Jahng, Wood and Trull (2008) define an acute change relative to the whole
#' sample: the 90th percentile of the successive changes of everyone on that
#' scale. So the cutoff is computed once here, from the unfiltered data, and
#' every person is then scored against the same bar.
#'
#' @noRd
.idio_pac_cutoffs <- function(data, id, time, vars, quantile, cutoff,
                              direction) {
  prep <- .idio_describe_prepare(data, vars, id, time, NULL)
  stats::setNames(lapply(prep$vars, function(v) {
    if (!is.null(cutoff)) return(as.numeric(cutoff))
    steps <- unlist(lapply(prep$order, function(i) diff(prep$data[[v]][i])),
                    use.names = FALSE)
    steps <- .idio_pac_steps(steps, direction)
    steps <- steps[is.finite(steps)]
    if (!length(steps)) return(NA_real_)
    unname(stats::quantile(steps, probs = quantile, na.rm = TRUE))
  }), prep$vars)
}

#' Successive changes on the scale the direction asks for
#' @noRd
.idio_pac_steps <- function(steps, direction) {
  switch(direction, absolute = abs(steps), increase = steps,
         decrease = -steps)
}

#' Sample skewness and excess kurtosis
#' @noRd
.idio_shape_stats <- function(v) {
  n <- length(v)
  if (n < 4L) return(c(skew = NA_real_, kurtosis = NA_real_))
  centred <- v - mean(v)
  spread <- sqrt(sum(centred^2) / n)
  if (!is.finite(spread) || spread == 0) {
    return(c(skew = NA_real_, kurtosis = NA_real_))
  }
  c(skew = sum(centred^3) / n / spread^3,
    kurtosis = sum(centred^4) / n / spread^4 - 3)
}

#' The extra columns that `detail = "full"` adds
#' @noRd
.idio_describe_full <- function(v, present, tt, bounds, pac_cutoff,
                                pac_direction) {
  usable <- v[present]
  shape <- .idio_shape_stats(usable)
  trend <- c(NA_real_, NA_real_)
  if (sum(present) >= 3L && stats::sd(tt[present]) > 0) {
    fit <- tryCatch(stats::lm(usable ~ tt[present]), error = function(e) NULL)
    # A series that is an exact linear function of time makes summary.lm warn
    # about an "essentially perfect fit". That is a real and unremarkable
    # series, not a problem, so the warning is not passed on.
    coefs <- tryCatch(suppressWarnings(stats::coef(summary(fit))),
                      error = function(e) NULL)
    if (!is.null(coefs) && nrow(coefs) >= 2L) trend <- coefs[2L, c(1L, 4L)]
  }
  runs <- if (sum(present)) max(rle(usable)$lengths) else NA_integer_

  # Probability of acute change: how often this person's successive changes
  # clear the sample-wide bar. MSSD says how BIG the changes are; this says how
  # OFTEN a large one happens, and two people with the same MSSD can differ
  # sharply on it -- one huge swing versus many merely large ones.
  steps <- .idio_pac_steps(diff(v), pac_direction)
  steps <- steps[is.finite(steps)]
  pac <- if (length(steps) && is.finite(pac_cutoff)) {
    mean(steps >= pac_cutoff)
  } else {
    NA_real_
  }

  data.frame(
    p_floor = if (sum(present)) mean(usable <= bounds[1L]) else NA_real_,
    p_ceiling = if (sum(present)) mean(usable >= bounds[2L]) else NA_real_,
    pac = pac,
    skew = unname(shape[["skew"]]), kurtosis = unname(shape[["kurtosis"]]),
    trend = unname(trend[1L]), trend_p = unname(trend[2L]),
    longest_run = as.integer(runs), stringsAsFactors = FALSE
  )
}

#' Describe one person's series of one variable
#' @noRd
.idio_describe_one <- function(v, tt, subject, name, detail = "basic",
                               bounds = c(NA_real_, NA_real_),
                               pac_cutoff = NA_real_,
                               pac_direction = "absolute") {
  v <- as.numeric(v)
  present <- !is.na(v)
  n <- sum(present)

  # Successive differences use adjacent occasions where BOTH values are
  # present; a gap contributes nothing rather than a spurious jump.
  steps <- diff(v)
  steps <- steps[is.finite(steps)]
  previous <- v[-length(v)]
  current <- v[-1L]
  pairs <- is.finite(previous) & is.finite(current)

  autocor <- NA_real_
  if (sum(pairs) >= 3L) {
    a <- previous[pairs]
    b <- current[pairs]
    if (stats::sd(a) > 0 && stats::sd(b) > 0) autocor <- stats::cor(a, b)
  }
  gaps <- diff(tt)
  gaps <- gaps[is.finite(gaps)]

  out <- data.frame(
    subject = subject, variable = name,
    n = as.integer(n), missing = as.integer(sum(!present)),
    mean = if (n) mean(v[present]) else NA_real_,
    median = if (n) stats::median(v[present]) else NA_real_,
    sd = if (n > 1L) stats::sd(v[present]) else NA_real_,
    min = if (n) min(v[present]) else NA_real_,
    max = if (n) max(v[present]) else NA_real_,
    rmssd = if (length(steps)) sqrt(mean(steps^2)) else NA_real_,
    autocor = autocor,
    span = if (length(tt) > 1L) max(tt) - min(tt) else NA_real_,
    gap_median = if (length(gaps)) stats::median(gaps) else NA_real_,
    gap_max = if (length(gaps)) max(gaps) else NA_real_,
    stringsAsFactors = FALSE
  )
  if (detail == "full") {
    out <- cbind(out, .idio_describe_full(v, present, tt, bounds, pac_cutoff,
                                          pac_direction))
  }
  out
}

#' @export
print.idiostats_descriptives <- function(x, n = 12L, ...) {
  tab <- as.data.frame(x)
  if (!.idio_printable(tab, c("subject", "variable", "n", "missing"))) {
    return(print.data.frame(tab, ...))
  }
  cat("PERSON DESCRIPTIVES\n")
  .idio_print_info(rbind(
    c("Grouping", attr(x, "id") %||% "-"),
    c("Time", attr(x, "time") %||% "(row order)"),
    c("People", format(length(unique(tab$subject)))),
    c("Variables", format(length(unique(tab$variable))))
  ))
  cat("\n")
  shown <- utils::head(tab, n)
  numeric_cols <- setdiff(names(shown)[vapply(shown, is.numeric, logical(1))],
                          c("n", "missing"))
  cells <- cbind(shown$subject, shown$variable,
                 format(shown$n), format(shown$missing),
                 do.call(cbind, lapply(shown[numeric_cols], .idio_num, 3L)))
  .idio_print_block(cells,
                    headers = c("subject", "variable", "n", "miss",
                                numeric_cols),
                    n_left = 2L)
  if (nrow(tab) > n) {
    cat(sprintf("\n  ... %d more rows.\n", nrow(tab) - n))
  }
  cat("\n  sd    = overall spread;  rmssd = occasion-to-occasion change\n")
  cat("  autocor = lag-1 carry-over (inertia)\n")
  invisible(x)
}

# ------------------------------------------------------------ correlations ----

#' Correlate variables within each person
#'
#' The most common idiographic statistic there is: for each person separately,
#' how do two variables move together *within* that person. One row per person
#' per pair.
#'
#' A correlation is unchanged by shifting a variable's location, so a
#' person-specific correlation is already a **within-person** correlation --
#' centering the data first would not change these numbers. What it is not is
#' the pooled correlation, which mixes within- and between-person covariation
#' and can carry the opposite sign.
#'
#' Confidence intervals and p-values come from the Fisher z transform, on that
#' person's own usable pairs.
#'
#' @param data Data frame of repeated measures.
#' @param vars Columns to correlate (any [fit_lm()] selector). Defaults to every
#'   numeric column other than `id` and `time`.
#' @param id Person/unit ID column.
#' @param time Optional ordering column, excluded from `vars` by default.
#' @param conf_level Confidence level for the intervals.
#' @param subject Optional person(s) to correlate. Defaults to everyone.
#' @param variable Optional variable(s); keeps pairs involving any of them.
#' @param sort_by Optional column of the result to sort by, e.g. `"r"`.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows to keep.
#' @param min_n Fewest complete pairs a person needs before a correlation is
#'   reported rather than `NA`.
#' @return A `data.frame` of one row per person per pair, with class
#'   `idiostats_correlations`.
#' @examples
#' correlate_persons(srl, "name", vars = c("effort", "efficacy", "planning"))
#'
#' # The strongest person-specific associations, sorted.
#' correlate_persons(srl, "name", vars = c("effort", "efficacy"),
#'                   sort_by = "r", decreasing = TRUE, n = 5)
#' @export
correlate_persons <- function(data, id, vars = NULL, time = NULL,
                              subject = NULL, variable = NULL, sort_by = NULL,
                              decreasing = FALSE, n = NULL,
                              conf_level = 0.95, min_n = 4L) {
  if (!(is.numeric(conf_level) && length(conf_level) == 1L &&
        conf_level > 0 && conf_level < 1)) {
    stop("`conf_level` must be a number between 0 and 1.", call. = FALSE)
  }
  .idio_count(min_n, "min_n")
  prep <- .idio_describe_prepare(data, vars, id, time, subject)
  if (length(prep$vars) < 2L) {
    stop("`vars` must name at least two columns to correlate.", call. = FALSE)
  }

  pairs <- utils::combn(prep$vars, 2L, simplify = FALSE)
  rows <- lapply(names(prep$order), function(subject) {
    i <- prep$order[[subject]]
    do.call(rbind, lapply(pairs, function(p) {
      .idio_correlate_one(prep$data[[p[1L]]][i], prep$data[[p[2L]]][i],
                          subject, p, conf_level, min_n)
    }))
  })
  out <- do.call(rbind, rows)
  if (!is.null(variable)) {
    out <- out[out$x %in% variable | out$y %in% variable, , drop = FALSE]
  }
  out <- .idio_arrange(out, NULL, sort_by, decreasing, n)
  structure(out, class = c("idiostats_correlations", "data.frame"),
            id = id, conf_level = conf_level)
}

#' One person, one pair, with a Fisher-z interval
#' @noRd
.idio_correlate_one <- function(a, b, subject, pair, conf_level, min_n) {
  a <- as.numeric(a)
  b <- as.numeric(b)
  keep <- is.finite(a) & is.finite(b)
  n <- sum(keep)
  empty <- data.frame(subject = subject, x = pair[1L], y = pair[2L],
                      n = as.integer(n), r = NA_real_, conf_low = NA_real_,
                      conf_high = NA_real_, p_value = NA_real_,
                      stringsAsFactors = FALSE)
  if (n < max(min_n, 3L)) return(empty)
  a <- a[keep]
  b <- b[keep]
  if (stats::sd(a) == 0 || stats::sd(b) == 0) return(empty)

  r <- stats::cor(a, b)
  # Fisher z: the interval is symmetric on the z scale, not the r scale, which
  # is what keeps it inside [-1, 1] near the ends.
  z <- atanh(pmin(pmax(r, -0.999999), 0.999999))
  se <- 1 / sqrt(n - 3L)
  crit <- stats::qnorm(1 - (1 - conf_level) / 2)
  stat <- r * sqrt((n - 2L) / max(1 - r^2, .Machine$double.eps))
  data.frame(
    subject = subject, x = pair[1L], y = pair[2L], n = as.integer(n),
    r = r, conf_low = tanh(z - crit * se), conf_high = tanh(z + crit * se),
    p_value = 2 * stats::pt(-abs(stat), df = n - 2L),
    stringsAsFactors = FALSE
  )
}

#' @export
print.idiostats_correlations <- function(x, n = 12L, ...) {
  tab <- as.data.frame(x)
  if (!.idio_printable(tab, c("subject", "x", "y", "n", "r"))) {
    return(print.data.frame(tab, ...))
  }
  cat("PERSON-SPECIFIC CORRELATIONS\n")
  .idio_print_info(rbind(
    c("Grouping", attr(x, "id") %||% "-"),
    c("People", format(length(unique(tab$subject)))),
    c("Pairs", format(nrow(unique(tab[c("x", "y")]))))
  ))
  cat("\n")
  shown <- utils::head(tab, n)
  .idio_print_block(
    cbind(shown$subject, shown$x, shown$y, format(shown$n),
          .idio_num(shown$r, 3L),
          sprintf("[%s, %s]", .idio_num(shown$conf_low, 2L),
                  .idio_num(shown$conf_high, 2L)),
          .idio_pval(shown$p_value)),
    headers = c("subject", "x", "y", "n", "r", "95% CI", "p"),
    n_left = 3L
  )
  if (nrow(tab) > n) cat(sprintf("\n  ... %d more rows.\n", nrow(tab) - n))
  invisible(x)
}
