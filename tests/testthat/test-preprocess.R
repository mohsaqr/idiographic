test_that("preprocess lag table matches the line-by-line fixture", {
  d <- utils::read.csv(testthat::test_path("fixtures", "gvar-line-input.csv"),
                       stringsAsFactors = FALSE)
  expected <- utils::read.csv(
    testthat::test_path("fixtures", "gvar-line-expected.csv"),
    stringsAsFactors = FALSE
  )

  pp <- preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, delete_missings = FALSE
  )
  got <- pp$pairs[, c("A", "B", "intercept", "L1_A", "L1_B")]

  expect_s3_class(pp, "preprocess_result")
  expect_equal(nrow(got), nrow(expected))
  for (i in seq_len(nrow(expected))) {
    expect_equal(got[i, , drop = FALSE], expected[i, , drop = FALSE],
                 tolerance = 1e-12, ignore_attr = TRUE,
                 info = paste("row", i))
  }
})

test_that("preprocess matrices are equivalent to .gvar_tsdata", {
  d <- synth_panel(n_id = 3, days = 2, beeps = 8, vars = c("A", "B", "C"),
                   seed = 301)
  vars <- c("A", "B", "C")
  d$B[c(4, 20)] <- NA_real_

  pp <- preprocess(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    scale = TRUE, center_within = TRUE, delete_missings = TRUE
  )
  ref <- idiographic:::.gvar_tsdata(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    scale = TRUE, center_within = TRUE, delete_missings = TRUE
  )

  expect_equal(pp$matrices$data_c, ref$data_c, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(pp$matrices$data_l, ref$data_l, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(sum(pp$counts$n_complete_pairs), nrow(ref$data_c))
  expect_output(print(pp), "Idiographic Preprocessing")
  expect_equal(as.data.frame(pp), pp$diagnostics)
})

test_that("preprocess flags trend, high AR, and zero variance risks", {
  n <- 80
  set.seed(302)
  a <- seq_len(n)
  b <- numeric(n)
  b[1] <- stats::rnorm(1)
  for (i in 2:n) b[i] <- 0.98 * b[i - 1L] + stats::rnorm(1, sd = 0.02)
  d <- data.frame(id = 1, day = 1, beep = seq_len(n),
                  A = a, B = b, C = 1)

  pp <- preprocess(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, ar_threshold = 0.9
  )
  diag <- pp$diagnostics

  expect_true(diag$flag_trend[diag$variable == "A"])
  expect_true(diag$flag_high_ar[diag$variable == "B"])
  expect_true(diag$flag_zero_variance[diag$variable == "C"])
})

test_that("preprocess screens stationarity risks beyond trend and AR", {
  n <- 160
  set.seed(901)
  random_walk <- cumsum(stats::rnorm(n, sd = 0.2)) + seq_len(n) * 0.03
  stationary <- numeric(n)
  for (i in 2:n) {
    stationary[i] <- 0.5 * stationary[i - 1L] + stats::rnorm(1, sd = 0.5)
  }
  variance_shift <- c(stats::rnorm(n / 2, sd = 0.2),
                      stats::rnorm(n / 2, sd = 1.2))
  d <- data.frame(id = 1, day = 1, beep = seq_len(n),
                  random_walk = random_walk,
                  stationary = stationary,
                  variance_shift = variance_shift)

  pp <- preprocess(
    d, vars = c("random_walk", "stationary", "variance_shift"),
    id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE
  )
  diag <- pp$diagnostics
  rw <- diag[diag$variable == "random_walk", ]
  st <- diag[diag$variable == "stationary", ]
  vs <- diag[diag$variable == "variance_shift", ]

  expect_true(rw$flag_mean_shift)
  expect_true(rw$flag_unit_root)
  expect_true(rw$flag_stationarity_risk)
  expect_false(st$flag_stationarity_risk)
  expect_true(vs$flag_sd_shift)
  expect_true(vs$flag_stationarity_risk)
  expect_gt(rw$unit_root_t, pp$config$unit_root_t_cutoff)
  expect_gt(vs$sd_ratio, pp$config$sd_ratio_threshold)
})

test_that("preprocess respects subject filtering", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 8, vars = c("A", "B"),
                   seed = 303)
  pp <- preprocess(d, vars = c("A", "B"), id = "id", day = "day",
                   beep = "beep", subject = 2, scale = FALSE)

  expect_equal(unique(pp$pairs$subject), "2")
  expect_equal(unique(pp$counts$subject), "2")
  expect_equal(unique(pp$diagnostics$subject), "2")
})

test_that("detrend removes the trend and unit-root flags it diagnoses", {
  n <- 160
  set.seed(707)
  trend_series <- cumsum(stats::rnorm(n, sd = 0.2)) + seq_len(n) * 0.05
  noise <- stats::rnorm(n)
  d <- data.frame(id = 1, day = 1, beep = seq_len(n),
                  A = trend_series, B = noise)

  raw <- preprocess(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", scale = FALSE, center_within = FALSE)
  a_raw <- raw$diagnostics[raw$diagnostics$variable == "A", ]
  expect_true(a_raw$flag_trend)

  lin <- preprocess(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", scale = FALSE, center_within = FALSE,
                    detrend = "linear")
  a_lin <- lin$diagnostics[lin$diagnostics$variable == "A", ]
  expect_false(a_lin$flag_trend)
  expect_lt(abs(a_lin$trend_slope), abs(a_raw$trend_slope))
  expect_identical(lin$config$detrend, "linear")

  dif <- preprocess(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", scale = FALSE, center_within = FALSE,
                    detrend = "difference")
  a_dif <- dif$diagnostics[dif$diagnostics$variable == "A", ]
  expect_false(a_dif$flag_unit_root)
  # First difference drops one occasion per id/day block.
  expect_equal(dif$n_retained, raw$n_retained - 1L)
  expect_output(print(dif), "Detrend:")
})

test_that("detrend = 'auto' transforms only the flagged subject-series", {
  set.seed(808)
  rw <- function() cumsum(stats::rnorm(60, sd = 0.4))
  st <- function() as.numeric(stats::arima.sim(list(ar = 0.3), 60))
  d <- rbind(
    data.frame(id = "p1", day = rep(1:4, each = 15), beep = rep(1:15, 4),
               A = rw(), B = st()),
    data.frame(id = "p2", day = rep(1:4, each = 15), beep = rep(1:15, 4),
               A = st(), B = st())
  )

  raw <- suppressMessages(preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE))
  map <- idiographic:::.preprocess_auto_map(raw$diagnostics)
  expect_identical(map$method[map$subject == "p1" & map$variable == "A"],
                   "difference")

  auto <- suppressMessages(preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, detrend = "auto"))
  expect_equal(sum(auto$diagnostics$flag_unit_root), 0)
  expect_equal(sum(auto$diagnostics$flag_trend), 0)
  expect_identical(auto$config$detrend, "auto")
  # Only p1's A was differenced -> 4 day-block starts dropped, nothing else.
  expect_equal(auto$n_retained, raw$n_retained - 4L)
})

test_that("per-variable detrend applies each method and leaves the rest", {
  set.seed(313)
  trend_series <- cumsum(stats::rnorm(90, sd = 0.1)) + seq_len(90) * 0.05
  d <- data.frame(id = 1, day = rep(1:3, each = 30), beep = rep(1:30, 3),
                  A = trend_series, B = trend_series + stats::rnorm(90),
                  C = stats::rnorm(90))

  pv <- suppressMessages(preprocess(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE,
    detrend = c(A = "difference", B = "linear")))

  # A differenced (drops one occasion per day block), B linearly detrended,
  # C untouched -> only A's differencing changes the retained-pair count.
  raw <- suppressMessages(preprocess(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE))
  expect_equal(pv$n_retained, raw$n_retained - 3L)
  expect_identical(pv$config$detrend, "custom")
  a <- pv$diagnostics[pv$diagnostics$variable == "A", ]
  b <- pv$diagnostics[pv$diagnostics$variable == "B", ]
  expect_false(a$flag_unit_root)
  expect_false(b$flag_trend)
})

test_that("checks selects which flags fire and drives the risk roll-up", {
  n <- 120
  set.seed(414)
  a <- seq_len(n)                                   # linear trend
  b <- numeric(n); for (i in 2:n) b[i] <- 0.97 * b[i - 1L] + stats::rnorm(1)
  d <- data.frame(id = 1, day = 1, beep = seq_len(n), A = a, B = b)

  full <- suppressMessages(preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, ar_threshold = 0.9))
  # Only screen for high AR: the trend flag must be silenced.
  ar_only <- suppressMessages(preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, ar_threshold = 0.9,
    checks = "high_ar"))

  expect_true(any(full$diagnostics$flag_trend))
  expect_false(any(ar_only$diagnostics$flag_trend))
  expect_true(any(ar_only$diagnostics$flag_high_ar))
  # risk roll-up now reflects only the selected check.
  expect_equal(ar_only$diagnostics$flag_stationarity_risk,
               ar_only$diagnostics$flag_high_ar)
})

test_that("bad detrend names and values error clearly", {
  d <- synth_panel(n_id = 2, days = 2, beeps = 10, vars = c("A", "B"),
                   seed = 5)
  expect_error(preprocess(d, vars = c("A", "B"), id = "id",
                          detrend = c(Z = "linear")), "must be variables")
  expect_error(preprocess(d, vars = c("A", "B"), id = "id",
                          detrend = c(A = "smooth")), "must be one of")
})

test_that("detrend = 'auto' is a no-op when no series is flagged", {
  d <- synth_panel(n_id = 3, days = 2, beeps = 10, vars = c("A", "B"),
                   seed = 42)
  # Thresholds set so nothing can flag -> auto must transform nothing and
  # report itself as "none".
  args <- list(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
               trend_alpha = 1e-9, ar_threshold = 1, unit_root_t_cutoff = 999)
  none <- suppressMessages(do.call(preprocess, args))
  auto <- suppressMessages(do.call(preprocess, c(args, detrend = "auto")))

  expect_equal(sum(none$diagnostics$flag_trend | none$diagnostics$flag_unit_root |
                     none$diagnostics$flag_high_ar), 0)
  expect_identical(auto$config$detrend, "none")
  expect_equal(auto$n_retained, none$n_retained)
  expect_null(auto$advice)
})
