short_srl <- function() subset(srl, name != "Aisha" | day <= 8)

test_that("failures() lists the person whose series is too short", {
  fit <- fit_lm(short_srl(), y = "effort", x = "efficacy", id = "name",
                time = "day", scope = "individual")
  tab <- failures(fit)
  expect_s3_class(tab, "data.frame")
  expect_named(tab, c("scope", "model", "estimator", "subject", "message"))
  expect_identical(tab$subject, "Aisha")
  expect_identical(rownames(tab), as.character(seq_len(nrow(tab))))
})

test_that("failures() filters by subject and returns zero rows when clean", {
  fit <- fit_lm(short_srl(), y = "effort", x = "efficacy", id = "name",
                time = "day", scope = "individual")
  expect_identical(nrow(failures(fit, subject = "Bob")), 0L)
  clean <- fit_lm(srl, y = "effort", x = "efficacy", id = "name",
                  time = "day", scope = "pooled")
  expect_identical(nrow(failures(clean)), 0L)
  expect_named(failures(clean), names(failures(fit)))
})

test_that("failures() equals the stored table it exposes", {
  fit <- fit_within_between(short_srl(), y = "effort", x = "efficacy",
                            id = "name", time = "day")
  expect_equal(failures(fit), fit$failures, ignore_attr = TRUE)
})

test_that("print methods point at failures() instead of $failures", {
  fit <- fit_lm(short_srl(), y = "effort", x = "efficacy", id = "name",
                time = "day", scope = "individual")
  out <- capture.output(print(fit))
  expect_true(any(grepl("failures()", out, fixed = TRUE)))
  expect_false(any(grepl("$failures", out, fixed = TRUE)))
})

test_that("failures() raises a classed error for objects without a table", {
  expect_error(failures(1), class = "idiographic_no_failure_table")
  expect_error(failures(list(a = 1)), class = "idiographic_no_failure_table")
})

test_that("rolling results expose windows through as.data.frame()", {
  set.seed(11)
  d <- data.frame(id = rep(c("p1", "p2"), each = 60), day = 1L,
                  beep = rep(seq_len(60), 2),
                  A = stats::rnorm(120), B = stats::rnorm(120),
                  C = stats::rnorm(120))
  roll <- fit_rolling_var(d, vars = c("A", "B", "C"), id = "id", day = "day",
                          beep = "beep", window_size = 40L, step = 20L)
  windows <- as.data.frame(roll, what = "windows")
  expect_s3_class(windows, "data.frame")
  expect_identical(windows, roll$windows)
  expect_identical(as.data.frame(roll), roll$estimates)
  expect_s3_class(failures(roll), "data.frame")
  expect_error(as.data.frame(roll, what = "fits"))
  out <- capture.output(print(roll))
  expect_false(any(grepl("x$windows", out, fixed = TRUE)))
})
