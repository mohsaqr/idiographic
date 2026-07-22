# Parity: native fit_mlvar_bayes() vs real Mplus DSEM ground truth.
#
# Fixtures in fixtures/mplus/mlvar_*.rds were produced by running Mplus 9 (DEMO)
# via mlVAR(estimator = "Mplus", temporal = "fixed", contemporaneous = "fixed")
# on standardized d = 2 synthetic panels (see generate-mplus-mlvar.R). We require
# STATISTICAL equivalence: posterior medians within Monte-Carlo error of Mplus,
# scaled by Mplus's own posterior SD (both are stochastic MCMC estimates).

fixture_files <- list.files(
  testthat::test_path("fixtures", "mplus"),
  pattern = "^mlvar_.*\\.rds$", full.names = TRUE)

test_that("Mplus mlVAR fixtures are present", {
  expect_true(length(fixture_files) >= 1L)
})

run_bayes <- function(fx, n_iter = 6000L, seed = 2024L) {
  fit_mlvar_bayes(fx$data, vars = fx$vars, id = fx$id, beep = fx$beep,
                    n_iter = n_iter, n_chains = 2L, seed = seed, verbose = FALSE)
}

for (f in fixture_files) {
  fx <- readRDS(f)
  tag <- fx$tag

  test_that(paste0("temporal B matches Mplus DSEM [", tag, "]"), {
    skip_if_not_installed("corpcor")
    fit <- run_bayes(fx)
    B <- attr(fit, "matrices")$B
    mB <- fx$mplus$B; mSD <- fx$mplus$B_sd
    # within ~1 posterior SD, and an absolute floor for MC noise
    tol <- pmax(0.045, 0.9 * mSD)
    expect_true(all(abs(B - mB) < tol),
                info = paste0("B diff:\n",
                              paste(round(abs(B - mB), 4), collapse = " ")))
    # tight aggregate check: mean abs error small
    expect_lt(mean(abs(B - mB)), 0.03)
  })

  test_that(paste0("contemporaneous Sigma_W matches Mplus [", tag, "]"), {
    skip_if_not_installed("corpcor")
    fit <- run_bayes(fx)
    SW <- attr(fit, "matrices")$Sigma_W
    expect_lt(max(abs(SW - fx$mplus$Sigma_W)), 0.08)
  })

  test_that(paste0("between Sigma_B matches Mplus (wide posterior) [", tag, "]"), {
    skip_if_not_installed("corpcor")
    fit <- run_bayes(fx)
    SB <- attr(fit, "matrices")$Sigma_B
    # Sigma_B has few clusters -> wide, skewed posterior; looser tolerance.
    expect_lt(max(abs(SB - fx$mplus$Sigma_B)), 0.12)
  })

  test_that(paste0("posterior SDs are on Mplus's scale [", tag, "]"), {
    skip_if_not_installed("corpcor")
    fit <- run_bayes(fx)
    cf <- coefs(fit)
    my_sd <- matrix(cf$posterior_sd, 2, 2, byrow = TRUE)
    expect_lt(max(abs(my_sd - fx$mplus$B_sd)), 0.02)
  })
}

test_that("object structure and accessors are well-formed", {
  skip_if_not_installed("corpcor")
  fx <- readRDS(fixture_files[[1]])
  fit <- run_bayes(fx, n_iter = 2000L)
  expect_s3_class(fit, "net_mlvar_bayes")
  expect_s3_class(fit, "net_mlvar")
  expect_named(fit, c("temporal", "contemporaneous", "between"))
  cf <- coefs(fit)
  expect_true(all(c("outcome", "predictor", "estimate", "posterior_sd",
                    "ci_lower", "ci_upper", "p", "significant") %in% names(cf)))
  expect_equal(nrow(cf), 4L)
  expect_true(attr(fit, "max_psr") < 1.1)          # converged
  expect_true(is.finite(attr(fit, "n_obs")))
})

test_that("convergence (PSR) is near 1 on a well-identified fixture", {
  skip_if_not_installed("corpcor")
  fx <- readRDS(fixture_files[[1]])
  fit <- run_bayes(fx)
  expect_lt(attr(fit, "max_psr"), 1.1)
})
