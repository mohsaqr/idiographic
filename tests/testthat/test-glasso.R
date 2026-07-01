# The pure-R graphical lasso underpins graphical_var(); test it against its own
# stationarity (KKT) conditions and validate its input guards.

test_that(".glasso_fit satisfies the KKT optimality conditions", {
  set.seed(1)
  X <- matrix(stats::rnorm(200 * 5), ncol = 5)
  S <- stats::cov(X)
  rho <- 0.1
  fit <- idiographic:::.glasso_fit(S, rho)
  v <- idiographic:::.glasso_kkt_violation(fit$wi, S, rho)
  expect_lt(v, 1e-6)
})

test_that(".glasso_fit matches glasso when available", {
  skip_if_not_installed("glasso")
  set.seed(2)
  X <- matrix(stats::rnorm(300 * 4), ncol = 4)
  S <- stats::cov(X)
  rho <- 0.15
  ours <- idiographic:::.glasso_fit(S, rho)$wi
  ref  <- glasso::glasso(S, rho = rho, penalize.diagonal = FALSE)$wi
  expect_equal(ours, ref, tolerance = 1e-4, ignore_attr = TRUE)
})

test_that(".glasso_fit rejects malformed input", {
  expect_error(idiographic:::.glasso_fit(matrix(1:6, 2, 3), 0.1), "square")
  bad <- matrix(c(1, NA, NA, 1), 2)
  expect_error(idiographic:::.glasso_fit(bad, 0.1), "non-finite")
  asym <- matrix(c(1, 0.5, 0.2, 1), 2)
  expect_error(idiographic:::.glasso_fit(asym, 0.1), "symmetric")
  S <- diag(2)
  expect_error(idiographic:::.glasso_fit(S, -1), "non-negative")
})
