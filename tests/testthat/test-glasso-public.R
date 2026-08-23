# The public graphical-lasso kernel is the surface sibling packages depend on,
# so it is tested against (a) its own optimality conditions and (b) invariants
# that hold for any correct solver. Both are self-contained: they need no
# competitor package, which is why they ship.
#
# The comparison against the glasso Fortran reference lives in
# test-expanded-equivalence.R, which is excluded from the CRAN tarball. The
# shipped package does not Suggest `glasso`.

random_cov <- function(p, n) {
  x <- matrix(stats::rnorm(n * p), n, p)
  s <- stats::cov(x)
  s / mean(diag(s))
}

test_that("glasso_fit() satisfies the KKT conditions it advertises", {
  set.seed(11)
  S <- random_cov(6L, 200L)
  for (rho in c(0.01, 0.1, 0.4)) {
    expect_lt(glasso_kkt(glasso_fit(S, rho = rho)), 1e-6)
  }
})

test_that("glasso_kkt() honours a penalised diagonal", {
  # Regression test. The diagonal stationarity condition is W_ii = S_ii only
  # when the diagonal is unpenalised; when it is penalised the condition is
  # W_ii - S_ii = rho. Ignoring that reported a spurious violation of exactly
  # rho for every penalize_diagonal = TRUE fit.
  set.seed(12)
  S <- random_cov(5L, 200L)
  rho <- 0.2
  fit <- glasso_fit(S, rho = rho, penalize_diagonal = TRUE)
  expect_lt(glasso_kkt(fit), 1e-6)
  # and the un-adjusted condition is off by exactly rho, which is what the
  # bug used to report
  naive <- glasso_kkt(fit$wi, S = S, rho = rho, penalize_diagonal = FALSE)
  expect_equal(naive, rho, tolerance = 1e-6)
})

test_that("glasso_fit() honours an element-wise penalty matrix", {
  set.seed(13)
  p <- 5L
  S <- random_cov(p, 200L)
  R <- matrix(0.02, p, p)
  R[1L, 2L] <- R[2L, 1L] <- 5      # crush this one edge
  diag(R) <- 0
  fit <- glasso_fit(S, rho = R)
  expect_identical(fit$wi[1L, 2L], 0)
  expect_lt(glasso_kkt(fit), 1e-6)
})

test_that("glasso_fit() respects hard zero constraints", {
  set.seed(14)
  p <- 6L
  S <- random_cov(p, 200L)
  zero <- cbind(c(1L, 2L), c(3L, 5L))
  fit <- glasso_fit(S, rho = 0, zero = zero)
  expect_true(all(fit$wi[zero] == 0))
  expect_true(all(fit$wi[zero[, c(2L, 1L)]] == 0))
})

test_that("a large enough penalty drives the solution to diagonal", {
  # NOTE: support NESTING is deliberately NOT asserted here. Graphical-lasso
  # supports are not nested in rho -- the edge count can rise as rho rises.
  # Counterexample (idiographic and glasso agree, both with ~1e-10 KKT):
  #   set.seed(11); A <- matrix(rnorm(64), 8)
  #   S <- cov2cor(crossprod(A) + diag(8) * .05)
  #   rho = 0.01 -> 26 edges; rho = 0.042916666667 -> 27 edges
  # An earlier version of this test asserted monotone shrinkage and passed only
  # because its fixture happened to be monotone.
  set.seed(15)
  S <- random_cov(8L, 150L)
  wi <- glasso_fit(S, rho = 0.4)$wi
  expect_identical(sum(wi[upper.tri(wi)] != 0), 0L)
  expect_lt(glasso_kkt(glasso_fit(S, rho = 0.4)), 1e-6)
})

test_that("glasso_fit() is scale-equivariant", {
  # Substituting S -> cS and rho -> c*rho leaves the objective unchanged up to
  # an additive p*log(c), so the minimiser must satisfy
  #   Theta(cS, c*rho) == Theta(S, rho) / c.
  # This is a property of the estimand, so it holds for any correct solver and
  # cannot be satisfied by accident.
  set.seed(25)
  S <- random_cov(6L, 200L)
  base <- glasso_fit(S, rho = 0.08)$wi
  for (cc in c(0.25, 3, 17)) {
    scaled <- glasso_fit(cc * S, rho = cc * 0.08)$wi
    expect_equal(scaled, base / cc, tolerance = 1e-7, ignore_attr = TRUE,
                 info = paste("c =", cc))
  }
})

test_that("the KKT certificate holds across the whole penalty range", {
  set.seed(26)
  S <- random_cov(8L, 150L)
  for (rho in c(0.005, 0.02, 0.05, 0.12, 0.3)) {
    expect_lt(glasso_kkt(glasso_fit(S, rho = rho)), 1e-6)
  }
})

test_that("glasso_kkt() does not penalise hard zero constraints", {
  # Regression test. At a hard-constrained entry the inactive-edge inequality
  # |W_ij - S_ij| <= rho_ij does NOT apply: the equality constraint carries its
  # own multiplier, which absorbs the residual. Checking it anyway reported
  # optimal, glasso-matching fits as violating optimality by ~0.03.
  set.seed(14)
  S <- random_cov(6L, 200L)
  zero <- cbind(c(1L, 2L), c(3L, 5L))
  fit <- glasso_fit(S, rho = 0, zero = zero)
  expect_true(all(fit$wi[zero] == 0))
  expect_lt(glasso_kkt(fit), 1e-6)
  # the constraints really are load-bearing: ignoring them reports a violation
  expect_gt(glasso_kkt(fit$wi, S = S, rho = 0), 1e-6)
})

test_that("the public kernel rejects an invalid covariance or penalty", {
  # A non-PSD S yields a precision matrix with a negative diagonal, and every
  # partial correlation derived from it is NaN.
  expect_error(glasso_fit(matrix(c(-1, 0.2, 0.2, 1), 2), 0.1),
               class = "idiographic_not_psd")
  # a singular but PSD covariance is legitimate and must still be accepted
  expect_s3_class(glasso_fit(matrix(1, 2, 2), 0.1), "glasso_result")
  # an asymmetric penalty matrix is ill-posed, not merely unusual
  expect_error(glasso_fit(matrix(c(1, 0.5, 0.5, 1), 2),
                          matrix(c(0, 0.01, 0.8, 0), 2)), "symmetric")
  # an invalid diagonal flag must not be silently coerced to FALSE by isTRUE()
  fit <- glasso_fit(diag(2), 0.2, penalize_diagonal = TRUE)
  expect_error(glasso_kkt(fit, penalize_diagonal = NA), "TRUE/FALSE")
})

test_that("glasso_fit() is equivariant to variable permutation", {
  set.seed(16)
  p <- 5L
  S <- random_cov(p, 200L)
  perm <- c(3L, 1L, 5L, 2L, 4L)
  a <- glasso_fit(S, rho = 0.08)$wi
  b <- glasso_fit(S[perm, perm], rho = 0.08)$wi
  expect_equal(a[perm, perm], b, tolerance = 1e-8, ignore_attr = TRUE)
})

test_that("glasso_path() equals glasso_fit() at each penalty", {
  set.seed(17)
  S <- random_cov(5L, 200L)
  rhos <- c(0.02, 0.1, 0.3)
  path <- glasso_path(S, rho = rhos, tol_outer = 1e-8, tol_inner = 1e-10)
  for (k in seq_along(rhos)) {
    expect_equal(path$wi[, , k], glasso_fit(S, rho = rhos[k])$wi,
                 tolerance = 1e-6, ignore_attr = TRUE)
  }
})

test_that("glasso results have tidy accessors", {
  set.seed(18)
  S <- random_cov(4L, 200L)
  fit <- glasso_fit(S, rho = 0.02)
  tab <- as.data.frame(fit)
  expect_s3_class(tab, "data.frame")
  expect_named(tab, c("from", "to", "precision", "weight"))
  expect_identical(nrow(tab), 6L)          # p * (p - 1) / 2 unique pairs
  expect_true(all(abs(tab$weight) <= 1 + 1e-8))

  path <- glasso_path(S, rho = c(0.02, 0.2))
  ptab <- as.data.frame(path)
  expect_named(ptab, c("rho", "from", "to", "precision", "weight"))
  expect_identical(nrow(ptab), 12L)
  expect_output(print(fit), "Graphical Lasso Fit")
  expect_output(print(path), "Graphical Lasso Path")
})

test_that("the public kernel rejects malformed input", {
  expect_error(glasso_fit(matrix(1:6, 2, 3), 0.1), "square")
  expect_error(glasso_fit(matrix(c(1, NA, NA, 1), 2), 0.1), "non-finite")
  expect_error(glasso_fit(matrix(c(1, 0.5, 0.2, 1), 2), 0.1), "symmetric")
  expect_error(glasso_fit(diag(2), -1), "non-negative")
  expect_error(glasso_fit(diag(3), 0.1, zero = cbind(1, 99)), "within the dimensions")
  expect_error(glasso_path(diag(3), rho = c(-1, 1)), "non-negative")
  expect_error(glasso_kkt(diag(3)), "required when")
})

test_that("glasso_kkt() warns when an override changes what is certified", {
  # Silently accepting a different rho returns a large violation that reads as
  # a failed certification when the fit is in fact optimal.
  set.seed(24)
  S <- random_cov(5L, 200L)
  fit <- glasso_fit(S, rho = 0.1, penalize_diagonal = TRUE)

  expect_silent(glasso_kkt(fit))
  expect_silent(glasso_kkt(fit, S = S))
  # re-supplying the SAME penalty must not warn, even though `rho` is stored
  # as a p x p matrix and the caller passes the scalar they fitted with
  expect_silent(glasso_kkt(fit, rho = 0.1))
  expect_silent(glasso_kkt(fit, penalize_diagonal = TRUE))

  expect_warning(glasso_kkt(fit, rho = 0.3),
                 class = "idiographic_glasso_kkt_override")
  expect_warning(glasso_kkt(fit, penalize_diagonal = FALSE),
                 class = "idiographic_glasso_kkt_override")

  R <- matrix(0.05, 5L, 5L)
  diag(R) <- 0
  mfit <- glasso_fit(S, rho = R)
  expect_silent(glasso_kkt(mfit, rho = R))
})

test_that("the tidy accessor refuses a degenerate precision matrix", {
  # stats::cov2cor() only WARNS on a non-positive diagonal and returns
  # non-finite partial correlations, which would enter the table as edges.
  for (bad in list(diag(c(1, 0, 2)), diag(c(1, -2, 2)), diag(c(1, NA, 2)))) {
    obj <- structure(list(wi = bad, w = diag(3), beta = matrix(0, 3, 3),
                          rho = matrix(0, 3, 3), penalize_diagonal = FALSE,
                          S = diag(3)),
                     class = c("glasso_result", "list"))
    expect_error(as.data.frame(obj), class = "idiographic_bad_precision")
  }
  ok <- structure(list(wi = diag(c(1, 1, 2)), w = diag(3),
                       beta = matrix(0, 3, 3), rho = matrix(0, 3, 3),
                       penalize_diagonal = FALSE, S = diag(3)),
                  class = c("glasso_result", "list"))
  expect_identical(nrow(as.data.frame(ok)), 3L)
})
