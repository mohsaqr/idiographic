# ---- Preprocessing audit for idiographic time-series models ----

#' Preprocess and audit idiographic time-series data
#'
#' @description
#' Builds the same lag-1 design used by [fit_graphical_var()] and [fit_var()],
#' optionally detrends or differences each series, and returns tidy diagnostics
#' for missingness, day-boundary drops, simple linear trends, AR(1) persistence,
#' split-half mean/variance drift, an ADF-style unit-root screen, and
#' zero-variance variables. It makes the modelling input explicit before
#' estimating VAR, graphical VAR, uSEM, GIMME, or mlVAR models; with `detrend`
#' it also cleans a non-stationary series in place so the flags can be
#' rechecked on the transformed data.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param id Character. Name of the person-ID column, or `NULL` for a single
#'   series.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param scale Logical. Whether to standardize variables before lagging.
#'   Default `TRUE`.
#' @param center_within Logical. Whether to center within person when more than
#'   one id is present. Default `TRUE`.
#' @param detrend How to remove non-stationarity from each series before
#'   lagging. Either a single string applied to every variable, or a
#'   **named character vector** giving a per-variable method (unlisted variables
#'   are left untouched, e.g. `c(planning = "difference", value = "linear")`).
#'   The available methods are:
#'   \describe{
#'     \item{`"none"`}{Default; diagnose only, transform nothing.}
#'     \item{`"auto"`}{Detrend only the subject-series that are flagged, leaving
#'       the stationary ones untouched: differencing a stochastic trend (unit
#'       root or near-unit-root persistence) and linearly detrending a
#'       deterministic trend. The "clean whoever needs it" option -- no
#'       subsetting, one call over everyone. Can be set per variable too.}
#'     \item{`"linear"`}{Replace the series with the residuals of a within-person
#'       regression on a linear time index.}
#'     \item{`"difference"`}{First-difference the series within id/day blocks.}
#'   }
#'   The diagnostics and the returned design reflect the detrended series, so
#'   the trend and unit-root flags can be rechecked after cleaning.
#' @param checks Character vector selecting which stationarity checkups to run:
#'   any of `"trend"`, `"high_ar"`, `"unit_root"`, `"mean_shift"`, `"sd_shift"`,
#'   `"zero_variance"`. Defaults to all of them. Deselecting a check turns its
#'   flag off in the report, in the `flag_stationarity_risk` roll-up, and in the
#'   `"auto"` detrend decision, so you can screen for only what you care about.
#' @param delete_missings Logical. If `TRUE`, `$pairs` contains only complete
#'   current/lagged rows; if `FALSE`, first rows of blocks and incomplete rows
#'   are retained with `NA` lags, matching `.gvar_tsdata()`. Default `TRUE`.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations.
#' @param subject Optional vector naming the subject(s) to preprocess.
#' @param trend_alpha Numeric p-value cutoff for the trend flag. Default `0.05`.
#' @param ar_threshold Numeric absolute AR(1) cutoff for the high-persistence
#'   flag. Default `0.95`.
#' @param mean_shift_threshold Numeric absolute standardized split-half mean
#'   shift cutoff. Default `0.8`.
#' @param sd_ratio_threshold Numeric split-half SD ratio cutoff. Default `2`.
#' @param unit_root_t_cutoff Numeric cutoff for the ADF-style lag-level
#'   t-statistic. Values greater than this cutoff are flagged as unit-root risk.
#'   Default `-2.86`, a common large-sample intercept-only screening cutoff.
#'
#' @return A `preprocess_result` object with:
#' \describe{
#'   \item{`pairs`}{The ordered current/lagged design table, including
#'     `intercept` and `L1_*` columns.}
#'   \item{`counts`}{Per-subject/per-day row and lag-pair counts.}
#'   \item{`diagnostics`}{Per-subject/per-variable missingness, trend, AR(1),
#'     split-half drift, unit-root screen, and stationarity risk indicators.}
#'   \item{`matrices`}{The exact `data_c` and `data_l` matrices returned by
#'     the VAR/GVAR preprocessing path.}
#' }
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, day = 1, beep = 1:40,
#'                 A = cumsum(rnorm(40)), B = rnorm(40))
#' pp <- preprocess(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep")
#' pp$counts
#' pp$diagnostics
#' # Difference the trending series and recheck the flags:
#' preprocess(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
#'            detrend = "difference")$diagnostics
#' @export
preprocess <- function(data, vars, id = NULL, day = NULL, beep = NULL,
                       scale = TRUE,
                       center_within = TRUE,
                       detrend = "none",
                       checks = c("trend", "high_ar", "unit_root",
                                  "mean_shift", "sd_shift", "zero_variance"),
                       delete_missings = TRUE,
                       min_obs = NULL,
                       subject = NULL,
                       trend_alpha = 0.05,
                       ar_threshold = 0.95,
                       mean_shift_threshold = 0.8,
                       sd_ratio_threshold = 2,
                       unit_root_t_cutoff = -2.86) {
  call <- match.call()
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(delete_missings, "delete_missings")
  checks <- match.arg(checks, c("trend", "high_ar", "unit_root", "mean_shift",
                                "sd_shift", "zero_variance"), several.ok = TRUE)
  spec <- .preprocess_detrend_spec(detrend, vars)
  stopifnot(is.numeric(trend_alpha), length(trend_alpha) == 1L,
            is.finite(trend_alpha), trend_alpha > 0, trend_alpha < 1)
  stopifnot(is.numeric(ar_threshold), length(ar_threshold) == 1L,
            is.finite(ar_threshold), ar_threshold > 0, ar_threshold <= 1)
  stopifnot(is.numeric(mean_shift_threshold),
            length(mean_shift_threshold) == 1L,
            is.finite(mean_shift_threshold), mean_shift_threshold >= 0)
  stopifnot(is.numeric(sd_ratio_threshold), length(sd_ratio_threshold) == 1L,
            is.finite(sd_ratio_threshold), sd_ratio_threshold >= 1)
  stopifnot(is.numeric(unit_root_t_cutoff), length(unit_root_t_cutoff) == 1L,
            is.finite(unit_root_t_cutoff))

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  data <- .ido_keep(data, id, min_obs, subject)
  .ido_check_numeric_vars(data, vars, check_variance = FALSE)

  diagnose <- function(p) {
    d <- .preprocess_diagnostics(p, vars, trend_alpha, ar_threshold,
                                 mean_shift_threshold, sd_ratio_threshold,
                                 unit_root_t_cutoff)
    .preprocess_apply_checks(d, checks)
  }
  lag_frame <- function(method) {
    .preprocess_lag_frame(data, vars, id, day, beep, scale, center_within,
                          method)
  }
  # A single plain method for every variable takes the fast uniform path;
  # anything with "auto" or a per-variable mix diagnoses first, then transforms
  # only the series each variable's spec calls for.
  uniform <- .preprocess_uniform_method(spec)
  if (!is.null(uniform)) {
    prep <- lag_frame(uniform)
    diagnostics <- diagnose(prep)
    applied <- uniform
  } else {
    prep <- lag_frame("none")
    diagnostics <- diagnose(prep)
    map <- .preprocess_build_map(diagnostics, spec)
    if (any(map$method != "none")) {
      prep <- lag_frame(map)
      diagnostics <- diagnose(prep)
      applied <- .preprocess_applied_label(spec)
    } else {
      applied <- "none"
    }
  }
  keep <- if (isTRUE(delete_missings)) prep$complete else rep(TRUE, prep$n)
  pairs <- .preprocess_pairs_table(prep, vars, keep)
  counts <- .preprocess_counts(prep, keep)
  matrices <- list(
    data_c = as.matrix(pairs[, vars, drop = FALSE]),
    data_l = as.matrix(pairs[, c("intercept", paste0("L1_", vars)),
                             drop = FALSE])
  )
  colnames(matrices$data_l) <- c("(Intercept)", vars)

  advice <- .preprocess_advice(diagnostics, call, applied)
  if (!is.null(advice)) message(advice)

  out <- list(
    pairs = pairs,
    counts = counts,
    diagnostics = diagnostics,
    matrices = matrices,
    advice = advice,
    n_rows = prep$n,
    n_retained = nrow(pairs),
    labels = vars,
    config = list(id = id, day = day, beep = beep, scale = scale,
                  center_within = center_within,
                  detrend = applied,
                  checks = checks,
                  delete_missings = delete_missings,
                  trend_alpha = trend_alpha,
                  ar_threshold = ar_threshold,
                  mean_shift_threshold = mean_shift_threshold,
                  sd_ratio_threshold = sd_ratio_threshold,
                  unit_root_t_cutoff = unit_root_t_cutoff)
  )
  class(out) <- "preprocess_result"
  out
}

#' Build an actionable detrend suggestion from the diagnostics. Returns `NULL`
#' when the data is already being detrended or shows no trend/unit-root risk.
#' Otherwise it recommends `"difference"` for a stochastic trend (unit root or
#' near-unit-root persistence) or `"linear"` for a deterministic linear trend,
#' and rewrites the user's own call so the message shows the exact line to run.
#' @noRd
.preprocess_advice <- function(diagnostics, call, detrend) {
  if (!identical(detrend, "none")) return(NULL)
  n_trend <- sum(diagnostics$flag_trend, na.rm = TRUE)
  n_unit  <- sum(diagnostics$flag_unit_root, na.rm = TRUE)
  n_ar    <- sum(diagnostics$flag_high_ar, na.rm = TRUE)
  n_series <- nrow(diagnostics)
  if (n_trend == 0L && n_unit == 0L && n_ar == 0L) return(NULL)

  n_flagged <- sum(diagnostics$flag_trend | diagnostics$flag_unit_root |
                     diagnostics$flag_high_ar, na.rm = TRUE)
  suggested <- call
  suggested$detrend <- "auto"
  paste0(
    sprintf("%d of %d subject-series show a trend or unit-root", n_flagged,
            n_series),
    " that can bias the temporal network. preprocess() only diagnosed this; ",
    "to clean just the series that need it, re-run with:\n  ",
    paste(deparse(suggested, width.cutoff = 500L), collapse = " ")
  )
}

#' @noRd
.preprocess_lag_frame <- function(data, vars, id, day, beep, scale,
                                  center_within, detrend = "none") {
  data <- as.data.frame(data)
  original_row <- seq_len(nrow(data))

  for (v in vars) {
    data[[v]] <- as.numeric(scale(data[[v]], center = TRUE, scale = scale))
  }

  idv <- if (is.null(id)) rep(1L, nrow(data)) else data[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(data)) else data[[day]]
  beepv <- if (is.null(beep)) seq_len(nrow(data)) else data[[beep]]

  if (isTRUE(center_within) && length(unique(idv)) > 1L) {
    for (v in vars) {
      m <- stats::ave(data[[v]], idv, FUN = function(z) mean(z, na.rm = TRUE))
      data[[v]] <- data[[v]] - m
    }
  }

  ord <- order(idv, dayv, beepv)
  data <- data[ord, , drop = FALSE]
  idv <- idv[ord]
  dayv <- dayv[ord]
  beepv <- beepv[ord]
  original_row <- original_row[ord]

  data <- .preprocess_apply_detrend(data, vars, idv, dayv, detrend)

  Y <- as.matrix(data[, vars, drop = FALSE])
  blk <- paste(idv, dayv, sep = "\r")
  same <- c(FALSE, blk[-1L] == blk[-length(blk)])
  lag <- matrix(NA_real_, nrow(Y), ncol(Y))
  lag[same, ] <- Y[which(same) - 1L, , drop = FALSE]
  colnames(lag) <- paste0("L1_", vars)

  complete <- !(rowSums(is.na(Y)) > 0 | rowSums(is.na(lag)) > 0)
  list(data = data, Y = Y, lag = lag, complete = complete, same = same,
       id_value = idv, day_value = dayv, beep_value = beepv,
       original_row = original_row, n = nrow(data))
}

#' Normalize the `detrend` argument to a per-variable named character vector
#' over `vars`, each entry one of `"none"`, `"auto"`, `"linear"`,
#' `"difference"`. A single unnamed string is recycled to every variable; a
#' named vector sets the listed variables and leaves the rest at `"none"`.
#' @noRd
.preprocess_detrend_spec <- function(detrend, vars) {
  allowed <- c("none", "auto", "linear", "difference")
  if (!is.character(detrend) || length(detrend) == 0L) {
    stop("`detrend` must be a character value or a named character vector.",
         call. = FALSE)
  }
  if (is.null(names(detrend))) {
    if (length(detrend) != 1L) {
      stop("An unnamed `detrend` must be a single value; name the entries to ",
           "set per-variable methods.", call. = FALSE)
    }
    method <- match.arg(detrend, allowed)
    return(stats::setNames(rep(method, length(vars)), vars))
  }
  bad_names <- setdiff(names(detrend), vars)
  if (length(bad_names)) {
    stop("`detrend` names must be variables in `vars`; unknown: ",
         paste(bad_names, collapse = ", "), call. = FALSE)
  }
  bad_vals <- setdiff(detrend, allowed)
  if (length(bad_vals)) {
    stop("`detrend` values must be one of ", paste(allowed, collapse = ", "),
         "; got: ", paste(bad_vals, collapse = ", "), call. = FALSE)
  }
  spec <- stats::setNames(rep("none", length(vars)), vars)
  spec[names(detrend)] <- detrend
  spec
}

#' If every variable shares the same plain (non-`"auto"`) method, return that
#' single method so the caller can take the fast uniform path; otherwise `NULL`.
#' @noRd
.preprocess_uniform_method <- function(spec) {
  u <- unique(spec)
  if (length(u) == 1L && u %in% c("none", "linear", "difference")) u else NULL
}

#' Short label describing an applied per-variable spec, for printing.
#' @noRd
.preprocess_applied_label <- function(spec) {
  u <- unique(spec[spec != "none"])
  if (length(u) == 1L && identical(u, "auto")) "auto" else "custom"
}

#' Per subject-series detrend decision from a per-variable `spec`. For a
#' variable set to `"auto"` it picks `"difference"` for a stochastic trend
#' (unit root or near-unit-root persistence), `"linear"` for a deterministic
#' trend, and `"none"` otherwise; any other method is applied as given. Returns
#' a `data.frame(subject, variable, method)`.
#' @noRd
.preprocess_build_map <- function(diagnostics, spec) {
  method <- vapply(seq_len(nrow(diagnostics)), function(i) {
    s <- spec[[diagnostics$variable[i]]]
    if (!identical(s, "auto")) return(s)
    if (isTRUE(diagnostics$flag_unit_root[i]) ||
          isTRUE(diagnostics$flag_high_ar[i])) {
      "difference"
    } else if (isTRUE(diagnostics$flag_trend[i])) {
      "linear"
    } else {
      "none"
    }
  }, character(1))
  data.frame(subject = as.character(diagnostics$subject),
             variable = diagnostics$variable, method = method,
             stringsAsFactors = FALSE)
}

#' Back-compat helper: the all-`"auto"` map.
#' @noRd
.preprocess_auto_map <- function(diagnostics) {
  vars <- unique(diagnostics$variable)
  .preprocess_build_map(diagnostics,
                        stats::setNames(rep("auto", length(vars)), vars))
}

#' Deactivate the flags not in `checks` (set them `FALSE`) and recompute the
#' `flag_stationarity_risk` roll-up from the selected checks only, so both the
#' report and the `"auto"` decision honour the requested checkups.
#' @noRd
.preprocess_apply_checks <- function(diagnostics, checks) {
  all_checks <- c("trend", "high_ar", "unit_root", "mean_shift", "sd_shift",
                  "zero_variance")
  for (chk in setdiff(all_checks, checks)) {
    diagnostics[[paste0("flag_", chk)]] <- FALSE
  }
  sel <- lapply(checks, function(chk) diagnostics[[paste0("flag_", chk)]])
  diagnostics$flag_stationarity_risk <- if (length(sel)) {
    Reduce(`|`, sel)
  } else {
    rep(FALSE, nrow(diagnostics))
  }
  diagnostics
}

#' Detrend each series before lagging. Operates on time-ordered data. `method`
#' is either a single string applied to every series (`"none"` no-op,
#' `"linear"` per person, `"difference"` per id/day block) or a per-series
#' `data.frame(subject, variable, method)` from the internal auto-map helper.
#' Returns the frame with the `vars` columns replaced.
#' @noRd
.preprocess_apply_detrend <- function(data, vars, idv, dayv, method) {
  if (is.data.frame(method)) {
    return(.preprocess_apply_detrend_map(data, vars, idv, dayv, method))
  }
  if (identical(method, "none")) return(data)
  block <- if (identical(method, "difference")) {
    paste(idv, dayv, sep = "\r")
  } else {
    as.character(idv)
  }
  fun <- if (identical(method, "linear")) {
    .preprocess_detrend_linear
  } else {
    .preprocess_detrend_difference
  }
  data[vars] <- lapply(vars, function(v) stats::ave(data[[v]], block, FUN = fun))
  data
}

#' Apply a per subject-series detrend map: linear detrend is per person,
#' difference is within that person's day blocks, and `"none"` series are left
#' untouched. Data must already be time-ordered.
#' @noRd
.preprocess_apply_detrend_map <- function(data, vars, idv, dayv, map) {
  subs <- as.character(idv)
  for (v in vars) {
    mv <- map[map$variable == v, , drop = FALSE]
    method_by_sub <- stats::setNames(mv$method, as.character(mv$subject))
    z <- data[[v]]
    for (s in unique(subs)) {
      m <- method_by_sub[[s]]
      if (is.null(m) || identical(m, "none")) next
      sel <- subs == s
      z[sel] <- if (identical(m, "linear")) {
        .preprocess_detrend_linear(z[sel])
      } else {
        stats::ave(z[sel], dayv[sel], FUN = .preprocess_detrend_difference)
      }
    }
    data[[v]] <- z
  }
  data
}

#' Residuals of a within-block regression on a linear time index. Preserves
#' length and NA positions; a flat or too-short block is returned unchanged.
#' @noRd
.preprocess_detrend_linear <- function(z) {
  ok <- is.finite(z)
  if (sum(ok) < 3L || stats::sd(z[ok]) == 0) return(z)
  tt <- seq_along(z)
  fit <- stats::lm.fit(cbind(1, tt[ok]), z[ok])
  out <- z
  out[ok] <- z[ok] - as.numeric(cbind(1, tt[ok]) %*% fit$coefficients)
  out
}

#' First difference within a block; the block-initial observation becomes `NA`
#' and is dropped by the same completeness rule as the lag.
#' @noRd
.preprocess_detrend_difference <- function(z) {
  c(NA_real_, diff(z))
}

#' @noRd
.preprocess_pairs_table <- function(prep, vars, keep) {
  out <- data.frame(
    original_row = prep$original_row[keep],
    subject = as.character(prep$id_value[keep]),
    day = as.character(prep$day_value[keep]),
    beep = prep$beep_value[keep],
    stringsAsFactors = FALSE
  )
  out <- cbind(out,
               as.data.frame(prep$Y[keep, , drop = FALSE]),
               data.frame(intercept = rep(1, sum(keep))),
               as.data.frame(prep$lag[keep, , drop = FALSE]))
  names(out)[match(vars, names(out))] <- vars
  rownames(out) <- NULL
  out
}

#' @noRd
.preprocess_counts <- function(prep, keep) {
  key <- paste(prep$id_value, prep$day_value, sep = "\r")
  split_idx <- split(seq_len(prep$n), key)
  rows <- lapply(split_idx, function(idx) {
    data.frame(
      subject = as.character(prep$id_value[idx[1L]]),
      day = as.character(prep$day_value[idx[1L]]),
      n_rows = length(idx),
      n_lag_possible = sum(prep$same[idx]),
      n_complete_pairs = sum(prep$complete[idx]),
      n_retained = sum(keep[idx]),
      n_boundary_dropped = sum(!prep$same[idx]),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @noRd
.preprocess_diagnostics <- function(prep, vars, trend_alpha, ar_threshold,
                                    mean_shift_threshold, sd_ratio_threshold,
                                    unit_root_t_cutoff) {
  ids <- unique(prep$id_value)
  rows <- list()
  pos <- 0L
  for (sid in ids) {
    idx <- which(prep$id_value == sid)
    time_idx <- seq_along(idx)
    for (j in seq_along(vars)) {
      y <- prep$Y[idx, j]
      lag <- prep$lag[idx, j]
      trend <- .preprocess_lm_slope(y, time_idx)
      ar <- .preprocess_lm_slope(y, lag)
      drift <- .preprocess_split_drift(y)
      unit_root <- .preprocess_unit_root_screen(y)
      s <- stats::sd(y, na.rm = TRUE)
      flag_zero <- !is.finite(s) || s == 0
      flag_trend <- is.finite(trend$p) && trend$p < trend_alpha
      flag_high_ar <- is.finite(ar$slope) && abs(ar$slope) >= ar_threshold
      flag_mean_shift <- is.finite(drift$mean_shift_std) &&
        drift$mean_shift_std >= mean_shift_threshold
      flag_sd_shift <- is.finite(drift$sd_ratio) &&
        drift$sd_ratio >= sd_ratio_threshold
      flag_unit_root <- is.finite(unit_root$t) &&
        unit_root$t > unit_root_t_cutoff
      pos <- pos + 1L
      rows[[pos]] <- data.frame(
        subject = as.character(sid),
        variable = vars[j],
        n = length(y),
        n_observed = sum(!is.na(y)),
        missing_prop = mean(is.na(y)),
        mean = mean(y, na.rm = TRUE),
        sd = s,
        trend_slope = trend$slope,
        trend_t = trend$t,
        trend_p = trend$p,
        ar1 = ar$slope,
        ar1_t = ar$t,
        ar1_p = ar$p,
        mean_first_half = drift$mean_first,
        mean_second_half = drift$mean_second,
        mean_shift = drift$mean_shift,
        mean_shift_std = drift$mean_shift_std,
        mean_shift_p = drift$mean_shift_p,
        sd_first_half = drift$sd_first,
        sd_second_half = drift$sd_second,
        sd_ratio = drift$sd_ratio,
        unit_root_coef = unit_root$coef,
        unit_root_t = unit_root$t,
        flag_zero_variance = flag_zero,
        flag_trend = flag_trend,
        flag_high_ar = flag_high_ar,
        flag_mean_shift = flag_mean_shift,
        flag_sd_shift = flag_sd_shift,
        flag_unit_root = flag_unit_root,
        flag_stationarity_risk = flag_trend || flag_high_ar ||
          flag_mean_shift || flag_sd_shift || flag_unit_root,
        stringsAsFactors = FALSE
      )
    }
  }
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

#' @noRd
.preprocess_split_drift <- function(y) {
  y <- y[is.finite(y)]
  if (length(y) < 6L || stats::sd(y) == 0) {
    return(list(mean_first = NA_real_, mean_second = NA_real_,
                mean_shift = NA_real_, mean_shift_std = NA_real_,
                mean_shift_p = NA_real_, sd_first = NA_real_,
                sd_second = NA_real_, sd_ratio = NA_real_))
  }
  cut <- floor(length(y) / 2)
  y1 <- y[seq_len(cut)]
  y2 <- y[seq.int(cut + 1L, length(y))]
  m1 <- mean(y1)
  m2 <- mean(y2)
  s1 <- stats::sd(y1)
  s2 <- stats::sd(y2)
  se <- sqrt(stats::var(y1) / length(y1) + stats::var(y2) / length(y2))
  tval <- if (is.finite(se) && se > 0) (m2 - m1) / se else NA_real_
  df <- .preprocess_welch_df(y1, y2)
  p <- if (is.finite(tval) && is.finite(df) && df > 0) {
    2 * stats::pt(abs(tval), df = df, lower.tail = FALSE)
  } else {
    NA_real_
  }
  sd_ratio <- if (all(is.finite(c(s1, s2))) && min(s1, s2) > 0) {
    max(s1, s2) / min(s1, s2)
  } else {
    NA_real_
  }
  list(mean_first = m1, mean_second = m2,
       mean_shift = m2 - m1,
       mean_shift_std = abs(m2 - m1) / stats::sd(y),
       mean_shift_p = p,
       sd_first = s1, sd_second = s2, sd_ratio = sd_ratio)
}

#' @noRd
.preprocess_welch_df <- function(y1, y2) {
  v1 <- stats::var(y1) / length(y1)
  v2 <- stats::var(y2) / length(y2)
  den <- v1^2 / (length(y1) - 1L) + v2^2 / (length(y2) - 1L)
  if (!is.finite(den) || den <= 0) return(NA_real_)
  (v1 + v2)^2 / den
}

#' @noRd
.preprocess_unit_root_screen <- function(y) {
  y <- y[is.finite(y)]
  if (length(y) < 8L || stats::sd(y) == 0) {
    return(list(coef = NA_real_, t = NA_real_))
  }
  dy <- diff(y)
  lag <- y[-length(y)]
  fit <- .preprocess_lm_slope(dy, lag)
  list(coef = fit$slope, t = fit$t)
}

#' @noRd
.preprocess_lm_slope <- function(y, x) {
  ok <- is.finite(y) & is.finite(x)
  if (sum(ok) < 3L || stats::sd(x[ok]) == 0 || stats::sd(y[ok]) == 0) {
    return(list(slope = NA_real_, t = NA_real_, p = NA_real_))
  }
  X <- cbind(1, x[ok])
  fit <- stats::lm.fit(X, y[ok])
  df <- length(y[ok]) - fit$rank
  if (df <= 0L) return(list(slope = fit$coefficients[2L],
                            t = NA_real_, p = NA_real_))
  rss <- sum(fit$residuals^2)
  sigma2 <- rss / df
  xtx_inv <- tryCatch(solve(crossprod(X)), error = function(e) NULL)
  if (is.null(xtx_inv)) {
    return(list(slope = fit$coefficients[2L], t = NA_real_, p = NA_real_))
  }
  se <- sqrt(sigma2 * xtx_inv[2L, 2L])
  tval <- fit$coefficients[2L] / se
  pval <- 2 * stats::pt(abs(tval), df = df, lower.tail = FALSE)
  list(slope = fit$coefficients[2L], t = tval, p = pval)
}

#' Print method for preprocessing results
#'
#' @param x A `preprocess_result` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.preprocess_result <- function(x, ...) {
  diag <- x$diagnostics
  cat("Idiographic Preprocessing\n")
  cat(sprintf("  Variables:      %d (%s)\n",
              length(x$labels), paste(x$labels, collapse = ", ")))
  if (!identical(x$config$detrend, "none")) {
    cat(sprintf("  Detrend:        %s\n", x$config$detrend))
  }
  all_checks <- c("trend", "high_ar", "unit_root", "mean_shift", "sd_shift",
                  "zero_variance")
  if (!setequal(x$config$checks, all_checks)) {
    cat(sprintf("  Checks:         %s\n", paste(x$config$checks, collapse = ", ")))
  }
  cat(sprintf("  Ordered rows:   %d\n", x$n_rows))
  cat(sprintf("  Retained pairs: %d\n", x$n_retained))
  cat(sprintf("  Trend flags:    %d\n", sum(diag$flag_trend, na.rm = TRUE)))
  cat(sprintf("  High AR flags:  %d\n", sum(diag$flag_high_ar, na.rm = TRUE)))
  cat(sprintf("  Drift flags:    %d\n",
              sum(diag$flag_mean_shift | diag$flag_sd_shift, na.rm = TRUE)))
  cat(sprintf("  Unit-root risk: %d\n",
              sum(diag$flag_unit_root, na.rm = TRUE)))
  cat(sprintf("  Zero variance:  %d\n",
              sum(diag$flag_zero_variance, na.rm = TRUE)))
  cat("  Tables:         x$pairs | x$counts | x$diagnostics\n")
  if (!is.null(x$advice)) cat("\n", x$advice, "\n", sep = "")
  invisible(x)
}

#' @export
as.data.frame.preprocess_result <- function(x, row.names = NULL,
                                            optional = FALSE, ...) {
  x$diagnostics
}

#' Summary method for preprocessing results
#'
#' Compact per-variable roll-up of the diagnostics: one row per variable with
#' its mean spread and the number of subject-series that tripped each
#' stationarity flag. Use `x$diagnostics` for the full per-subject table.
#'
#' @param object A `preprocess_result` object.
#' @param ... Ignored.
#' @return A tidy per-variable `data.frame`.
#' @export
summary.preprocess_result <- function(object, ...) {
  d <- object$diagnostics
  vars <- object$labels
  count <- function(flag) {
    as.integer(tapply(d[[flag]], factor(d$variable, levels = vars),
                      function(z) sum(z, na.rm = TRUE)))
  }
  data.frame(
    variable    = vars,
    n_series    = as.integer(table(factor(d$variable, levels = vars))),
    mean_sd     = round(as.numeric(tapply(d$sd,
                        factor(d$variable, levels = vars),
                        function(z) mean(z, na.rm = TRUE))), 3),
    n_trend     = count("flag_trend"),
    n_high_ar   = count("flag_high_ar"),
    n_unit_root = count("flag_unit_root"),
    n_flagged   = count("flag_stationarity_risk"),
    stringsAsFactors = FALSE
  )
}
