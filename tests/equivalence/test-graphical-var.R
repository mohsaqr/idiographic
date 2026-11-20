# fit_graphical_var(), fit_graphical_var_each(): the regularised graphical VAR (Wild et al., 2010;
# Epskamp, Waldorp, Mottus & Borsboom, 2018) against graphicalVAR::graphicalVAR() 0.4.1 on the same data,
# grid size, EBIC gamma and options. idiographic ports the estimator (no call to graphicalVAR in the source).
#
# Both sides iterate (coordinate descent inside an alternating scheme) to their own convergence thresholds and
# pick the penalties on the same grid, so they agree to those thresholds and not to rounding. The tolerances are
# the ones the package's own oracle tests used: 1e-6 where the old test bounded the largest absolute
# difference, 1e-4 and 1e-3 where it bounded testthat's mean relative difference (stated per test).

items <- c("efficacy", "planning", "effort")
abc <- c("A", "B", "C")

#' graphicalVAR's estimate as idiographic's coefficient table: the temporal coefficients (`beta` without its
#' intercept, one row per outcome) and the partial contemporaneous correlations
gvar_reference <- function(data, vars, ...) {
  fit <- graphicalVAR::graphicalVAR(data, vars = vars, verbose = FALSE, ...)
  ref_network(temporal = ref_named(fit$beta[, -1L, drop = FALSE], vars)[vars, vars],
              contemporaneous = ref_named(fit$PCC, vars))
}

#' graphicalVAR's precision matrix of the innovations as a table of the upper triangle and the diagonal
gvar_kappa <- function(data, vars, ...) {
  kappa <- ref_named(graphicalVAR::graphicalVAR(data, vars = vars, verbose = FALSE, ...)$kappa, vars)
  cells <- which(upper.tri(kappa, diag = TRUE), arr.ind = TRUE)
  data.frame(from = vars[cells[, "row"]], to = vars[cells[, "col"]], kappa = kappa[cells])
}

#' The same cells of idiographic's kappa. API gap: matrices() returns a list of matrices, so the precision
#' matrix is reached by name.
own_kappa <- function(fit, vars) {
  kappa <- matrices(fit)[["kappa"]]
  cells <- which(upper.tri(kappa, diag = TRUE), arr.ind = TRUE)
  data.frame(from = vars[cells[, "row"]], to = vars[cells[, "col"]], kappa = kappa[cells])
}

test_that("one learner's diary, penalties chosen by BIC on a 15 x 15 grid", {
  skip_without_reference("graphicalVAR")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  fit <- fit_graphical_var(learner, vars = items, beep = "occasion", n_lambda = 15, gamma = 0)
  # 1e-4: the bound of the package's fixture test against graphicalVAR (tests/testthat, mean relative).
  expect_reference(coefs(fit), gvar_reference(learner, items, beepvar = "occasion", nLambda = 15, gamma = 0),
                   reference = "graphicalVAR", covers = c("fit_graphical_var()", "coefs()", "coefs.gvar_result()"),
                   quantity = "Tariq, EBIC gamma = 0", tolerance = 1e-4, key = c("network", "from", "to"),
                   note = "esm_srl, learner Tariq: 78 consecutive daily occasions.")
  expect_reference(own_kappa(fit, items), gvar_kappa(learner, items, beepvar = "occasion", nLambda = 15, gamma = 0),
                   reference = "graphicalVAR", covers = c("fit_graphical_var()", "matrices()", "matrices.gvar_result()"),
                   quantity = "Tariq, precision of the innovations", tolerance = 1e-4, key = c("from", "to"))
})

test_that("the edge table holds the non-zero coefficients", {
  skip_without_reference("graphicalVAR")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  fit <- fit_graphical_var(learner, vars = items, beep = "occasion", n_lambda = 15, gamma = 0)
  theirs <- subset(gvar_reference(learner, items, beepvar = "occasion", nLambda = 15, gamma = 0),
                   weight != 0 & !(network == "temporal" & from == to))
  expect_reference(edges(fit), theirs, reference = "graphicalVAR",
                   covers = c("edges()", "edges.gvar_result()", "as.data.frame.gvar_result()"),
                   quantity = "Tariq, non-zero edges without self-loops", tolerance = 1e-4,
                   key = c("network", "from", "to"))
  expect_reference(as.data.frame(fit), theirs, reference = "graphicalVAR",
                   covers = "as.data.frame.gvar_result()", quantity = "Tariq, the data frame of the fit",
                   tolerance = 1e-4, key = c("network", "from", "to"))
})

test_that("a simulated series across the options graphicalVAR offers", {
  skip_without_reference("graphicalVAR")
  series <- ref_panel(n_id = 1L, days = 15L, beeps = 10L, vars = abc, ar = 0.4, between_sd = 0, seed = 812L)
  mask_beta <- matrix(c(0, 1, 1, 1, 0, 1, 1, 1, 0), 3L, 3L, byrow = TRUE)
  cases <- list(
    "gamma = 0" = list(ours = list(gamma = 0), theirs = list(gamma = 0)),
    "unpenalised autoregression" = list(ours = list(penalize_diagonal = FALSE), theirs = list(penalize.diagonal = FALSE)),
    "fixed lambda_kappa = 0.1" = list(ours = list(lambda_kappa = 0.1), theirs = list(lambda_kappa = 0.1)),
    "beta penalty mask" = list(ours = list(regularize_mat_beta = mask_beta), theirs = list(regularize_mat_beta = mask_beta)),
    "penalised likelihood" = list(ours = list(likelihood = "penalized"), theirs = list(likelihood = "penalized")),
    "both penalties fixed at 0.08" = list(ours = list(lambda_beta = 0.08, lambda_kappa = 0.08),
                                          theirs = list(lambda_beta = 0.08, lambda_kappa = 0.08))
  )
  tables <- Map(\(case, label) {
    ours <- do.call(fit_graphical_var, c(list(data = series, vars = abc, id = "id", day = "day", beep = "beep",
                                              n_lambda = 15, verbose = FALSE), case$ours))
    theirs <- do.call(gvar_reference, c(list(data = series, vars = abc, idvar = "id", dayvar = "day",
                                             beepvar = "beep", nLambda = 15), case$theirs))
    list(ours = cbind(case = label, coefs(ours)), theirs = cbind(case = label, theirs))
  }, cases, names(cases))
  # 1e-6: the old test's bound (largest absolute difference across beta and kappa).
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), do.call(rbind, lapply(tables, \(t) t$theirs)),
                   reference = "graphicalVAR", covers = c("fit_graphical_var()", "coefs.gvar_result()"),
                   quantity = "simulated series, six option sets", tolerance = 1e-6,
                   key = c("case", "network", "from", "to"))
})

test_that("penalty minima, a kappa mask and an unpenalised fixed lambda_beta", {
  skip_without_reference("graphicalVAR")
  series <- ref_panel(n_id = 1L, days = 15L, beeps = 10L, vars = abc, ar = 0.4, between_sd = 0, seed = 23L)
  open_mask <- matrix(TRUE, 3L, 3L)
  kappa_mask <- open_mask
  diag(kappa_mask) <- FALSE
  kappa_mask[1L, 2L] <- kappa_mask[2L, 1L] <- FALSE
  cases <- list(
    "lambda_min_beta = 0.01" = list(ours = list(lambda_min_beta = 0.01), theirs = list(lambda_min_beta = 0.01)),
    "kappa mask, diagonal free" = list(ours = list(regularize_mat_kappa = kappa_mask),
                                       theirs = list(regularize_mat_kappa = kappa_mask)),
    "kappa mask, diagonal penalised" = list(ours = list(regularize_mat_kappa = open_mask),
                                            theirs = list(regularize_mat_kappa = open_mask)),
    "fixed lambda_beta = 0.1, gamma = 0.5" = list(ours = list(lambda_beta = 0.1, gamma = 0.5),
                                                  theirs = list(lambda_beta = 0.1, gamma = 0.5))
  )
  tables <- Map(\(case, label) {
    ours <- do.call(fit_graphical_var, c(list(data = series, vars = abc, id = "id", n_lambda = 20), case$ours))
    theirs <- do.call(gvar_reference, c(list(data = series[abc], vars = abc, nLambda = 20), case$theirs))
    list(ours = cbind(case = label, coefs(ours)), theirs = cbind(case = label, theirs))
  }, cases, names(cases))
  # 1e-3: the old test's bound for these options (testthat's mean relative difference).
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), do.call(rbind, lapply(tables, \(t) t$theirs)),
                   reference = "graphicalVAR", covers = c("fit_graphical_var()", "coefs.gvar_result()"),
                   quantity = "simulated series, penalty options", tolerance = 1e-3,
                   key = c("case", "network", "from", "to"))
})

test_that("several people, days, missing values and grid options", {
  skip_without_reference("graphicalVAR")
  panel <- ref_panel(n_id = 8L, days = 2L, beeps = 12L, vars = abc, seed = 906L)
  with_missing <- panel
  with_missing$A[c(4L, 30L)] <- NA_real_
  cases <- list(
    "not centred within person" = list(data = panel, ours = list(center_within = FALSE, n_lambda = 10),
                                       theirs = list(centerWithin = FALSE, nLambda = 10)),
    "lambda minima 0.2 and 0.1" = list(data = panel,
                                       ours = list(lambda_min_kappa = 0.2, lambda_min_beta = 0.1, n_lambda = 10),
                                       theirs = list(lambda_min_kappa = 0.2, lambda_min_beta = 0.1, nLambda = 10)),
    "two missing values deleted" = list(data = with_missing, ours = list(delete_missings = TRUE, n_lambda = 8),
                                        theirs = list(deleteMissings = TRUE, nLambda = 8))
  )
  tables <- Map(\(case, label) {
    ours <- do.call(fit_graphical_var, c(list(data = case$data, vars = abc, id = "id", day = "day", beep = "beep"),
                                         case$ours))
    theirs <- do.call(gvar_reference, c(list(data = case$data, vars = abc, idvar = "id", dayvar = "day",
                                             beepvar = "beep"), case$theirs))
    list(ours = cbind(case = label, coefs(ours)), theirs = cbind(case = label, theirs))
  }, cases, names(cases))
  # 1e-6: the old test's bound (largest absolute difference).
  expect_reference(do.call(rbind, lapply(tables, \(t) t$ours)), do.call(rbind, lapply(tables, \(t) t$theirs)),
                   reference = "graphicalVAR", covers = c("fit_graphical_var()", "coefs.gvar_result()"),
                   quantity = "eight people, two days", tolerance = 1e-6, key = c("case", "network", "from", "to"))
})

test_that("one graphical VAR per person equals graphicalVAR run on each person", {
  skip_without_reference("graphicalVAR")
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 55L, vars = abc, seed = 904L)
  ours <- fit_graphical_var_each(panel, vars = abc, id = "id", day = "day", beep = "beep", n_lambda = 8,
                                 verbose = FALSE)
  theirs <- do.call(rbind, lapply(split(panel, panel$id), \(person) {
    cbind(subject = as.character(person$id[[1L]]),
          gvar_reference(person, abc, idvar = "id", dayvar = "day", beepvar = "beep", nLambda = 8))
  }))
  # 1e-6: the old test's bound (largest absolute difference).
  expect_reference(coefs(ours), theirs, reference = "graphicalVAR",
                   covers = c("fit_graphical_var_each()", "coefs.gvar_list()"), quantity = "three people, 55 occasions",
                   tolerance = 1e-6, key = c("subject", "network", "from", "to"))
  expect_reference(as.data.frame(ours), theirs, reference = "graphicalVAR",
                   covers = c("fit_graphical_var_each()", "as.data.frame.gvar_list()"),
                   quantity = "three people, the data frame of the fits", tolerance = 1e-6,
                   key = c("subject", "network", "from", "to"))
})

#' graphicalVAR::graphicalVAR() with the graphical lasso inside it run to thr = 1e-12
#'
#' graphicalVAR calls glasso::glasso() at its default threshold, thr = 1e-4, where idiographic's kernel stops at
#' 1e-8; on some inputs that leaves graphicalVAR's partial correlations about 1e-6 from the converged solution.
#' This runs graphicalVAR's own code with glasso converged, and restores glasso on exit.
gvar_converged <- function(data, vars, ...) {
  imports <- parent.env(asNamespace("graphicalVAR"))
  original <- get("glasso", envir = imports)
  unlockBinding("glasso", imports)
  on.exit({
    assign("glasso", original, envir = imports)
    lockBinding("glasso", imports)
  }, add = TRUE)
  assign("glasso", function(...) original(..., thr = 1e-12, maxit = 1e5), envir = imports)
  gvar_reference(data, vars, ...)
}

test_that("the edge tables of per-person graphical VARs", {
  skip_without_reference("graphicalVAR")
  # edges() of a gvar_list stops when one person's network has no edge besides self-loops: declared in the next
  # test; here the edges are compared on three learners whose networks all have edges.
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"), select = c(name, day, efficacy, planning, effort))
  ours <- fit_graphical_var_each(three, vars = items, id = "name", beep = "day", n_lambda = 8, verbose = FALSE)
  by_learner <- split(three, three$name)
  theirs <- do.call(rbind, lapply(by_learner, \(learner) {
    cbind(subject = learner$name[[1L]], gvar_reference(learner, items, beepvar = "day", nLambda = 8))
  }))
  edges_only <- function(table) subset(table, weight != 0 & !(network == "temporal" & from == to))
  expect_known_difference(edges(ours), edges_only(theirs), reference = "graphicalVAR",
                          covers = c("fit_graphical_var_each()", "edges.gvar_list()"),
                          quantity = "three learners, non-zero edges", tolerance = 1e-6,
                          key = c("subject", "network", "from", "to"),
                          reason = "graphicalVAR runs glasso::glasso() at its default thr = 1e-4 and stops about 2e-6 short of the solution for Alice; idiographic's kernel converges to 1e-8. With glasso run to 1e-12 inside graphicalVAR the two agree to 1e-10 (next comparison).",
                          agrees_with = "graphicalVAR with its glasso run to thr = 1e-12")
  converged <- do.call(rbind, lapply(by_learner, \(learner) {
    cbind(subject = learner$name[[1L]], gvar_converged(learner, items, beepvar = "day", nLambda = 8))
  }))
  expect_reference(edges(ours), edges_only(converged), reference = "graphicalVAR",
                   covers = c("fit_graphical_var_each()", "edges.gvar_list()"),
                   quantity = "three learners, non-zero edges, glasso converged", tolerance = 1e-6,
                   key = c("subject", "network", "from", "to"))
})

test_that("node strengths and network summaries follow from graphicalVAR's networks", {
  skip_without_reference("graphicalVAR")
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  fit <- fit_graphical_var(learner, vars = items, beep = "occasion", n_lambda = 15, gamma = 0)
  theirs <- gvar_reference(learner, items, beepvar = "occasion", nLambda = 15, gamma = 0)
  # 1e-4, as for the coefficients these are sums of.
  expect_reference(nodes(fit), ref_nodes(theirs, items), reference = "graphicalVAR",
                   covers = c("nodes()", "nodes.gvar_result()"), quantity = "Tariq, node strengths", tolerance = 1e-4,
                   key = c("network", "node"))
  expect_reference(summary(fit), ref_network_summary(theirs, items), reference = "graphicalVAR",
                   covers = "summary.gvar_result()", quantity = "Tariq, network summary", tolerance = 1e-4, key = "network")
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 55L, vars = abc, seed = 904L)
  each <- fit_graphical_var_each(panel, vars = abc, id = "id", day = "day", beep = "beep", n_lambda = 8, verbose = FALSE)
  per_person <- lapply(split(panel, panel$id), \(person) {
    gvar_reference(person, abc, idvar = "id", dayvar = "day", beepvar = "beep", nLambda = 8)
  })
  expect_reference(nodes(each),
                   do.call(rbind, Map(\(table, subject) cbind(subject = subject, ref_nodes(table, abc)), per_person, names(per_person))),
                   reference = "graphicalVAR", covers = "nodes.gvar_list()", quantity = "three people, node strengths",
                   tolerance = 1e-6, key = c("subject", "network", "node"))
  expect_reference(summary(each),
                   do.call(rbind, Map(\(table, subject) cbind(subject = subject, ref_network_summary(table, abc)), per_person, names(per_person))),
                   reference = "graphicalVAR", covers = "summary.gvar_list()", quantity = "three people, network summaries",
                   tolerance = 1e-6, key = c("subject", "network"))
})

test_that("edges() of per-person graphical VARs when one person has no edge", {
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 55L, vars = abc, seed = 904L)
  each <- fit_graphical_var_each(panel, vars = abc, id = "id", day = "day", beep = "beep", n_lambda = 8,
                                 verbose = FALSE)
  # Person 2's estimated network has no edge besides its self-loops; the others have edges. edges() should return
  # the edges of persons 1 and 3 (coefs() of the same object works).
  expect_defect_error(edges(each),
                      defect = "edges() of a fit_graphical_var_each() result stops ('arguments imply differing number of rows: 1, 0') when one person's network has no edge besides self-loops; FINDINGS.md",
                      covers = c("edges.gvar_list()", "fit_graphical_var_each()"),
                      quantity = "three people, person 2 without edges")
})

test_that("one person's matrices of per-person graphical VARs equal graphicalVAR on that person", {
  skip_without_reference("graphicalVAR")
  panel <- ref_panel(n_id = 3L, days = 1L, beeps = 55L, vars = abc, seed = 904L)
  each <- fit_graphical_var_each(panel, vars = abc, id = "id", day = "day", beep = "beep", n_lambda = 8,
                                 verbose = FALSE)
  third <- subset(panel, id == 3L)
  reference <- graphicalVAR::graphicalVAR(third, vars = abc, idvar = "id", dayvar = "day", beepvar = "beep", nLambda = 8,
                                          verbose = FALSE)
  # API gap: matrices() returns a list of matrices, so each matrix is reached by name. 1e-6, the bound of the
  # per-person comparison above.
  expect_reference(matrices(each, subject = "3", print = FALSE)[["temporal"]], ref_named(reference$beta[, -1L], abc),
                   reference = "graphicalVAR", covers = c("matrices.gvar_list()", "fit_graphical_var_each()"),
                   quantity = "person 3, temporal coefficients (outcome rows)", tolerance = 1e-6)
  expect_reference(matrices(each, subject = "3", print = FALSE)[["PCC"]], ref_named(reference$PCC, abc),
                   reference = "graphicalVAR", covers = "matrices.gvar_list()",
                   quantity = "person 3, partial contemporaneous correlations", tolerance = 1e-6)
})
