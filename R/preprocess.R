# ---- Preprocessing audit for idiographic time-series models ----

#' Audit preprocessing and lag construction
#'
#' @description
#' Builds the same lag-1 design used by [graphical_var()] and [build_var()],
#' then returns tidy diagnostics for missingness, day-boundary drops, simple
#' linear trends, AR(1) persistence, split-half mean/variance drift, an
#' ADF-style unit-root screen, and zero-variance variables. This is a preflight
#' tool: it does not fit a network, but it makes the modelling input explicit
#' before estimating VAR, graphical VAR, uSEM, GIMME, or mlVAR models.
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
#' @param delete_missings Logical. If `TRUE`, `$pairs` contains only complete
#'   current/lagged rows; if `FALSE`, first rows of blocks and incomplete rows
#'   are retained with `NA` lags, matching `.gvar_tsdata()`. Default `TRUE`.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations.
#' @param subject Optional vector naming the subject(s) to audit.
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
#' @return A `preprocess_audit` object with:
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
#'                 A = rnorm(40), B = rnorm(40))
#' audit <- audit_preprocess(d, vars = c("A", "B"), id = "id",
#'                           day = "day", beep = "beep")
#' audit$counts
#' audit$diagnostics
#' @export
audit_preprocess <- function(data, vars, id = NULL, day = NULL, beep = NULL,
                             scale = TRUE,
                             center_within = TRUE,
                             delete_missings = TRUE,
                             min_obs = NULL,
                             subject = NULL,
                             trend_alpha = 0.05,
                             ar_threshold = 0.95,
                             mean_shift_threshold = 0.8,
                             sd_ratio_threshold = 2,
                             unit_root_t_cutoff = -2.86) {
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(delete_missings, "delete_missings")
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

  prep <- .preprocess_lag_frame(data, vars, id, day, beep, scale,
                                center_within)
  keep <- if (isTRUE(delete_missings)) prep$complete else rep(TRUE, prep$n)
  pairs <- .preprocess_pairs_table(prep, vars, keep)
  counts <- .preprocess_counts(prep, keep)
  diagnostics <- .preprocess_diagnostics(
    prep, vars, trend_alpha, ar_threshold, mean_shift_threshold,
    sd_ratio_threshold, unit_root_t_cutoff
  )
  matrices <- list(
    data_c = as.matrix(pairs[, vars, drop = FALSE]),
    data_l = as.matrix(pairs[, c("intercept", paste0("L1_", vars)),
                             drop = FALSE])
  )
  colnames(matrices$data_l) <- c("(Intercept)", vars)

  out <- list(
    pairs = pairs,
    counts = counts,
    diagnostics = diagnostics,
    matrices = matrices,
    n_rows = prep$n,
    n_retained = nrow(pairs),
    labels = vars,
    config = list(id = id, day = day, beep = beep, scale = scale,
                  center_within = center_within,
                  delete_missings = delete_missings,
                  trend_alpha = trend_alpha,
                  ar_threshold = ar_threshold,
                  mean_shift_threshold = mean_shift_threshold,
                  sd_ratio_threshold = sd_ratio_threshold,
                  unit_root_t_cutoff = unit_root_t_cutoff)
  )
  class(out) <- "preprocess_audit"
  out
}

#' @noRd
.preprocess_lag_frame <- function(data, vars, id, day, beep, scale,
                                  center_within) {
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

#' Print method for preprocessing audits
#'
#' @param x A `preprocess_audit` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.preprocess_audit <- function(x, ...) {
  diag <- x$diagnostics
  cat("Idiographic Preprocessing Audit\n")
  cat(sprintf("  Variables:      %d (%s)\n",
              length(x$labels), paste(x$labels, collapse = ", ")))
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
  invisible(x)
}

#' @export
as.data.frame.preprocess_audit <- function(x, row.names = NULL,
                                           optional = FALSE, ...) {
  x$diagnostics
}
