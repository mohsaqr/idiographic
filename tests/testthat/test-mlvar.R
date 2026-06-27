test_that("build_mlvar returns three named netobjects + tidy coefs", {
  d <- synth_panel(n_id = 12, days = 4, beeps = 12, seed = 3)
  fit <- suppressWarnings(
    build_mlvar(d, vars = c("A", "B", "C"), id = "id",
                day = "day", beep = "beep")
  )
  expect_s3_class(fit, "net_mlvar")
  expect_named(fit, c("temporal", "contemporaneous", "between"))
  expect_true(all(vapply(fit, inherits, logical(1), "netobject")))

  co <- coefs(fit)
  expect_s3_class(co, "data.frame")
  expect_equal(nrow(co), 9L)                # d * d
  expect_named(co, c("outcome", "predictor", "beta", "se", "t", "p",
                     "ci_lower", "ci_upper", "significant"))
})

test_that("coefs() errors for unsupported classes", {
  expect_error(coefs(1L), "No coefs")
})

test_that("matches mlVAR to machine precision on well-conditioned data", {
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 20, days = 6, beeps = 10, seed = 21)
  vars <- c("A", "B", "C")
  fit <- suppressWarnings(
    build_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
  )
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    scale = FALSE, verbose = FALSE
  ))
  # Temporal fixed effects: exact ([response, predictor] orientation).
  expect_equal(fit$temporal$weights, ref$results$Beta$mean[, , 1],
               tolerance = 1e-8, ignore_attr = TRUE)
  # Off-diagonal contemporaneous / between pcor (diagonals differ by convention).
  co <- fit$contemporaneous$weights
  rc <- ref$results$Theta$pcor$mean
  expect_equal(co[upper.tri(co)], rc[upper.tri(rc)], tolerance = 1e-8)
  bt <- fit$between$weights
  rb <- ref$results$Omega_mu$pcor$mean
  expect_equal(bt[upper.tri(bt)], rb[upper.tri(rb)], tolerance = 1e-8)
})

test_that("unsupported mlVAR modes error clearly; aliases work", {
  d <- synth_panel(n_id = 8, days = 3, beeps = 12, seed = 4)
  vars <- c("A", "B", "C")
  expect_error(build_mlvar(d, vars = vars, id = "id", temporal = "correlated"),
               "fixed")
  expect_error(build_mlvar(d, vars = vars, id = "id",
                           contemporaneous = "orthogonal"), "fixed")
  expect_error(build_mlvar(d, vars = vars, id = "id", estimator = "lm"), "lmer")
  expect_error(build_mlvar(d, vars = vars, id = "id", lags = 2), "lags")
  # standardize is a deprecated alias for scale: identical temporal weights.
  a <- suppressWarnings(build_mlvar(d, vars = vars, id = "id", standardize = TRUE))
  b <- suppressWarnings(build_mlvar(d, vars = vars, id = "id", scale = TRUE))
  expect_equal(a$temporal$weights, b$temporal$weights)
})

test_that("conflicting scale/standardize warns and honours the canonical name", {
  d <- synth_panel(n_id = 8, days = 3, beeps = 12, seed = 4)
  vars <- c("A", "B", "C")
  # standardize is a deprecated alias of scale; if both are set and disagree,
  # the canonical `scale` wins and a warning is emitted (not silently dropped).
  expect_warning(
    a <- build_mlvar(d, vars = vars, id = "id", scale = TRUE,
                     standardize = FALSE),
    "disagree"
  )
  b <- suppressWarnings(build_mlvar(d, vars = vars, id = "id", scale = TRUE))
  expect_equal(a$temporal$weights, b$temporal$weights)
})

test_that("AR = TRUE gives a diagonal temporal matrix matching mlVAR", {
  skip_if_not_installed("mlVAR")
  d <- synth_panel(n_id = 18, days = 5, beeps = 11, seed = 31)
  vars <- c("A", "B", "C")
  fit <- suppressWarnings(build_mlvar(d, vars = vars, id = "id", day = "day",
                                      beep = "beep", AR = TRUE))
  B <- fit$temporal$weights
  expect_true(all(B[row(B) != col(B)] == 0))      # off-diagonal exactly 0
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    AR = TRUE, scale = FALSE, verbose = FALSE))
  expect_equal(B, ref$results$Beta$mean[, , 1], tolerance = 1e-8,
               ignore_attr = TRUE)
  # AR off-diagonal coefs are coherent: beta 0, significant FALSE (not NA).
  co <- coefs(fit)
  off <- co[co$outcome != co$predictor, , drop = FALSE]
  expect_true(all(off$beta == 0))
  expect_false(any(is.na(off$significant)))
  expect_true(all(!off$significant))
})

test_that("singular between-network returns zeros with a warning (convention)", {
  # A zero random-intercept SD makes the between network non-estimable; idionet
  # returns zeros (with a warning) by convention rather than NA like mlVAR.
  vars <- c("A", "B")
  Gamma <- matrix(c(0, 0.2, 0.1, 0), 2, 2, dimnames = list(vars, vars))
  mu_SD <- c(A = 1, B = 0)                  # B has no between-person variance
  expect_warning(
    bt <- idionet:::.mlvar_compute_between_from_gamma(Gamma, mu_SD, vars),
    "not estimable"
  )
  expect_true(all(bt == 0))
  expect_equal(dim(bt), c(2L, 2L))
})

test_that("defensive coefficient matchers fill missing names with NA", {
  fe <- c(L1_A = 0.3, L1_B = -0.1)
  expect_equal(idionet:::.mlvar_vec(fe, c("L1_A", "L1_B", "L1_C")),
               c(0.3, -0.1, NA))
  m <- matrix(c(0.2, 0.05), 1, 2,
              dimnames = list("L1_A", c("Std. Error", "t value")))
  expect_equal(idionet:::.mlvar_row(m, c("L1_A", "L1_B"), "Std. Error"),
               c(0.2, NA))
})
