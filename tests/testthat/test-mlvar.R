test_that("fit_mlvar returns three named cograph networks + tidy coefs", {
  d <- synth_panel(n_id = 12, days = 4, beeps = 12, seed = 3)
  fit <- suppressWarnings(
    fit_mlvar(d, vars = c("A", "B", "C"), id = "id",
                day = "day", beep = "beep")
  )
  expect_s3_class(fit, "net_mlvar")
  expect_s3_class(fit, "cograph_group")
  expect_named(fit, c("temporal", "contemporaneous", "between"))
  expect_true(all(vapply(fit, inherits, logical(1), "cograph_network")))
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

test_that("mlVAR modes, multiple lags, and aliases work", {
  d <- synth_panel(n_id = 10, days = 3, beeps = 12, seed = 4)
  vars <- c("A", "B", "C")
  correlated <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", temporal = "correlated"
  ))
  expect_s3_class(correlated, "net_mlvar")
  expect_length(attr(correlated, "temporal_subjects"), 10L)

  orthogonal <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", contemporaneous = "orthogonal"
  ))
  expect_length(attr(orthogonal, "contemporaneous_subjects"), 10L)

  unique <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", estimator = "lm",
    temporal = "unique", contemporaneous = "unique"
  ))
  expect_s3_class(unique, "net_mlvar")
  expect_length(attr(unique, "temporal_subjects"), 10L)

  multi <- suppressWarnings(fit_mlvar(d, vars = vars, id = "id", lags = c(1, 2)))
  expect_named(multi, c("temporal_lag1", "temporal_lag2",
                        "contemporaneous", "between"))
  expect_equal(nrow(coefs(multi)), 18L)
  expect_equal(sort(unique(coefs(multi)$lag)), c(1L, 2L))
  # standardize is a deprecated alias for scale: identical temporal weights.
  a <- suppressWarnings(fit_mlvar(d, vars = vars, id = "id", standardize = TRUE))
  b <- suppressWarnings(fit_mlvar(d, vars = vars, id = "id", scale = TRUE))
  expect_equal(a$temporal$weights, b$temporal$weights)
})

test_that("conflicting scale/standardize warns and honours the canonical name", {
  d <- synth_panel(n_id = 8, days = 3, beeps = 12, seed = 4)
  vars <- c("A", "B", "C")
  # standardize is a deprecated alias of scale; if both are set and disagree,
  # the canonical `scale` wins and a warning is emitted (not silently dropped).
  expect_warning(
    a <- fit_mlvar(d, vars = vars, id = "id", scale = TRUE,
                     standardize = FALSE),
    "disagree"
  )
  b <- suppressWarnings(fit_mlvar(d, vars = vars, id = "id", scale = TRUE))
  expect_equal(a$temporal$weights, b$temporal$weights)
})

test_that("easy mlVAR controls map to explicit native behavior", {
  d <- synth_panel(n_id = 8, days = 3, beeps = 10, seed = 44)
  vars <- c("A", "B", "C")

  global <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    standardize_mode = "global"
  ))
  explicit <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep", scale = TRUE
  ))
  expect_equal(global$temporal$weights, explicit$temporal$weights)

  bad <- d
  bad$A[5] <- NA_real_
  expect_error(
    fit_mlvar(bad, vars = vars, id = "id", day = "day", beep = "beep",
              missing = "fail"),
    "Missing model or ordering values"
  )

  aligned <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    lags = 1, compare_to_lags = c(1, 2)
  ))
  ordinary <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep", lags = 1
  ))
  expect_lt(attr(aligned, "n_obs"), attr(ordinary, "n_obs"))

  means <- stats::aggregate(d[vars], list(id = d$id), mean)
  known <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep",
    true_means = means
  ))
  expect_s3_class(known, "net_mlvar")
  expect_identical(attr(known, "config")$engine, "frequentist")

  parallel_fit <- suppressWarnings(fit_mlvar(
    d, vars = vars, id = "id", day = "day", beep = "beep", nCores = 2
  ))
  expect_equal(parallel_fit$temporal$weights, ordinary$temporal$weights,
               tolerance = 0)

  legacy_warnings <- character()
  legacy <- withCallingHandlers(
    fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep",
              orthogonal = TRUE),
    warning = function(w) {
      legacy_warnings <<- c(legacy_warnings, conditionMessage(w))
      invokeRestart("muffleWarning")
    }
  )
  expect_match(paste(legacy_warnings, collapse = " "), "deprecated")
  expect_identical(attr(legacy, "config")$temporal, "orthogonal")
  expect_error(
    fit_mlvar(d, vars = vars, id = "id", unknown_control = 1),
    "Unused frequentist engine"
  )
})

test_that("singular between-network returns zeros with a warning (convention)", {
  # A zero random-intercept SD makes the between network non-estimable; idiographic
  # returns zeros (with a warning) by convention rather than NA like mlVAR.
  vars <- c("A", "B")
  Gamma <- matrix(c(0, 0.2, 0.1, 0), 2, 2, dimnames = list(vars, vars))
  mu_SD <- c(A = 1, B = 0)                  # B has no between-person variance
  expect_warning(
    bt <- idiographic:::.mlvar_compute_between_from_gamma(Gamma, mu_SD, vars),
    "not estimable"
  )
  expect_true(all(bt == 0))
  expect_equal(dim(bt), c(2L, 2L))
})

test_that("defensive coefficient matchers fill missing names with NA", {
  fe <- c(L1_A = 0.3, L1_B = -0.1)
  expect_equal(idiographic:::.mlvar_vec(fe, c("L1_A", "L1_B", "L1_C")),
               c(0.3, -0.1, NA))
  m <- matrix(c(0.2, 0.05), 1, 2,
              dimnames = list("L1_A", c("Std. Error", "t value")))
  expect_equal(idiographic:::.mlvar_row(m, c("L1_A", "L1_B"), "Std. Error"),
               c(0.2, NA))
})
