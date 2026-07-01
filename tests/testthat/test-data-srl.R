# The shipped srl dataset must be model-ready with no further wrangling.

test_that("srl dataset loads with the documented structure", {
  data(srl, package = "idiographic")
  expect_s3_class(srl, "data.frame")
  expect_equal(nrow(srl), 5616L)
  expect_equal(length(unique(srl$name)), 36L)
  expect_true(all(c("name", "day", "efficacy", "value", "planning",
                    "monitoring", "effort", "control", "help", "social",
                    "organizing") %in% names(srl)))
})

test_that("srl is already ordered and carries a within-person occasion index", {
  data(srl, package = "idiographic")
  # day is a per-person 1..156 index, and rows are ordered by name then day.
  per <- tapply(srl$day, srl$name, function(d) identical(d, seq_along(d)))
  expect_true(all(per))
  expect_false(is.unsorted(order(srl$name, srl$day)))
})

test_that("srl fits every single-series estimator with no preprocessing", {
  data(srl, package = "idiographic")
  vars <- c("efficacy", "value", "planning", "monitoring", "effort")
  fit <- build_var(srl, vars = vars, id = "name", subject = "Grace")
  expect_s3_class(fit, "var_result")
  expect_equal(fit$labels, vars)
})
