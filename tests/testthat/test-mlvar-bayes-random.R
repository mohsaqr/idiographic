# Parity + recovery for the random-slope (full DSEM) sampler.
#
# The Mplus DEMO caps time-series latent variables at 2, so the only Mplus-
# checkable random model is the univariate random-AR(1) (random intercept +
# random slope). We validate the engine there against real Mplus output, and
# validate the multivariate engine by parameter recovery (it is dimension-
# general; the p = 1 case exercises the same conjugate blocks).

test_that("random-slope engine matches Mplus DSEM random-AR(1) [p = 1]", {
  f <- testthat::test_path("fixtures", "mplus", "randomar.rds")
  skip_if_not(file.exists(f))
  fx <- readRDS(f)
  prep <- .mlvb_prepare(fx$data, "V1", "id", NULL, "beep",
                        scale = TRUE, scaleWithin = FALSE)
  set.seed(1)
  ch <- lapply(1:2, function(c)
    .mlvb_gibbs_random(prep$persons, 1L, 6000L, 3000L, 1L, seed = c))
  pooled <- function(s) c(ch[[1]][[s]], ch[[2]][[s]])
  expect_lt(abs(stats::median(pooled("B"))       - fx$mplus$gamma_phi), 0.03)
  expect_lt(abs(stats::median(pooled("alpha"))   - fx$mplus$gamma_mu),  0.03)
  expect_lt(abs(stats::median(pooled("SW"))      - fx$mplus$sigma2),    0.03)
  expect_lt(abs(stats::median(pooled("SB"))      - fx$mplus$var_mu),    0.05)
  expect_lt(abs(stats::median(pooled("slopeVar")) - fx$mplus$var_phi),  0.01)
})

test_that("random-slope build recovers a known p = 2 transition matrix", {
  set.seed(7); n_id <- 60; n_t <- 50
  Bmean <- matrix(c(0.35, 0.10, 0.05, 0.30), 2, 2, byrow = TRUE)
  rows <- lapply(seq_len(n_id), function(i) {
    mu_i <- rnorm(2, 0, 0.5); Bi <- Bmean + matrix(rnorm(4, 0, 0.08), 2, 2)
    y <- matrix(0, n_t, 2)
    for (t in 2:n_t) y[t, ] <- mu_i + Bi %*% (y[t - 1, ] - mu_i) + rnorm(2)
    data.frame(id = i, beep = seq_len(n_t), V1 = y[, 1], V2 = y[, 2])
  })
  d <- do.call(rbind, rows)
  fit <- fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                           temporal = "random", n_iter = 3000, n_chains = 2,
                           seed = 3)
  expect_s3_class(fit, "net_mlvar_bayes")
  expect_identical(attr(fit, "temporal_type"), "random")
  expect_lt(max(abs(attr(fit, "matrices")$B - Bmean)), 0.06)
  expect_true(!is.null(attr(fit, "slope_sd")))
  expect_true(all(attr(fit, "slope_sd") > 0))
  expect_lt(attr(fit, "max_psr"), 1.15)
})

test_that("random-slope path errors when subjects <= random effects", {
  set.seed(1)
  rows <- lapply(1:4, function(i) {
    y <- matrix(0, 30, 2)
    for (t in 2:30) y[t, ] <- c(0.3, 0.2) * y[t - 1, ] + rnorm(2)
    data.frame(id = i, beep = seq_len(30), V1 = y[, 1], V2 = y[, 2])
  })
  d <- do.call(rbind, rows)                         # N = 4 < p + p^2 + 1 = 7
  expect_error(
    fit_mlvar_bayes(d, vars = c("V1", "V2"), id = "id", beep = "beep",
                      temporal = "random", n_iter = 500),
    "at least .* subjects")
})

test_that("random residual covariance produces finite recovery-validated output", {
  set.seed(19)
  n_id <- 16; n_t <- 35
  Bmean <- matrix(c(.30, .08, .04, .25), 2, 2, byrow = TRUE)
  rows <- lapply(seq_len(n_id), function(i) {
    mu <- rnorm(2, 0, .4)
    Bi <- Bmean + matrix(rnorm(4, 0, .05), 2, 2)
    sd_i <- runif(2, .7, 1.3)
    Sigma_i <- diag(sd_i) %*% matrix(c(1, .2, .2, 1), 2, 2) %*%
      diag(sd_i)
    L <- t(chol(Sigma_i))
    y <- matrix(0, n_t, 2)
    for (tt in 2:n_t) {
      y[tt, ] <- mu + Bi %*% (y[tt - 1, ] - mu) +
        as.numeric(L %*% rnorm(2))
    }
    data.frame(id = i, beep = seq_len(n_t), V1 = y[, 1], V2 = y[, 2])
  })
  d <- do.call(rbind, rows)
  fit <- fit_mlvar_bayes(
    d, vars = c("V1", "V2"), id = "id", beep = "beep",
    temporal = "random", residual = "random", n_iter = 700,
    n_burnin = 300, n_chains = 1, thin = 2, seed = 19
  )

  expect_identical(attr(fit, "residual_type"), "random")
  expect_true(all(is.finite(attr(fit, "matrices")$Sigma_W)))
  expect_true(all(diag(attr(fit, "matrices")$Sigma_W) > 0))
  expect_lt(max(abs(attr(fit, "matrices")$B - Bmean)), .2)
  expect_identical(equivalence(fit)$status, "validated_recovery")
})
