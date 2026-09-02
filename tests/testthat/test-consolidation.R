test_that("consolidated statistical results use the idiographic identity", {
  set.seed(101)
  d <- data.frame(
    id = rep(1:3, each = 30),
    time = rep(seq_len(30), 3),
    x = stats::rnorm(90)
  )
  d$y <- 0.7 * d$x + stats::rnorm(90, sd = 0.3)

  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "time",
                scope = "pooled", min_train = 10)
  expect_identical(class(fit)[1L], "idiographic_fit")
  expect_s3_class(fit, "idiostats_fit")
  expect_output(print(fit), "Idiographic Fit")
  printed <- utils::capture.output(print(fit))
  expect_false(any(grepl("Idiostats Fit", printed, fixed = TRUE)))

  desc <- describe_persons(d, id = "id", vars = "x", time = "time")
  expect_identical(class(desc)[1L], "idiographic_descriptives")
  expect_s3_class(desc, "idiostats_descriptives")
})

test_that("fit_ml preserves both public calling contracts", {
  set.seed(102)
  d <- data.frame(
    id = rep(1:3, each = 30),
    time = rep(seq_len(30), 3),
    x = stats::rnorm(90)
  )
  d$y <- d$x + stats::rnorm(90, sd = 0.2)

  historical <- fit_ml(d, outcome = "y", predictors = "x", id = "id",
                       beep = "time", model = "linear", min_train = 10)
  expect_s3_class(historical, "idioml_result")

  consolidated <- fit_ml(d, y = "y", x = "x", id = "id", time = "time",
                         scope = "pooled", model = "linear", min_train = 10)
  expect_identical(class(consolidated)[1L], "idiographic_fit")
  expect_s3_class(consolidated, "idiostats_fit")
})
