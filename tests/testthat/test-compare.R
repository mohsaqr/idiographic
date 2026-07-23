test_that("compare_idiographic stacks direct VAR and graphical VAR summaries", {
  skip_on_cran()
  d <- synth_single(n_t = 100, vars = c("A", "B", "C"), seed = 701)
  vars <- c("A", "B", "C")
  cmp <- compare_idiographic(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    estimators = c("var", "graphical_var"),
    estimator_args = list(
      var = list(scale = FALSE, center_within = FALSE),
      graphical_var = list(scale = FALSE, center_within = FALSE, n_lambda = 5)
    )
  )

  expect_s3_class(cmp, "model_comparison")
  expect_equal(cmp$n_success, 2L)
  expect_equal(nrow(cmp$failures), 0L)
  expect_named(cmp$comparison,
               c("method", "network", "n_nodes", "n_edges", "density",
                 "mean_abs_weight", "n_positive", "n_negative", "n_self",
                 "max_abs_weight"))
  expect_setequal(cmp$comparison$method, c("var", "graphical_var"))
  expect_output(print(cmp), "Idiographic Model Comparison")
  expect_equal(as.data.frame(cmp), cmp$comparison)

  direct_var <- fit_var(d, vars = vars, id = "id", day = "day",
                          beep = "beep", scale = FALSE,
                          center_within = FALSE)
  direct_row <- subset(summary(direct_var), network == "temporal")
  cmp_row <- subset(cmp$comparison, method == "var" & network == "temporal")
  expect_equal(cmp_row$n_edges, direct_row$n_edges)
  expect_equal(cmp_row$density, direct_row$density)
})

test_that("compare_idiographic keeps successful fits and captures failures", {
  skip_on_cran()
  d <- synth_single(n_t = 80, vars = c("A", "B"), seed = 702)
  cmp <- compare_idiographic(
    d[, c("A", "B")], vars = c("A", "B"),
    estimators = c("var", "usem"),
    keep_fits = TRUE,
    estimator_args = list(var = list(scale = FALSE))
  )

  expect_equal(cmp$n_success, 1L)
  expect_named(cmp$fits, "var")
  expect_s3_class(cmp$fits$var, "var_result")
  expect_equal(cmp$failures$method, "usem")
  expect_match(cmp$failures$message, "id")
})

test_that("compare_idiographic supports uSEM and GIMME in the comparison table", {
  skip_on_cran()
  skip_if_not_installed("lavaan")
  d <- synth_planted_panel(n_id = 3, days = 4, beeps = 16, seed = 703)
  cmp <- compare_idiographic(
    d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    estimators = c("usem", "gimme"),
    estimator_args = list(
      usem = list(temporal = "ar", contemporaneous = "none",
                  residual_cov = TRUE),
      gimme = list(VAR = TRUE, groupcutoff = 1, n_excellent = 1, seed = 1)
    )
  )

  expect_equal(cmp$n_success, 2L)
  expect_setequal(cmp$comparison$method, c("usem", "gimme"))
  expect_true(any(cmp$comparison$network == "temporal"))
})

test_that("compare_idiographic validates estimator names and argument lists", {
  skip_on_cran()
  d <- synth_single(n_t = 60, vars = c("A", "B"), seed = 704)
  expect_error(
    compare_idiographic(d, vars = c("A", "B"), estimators = "nope"),
    "Unsupported estimator"
  )
  expect_error(
    compare_idiographic(d, vars = c("A", "B"),
                        estimator_args = list(var = "bad")),
    "must be a list"
  )
})
