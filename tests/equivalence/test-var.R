# fit_var(), fit_var_each(), fit_rolling_var(), fit_idiographic(method = "var"): the person-specific VAR(1) by
# least squares, against stats::lm() on the lagged, standardised series. Temporal weights are the regression
# coefficients of each variable on the previous occasion's variables; contemporaneous weights are the partial
# correlations of the residuals.
#
# Closed-form least squares on at most 155 rows, solved by QR on both sides: the sides can differ only by
# rounding, so 1e-10.

items <- c("efficacy", "planning", "effort")

#' The VAR(1) of one series by stats::lm(), as idiographic's coefficient table
#'
#' @param series A data frame of the variables, in time order, with consecutive occasions and no missing value.
#' @param vars The variables.
#' @param standardise Whether each variable is first standardised over the series.
var_reference <- function(series, vars, standardise = TRUE) {
  stopifnot("the reference needs complete rows" = !anyNA(series[vars]))
  values <- if (standardise) as.data.frame(scale(series[vars])) else series[vars]
  lagged <- ref_lagged(values)
  formula <- stats::as.formula(sprintf("cbind(%s) ~ %s", toString(vars), paste0(vars, "_lag", collapse = " + ")))
  fit <- stats::lm(formula, data = lagged)
  # coef(): one row per predictor (after the intercept), one column per outcome.
  temporal <- ref_named(t(stats::coef(fit)[-1L, , drop = FALSE]), vars)
  partial <- ref_named(ref_partial(solve(stats::cov(stats::residuals(fit)))), vars)
  ref_network(temporal = temporal, contemporaneous = partial)
}

test_that("one learner's diary: temporal coefficients and contemporaneous partial correlations", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  stopifnot("the occasions are consecutive" = all(diff(learner$occasion) == 1L))
  fit <- fit_var(learner, vars = items, beep = "occasion")
  expect_reference(coefs(fit), var_reference(learner, items), reference = "stats",
                   covers = c("fit_var()", "coefs()", "coefs.var_result()"), quantity = "Tariq, standardised",
                   tolerance = 1e-10, key = c("network", "from", "to"),
                   note = "esm_srl, learner Tariq: 78 consecutive daily occasions.")
  expect_reference(as.data.frame(fit), subset(var_reference(learner, items), !(network == "temporal" & from == to)),
                   reference = "stats", covers = c("as.data.frame.var_result()", "edges()", "edges.var_result()"),
                   quantity = "Tariq, the data frame of the fit", tolerance = 1e-10, key = c("network", "from", "to"))
  through_registry <- fit_idiographic(learner, method = "var", vars = items, beep = "occasion")
  expect_reference(coefs(through_registry), var_reference(learner, items), reference = "stats",
                   covers = "fit_idiographic()", quantity = "Tariq, through fit_idiographic(method = 'var')",
                   tolerance = 1e-10, key = c("network", "from", "to"))
})

test_that("unstandardised series", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  fit <- fit_var(learner, vars = items, beep = "occasion", scale = FALSE)
  expect_reference(coefs(fit), var_reference(learner, items, standardise = FALSE), reference = "stats",
                   covers = c("fit_var()", "coefs.var_result()"), quantity = "Tariq, raw scale",
                   tolerance = 1e-10, key = c("network", "from", "to"))
})

test_that("one VAR per person equals stats::lm() on each person", {
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"), select = c(name, day, efficacy, planning, effort))
  fit <- fit_var_each(three, vars = items, id = "name", beep = "day")
  theirs <- do.call(rbind, lapply(split(three, three$name), \(learner) {
    stopifnot("the days are consecutive" = all(diff(learner$day) == 1L))
    cbind(subject = learner$name[[1L]], var_reference(learner, items))
  }))
  expect_reference(coefs(fit), theirs, reference = "stats", covers = c("fit_var_each()", "coefs.var_list()"),
                   quantity = "three learners, 156 days", tolerance = 1e-10, key = c("subject", "network", "from", "to"))
  expect_reference(as.data.frame(fit), theirs, reference = "stats",
                   covers = c("fit_var_each()", "as.data.frame.var_list()"),
                   quantity = "three learners, the data frame of the fits", tolerance = 1e-10,
                   key = c("subject", "network", "from", "to"))
})

test_that("a rolling window is the VAR of the rows in the window", {
  learner <- subset(srl, name == "Aisha", select = c(day, efficacy, effort))
  vars <- c("efficacy", "effort")
  fit <- fit_rolling_var(learner, vars = vars, beep = "day", window_size = 50, step = 25)
  starts <- seq(1L, nrow(learner) - 49L, by = 25L)
  theirs <- do.call(rbind, lapply(seq_along(starts), \(window) {
    rows <- learner[seq(starts[[window]], length.out = 50L), ]
    cbind(window = window, var_reference(rows, vars))
  }))
  expect_reference(coefs(fit), theirs, reference = "stats",
                   covers = c("fit_rolling_var()", "coefs.rolling_var_result()"),
                   quantity = "Aisha, windows of 50 days every 25", tolerance = 1e-10,
                   key = c("window", "network", "from", "to"))
  expect_reference(as.data.frame(fit), theirs, reference = "stats",
                   covers = c("fit_rolling_var()", "as.data.frame.rolling_var_result()"),
                   quantity = "Aisha, the data frame of the windows", tolerance = 1e-10,
                   key = c("window", "network", "from", "to"))
})

test_that("node strengths, network summaries, edges and residual covariance follow from the least-squares fit", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  fit <- fit_var(learner, vars = items, beep = "occasion")
  theirs <- var_reference(learner, items)
  expect_reference(nodes(fit), ref_nodes(theirs, items),
                   reference = "independent: node strengths of the stats::lm networks",
                   covers = c("nodes()", "nodes.var_result()"), quantity = "Tariq, node strengths", tolerance = 1e-10,
                   key = c("network", "node"))
  expect_reference(summary(fit), ref_network_summary(theirs, items),
                   reference = "independent: edge counts and mean weights of the stats::lm networks",
                   covers = "summary.var_result()", quantity = "Tariq, network summary", tolerance = 1e-10, key = "network")
  # The same strengths and counts computed by igraph on the stats::lm networks.
  expect_reference(nodes(fit), igraph_nodes(theirs, items), reference = "igraph",
                   covers = c("nodes()", "nodes.var_result()"), quantity = "Tariq, node strengths by igraph::strength()",
                   tolerance = 1e-10, key = c("network", "node"))
  expect_reference(summary(fit), igraph_summary(theirs, items), reference = "igraph",
                   covers = "summary.var_result()", quantity = "Tariq, network summary by igraph",
                   tolerance = 1e-10, key = "network")
  values <- as.data.frame(scale(learner[items]))
  lagged <- ref_lagged(values)
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + "))),
                     data = lagged)
  # API gap: matrices() returns a list of matrices, so the residual covariance is reached by name.
  expect_reference(matrices(fit)[["residual_cov"]], ref_named(stats::cov(stats::residuals(model)), items),
                   reference = "stats", covers = c("matrices.var_result()", "fit_var()"),
                   quantity = "Tariq, residual covariance", tolerance = 1e-10)
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"), select = c(name, day, efficacy, planning, effort))
  each <- fit_var_each(three, vars = items, id = "name", beep = "day")
  per_person <- lapply(split(three, three$name), \(person) var_reference(person, items))
  stacked <- do.call(rbind, Map(\(table, subject) cbind(subject = subject, table), per_person, names(per_person)))
  expect_reference(edges(each), subset(stacked, !(network == "temporal" & from == to)), reference = "stats",
                   covers = c("edges.var_list()", "fit_var_each()"), quantity = "three learners, edges",
                   tolerance = 1e-10, key = c("subject", "network", "from", "to"))
  expect_reference(nodes(each),
                   do.call(rbind, Map(\(table, subject) cbind(subject = subject, ref_nodes(table, items)), per_person, names(per_person))),
                   reference = "independent: node strengths of the stats::lm networks",
                   covers = "nodes.var_list()", quantity = "three learners, node strengths", tolerance = 1e-10,
                   key = c("subject", "network", "node"))
  expect_reference(summary(each),
                   do.call(rbind, Map(\(table, subject) cbind(subject = subject, ref_network_summary(table, items)), per_person, names(per_person))),
                   reference = "independent: edge counts and mean weights of the stats::lm networks",
                   covers = "summary.var_list()", quantity = "three learners, network summaries", tolerance = 1e-10,
                   key = c("subject", "network"))
  by_igraph <- \(fun) do.call(rbind, Map(\(table, subject) cbind(subject = subject, fun(table, items)), per_person,
                                         names(per_person)))
  expect_reference(nodes(each), by_igraph(igraph_nodes), reference = "igraph", covers = "nodes.var_list()",
                   quantity = "three learners, node strengths by igraph::strength()", tolerance = 1e-10,
                   key = c("subject", "network", "node"))
  expect_reference(summary(each), by_igraph(igraph_summary), reference = "igraph", covers = "summary.var_list()",
                   quantity = "three learners, network summaries by igraph", tolerance = 1e-10,
                   key = c("subject", "network"))
})

test_that("per-person and per-window matrices, and the summary of the windows", {
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"), select = c(name, day, efficacy, planning, effort))
  each <- fit_var_each(three, vars = items, id = "name", beep = "day")
  alice <- subset(three, name == "Alice")
  values <- as.data.frame(scale(alice[items]))
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + "))),
                     data = ref_lagged(values))
  # API gap: matrices() returns a list of matrices, so each matrix is reached by name.
  expect_reference(matrices(each, subject = "Alice", print = FALSE)[["temporal"]],
                   ref_named(t(stats::coef(model)[-1L, , drop = FALSE]), items),
                   reference = "stats", covers = c("matrices.var_list()", "fit_var_each()"),
                   quantity = "Alice, temporal coefficients (outcome rows)", tolerance = 1e-10)
  expect_reference(matrices(each, subject = "Alice", print = FALSE)[["residual_cov"]],
                   ref_named(stats::cov(stats::residuals(model)), items),
                   reference = "stats", covers = "matrices.var_list()", quantity = "Alice, residual covariance",
                   tolerance = 1e-10)
  learner <- subset(srl, name == "Aisha", select = c(day, efficacy, effort))
  pair <- c("efficacy", "effort")
  rolling <- fit_rolling_var(learner, vars = pair, beep = "day", window_size = 50, step = 25, keep_fits = TRUE)
  starts <- seq(1L, nrow(learner) - 49L, by = 25L)
  theirs <- do.call(rbind, lapply(seq_along(starts), \(window) {
    cbind(window = window, var_reference(learner[seq(starts[[window]], length.out = 50L), ], pair))
  }))
  expect_reference(summary(rolling), theirs, reference = "stats", covers = "summary.rolling_var_result()",
                   quantity = "Aisha, the summary of the windows", tolerance = 1e-10,
                   key = c("window", "network", "from", "to"))
  second <- learner[seq(starts[[2L]], length.out = 50L), ]
  window_model <- stats::lm(cbind(efficacy, effort) ~ efficacy_lag + effort_lag,
                            data = ref_lagged(as.data.frame(scale(second[pair]))))
  expect_reference(matrices(rolling, fit = 2L, print = FALSE)[["temporal"]],
                   ref_named(t(stats::coef(window_model)[-1L, , drop = FALSE]), pair),
                   reference = "stats", covers = c("matrices.rolling_var_result()", "fit_rolling_var()"),
                   quantity = "Aisha, second window, temporal coefficients", tolerance = 1e-10)
})
