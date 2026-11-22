# test_subgroups(): the full covariance models (EEE, VVV) are the unpenalised
# Gaussian maximum-likelihood estimates (Fraley & Raftery 2002). Up to 0.4.0.9008
# a ridge of 1e-4 times the mean coefficient variance was added, which left the
# one-group log-likelihood 3.5e-7 below the maximum on srl.

test_that("one-group full-covariance log-likelihood is the closed-form Gaussian ML", {
  predictors <- c("efficacy", "planning")
  d <- srl[stats::complete.cases(srl[c("effort", predictors)]), ]
  slopes <- t(vapply(split(d, d$name), function(person) {
    stats::coef(stats::lm(effort ~ efficacy + planning, data = person))[predictors]
  }, numeric(2)))
  b <- scale(slopes)
  n <- nrow(b)
  p <- ncol(b)
  centred <- sweep(b, 2L, colMeans(b))
  sigma_ml <- crossprod(centred) / n
  loglik_ml <- -n / 2 * (p * log(2 * pi) +
                           as.numeric(determinant(sigma_ml)$modulus) + p)

  tab <- as.data.frame(test_subgroups(d, y = "effort", x = predictors, id = "name"))
  full <- subset(tab, k == 1L & model %in% c("EEE", "VVV"))
  expect_equal(nrow(full), 2L)
  expect_equal(full$loglik, rep(loglik_ml, 2L), tolerance = 1e-10)
  # Invariant: with one group, EEE and VVV are the same model.
  expect_equal(full$loglik[1L], full$loglik[2L], tolerance = 1e-12)
  # BIC is -2 log L + npar log n with npar = p + p(p + 1) / 2.
  expect_equal(full$bic, -2 * full$loglik + (p + p * (p + 1) / 2) * log(n),
               tolerance = 1e-12)
})
