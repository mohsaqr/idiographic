# preprocess(): the lag-1 design and the per-series stationarity diagnostics, each written here from its
# definition with stats::lm(), stats::t.test() and base R on the same prepared series.
#
# The preparation, as documented: each variable standardised over all rows, centred within person, ordered by
# person, day and occasion; the lag is the previous occasion of the same person and day. Per person and variable:
# the linear trend is the least-squares slope on the occasion index 1..n, AR(1) the slope on the lagged value,
# the split-half drift a Welch t-test of the second half against the first (observed values), the unit-root
# screen the Dickey-Fuller regression without lags, diff(y) on the lagged level (observed values in order).
#
# Least squares on at most 30 rows and closed-form moments on both sides: 1e-10.

abc <- c("A", "B", "C")

#' A panel with a trend in A, two missing values in B and a random walk in C for person 3
preprocess_panel_data <- function() {
  panel <- ref_panel(n_id = 3L, days = 2L, beeps = 15L, vars = abc, seed = 31L)
  panel$A <- panel$A + 0.12 * (panel$beep + 15 * (panel$day - 1))
  panel$B[c(5L, 40L)] <- NA
  set.seed(32L)
  walk <- panel$id == 3L
  panel$C[walk] <- cumsum(stats::rnorm(sum(walk)))
  panel
}

#' The prepared series: standardised over all rows, centred within person, in time order, with the lag
prepared_series <- function(panel, vars) {
  values <- as.data.frame(lapply(panel[vars], \(z) (z - mean(z, na.rm = TRUE)) / stats::sd(z, na.rm = TRUE)))
  values <- as.data.frame(lapply(values, \(z) z - stats::ave(z, panel$id, FUN = \(v) mean(v, na.rm = TRUE))))
  ordered <- order(panel$id, panel$day, panel$beep)
  frame <- data.frame(id = panel$id, day = panel$day, beep = panel$beep, values)[ordered, ]
  block <- paste(frame$id, frame$day)
  same <- c(FALSE, block[-1L] == block[-length(block)])
  lags <- as.data.frame(lapply(frame[vars], \(z) ifelse(same, c(NA, z[-length(z)]), NA_real_)))
  names(lags) <- paste0("L1_", vars)
  data.frame(frame, lags, row.names = NULL)
}

#' A slope, its t and its p-value from stats::lm()
lm_slope <- function(y, x) {
  row <- stats::coef(summary(stats::lm(y ~ x)))["x", ]
  c(slope = row[["Estimate"]], t = row[["t value"]], p = row[["Pr(>|t|)"]])
}

#' The diagnostics of one series from their definitions
series_diagnostics <- function(y, lag, subject, variable) {
  observed <- y[!is.na(y)]
  half <- floor(length(observed) / 2)
  first <- observed[seq_len(half)]
  second <- observed[-seq_len(half)]
  welch <- stats::t.test(second, first, var.equal = FALSE)
  trend <- lm_slope(y, seq_along(y))
  ar <- lm_slope(y, lag)
  dickey_fuller <- lm_slope(diff(observed), observed[-length(observed)])
  data.frame(subject = as.character(subject), variable = variable, n = length(y), n_observed = length(observed),
             missing_prop = mean(is.na(y)), mean = mean(observed), sd = stats::sd(observed),
             trend_slope = trend[["slope"]], trend_t = trend[["t"]], trend_p = trend[["p"]],
             ar1 = ar[["slope"]], ar1_t = ar[["t"]], ar1_p = ar[["p"]],
             mean_first_half = mean(first), mean_second_half = mean(second), mean_shift = mean(second) - mean(first),
             mean_shift_std = abs(mean(second) - mean(first)) / stats::sd(observed),
             mean_shift_p = welch$p.value,
             sd_first_half = stats::sd(first), sd_second_half = stats::sd(second),
             sd_ratio = max(stats::sd(first), stats::sd(second)) / min(stats::sd(first), stats::sd(second)),
             unit_root_coef = dickey_fuller[["slope"]], unit_root_t = dickey_fuller[["t"]],
             flag_trend = trend[["p"]] < 0.05, flag_high_ar = abs(ar[["slope"]]) >= 0.95,
             flag_mean_shift = abs(mean(second) - mean(first)) / stats::sd(observed) >= 0.8,
             flag_sd_shift = max(stats::sd(first), stats::sd(second)) / min(stats::sd(first), stats::sd(second)) >= 2,
             flag_unit_root = dickey_fuller[["t"]] > -2.86)
}

#' Every person's and variable's diagnostics, with the any-flag roll-up
all_diagnostics <- function(series, vars) {
  rows <- lapply(split(series, series$id), \(person) {
    do.call(rbind, lapply(vars, \(v) series_diagnostics(person[[v]], person[[paste0("L1_", v)]], person$id[[1L]], v)))
  })
  out <- do.call(rbind, rows)
  out$flag_stationarity_risk <- out$flag_trend | out$flag_high_ar | out$flag_mean_shift | out$flag_sd_shift |
    out$flag_unit_root
  out
}

test_that("per-series diagnostics equal their definitions", {
  panel <- preprocess_panel_data()
  pp <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep"))
  theirs <- all_diagnostics(prepared_series(panel, abc), abc)
  expect_reference(as.data.frame(pp), theirs, reference = "stats",
                   covers = c("preprocess()", "as.data.frame.preprocess_result()"),
                   quantity = "three people, two days of 15 occasions", tolerance = 1e-10,
                   key = c("subject", "variable"),
                   note = "Slopes, t and p from stats::lm(); the split-half p-value from stats::t.test(var.equal = FALSE).")
  per_variable <- do.call(rbind, lapply(abc, \(v) {
    rows <- subset(theirs, variable == v)
    data.frame(variable = v, n_series = nrow(rows), mean_sd = round(mean(rows$sd), 3), n_trend = sum(rows$flag_trend),
               n_high_ar = sum(rows$flag_high_ar), n_unit_root = sum(rows$flag_unit_root),
               n_flagged = sum(rows$flag_stationarity_risk))
  }))
  # mean_sd is rounded to three decimals on both sides.
  expect_reference(summary(pp), per_variable, reference = "independent: counts of the flags written from their definitions",
                   covers = "summary.preprocess_result()", quantity = "flags per variable", tolerance = 1e-10,
                   key = "variable")
})

test_that("the lag-1 design matrices hold the complete current and lagged rows", {
  panel <- preprocess_panel_data()
  pp <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep"))
  series <- prepared_series(panel, abc)
  complete <- series[stats::complete.cases(series[c(abc, paste0("L1_", abc))]), ]
  current <- as.matrix(complete[abc])
  lagged <- cbind("(Intercept)" = 1, as.matrix(complete[paste0("L1_", abc)]))
  colnames(lagged) <- c("(Intercept)", abc)
  rownames(current) <- rownames(lagged) <- NULL
  # API gap: matrices() returns a list of matrices, so each design matrix is reached by name.
  expect_reference(matrices(pp, print = FALSE)[["data_c"]], current, reference = "independent: the lag-1 design",
                   covers = c("preprocess()", "matrices.preprocess_result()"),
                   quantity = "current values of the complete pairs", tolerance = 1e-12)
  expect_reference(matrices(pp, print = FALSE)[["data_l"]], lagged, reference = "independent: the lag-1 design",
                   covers = c("preprocess()", "matrices.preprocess_result()"),
                   quantity = "lagged values of the complete pairs", tolerance = 1e-12)
})

test_that("detrending by a linear fit and by differencing, then the diagnostics", {
  panel <- preprocess_panel_data()
  series <- prepared_series(panel, abc)
  relag <- function(frame) {
    block <- paste(frame$id, frame$day)
    same <- c(FALSE, block[-1L] == block[-length(block)])
    frame[paste0("L1_", abc)] <- lapply(frame[abc], \(z) ifelse(same, c(NA, z[-length(z)]), NA_real_))
    frame
  }
  # Linear: each person's series replaced by the residuals of its regression on the occasion index.
  linear <- series
  linear[abc] <- lapply(abc, \(v) stats::ave(series[[v]], series$id, FUN = \(z) {
    index <- seq_along(z)
    z - stats::predict(stats::lm(z ~ index), newdata = data.frame(index = index))
  }))
  ours <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep", detrend = "linear"))
  expect_reference(as.data.frame(ours), all_diagnostics(relag(linear), abc), reference = "stats",
                   covers = c("preprocess()", "as.data.frame.preprocess_result()"),
                   quantity = "linear detrending", tolerance = 1e-10, key = c("subject", "variable"))
  # Difference: the first difference within each person and day; the first occasion of a day has none.
  differenced <- series
  differenced[abc] <- lapply(abc, \(v) stats::ave(series[[v]], series$id, series$day, FUN = \(z) c(NA, diff(z))))
  ours <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep", detrend = "difference"))
  expect_reference(as.data.frame(ours), all_diagnostics(relag(differenced), abc), reference = "stats",
                   covers = c("preprocess()", "as.data.frame.preprocess_result()"),
                   quantity = "first differences", tolerance = 1e-10, key = c("subject", "variable"))
})

test_that("the unit-root screen by urca::ur.df(), and the flag counts that follow", {
  panel <- preprocess_panel_data()
  pp <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep"))
  series <- prepared_series(panel, abc)
  # The Dickey-Fuller regression with a drift and no augmentation lags, by urca (Pfaff, 2008): tau2 is the t of
  # the lagged level.
  dickey_fuller <- do.call(rbind, lapply(split(series, series$id), \(person) {
    do.call(rbind, lapply(abc, \(v) {
      observed <- person[[v]][!is.na(person[[v]])]
      test <- urca::ur.df(observed, type = "drift", lags = 0L)
      data.frame(subject = as.character(person$id[[1L]]), variable = v,
                 unit_root_coef = unname(test@testreg$coefficients["z.lag.1", "Estimate"]),
                 unit_root_t = unname(test@teststat[1L, "tau2"]))
    }))
  }))
  expect_reference(as.data.frame(pp), dickey_fuller, reference = "urca",
                   covers = c("preprocess()", "as.data.frame.preprocess_result()"),
                   quantity = "three people, Dickey-Fuller coefficient and t by urca::ur.df()", tolerance = 1e-10,
                   key = c("subject", "variable"))
  # The flags from stats::lm() and stats::t.test() (all_diagnostics()) with the unit-root t of urca, counted.
  flags <- merge(subset(all_diagnostics(series, abc), select = -unit_root_t), dickey_fuller[c("subject", "variable", "unit_root_t")],
                 by = c("subject", "variable"))
  flags$flag_unit_root <- flags$unit_root_t > -2.86
  flags$flag_stationarity_risk <- flags$flag_trend | flags$flag_high_ar | flags$flag_mean_shift | flags$flag_sd_shift |
    flags$flag_unit_root
  counted <- do.call(rbind, lapply(abc, \(v) {
    rows <- subset(flags, variable == v)
    data.frame(variable = v, n_series = nrow(rows), mean_sd = round(mean(rows$sd), 3), n_trend = sum(rows$flag_trend),
               n_high_ar = sum(rows$flag_high_ar), n_unit_root = sum(rows$flag_unit_root),
               n_flagged = sum(rows$flag_stationarity_risk))
  }))
  expect_reference(summary(pp), counted, reference = "urca", covers = "summary.preprocess_result()",
                   quantity = "flags per variable, the unit-root t by urca::ur.df() and the rest by stats",
                   tolerance = 1e-10, key = "variable")
})

test_that("the lag-1 design by datawizard::demean() and dplyr::lag()", {
  panel <- preprocess_panel_data()
  pp <- suppressMessages(preprocess(panel, vars = abc, id = "id", day = "day", beep = "beep"))
  standardised <- data.frame(panel[c("id", "day", "beep")], scale(panel[abc]))
  # Centred within person by datawizard; each value's lag is the previous occasion of the same person and day.
  centred <- datawizard::demean(standardised, select = abc, by = "id")
  frame <- data.frame(standardised[c("id", "day", "beep")], centred[paste0(abc, "_within")])
  names(frame) <- c("id", "day", "beep", abc)
  lagged <- frame |>
    dplyr::arrange(id, day, beep) |>
    dplyr::group_by(id, day) |>
    dplyr::mutate(dplyr::across(dplyr::all_of(abc), dplyr::lag, .names = "L1_{.col}")) |>
    dplyr::ungroup() |>
    as.data.frame()
  complete <- lagged[stats::complete.cases(lagged[c(abc, paste0("L1_", abc))]), ]
  current <- as.matrix(complete[abc])
  previous <- cbind("(Intercept)" = 1, as.matrix(complete[paste0("L1_", abc)]))
  colnames(previous) <- c("(Intercept)", abc)
  rownames(current) <- rownames(previous) <- NULL
  # API gap: matrices() returns a list of matrices, so each design matrix is reached by name.
  expect_reference(matrices(pp, print = FALSE)[["data_c"]], current, reference = "dplyr",
                   covers = c("preprocess()", "matrices.preprocess_result()"),
                   quantity = "current values of the complete pairs (datawizard::demean(), dplyr::lag())",
                   tolerance = 1e-12)
  expect_reference(matrices(pp, print = FALSE)[["data_l"]], previous, reference = "dplyr",
                   covers = c("preprocess()", "matrices.preprocess_result()"),
                   quantity = "lagged values of the complete pairs (datawizard::demean(), dplyr::lag())",
                   tolerance = 1e-12)
})
