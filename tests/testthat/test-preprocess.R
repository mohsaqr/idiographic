test_that("audit_preprocess lag table matches the line-by-line fixture", {
  d <- utils::read.csv(testthat::test_path("fixtures", "gvar-line-input.csv"),
                       stringsAsFactors = FALSE)
  expected <- utils::read.csv(
    testthat::test_path("fixtures", "gvar-line-expected.csv"),
    stringsAsFactors = FALSE
  )

  audit <- audit_preprocess(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, delete_missings = FALSE
  )
  got <- audit$pairs[, c("A", "B", "intercept", "L1_A", "L1_B")]

  expect_s3_class(audit, "preprocess_audit")
  expect_equal(nrow(got), nrow(expected))
  for (i in seq_len(nrow(expected))) {
    expect_equal(got[i, , drop = FALSE], expected[i, , drop = FALSE],
                 tolerance = 1e-12, ignore_attr = TRUE,
                 info = paste("row", i))
  }
})

test_that("audit_preprocess matrices are equivalent to .gvar_tsdata", {
  d <- synth_panel(n_id = 3, days = 2, beeps = 8, vars = c("A", "B", "C"),
                   seed = 301)
  vars <- c("A", "B", "C")
  d$B[c(4, 20)] <- NA_real_

  audit <- audit_preprocess(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    scale = TRUE, center_within = TRUE, delete_missings = TRUE
  )
  ref <- idiographic:::.gvar_tsdata(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    scale = TRUE, center_within = TRUE, delete_missings = TRUE
  )

  expect_equal(audit$matrices$data_c, ref$data_c, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(audit$matrices$data_l, ref$data_l, tolerance = 1e-12,
               ignore_attr = TRUE)
  expect_equal(sum(audit$counts$n_complete_pairs), nrow(ref$data_c))
  expect_output(print(audit), "Idiographic Preprocessing Audit")
  expect_equal(as.data.frame(audit), audit$diagnostics)
})

test_that("audit_preprocess flags trend, high AR, and zero variance risks", {
  n <- 80
  set.seed(302)
  a <- seq_len(n)
  b <- numeric(n)
  b[1] <- stats::rnorm(1)
  for (i in 2:n) b[i] <- 0.98 * b[i - 1L] + stats::rnorm(1, sd = 0.02)
  d <- data.frame(id = 1, day = 1, beep = seq_len(n),
                  A = a, B = b, C = 1)

  audit <- audit_preprocess(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, ar_threshold = 0.9
  )
  diag <- audit$diagnostics

  expect_true(diag$flag_trend[diag$variable == "A"])
  expect_true(diag$flag_high_ar[diag$variable == "B"])
  expect_true(diag$flag_zero_variance[diag$variable == "C"])
})

test_that("audit_preprocess screens stationarity risks beyond trend and AR", {
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

  audit <- audit_preprocess(
    d, vars = c("random_walk", "stationary", "variance_shift"),
    id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE
  )
  diag <- audit$diagnostics
  rw <- diag[diag$variable == "random_walk", ]
  st <- diag[diag$variable == "stationary", ]
  vs <- diag[diag$variable == "variance_shift", ]

  expect_true(rw$flag_mean_shift)
  expect_true(rw$flag_unit_root)
  expect_true(rw$flag_stationarity_risk)
  expect_false(st$flag_stationarity_risk)
  expect_true(vs$flag_sd_shift)
  expect_true(vs$flag_stationarity_risk)
  expect_gt(rw$unit_root_t, audit$config$unit_root_t_cutoff)
  expect_gt(vs$sd_ratio, audit$config$sd_ratio_threshold)
})

test_that("audit_preprocess respects subject filtering", {
  d <- synth_panel(n_id = 4, days = 2, beeps = 8, vars = c("A", "B"),
                   seed = 303)
  audit <- audit_preprocess(d, vars = c("A", "B"), id = "id", day = "day",
                            beep = "beep", subject = 2, scale = FALSE)

  expect_equal(unique(audit$pairs$subject), "2")
  expect_equal(unique(audit$counts$subject), "2")
  expect_equal(unique(audit$diagnostics$subject), "2")
})
