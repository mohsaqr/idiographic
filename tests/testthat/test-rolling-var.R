test_that("rolling_var returns tidy windowed VAR estimates", {
  d <- synth_single(n_t = 100, vars = c("A", "B", "C"), seed = 601)
  tv <- rolling_var(d, vars = c("A", "B", "C"), id = "id",
                    day = "day", beep = "beep",
                    window_size = 40, step = 20,
                    scale = FALSE, center_within = FALSE)

  expect_s3_class(tv, "rolling_var_result")
  expect_equal(tv$n_windows, 4L)
  expect_named(tv$windows,
               c("subject", "window", "start_row", "end_row", "start_day",
                 "end_day", "start_beep", "end_beep"))
  expect_named(tv$estimates,
               c("subject", "window", "start_row", "end_row", "start_day",
                 "end_day", "start_beep", "end_beep",
                 "network", "from", "to", "weight"))
  expect_output(print(tv), "Rolling VAR Result")
  expect_equal(as.data.frame(tv), tv$estimates)
})

test_that("rolling_var window estimates equal repeated build_var calls", {
  d <- synth_single(n_t = 100, vars = c("A", "B", "C"), seed = 602)
  vars <- c("A", "B", "C")
  tv <- rolling_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                    window_size = 40, step = 20,
                    scale = FALSE, center_within = FALSE)

  direct <- build_var(d[1:40, , drop = FALSE], vars = vars, id = "id",
                      day = "day", beep = "beep",
                      scale = FALSE, center_within = FALSE)
  got <- subset(tv$estimates, window == 1,
                select = c("network", "from", "to", "weight"))
  expect_equal(got, coefs(direct), tolerance = 1e-12, ignore_attr = TRUE)
})

test_that("rolling_var detects a planted changing lagged effect", {
  set.seed(603)
  n <- 180
  A <- numeric(n)
  B <- numeric(n)
  A[1] <- stats::rnorm(1)
  B[1] <- stats::rnorm(1)
  for (t in 2:n) {
    lag_effect <- if (t <= 90) 0.65 else -0.65
    A[t] <- 0.45 * A[t - 1L] + stats::rnorm(1, sd = 0.4)
    B[t] <- lag_effect * A[t - 1L] + 0.35 * B[t - 1L] +
      stats::rnorm(1, sd = 0.4)
  }
  d <- data.frame(id = 1, day = 1, beep = seq_len(n), A = A, B = B)

  tv <- rolling_var(d, vars = c("A", "B"), id = "id", day = "day",
                    beep = "beep", window_size = 70, step = 50,
                    scale = FALSE, center_within = FALSE)
  ab <- subset(tv$estimates, network == "temporal" & from == "A" & to == "B")

  expect_gt(ab$weight[ab$window == 1], 0.45)
  expect_lt(ab$weight[ab$window == 3], -0.40)
})

test_that("rolling_var validates window geometry and filters subjects", {
  d <- synth_panel(n_id = 3, days = 2, beeps = 10, vars = c("A", "B"),
                   seed = 604)
  one <- rolling_var(d, vars = c("A", "B"), id = "id", day = "day",
                     beep = "beep", window_size = 12, step = 6,
                     subject = 2, scale = FALSE)

  expect_equal(unique(one$windows$subject), "2")
  expect_error(
    rolling_var(d, vars = c("A", "B"), id = "id", day = "day",
                beep = "beep", window_size = 200),
    "No rolling VAR windows"
  )
})
