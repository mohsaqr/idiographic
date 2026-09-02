#' Prepare repeated-measures data for idiographic modelling
#'
#' Three transforms that idiographic work almost always needs, in one call.
#'
#' **Person-centering** (`center = "person"`) subtracts each person's own mean,
#' so what remains is how a person varies *around themselves*. This is the
#' transform that separates a within-person effect from a between-person one: on
#' raw scores a predictor can look strong only because high-scoring people also
#' score high on the outcome, while within any single person it does nothing.
#' Grand-centering (`center = "grand"`) subtracts one overall mean and does not
#' remove that confound.
#'
#' **Person-scaling** (`scale = "person"`) divides by each person's own standard
#' deviation, putting people on a common footing when they differ in how much
#' they fluctuate.
#'
#' **Lagging** (`lag`) adds `<var>_lag1`-style columns, shifted *within* each
#' person and in time order, so a person's yesterday never leaks into another
#' person's today. Rows with no predecessor get `NA`; the fitters drop them.
#'
#' A lag counts **occasions, not elapsed time**. When sampling is irregular
#' that is a real hazard: "the previous occasion" may be twenty minutes back
#' for one row and three days back for the next, and a lag-1 effect estimated
#' across both is not one quantity. Give `lag_max_gap` to refuse the stretched
#' ones -- a lagged value whose actual gap exceeds it becomes `NA` rather than
#' a silently incomparable number. [describe_persons()] reports `gap_median`
#' and `gap_max` so you can see whether this applies to your data before
#' choosing.
#'
#' **Detrending** (`detrend`) removes a linear time trend, so that what remains
#' is fluctuation around a person's trajectory rather than the trajectory
#' itself. Two people can both be rising steadily and appear strongly
#' correlated on every variable purely because time is passing. Following the
#' usual experience-sampling convention the trend is removed **only when it is
#' significant** (`detrend_alpha = 0.05`); set `detrend_alpha = 1` to remove it
#' unconditionally. `detrend = "person"` fits each person's own trend over
#' their own occasions -- the idiographic choice, and the default meaning of
#' detrending here -- while `"grand"` fits a single trend across everyone.
#'
#' Detrending preserves each series' **level**: the residuals have the mean
#' added back, so `detrend` removes only the slope and stays independent of
#' `center`. Series with fewer than three usable occasions are left alone.
#'
#' **Decomposing** (`decompose = TRUE`) keeps *both* halves instead of choosing
#' one: it appends `<var>_within` (the deviation from the person's own mean) and
#' `<var>_between` (that mean), leaving the original column untouched. This is
#' the input a within-between model needs -- see [fit_within_between()], which
#' does the same split internally on training rows only. Person-centering and
#' decomposition are alternatives, not companions: centering throws the between
#' half away, so asking for both at once is refused.
#'
#' @param data Data frame.
#' @param id Person/unit ID column.
#' @param time Optional ordering column. Required for `lag`.
#' @param vars Columns to transform (any [fit_lm()] selector). Defaults to every
#'   numeric column other than `id` and `time`.
#' @param center `"none"`, `"person"`, or `"grand"`.
#' @param scale `"none"`, `"person"`, or `"grand"`.
#' @param lag Integer lags to create, e.g. `lag = 1` or `lag = 1:2`.
#' @param lag_max_gap Largest elapsed time a lag may span, on the scale of
#'   `time`. A lagged value reaching further back becomes `NA`. `NULL` accepts
#'   any gap, which is only safe when occasions are evenly spaced.
#' @param decompose Append `<var>_within` and `<var>_between` columns.
#' @param detrend `"none"`, `"person"` (each person's own trend over their own
#'   occasions), or `"grand"` (one trend across everyone). Needs `time`.
#' @param detrend_alpha Only remove a trend when it is significant at this
#'   level. Set to `1` to detrend unconditionally.
#' @return The data frame, transformed in place, with any lag and decomposition
#'   columns appended.
#' @examples
#' # Within-person variation only, plus yesterday's efficacy.
#' prepped <- preprocess_panel(srl, id = "name", time = "day",
#'                       vars = "efficacy:monitoring",
#'                       center = "person", lag = 1)
#' fit_lm(prepped, y = "effort", x = c("efficacy", "efficacy_lag1"),
#'        id = "name", time = "day")
#'
#' # Keep both halves, so the two effects can be compared in one model. A
#' # between-person column is constant inside a person, so it only belongs in a
#' # pooled model -- or use fit_within_between(), which handles the split itself.
#' split <- preprocess_panel(srl, id = "name", vars = c("efficacy", "planning"),
#'                     decompose = TRUE)
#' fit_lm(split, y = "effort", x = c("efficacy_within", "efficacy_between"),
#'        id = "name", scope = "pooled")
#' @export
preprocess_panel <- function(data, id, time = NULL, vars = NULL,
                       center = c("none", "person", "grand"),
                       scale = c("none", "person", "grand"), lag = NULL,
                       decompose = FALSE, lag_max_gap = NULL,
                       detrend = c("none", "person", "grand"),
                       detrend_alpha = 0.05) {
  center <- match.arg(center)
  scale <- match.arg(scale)
  detrend <- match.arg(detrend)
  if (!(is.numeric(detrend_alpha) && length(detrend_alpha) == 1L &&
        detrend_alpha > 0 && detrend_alpha <= 1)) {
    stop("`detrend_alpha` must be a number in (0, 1].", call. = FALSE)
  }
  if (!(is.logical(decompose) && length(decompose) == 1L && !is.na(decompose))) {
    stop("`decompose` must be TRUE or FALSE.", call. = FALSE)
  }
  if (decompose && center == "person") {
    stop("`center = \"person\"` removes the between-person component, while ",
         "`decompose = TRUE` keeps it. Choose one.", call. = FALSE)
  }

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
  if (!length(vars)) stop("No columns to preprocess.", call. = FALSE)

  key <- as.character(data[[id]])

  # Detrending comes first: it removes the slope from the raw series, so that
  # any centering or scaling afterwards applies to the de-trended values.
  if (detrend != "none") {
    if (is.null(time)) {
      stop("`detrend` needs `time`, so that a trend means change over ",
           "occasions rather than over row order.", call. = FALSE)
    }
    not_numeric <- vars[!vapply(data[vars], is.numeric, logical(1))]
    if (length(not_numeric)) {
      stop("`detrend` needs numeric columns; these are not: ",
           paste(not_numeric, collapse = ", "), ".", call. = FALSE)
    }
    tt <- .idio_time_numeric(data[[time]], time)
    data[vars] <- lapply(data[vars], .idio_detrend, key = key, time = tt,
                         scope = detrend, alpha = detrend_alpha)
  }

  if (center != "none" || scale != "none") {
    data[vars] <- lapply(data[vars], .idio_rescale, key = key, center = center,
                         scale = scale)
  }

  if (decompose) {
    not_numeric <- vars[!vapply(data[vars], is.numeric, logical(1))]
    if (length(not_numeric)) {
      stop("`decompose` needs numeric columns; these are not: ",
           paste(not_numeric, collapse = ", "), ".", call. = FALSE)
    }
    parts <- .idio_decompose_cols(data[vars], key,
                                  .idio_person_means(data[vars], key))
    split_cols <- stats::setNames(
      c(as.data.frame(parts$within), as.data.frame(parts$between)),
      c(paste0(vars, "_within"), paste0(vars, "_between"))
    )
    data <- cbind(data, split_cols)
  }

  if (!is.null(lag)) {
    if (is.null(time)) {
      stop("`lag` needs `time`, so that a lag means the previous occasion ",
           "rather than the previous row.", call. = FALSE)
    }
    if (!(is.numeric(lag) && all(is.finite(lag)) && all(lag >= 1) &&
          all(lag == as.integer(lag)))) {
      stop("`lag` must be one or more whole numbers >= 1.", call. = FALSE)
    }
    if (!is.null(lag_max_gap) &&
        !(is.numeric(lag_max_gap) && length(lag_max_gap) == 1L &&
          is.finite(lag_max_gap) && lag_max_gap > 0)) {
      stop("`lag_max_gap` must be NULL or one positive number.", call. = FALSE)
    }
    clock <- .idio_time_numeric(data[[time]], time)
    ord <- order(key, clock)
    lagged <- lapply(as.integer(lag), function(k) {
      # How far back each lagged value actually reaches, so an over-stretched
      # one can be refused instead of quietly standing in for a short gap.
      reach <- .idio_lag_within(clock[ord], key[ord], k)
      spanned <- clock[ord] - reach
      too_far <- if (is.null(lag_max_gap)) {
        rep(FALSE, length(spanned))
      } else {
        !is.na(spanned) & spanned > lag_max_gap
      }
      out <- lapply(data[vars], function(v) {
        shifted <- .idio_lag_within(v[ord], key[ord], k)
        shifted[too_far] <- NA_real_
        shifted[order(ord)]
      })
      stats::setNames(as.data.frame(out, stringsAsFactors = FALSE),
                      paste0(vars, "_lag", k))
    })
    data <- do.call(cbind, c(list(data), lagged))
  }

  data
}

#' Time as a number, on the scale the occasions were actually measured on
#'
#' A trend is a slope *per unit of time*, so the spacing between occasions has
#' to survive the conversion. `as.numeric()` on a factor returns level codes,
#' which silently replaces irregular occasions (day 1, 2, 5, 40, 100) with
#' their ranks (1, 2, 3, 4, 5) and leaves part of the trend behind. On a
#' character date it returns `NA`, which turns detrending into a silent no-op.
#' Both are refused or converted properly here.
#'
#' @noRd
.idio_time_numeric <- function(v, arg = "time") {
  if (is.numeric(v)) return(as.numeric(v))
  if (inherits(v, c("Date", "POSIXct", "POSIXlt"))) return(as.numeric(v))
  chars <- as.character(v)
  numbers <- suppressWarnings(as.numeric(chars))
  if (!any(is.na(numbers) & !is.na(chars))) return(numbers)
  stop("`", arg, "` must be numeric, a Date/POSIXct, or convertible to a ",
       "number: a trend is a slope per unit of time, so the spacing between ",
       "occasions has to be known. Convert it first, e.g. with as.Date().",
       call. = FALSE)
}

#' Remove a linear time trend, within each person or across everyone
#' @noRd
.idio_detrend <- function(v, key, time, scope, alpha) {
  v <- as.numeric(v)
  if (scope == "grand") return(.idio_detrend_one(v, time, alpha))
  idx <- split(seq_along(v), key)
  parts <- lapply(idx, function(i) .idio_detrend_one(v[i], time[i], alpha))
  v[unlist(idx, use.names = FALSE)] <- unlist(parts, use.names = FALSE)
  v
}

#' Detrend one series, keeping its level
#'
#' The residuals have the mean added back, so detrending removes the slope and
#' nothing else -- `detrend` and `center` stay independent choices. A series
#' too short to support a trend, or measured at a single occasion, is returned
#' untouched rather than silently flattened.
#'
#' @noRd
.idio_detrend_one <- function(v, tt, alpha) {
  ok <- is.finite(v) & is.finite(tt)
  if (sum(ok) < 3L || stats::sd(tt[ok]) == 0) return(v)
  fit <- tryCatch(stats::lm(v ~ tt, na.action = stats::na.exclude),
                  error = function(e) NULL)
  if (is.null(fit)) return(v)
  coefs <- tryCatch(stats::coef(summary(fit)), error = function(e) NULL)
  if (is.null(coefs) || nrow(coefs) < 2L) return(v)
  p <- coefs[2L, 4L]
  if (alpha < 1 && !(is.finite(p) && p < alpha)) return(v)
  as.numeric(stats::residuals(fit)) + mean(v[ok])
}

.idio_rescale <- function(v, key, center, scale) {
  if (center == "person") {
    v <- v - stats::ave(v, key, FUN = function(z) mean(z, na.rm = TRUE))
  } else if (center == "grand") {
    v <- v - mean(v, na.rm = TRUE)
  }
  if (scale == "person") {
    s <- stats::ave(v, key, FUN = function(z) stats::sd(z, na.rm = TRUE))
    s[!is.finite(s) | s == 0] <- 1
    v <- v / s
  } else if (scale == "grand") {
    s <- stats::sd(v, na.rm = TRUE)
    if (!is.finite(s) || s == 0) s <- 1
    v <- v / s
  }
  v
}

#' Shift a vector by k occasions inside each person
#'
#' The first k rows of every person have no predecessor and become NA -- never
#' the previous person's last value.
#'
#' @noRd
.idio_lag_within <- function(v, key, k) {
  unsplit(lapply(split(v, key), function(z) {
    c(rep(NA_real_, min(k, length(z))), utils::head(z, max(0L, length(z) - k)))
  }), key)
}
