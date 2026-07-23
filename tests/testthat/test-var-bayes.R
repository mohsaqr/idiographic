# Parity: native fit_var_bayes() vs real Mplus Bayesian VAR(1) ground truth.
# Fixtures var_*.rds hold a single standardized series and the Mplus BAYES
# posterior medians for B (temporal) and Sigma (residual covariance). The exact
# Normal-Inverse-Wishart sampler should reproduce them to tight MC error.

var_fixture_files <- list.files(
  testthat::test_path("fixtures", "mplus"),
  pattern = "^var_.*\\.rds$", full.names = TRUE)

test_that("Mplus VAR fixtures are present", {
  skip_on_cran()
  expect_true(length(var_fixture_files) >= 1L)
})

run_vb <- function(fx, n_iter = 6000L, seed = 2024L) {
  fit_var_bayes(fx$data, vars = fx$vars, n_iter = n_iter, n_chains = 2L,
                  seed = seed, verbose = FALSE)
}

for (f in var_fixture_files) {
  fx <- readRDS(f); tag <- fx$tag

  test_that(paste0("temporal B matches Mplus BAYES VAR [", tag, "]"), {
    skip_on_cran()
    fit <- run_vb(fx)
    expect_lt(max(abs(fit$temporal - fx$mplus$B)), 0.03)
    expect_lt(mean(abs(fit$temporal - fx$mplus$B)), 0.02)
  })

  test_that(paste0("residual covariance Sigma matches Mplus [", tag, "]"), {
    skip_on_cran()
    fit <- run_vb(fx)
    expect_lt(max(abs(fit$Sigma - fx$mplus$Sigma)), 0.03)
  })

  test_that(paste0("posterior SDs match Mplus scale [", tag, "]"), {
    skip_on_cran()
    fit <- run_vb(fx)
    my_sd <- matrix(coefs(fit)$posterior_sd, 2, 2, byrow = TRUE)
    expect_lt(max(abs(my_sd - fx$mplus$B_sd)), 0.02)
  })
}

test_that("var_bayes object structure and accessors are well-formed", {
  skip_on_cran()
  fx <- readRDS(var_fixture_files[[1]])
  fit <- run_vb(fx, n_iter = 2000L)
  expect_s3_class(fit, "var_bayes_result")
  expect_true(all(c("temporal", "kappa", "PCC", "PDC", "Sigma", "labels",
                    "n_obs") %in% names(attr(fit, "model"))))
  cf <- coefs(fit)
  expect_equal(nrow(cf), 4L)
  expect_true(all(c("estimate", "posterior_sd", "ci_lower", "ci_upper", "p",
                    "significant") %in% names(cf)))
  g <- as_netobject(fit)
  expect_named(g, c("temporal", "contemporaneous"))
  s <- summary(fit)
  expect_s3_class(s, "data.frame")
})

test_that("Bayesian VAR median ~ OLS VAR on a pooled multi-subject panel", {
  skip_on_cran()
  # No direct Mplus analogue for the within-centred pooled fit, so cross-check
  # the Bayesian posterior median against the frequentist OLS fit_var().
  set.seed(11)
  rows <- lapply(1:8, function(i) {
    y <- matrix(0, 60, 2)
    for (t in 2:60) y[t, ] <- c(0.3, 0.25) * y[t - 1, ] + rnorm(2)
    data.frame(id = i, beep = seq_len(60), A = y[, 1], B = y[, 2])
  })
  d <- do.call(rbind, rows)
  vb <- fit_var_bayes(d, vars = c("A", "B"), id = "id", beep = "beep",
                        n_iter = 4000, seed = 5)
  ov <- fit_var(d, vars = c("A", "B"), id = "id", beep = "beep")
  expect_lt(max(abs(vb$temporal - ov$temporal)), 0.05)
})
