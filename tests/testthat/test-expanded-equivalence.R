# The comparisons with graphicalVAR, mlVAR, gimme and glasso that lived here are declared equivalence tests in
# tests/equivalence/ (test-graphical-var.R, test-mlvar.R, test-gimme.R, test-glasso.R). What stays are contract
# tests that need the reference packages installed but compare nothing with them.

test_that("AR = TRUE gives a diagonal temporal matrix with coherent coefficients", {
  skip_unless_equivalence()
  skip_if_not_installed("lme4")
  d <- synth_panel(n_id = 18, days = 5, beeps = 11, seed = 31)
  fit <- suppressWarnings(fit_mlvar(d, vars = c("A", "B", "C"), id = "id",
                                    day = "day", beep = "beep", AR = TRUE))
  B <- fit$temporal$weights
  expect_true(all(B[row(B) != col(B)] == 0))
  co <- coefs(fit)
  off <- co[co$outcome != co$predictor, , drop = FALSE]
  expect_true(all(off$beta == 0))
  expect_false(any(is.na(off$significant)))
  expect_true(all(!off$significant))
})

test_that("reference engine converts upstream output without changing layers", {
  skip_unless_equivalence()
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 10, days = 3, beeps = 10, seed = 72)
  fit <- suppressWarnings(fit_mlvar(
    d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
    engine = "reference", verbose = FALSE
  ))
  expect_s3_class(fit, "net_mlvar_reference")
  expect_named(fit, c("temporal", "contemporaneous", "between"))
  expect_equal(nrow(coefs(fit)), 9L)
  expect_identical(equivalence(fit)$status, "delegated")
})

test_that("fit_gimme covers the full gimme::gimme() argument surface", {
  skip_unless_equivalence()
  skip_if_not_installed("gimme")
  missing <- setdiff(names(formals(gimme::gimme)), names(formals(fit_gimme)))
  expect_length(missing, 0L)
})
