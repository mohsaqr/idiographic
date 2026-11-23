# fit_var_bayes(), coefs() and summary() of its result: the Bayesian VAR(1) with a flat prior on the coefficients
# and on the residual covariance, sampled by a two-block Gibbs sampler. Its posterior is known in closed form
# (Zellner, 1971, ch. 8): with n lag pairs, q = p + 1 regressors (intercept and p lags), the least-squares
# coefficients B and residual cross-products S, the residual covariance is inverse Wishart IW(S, n - 2q) and each
# coefficient B_ij is Student t with nu = n - 2q - p + 1 degrees of freedom, centre B_ij (the stats::lm()
# estimate) and scale^2 = [(X'X)^-1]_ii S_jj / nu. So the posterior median of a coefficient is its least-squares
# estimate, its SD scale sqrt(nu / (nu - 2)), its 95% interval the t quantiles, and the reported tail
# probability min(P(B > 0), P(B < 0)) = pt(-|B_ij| / scale, nu).
#
# The sampler's numbers are Monte Carlo estimates, so the tolerances are 4 Monte Carlo standard errors, fixed
# before the run from the effective number of draws (coda::effectiveSize() on each chain, summed; the smallest
# over the coefficients): a median, 1.2533 sd / sqrt(ESS); an SD, sd sqrt((kappa - 1) / (4 ESS)) with the
# t kurtosis kappa = 3 + 6 / (nu - 4); a 2.5% or 97.5% quantile, sqrt(0.025 0.975 / ESS) / f(q) with f the
# posterior density at the quantile; a tail probability, sqrt(P (1 - P) / ESS) at its largest, 0.5 / sqrt(ESS).
#
# The reference is the closed form (an independent computation): stats::lm() supplies the least-squares centre,
# but no other software computes this posterior, so no row is labelled as stats' number.

items <- c("efficacy", "planning", "effort")
draws_per_chain <- 10000L

#' The closed-form posterior of the VAR(1) of a standardised series, one row per outcome and predictor
closed_form_posterior <- function(series, vars) {
  lagged <- ref_lagged(as.data.frame(scale(series[vars])))
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(vars), paste0(vars, "_lag", collapse = " + "))),
                     data = lagged)
  X <- stats::model.matrix(model)
  n <- nrow(X)
  q <- ncol(X)
  p <- length(vars)
  nu <- n - 2 * q - p + 1
  unscaled <- diag(solve(crossprod(X)))[-1L]
  cross <- diag(crossprod(stats::residuals(model)))
  cells <- expand.grid(outcome = seq_len(p), predictor = seq_len(p))
  centre <- stats::coef(model)[-1L, , drop = FALSE][cbind(cells$predictor, cells$outcome)]
  scale <- sqrt(unscaled[cells$predictor] * cross[cells$outcome] / nu)
  data.frame(outcome = vars[cells$outcome], predictor = vars[cells$predictor], estimate = unname(centre),
             posterior_sd = unname(scale * sqrt(nu / (nu - 2))),
             ci_lower = unname(centre + stats::qt(0.025, nu) * scale), ci_upper = unname(centre + stats::qt(0.975, nu) * scale),
             p = unname(stats::pt(-abs(centre) / scale, nu)), scale = unname(scale), nu = nu)
}

#' The smallest effective number of draws over the coefficients, the chains' effective sizes summed
smallest_ess <- function(fit, chains) {
  draws <- fit$posterior$B
  per_chain <- dim(draws)[[3L]] / chains
  cells <- which(array(TRUE, dim(draws)[1:2]), arr.ind = TRUE)
  min(vapply(seq_len(nrow(cells)), \(cell) {
    values <- draws[cells[cell, 1L], cells[cell, 2L], ]
    sum(vapply(seq_len(chains), \(chain) {
      unname(coda::effectiveSize(values[(chain - 1L) * per_chain + seq_len(per_chain)]))
    }, numeric(1)))
  }, numeric(1)))
}

test_that("the posterior of one learner's VAR(1) is the closed-form matrix-t posterior (Monte Carlo summary)", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  exact <- closed_form_posterior(learner, items)
  invisible(lapply(1:3, \(seed) {
    fit <- fit_var_bayes(learner, vars = items, beep = "occasion", n_iter = 2L * draws_per_chain, seed = seed)
    ess <- smallest_ess(fit, chains = 2L)
    sd_max <- max(exact$posterior_sd)
    expect_reference(coefs(fit), exact[c("outcome", "predictor", "estimate")],
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = c("fit_var_bayes()", "coefs.var_bayes_result()"),
                     quantity = sprintf("Monte Carlo summary: posterior medians against the stats::lm() coefficients, seed %d", seed),
                     tolerance = 4 * 1.2533 * sd_max / sqrt(ess), key = c("outcome", "predictor"),
                     note = "Statistical evidence: the posterior median of a flat-prior VAR coefficient is its least-squares estimate; tolerance 4 Monte Carlo standard errors.")
    kappa <- 3 + 6 / (exact$nu[[1L]] - 4)
    expect_reference(coefs(fit), exact[c("outcome", "predictor", "posterior_sd")],
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = c("fit_var_bayes()", "coefs.var_bayes_result()"),
                     quantity = sprintf("Monte Carlo summary: posterior SDs, seed %d", seed),
                     tolerance = 4 * sd_max * sqrt((kappa - 1) / (4 * ess)), key = c("outcome", "predictor"))
    density <- min(stats::dt(stats::qt(0.975, exact$nu[[1L]]), exact$nu[[1L]]) / exact$scale)
    expect_reference(coefs(fit), exact[c("outcome", "predictor", "ci_lower", "ci_upper")],
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = c("fit_var_bayes()", "coefs.var_bayes_result()"),
                     quantity = sprintf("Monte Carlo summary: 95%% posterior intervals, seed %d", seed),
                     tolerance = 4 * sqrt(0.025 * 0.975 / ess) / density, key = c("outcome", "predictor"))
    expect_reference(coefs(fit), exact[c("outcome", "predictor", "p")],
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = c("fit_var_bayes()", "coefs.var_bayes_result()"),
                     quantity = sprintf("Monte Carlo summary: posterior tail probabilities, seed %d", seed),
                     tolerance = 4 * 0.5 / sqrt(ess), key = c("outcome", "predictor"))
    off <- exact[exact$outcome != exact$predictor, ]
    temporal <- data.frame(network = "temporal", n_nodes = 3L, n_edges = sum(off$estimate != 0),
                           density = sum(off$estimate != 0) / 6, mean_abs_weight = mean(abs(off$estimate)),
                           n_positive = sum(off$estimate > 0), n_negative = sum(off$estimate < 0))
    # |a| - |b| <= |a - b|, so a mean of absolute medians is within the medians' tolerance.
    expect_reference(subset(summary(fit), network == "temporal"), temporal,
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = c("summary.var_bayes_result()", "fit_var_bayes()"),
                     quantity = sprintf("Monte Carlo summary: temporal layer against the stats::lm() coefficients, seed %d", seed),
                     tolerance = 4 * 1.2533 * sd_max / sqrt(ess), key = "network")
    ols <- matrix(0, 3L, 3L, dimnames = list(items, items))
    ols[cbind(exact$predictor, exact$outcome)] <- exact$estimate
    expect_reference(matrices(as_netobject(fit)[["temporal"]], print = FALSE)[["weights"]], ols,
                     reference = "independent: the closed-form matrix-t posterior of the flat-prior VAR (Zellner, 1971)",
                     covers = "as_netobject.var_bayes_result()",
                     quantity = sprintf("Monte Carlo summary: temporal layer of as_netobject() (predictor rows), seed %d", seed),
                     tolerance = 4 * 1.2533 * sd_max / sqrt(ess))
  }))
})

test_that("parameter recovery: a long simulab VAR(1) series, by least squares and by the Bayesian VAR", {
  truth <- matrix(c(0.5, 0.2, -0.1, 0.3), 2L, 2L, byrow = TRUE, dimnames = list(c("A", "B"), c("A", "B")))
  invisible(lapply(1:3, \(seed) {
    series <- as.data.frame(simulab::simulate_longitudinal(n = 1, occasions = 600, transition = truth, seed = seed))
    lagged <- ref_lagged(series[c("A", "B")])
    model <- stats::lm(cbind(A, B) ~ A_lag + B_lag, data = lagged)
    # Each coefficient's standard error from stats::lm(), the larger of the two outcomes: the sampling error the
    # recovery tolerance is 4 times.
    se <- max(sqrt(diag(stats::vcov(model))))
    expected <- data.frame(network = "temporal", from = rep(c("A", "B"), each = 2L), to = rep(c("A", "B"), 2L),
                           weight = as.vector(truth))
    expect_reference(subset(coefs(fit_var(series, vars = c("A", "B"), beep = "occasion", scale = FALSE)), network == "temporal"),
                     expected, reference = "independent: recovery of the parameters of simulab simulate_longitudinal()",
                     covers = "fit_var()", quantity = sprintf("600 occasions, transition matrix, seed %d", seed),
                     tolerance = 4 * se, key = c("network", "from", "to"),
                     note = "Recovery: the generator's transition matrix; tolerance 4 standard errors of the estimate.")
    bayes <- fit_var_bayes(series, vars = c("A", "B"), beep = "occasion", scale = FALSE, n_iter = 4000L, seed = seed)
    expect_reference(coefs(bayes),
                     data.frame(outcome = rep(c("A", "B"), 2L), predictor = rep(c("A", "B"), each = 2L),
                                estimate = as.vector(truth)),
                     reference = "independent: recovery of the parameters of simulab simulate_longitudinal()",
                     covers = c("fit_var_bayes()", "coefs.var_bayes_result()"),
                     quantity = sprintf("600 occasions, posterior medians against the transition matrix, seed %d", seed),
                     tolerance = 4 * se, key = c("outcome", "predictor"))
  }))
})

test_that("parameter recovery: a simulab multilevel VAR(1) panel by the multilevel Bayesian VAR", {
  truth <- matrix(c(0.4, 0.15, 0, 0.3), 2L, 2L, byrow = TRUE, dimnames = list(c("A", "B"), c("A", "B")))
  invisible(lapply(1:3, \(seed) {
    panel <- as.data.frame(simulab::simulate_longitudinal(n = 40, occasions = 80, transition = truth,
                                                          between_covariance = diag(0.5, 2L), seed = seed))
    # The sampling error: pooled least squares of the person-centred series on their lags (every person has the
    # same transition matrix, so this is the efficient estimator's error, up to the centring).
    centred <- do.call(rbind, lapply(split(panel, panel$id), \(person) {
      ref_lagged(as.data.frame(scale(person[c("A", "B")], scale = FALSE)))
    }))
    se <- max(sqrt(diag(stats::vcov(stats::lm(cbind(A, B) ~ A_lag + B_lag, data = centred)))))
    fit <- fit_mlvar_bayes(panel, vars = c("A", "B"), id = "id", beep = "occasion", scale = FALSE, n_iter = 2000L,
                           seed = seed)
    expect_reference(coefs(fit),
                     data.frame(outcome = rep(c("A", "B"), 2L), predictor = rep(c("A", "B"), each = 2L),
                                estimate = as.vector(truth)),
                     reference = "independent: recovery of the parameters of simulab simulate_longitudinal()",
                     covers = c("fit_mlvar_bayes()", "coefs.net_mlvar_bayes()"),
                     quantity = sprintf("40 people x 80 occasions, fixed temporal effects, seed %d", seed),
                     tolerance = 4 * se, key = c("outcome", "predictor"),
                     note = "Recovery: the generator's transition matrix; tolerance 4 standard errors of the pooled within-person estimate.")
  }))
})
