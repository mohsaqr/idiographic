# glasso_fit(), glasso_path(), glasso_kkt(): the graphical lasso
#   minimise  -log det(Theta) + tr(S Theta) + sum rho_ij |Theta_ij|
# against the Fortran kernel of the glasso package (Friedman, Hastie & Tibshirani, 2008) run to tight
# convergence (thr = 1e-12), and the optimality residual against its definition in base R.

# The problem is strictly convex with one solution, and both solvers iterate to it: they agree to their
# convergence thresholds, not to rounding. 1e-6 is the bound the package's own grid test used.
solver_tolerance <- 1e-6

items <- c("efficacy", "value", "planning", "monitoring", "effort", "regulation")
diary_correlations <- stats::cor(esm_srl[items], use = "complete.obs")

#' The reference's solution as an edge table
glasso_edges <- function(S, ...) {
  solved <- glasso::glasso(S, thr = 1e-12, maxit = 1e4, ...)
  precision <- ref_named(solved$wi, colnames(S))
  merge(ref_undirected(precision, "precision"), ref_undirected(ref_partial(precision), "weight"), by = c("from", "to"))
}

#' A covariance matrix of `p` simulated variables with unit average variance
simulated_covariance <- function(p, n, seed) {
  set.seed(seed)
  covariance <- stats::cov(matrix(stats::rnorm(n * p), n, p, dimnames = list(NULL, paste0("V", seq_len(p)))))
  covariance / mean(diag(covariance))
}

test_that("precision and partial correlations of six diary items at rho = 0.1", {
  skip_without_reference("glasso")
  expect_reference(as.data.frame(glasso_fit(diary_correlations, rho = 0.1)),
                   glasso_edges(diary_correlations, rho = 0.1, penalize.diagonal = FALSE), reference = "glasso",
                   covers = c("glasso_fit()", "as.data.frame.glasso_result()"), quantity = "diary items, rho = 0.1",
                   tolerance = solver_tolerance, key = c("from", "to"),
                   note = "esm_srl, 2,790 complete rows; the diagonal is not penalised.")
})

test_that("a grid of sizes and penalties, with and without a penalised diagonal", {
  skip_without_reference("glasso")
  grid <- expand.grid(p = c(3L, 6L, 10L), rho = c(0.01, 0.1, 0.35), diagonal = c(FALSE, TRUE))
  cells <- lapply(seq_len(nrow(grid)), \(row) {
    S <- simulated_covariance(grid$p[[row]], n = 150L, seed = 1900L + row)
    label <- sprintf("p = %d, rho = %s, diagonal %s", grid$p[[row]], grid$rho[[row]], grid$diagonal[[row]])
    list(mine = cbind(case = label, as.data.frame(glasso_fit(S, rho = grid$rho[[row]], penalize_diagonal = grid$diagonal[[row]]))),
         theirs = cbind(case = label, glasso_edges(S, rho = grid$rho[[row]], penalize.diagonal = grid$diagonal[[row]])))
  })
  expect_reference(do.call(rbind, lapply(cells, \(cell) cell$mine)), do.call(rbind, lapply(cells, \(cell) cell$theirs)),
                   reference = "glasso", covers = c("glasso_fit()", "as.data.frame.glasso_result()"),
                   quantity = "simulated covariance", tolerance = solver_tolerance, key = c("case", "from", "to"))
})

test_that("a matrix of penalties, and entries constrained to zero", {
  skip_without_reference("glasso")
  S <- simulated_covariance(6L, n = 150L, seed = 20L)
  set.seed(21)
  penalties <- matrix(stats::runif(36L, 0.02, 0.3), 6L, 6L)
  penalties <- (penalties + t(penalties)) / 2
  diag(penalties) <- 0
  expect_reference(as.data.frame(glasso_fit(S, rho = penalties, penalize_diagonal = TRUE)),
                   glasso_edges(S, rho = penalties, penalize.diagonal = TRUE), reference = "glasso",
                   covers = c("glasso_fit()", "as.data.frame.glasso_result()"), quantity = "penalty matrix",
                   tolerance = solver_tolerance, key = c("from", "to"))
  constrained <- utils::head(which(upper.tri(S), arr.ind = TRUE), 5L)
  # glasso() warns that with rho = 0 it may not converge when p > n; here p = 6 and n = 150.
  unpenalised <- suppressWarnings(glasso_edges(S, rho = 0, zero = constrained))
  expect_reference(as.data.frame(glasso_fit(S, rho = 0, zero = constrained)), unpenalised, reference = "glasso",
                   covers = c("glasso_fit()", "as.data.frame.glasso_result()"), quantity = "five entries constrained to zero, rho = 0",
                   tolerance = solver_tolerance, key = c("from", "to"))
})

test_that("a path of penalties is the fit at each penalty", {
  skip_without_reference("glasso")
  penalties <- c(0.05, 0.1, 0.2, 0.4)
  theirs <- do.call(rbind, lapply(penalties, \(rho) {
    cbind(rho = rho, glasso_edges(diary_correlations, rho = rho, penalize.diagonal = FALSE))
  }))
  # glasso_path() stops at 1e-4 by default, as glasso::glassopath() does; the reference is run to 1e-12, so the
  # path is run to the tolerances glasso_fit() uses, and both sides then sit at the one solution of each problem.
  path <- glasso_path(diary_correlations, rho = penalties, tol_outer = 1e-8, tol_inner = 1e-10)
  expect_reference(as.data.frame(path), theirs, reference = "glasso",
                   covers = c("glasso_path()", "as.data.frame.glasso_path_result()"), quantity = "diary items, path",
                   tolerance = solver_tolerance, key = c("rho", "from", "to"))
})

test_that("the optimality residual is the largest violation of the stationarity conditions", {
  skip_without_reference("glasso")
  # A precision matrix that solves the problem at rho = 0.1, judged against the problem at rho = 0.25: the
  # residual is then far from zero, so the comparison is of a number and not of two roundings of zero.
  precision <- glasso::glasso(diary_correlations, rho = 0.1, penalize.diagonal = FALSE, thr = 1e-12, maxit = 1e4)$wi
  gap <- solve(precision) - diary_correlations
  pairs <- upper.tri(precision)
  active <- abs(precision[pairs]) > 1e-8
  # Stationarity: W - S = rho * sign(Theta) on an edge, |W - S| <= rho off an edge, W_ii = S_ii.
  violation <- max(abs(diag(gap)),
                   abs(gap[pairs][active] - 0.25 * sign(precision[pairs][active])),
                   pmax(abs(gap[pairs][!active]) - 0.25, 0))
  # Sums and one matrix inverse of a 6 x 6 matrix on both sides.
  expect_reference(glasso_kkt(precision, S = diary_correlations, rho = 0.25), violation,
                   reference = "independent: graphical-lasso stationarity conditions (Friedman et al., 2008)",
                   covers = "glasso_kkt()", quantity = "residual of the rho = 0.1 solution in the rho = 0.25 problem",
                   tolerance = 1e-12)
  # The invariant: at glasso's own solution of the rho = 0.25 problem the conditions hold, so the residual is
  # zero up to the solver's convergence (thr = 1e-12 on the mean absolute change of the covariance).
  optimum <- glasso::glasso(diary_correlations, rho = 0.25, penalize.diagonal = FALSE, thr = 1e-12, maxit = 1e4)$wi
  expect_reference(glasso_kkt(optimum, S = diary_correlations, rho = 0.25), 0,
                   reference = "independent: graphical-lasso stationarity conditions (Friedman et al., 2008)",
                   covers = "glasso_kkt()", quantity = "residual of glasso's own rho = 0.25 solution (an optimum: zero)",
                   tolerance = 1e-6)
})
