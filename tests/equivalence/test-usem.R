# fit_usem(): the unified structural equation model (Kim, Zhu, Chang, Bentler & Ernst, 2007; Gates, Molenaar,
# Hillary, Ram & Rovine, 2010) fitted per person, with lagged (temporal) and same-occasion (contemporaneous)
# paths, reported as standardised coefficients (std.all).
#
# fit_usem() fits each person's model with lavaan, so a comparison with lavaan is declared `internal`: it checks
# the data preparation, the syntax and the extraction. The independent evidence is the definition: for a
# recursive model with uncorrelated residuals and the lagged variables exogenous, the maximum-likelihood
# estimates are each equation's least-squares estimates, and the model-implied variances of an equation's
# variables equal their sample variances, so a standardised coefficient is b * sd(x) / sd(y).

abc <- c("A", "B", "C")

#' One person's standardised least-squares coefficients of each equation, as coefs() shapes them
#'
#' @param series The person's series (one row per occasion, consecutive).
#' @param contemporaneous Named list: for each outcome, its same-occasion predictors.
usem_definition <- function(series, contemporaneous, subject) {
  lagged <- ref_lagged(series[abc])
  rows <- lapply(abc, \(outcome) {
    predictors <- c(contemporaneous[[outcome]], paste0(abc, "_lag"))
    fit <- stats::lm(stats::reformulate(predictors, response = outcome), data = lagged)
    spread <- vapply(lagged[predictors], stats::sd, numeric(1))
    standardised <- stats::coef(fit)[predictors] * spread / stats::sd(lagged[[outcome]])
    data.frame(subject = subject, network = ifelse(grepl("_lag$", predictors), "temporal", "contemporaneous"),
               from = sub("_lag$", "", predictors), to = outcome, weight = unname(standardised))
  })
  do.call(rbind, rows)
}

test_that("standardised coefficients of each person equal the standardised least-squares coefficients", {
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 60L, vars = abc, seed = 101L)
  fit <- fit_usem(panel, vars = abc, id = "id", day = "day", beep = "beep", temporal = "all",
                  contemporaneous = c("B ~ A", "C ~ B"), residual_cov = FALSE)
  theirs <- do.call(rbind, lapply(split(panel, panel$id), \(person) {
    usem_definition(person, list(B = "A", C = "B"), as.character(person$id[[1L]]))
  }))
  ours <- subset(coefs(fit), network != "residual_cov" & (network == "temporal" | weight != 0))
  # lavaan's quasi-Newton optimiser stops at its own convergence criterion; the maximum-likelihood estimate
  # equals the least-squares one only at the optimum. 1e-6 is far below any standard error and far above
  # rounding.
  expect_reference(ours, theirs,
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = c("fit_usem()", "coefs.net_usem()"), quantity = "three people, 59 lag pairs each",
                   tolerance = 1e-6, key = c("subject", "network", "from", "to"))
  averaged <- stats::aggregate(weight ~ network + from + to, data = theirs, FUN = mean)
  # API gap: matrices() returns a list of matrices, so each network is reached by name.
  temporal <- matrices(fit)[["temporal"]]
  expect_reference(ref_directed(temporal), subset(averaged, network == "temporal", select = -network),
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = c("fit_usem()", "matrices.net_usem()"), quantity = "temporal network averaged over people",
                   tolerance = 1e-6, key = c("from", "to"))
})

test_that("a standardised, robust model with residual covariances against lavaan (internal)", {
  skip_without_reference("lavaan")
  panel <- ref_panel(n_id = 2L, days = 1L, beeps = 42L, vars = abc, seed = 103L)
  fit <- fit_usem(panel, vars = abc, id = "id", day = "day", beep = "beep", temporal = "all",
                  contemporaneous = c("B ~ A", "C ~ B"), residual_cov = TRUE, standardize = TRUE, estimator = "mlr")
  syntax <- fit$syntax
  theirs <- do.call(rbind, lapply(split(panel, panel$id), \(person) {
    # Each person's series standardised, then each occasion beside the previous one (complete pairs only).
    pairs <- ref_lagged(as.data.frame(scale(person[abc])))
    names(pairs) <- sub("_lag$", "lag", names(pairs))
    model <- lavaan::lavaan(model = paste(syntax, collapse = "\n"), data = pairs, model.type = "sem",
                            missing = "fiml", estimator = "mlr", int.ov.free = FALSE, int.lv.free = TRUE,
                            auto.fix.first = TRUE, auto.var = TRUE, auto.cov.lv.x = TRUE, auto.th = TRUE,
                            auto.delta = TRUE, auto.cov.y = FALSE, auto.fix.single = TRUE, warn = FALSE)
    beta <- lavaan::lavInspect(model, "std")$beta
    lag_names <- paste0(abc, "lag")
    data.frame(subject = as.character(person$id[[1L]]),
               network = rep(c("temporal", "contemporaneous"), each = length(abc)^2),
               from = rep(rep(abc, each = length(abc)), 2L), to = rep(abc, 2L * length(abc)),
               weight = c(as.vector(beta[abc, lag_names]), as.vector(beta[abc, abc])))
  }))
  # The same lavaan model on both sides: 1e-10 as in the old test.
  expect_reference(subset(coefs(fit), network != "residual_cov"), theirs, reference = "lavaan",
                   covers = "fit_usem()", quantity = "two people, standardised, MLR", tolerance = 1e-10,
                   key = c("subject", "network", "from", "to"),
                   note = "Internal: fit_usem() fits the same lavaan model. API gap: the model syntax is read from the result.")
})

test_that("edges, node strengths and network summaries of the averaged uSEM networks", {
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 60L, vars = abc, seed = 101L)
  fit <- fit_usem(panel, vars = abc, id = "id", day = "day", beep = "beep", temporal = "all",
                  contemporaneous = c("B ~ A", "C ~ B"), residual_cov = FALSE)
  paths <- do.call(rbind, lapply(split(panel, panel$id), \(person) {
    usem_definition(person, list(B = "A", C = "B"), as.character(person$id[[1L]]))
  }))
  # Every person has every path of the model, so the averaged network is the mean over people. Both networks
  # are directed (from predictor to outcome); without residual covariances the third layer is empty.
  averaged <- stats::aggregate(weight ~ network + from + to, data = paths, FUN = mean)
  weights <- lapply(c(temporal = "temporal", contemporaneous = "contemporaneous"), \(layer) {
    cells <- matrix(0, 3L, 3L, dimnames = list(abc, abc))
    part <- subset(averaged, network == layer)
    cells[cbind(part$from, part$to)] <- part$weight
    cells
  })
  realised <- subset(averaged, weight != 0 & from != to)
  # Means of three least-squares coefficients, each within lavaan's 1e-6 of the optimum (above).
  expect_reference(edges(fit), realised,
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = c("edges.net_usem()", "fit_usem()"), quantity = "averaged networks, edges",
                   tolerance = 1e-6, key = c("network", "from", "to"))
  expect_reference(as.data.frame(fit), realised,
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = "as.data.frame.net_usem()", quantity = "averaged networks, the data frame of the fit",
                   tolerance = 1e-6, key = c("network", "from", "to"))
  strengths <- do.call(rbind, Map(\(cells, layer) {
    off <- abs(cells)
    diag(off) <- 0
    data.frame(network = layer, node = abc, strength = rowSums(off) + colSums(off), out_strength = rowSums(off),
               in_strength = colSums(off), self = diag(cells))
  }, weights, names(weights)))
  expect_reference(subset(nodes(fit), network != "residual_cov"), strengths,
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = "nodes.net_usem()", quantity = "averaged networks, node strengths", tolerance = 1e-6,
                   key = c("network", "node"))
  counts <- do.call(rbind, Map(\(cells, layer) {
    w <- cells[row(cells) != col(cells) & cells != 0]
    data.frame(network = layer, n_nodes = 3L, n_edges = length(w), density = length(w) / 6,
               mean_abs_weight = mean(abs(w)), n_positive = sum(w > 0), n_negative = sum(w < 0))
  }, weights, names(weights)))
  expect_reference(subset(summary(fit), network != "residual_cov"), counts,
                   reference = "independent: standardised least squares of a recursive model (ML = OLS)",
                   covers = "summary.net_usem()", quantity = "averaged networks, summary", tolerance = 1e-6,
                   key = "network")
})
