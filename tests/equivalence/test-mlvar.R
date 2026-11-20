# fit_mlvar(): the two-step multilevel VAR (Epskamp, Waldorp, Mottus & Borsboom, 2018) against
# mlVAR::mlVAR() 0.7.3 run directly on the same data and options.
#
# What this is evidence of. idiographic's native engine fits the node-wise mixed models with lme4, as mlVAR
# does; the comparison with mlVAR therefore checks idiographic's own data preparation, design, extraction of
# the fixed effects, residual and between-person networks against mlVAR's code, on the shared lme4 fit. Two
# further comparisons are declared `internal` and count for nothing: fit_mlvar(engine = "reference"), which
# calls mlVAR::mlVAR() from inside the package and converts its output (so a conversion error would be shared),
# and Nestimate::build_mlvar(), which calls idiographic::fit_mlvar() itself.
#
# Both sides fit the same mixed models with the same optimiser; they agree far below any standard error.
# 1e-8 is the bound of the package's own oracle tests against mlVAR (largest absolute difference).

items <- c("efficacy", "planning", "effort")
abc <- c("A", "B", "C")

#' mlVAR's temporal fixed effects with their standard errors, p-values and 95% intervals, as coefs() shapes them
mlvar_coefficients <- function(fit) {
  beta <- fit$results$Beta
  vars <- dimnames(beta$mean)[[1L]]
  cells <- expand.grid(outcome = vars, predictor = vars, stringsAsFactors = FALSE)
  at <- cbind(match(cells$outcome, vars), match(cells$predictor, vars), 1L)
  data.frame(cells, beta = beta$mean[at], se = beta$SE[at], p = beta$P[at], ci_lower = beta$lower[at],
             ci_upper = beta$upper[at])
}

run_mlvar <- function(data, vars, ...) {
  # mlVAR warns when a person has too few observations for a lag or a variance is estimated at zero; the
  # warnings concern mlVAR's own fit, which is the reference whatever it says.
  suppressWarnings(mlVAR::mlVAR(data, vars = vars, estimator = "lmer", verbose = FALSE, ...))
}

test_that("41 learners' diaries, fixed temporal and contemporaneous effects", {
  skip_without_reference("mlVAR")
  fit <- fit_mlvar(esm_srl, vars = items, id = "name", beep = "occasion")
  reference <- run_mlvar(esm_srl, items, idvar = "name", beepvar = "occasion", temporal = "fixed",
                         contemporaneous = "fixed", scale = FALSE)
  expect_reference(edges(fit, include_self = TRUE), mlvar_networks(reference), reference = "mlVAR",
                   covers = c("fit_mlvar()", "edges()", "edges.net_mlvar()"), quantity = "esm_srl, three networks",
                   tolerance = 1e-8, key = c("network", "from", "to"))
  # Standard errors, p-values and intervals come from the same lme4 fits: 1e-8 as for the estimates.
  expect_reference(coefs(fit), mlvar_coefficients(reference), reference = "mlVAR",
                   covers = c("fit_mlvar()", "coefs()", "coefs.net_mlvar()"),
                   quantity = "esm_srl, temporal fixed effects with standard errors and intervals",
                   tolerance = 1e-8, key = c("outcome", "predictor"))
  expect_reference(as.data.frame(fit), subset(mlvar_networks(reference), !(network == "temporal" & from == to)),
                   reference = "mlVAR", covers = c("fit_mlvar()", "as.data.frame.net_mlvar()"),
                   quantity = "esm_srl, the data frame of the fit", tolerance = 1e-8, key = c("network", "from", "to"))
})

test_that("node strengths and network summaries follow from mlVAR's networks", {
  skip_without_reference("mlVAR")
  fit <- fit_mlvar(esm_srl, vars = items, id = "name", beep = "occasion")
  networks <- mlvar_networks(run_mlvar(esm_srl, items, idvar = "name", beepvar = "occasion", temporal = "fixed",
                                       contemporaneous = "fixed", scale = FALSE))
  expect_reference(nodes(fit), ref_nodes(networks, items), reference = "mlVAR", covers = c("nodes()", "nodes.net_mlvar()"),
                   quantity = "esm_srl, node strengths", tolerance = 1e-8, key = c("network", "node"))
  expect_reference(summary(fit), ref_network_summary(networks, items), reference = "mlVAR",
                   covers = "summary.net_mlvar()", quantity = "esm_srl, network summary", tolerance = 1e-8, key = "network")
})

test_that("simulated panels with day and beep, an autoregression-only model, and several lags", {
  skip_without_reference("mlVAR")
  well_conditioned <- ref_panel(n_id = 20L, days = 6L, beeps = 10L, vars = abc, seed = 21L)
  cross_lagged <- ref_panel(n_id = 12L, days = 4L, beeps = 8L, vars = abc, between_sd = 0.4, seed = 1401L,
                            transition = matrix(c(0.32, -0.15, 0, 0.18, 0.28, 0, 0, -0.12, 0.25), 3L, byrow = TRUE))
  autoregressive <- ref_panel(n_id = 18L, days = 5L, beeps = 11L, vars = abc, seed = 31L)
  cases <- list(
    "20 people, 6 days of 10" = list(data = well_conditioned, ours = list(), theirs = list()),
    "12 people, cross-lagged" = list(data = cross_lagged, ours = list(), theirs = list()),
    "AR = TRUE" = list(data = autoregressive, ours = list(AR = TRUE), theirs = list(AR = TRUE))
  )
  tables <- Map(\(case, label) {
    ours <- do.call(fit_mlvar, c(list(data = case$data, vars = abc, id = "id", day = "day", beep = "beep"), case$ours))
    theirs <- do.call(run_mlvar, c(list(data = case$data, vars = abc, idvar = "id", dayvar = "day", beepvar = "beep",
                                        temporal = "fixed", contemporaneous = "fixed", scale = FALSE), case$theirs))
    list(ours = cbind(case = label, edges(ours, include_self = TRUE)), theirs = cbind(case = label, mlvar_networks(theirs)))
  }, cases, names(cases))
  ours <- do.call(rbind, lapply(tables, \(t) t$ours))
  theirs <- do.call(rbind, lapply(tables, \(t) t$theirs))
  # edges() leaves out a weight of exactly zero (the cross-lags of AR = TRUE), which mlVAR reports as 0.
  expect_reference(ours, subset(theirs, weight != 0), reference = "mlVAR", covers = c("fit_mlvar()", "edges.net_mlvar()"),
                   quantity = "simulated panels, three networks", tolerance = 1e-8,
                   key = c("case", "network", "from", "to"))
})

test_that("every random-effect structure lme4 supports", {
  skip_without_reference("mlVAR")
  panel <- ref_panel(n_id = 14L, days = 2L, beeps = 12L, vars = abc, seed = 905L)
  structures <- expand.grid(temporal = c("fixed", "correlated", "orthogonal"),
                            contemporaneous = c("fixed", "unique", "correlated", "orthogonal"), stringsAsFactors = FALSE)
  tables <- lapply(seq_len(nrow(structures)), \(row) {
    label <- sprintf("temporal %s, contemporaneous %s", structures$temporal[[row]], structures$contemporaneous[[row]])
    ours <- fit_mlvar(panel, vars = abc, id = "id", day = "day", beep = "beep", scale = FALSE,
                      temporal = structures$temporal[[row]], contemporaneous = structures$contemporaneous[[row]])
    theirs <- run_mlvar(panel, abc, idvar = "id", dayvar = "day", beepvar = "beep", scale = FALSE,
                        temporal = structures$temporal[[row]], contemporaneous = structures$contemporaneous[[row]])
    list(ours = cbind(case = label, edges(ours, include_self = TRUE)), theirs = cbind(case = label, mlvar_networks(theirs)))
  })
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), subset(do.call(rbind, lapply(tables, \(t) t$theirs)), weight != 0),
                   reference = "mlVAR", covers = c("fit_mlvar()", "edges.net_mlvar()"),
                   quantity = "14 people, twelve random-effect structures", tolerance = 1e-8,
                   key = c("case", "network", "from", "to"))
})

test_that("least-squares estimation with person-specific temporal effects", {
  skip_without_reference("mlVAR")
  panel <- ref_panel(n_id = 12L, days = 3L, beeps = 12L, vars = abc, seed = 816L)
  tables <- lapply(c("fixed", "unique", "correlated", "orthogonal"), \(mode) {
    ours <- fit_mlvar(panel, vars = abc, id = "id", day = "day", beep = "beep", estimator = "lm",
                      temporal = "unique", contemporaneous = mode)
    theirs <- suppressWarnings(mlVAR::mlVAR(panel, vars = abc, idvar = "id", dayvar = "day", beepvar = "beep",
                                            estimator = "lm", temporal = "unique", contemporaneous = mode, scale = FALSE,
                                            verbose = FALSE))
    list(ours = cbind(case = mode, edges(ours, include_self = TRUE)), theirs = cbind(case = mode, mlvar_networks(theirs)))
  })
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), subset(do.call(rbind, lapply(tables, \(t) t$theirs)), weight != 0),
                   reference = "mlVAR", covers = c("fit_mlvar()", "edges.net_mlvar()"),
                   quantity = "estimator = 'lm', temporal = 'unique'", tolerance = 1e-8,
                   key = c("case", "network", "from", "to"))
})

test_that("preparation controls against mlVAR called through the package (internal)", {
  skip_without_reference("mlVAR")
  panel <- ref_panel(n_id = 12L, days = 3L, beeps = 12L, vars = abc, seed = 813L)
  true_means <- stats::aggregate(panel[abc], list(id = panel$id), mean)
  cases <- list("scale and scaleWithin" = list(scale = TRUE, scaleWithin = TRUE), "lags 1 and 2" = list(lags = c(1L, 2L)),
                "lag 1 aligned to lags 1 and 2" = list(lags = 1L, compare_to_lags = c(1L, 2L)),
                "known person means" = list(true_means = true_means), "detrended by position" = list(detrend = "position"))
  tables <- Map(\(arguments, label) {
    call <- c(list(data = panel, vars = abc, id = "id", day = "day", beep = "beep"), arguments)
    ours <- suppressWarnings(do.call(fit_mlvar, call))
    theirs <- suppressWarnings(do.call(fit_mlvar, c(call, list(engine = "reference"))))
    list(ours = cbind(case = label, edges(ours, include_self = TRUE)),
         theirs = cbind(case = label, edges(theirs, include_self = TRUE)))
  }, cases, names(cases))
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), do.call(rbind, lapply(tables, \(t) t$theirs)),
                   reference = "mlVAR through fit_mlvar(engine = 'reference')", covers = "fit_mlvar()",
                   quantity = "preparation controls", tolerance = 1e-8, key = c("case", "network", "from", "to"),
                   note = "Internal: the reference is mlVAR::mlVAR() called and converted by idiographic itself.")
})

test_that("Nestimate::build_mlvar() calls fit_mlvar() and reads the temporal matrix the other way round (internal)", {
  skip_without_reference("Nestimate")
  panel <- ref_panel(n_id = 12L, days = 8L, beeps = 6L, vars = abc, seed = 5150L)
  ours <- fit_mlvar(panel, vars = abc, id = "id", day = "day", beep = "beep", lags = 1L, scale = FALSE)
  theirs <- suppressMessages(Nestimate::build_mlvar(panel, vars = abc, id = "id", day = "day", beep = "beep",
                                                    lag = 1L, standardize = FALSE))
  # API gap: matrices() returns a list of matrices, so each layer is reached by name.
  layers <- matrices(ours)
  expect_known_difference(layers[["temporal"]], theirs$temporal$weights,
                          reference = "Nestimate", covers = c("fit_mlvar()", "matrices.net_mlvar()"),
                          quantity = "temporal matrix as stored", tolerance = 0,
                          reason = "Nestimate::build_mlvar() (>= 1.0.10) stores t(fit_mlvar()$temporal$weights): a network object reads its weights from row to column, predictor to outcome; idiographic keeps one row per outcome.",
                          agrees_with = "t() of Nestimate's temporal matrix")
  expect_reference(layers[["temporal"]], t(theirs$temporal$weights), reference = "Nestimate",
                   covers = c("fit_mlvar()", "matrices.net_mlvar()"), quantity = "temporal matrix, transposed back",
                   tolerance = 0)
  expect_reference(layers[["contemporaneous"]], theirs$contemporaneous$weights, reference = "Nestimate",
                   covers = c("fit_mlvar()", "matrices.net_mlvar()"), quantity = "contemporaneous matrix", tolerance = 0)
  expect_reference(layers[["between"]], theirs$between$weights, reference = "Nestimate",
                   covers = c("fit_mlvar()", "matrices.net_mlvar()"), quantity = "between matrix", tolerance = 0)
})
