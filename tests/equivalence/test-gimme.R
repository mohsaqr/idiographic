# fit_gimme(): Group Iterative Multiple Model Estimation (Gates & Molenaar, 2012; Lane & Gates, 2017) against
# gimme::gimme() 10.0 run here on the same series. idiographic re-implements the search (group stage, individual
# stage, pruning) and fits each model with lavaan, as gimme does; gimme is a separate implementation of the
# search, so agreement checks idiographic's search, pruning and extraction.
#
# The tolerances are the old oracle test's: 0 for the path counts, the path estimates and the residual
# covariances, which both sides round to four decimals as gimme returns them; 5e-5 (half a unit in the fourth
# decimal) for the fit indices, which gimme rounds to four decimals and idiographic keeps at lavaan's precision.

#' One person's matrix of a gimme result as a long table of cells
matrix_cells <- function(cells, subject, value = "weight") {
  rows <- rownames(cells) %||% as.character(seq_len(nrow(cells)))
  columns <- colnames(cells) %||% as.character(seq_len(ncol(cells)))
  out <- data.frame(subject = subject, row = rows[as.vector(row(cells))], column = columns[as.vector(col(cells))],
                    value = as.vector(cells))
  names(out)[[4L]] <- value
  out
}

#' gimme's estimated paths as coefs() shapes them: one row per person and non-zero path, the lagged
#' predictors as the temporal network
gimme_paths <- function(reference) {
  cells <- do.call(rbind, Map(matrix_cells, reference$path_est_mats, names(reference$path_est_mats) %||%
                                as.character(seq_along(reference$path_est_mats))))
  cells <- cells[cells$weight != 0, ]
  lagged <- grepl("lag$", cells$column)
  data.frame(subject = cells$subject, network = ifelse(lagged, "temporal", "contemporaneous"),
             from = sub("lag$", "", cells$column), to = cells$row, weight = cells$weight)
}

#' gimme run on one list of series, its console output discarded (it prints its progress)
run_gimme <- function(series, ...) {
  printed <- utils::capture.output(result <- gimme::gimme(data = series, plot = FALSE, ...))
  result
}

#' The person series of a panel, as gimme reads them: one matrix per person, named by the person
person_series <- function(panel, vars) {
  lapply(split(panel, panel$id), \(person) as.matrix(person[vars]))
}

#' Compare one fit with gimme's result on every quantity both report
compare_gimme <- function(ours, reference, label) {
  subjects <- as.character(seq_along(reference$path_est_mats))
  names(reference$path_est_mats) <- subjects
  expect_reference(cbind(case = label, coefs(ours)), cbind(case = label, gimme_paths(reference)), reference = "gimme",
                   covers = c("fit_gimme()", "coefs.net_gimme()"), quantity = sprintf("%s: path estimates", label),
                   tolerance = 0, key = c("case", "subject", "network", "from", "to"))
  # API gap: matrices() returns a list of matrices, so the counts are reached by name.
  # Compared by position: the two sides label the lagged columns differently.
  expect_reference(unname(matrices(ours)[["path_counts"]]), unname(reference$path_counts), reference = "gimme",
                   covers = c("fit_gimme()", "matrices.net_gimme()"), quantity = sprintf("%s: path counts", label),
                   tolerance = 0)
  # API gap: the residual covariances and the fit indices have no accessor; they are read from the result.
  expect_reference(do.call(rbind, Map(\(cells, subject) matrix_cells(unname(cells), subject, "psi"), ours$psi, subjects)),
                   do.call(rbind, Map(\(cells, subject) matrix_cells(unname(cells), subject, "psi"), reference$psi, subjects)),
                   reference = "gimme",
                   covers = "fit_gimme()", quantity = sprintf("%s: residual covariances", label), tolerance = 0,
                   key = c("subject", "row", "column"))
  counts <- reference$path_counts
  shares <- data.frame(row = rownames(counts)[as.vector(row(counts))], column = colnames(counts)[as.vector(col(counts))],
                       weight = as.vector(counts) / length(subjects))
  shares <- shares[shares$weight != 0, ]
  shares <- data.frame(case = label, network = ifelse(grepl("lag$", shares$column), "temporal", "contemporaneous"),
                       from = sub("lag$", "", shares$column), to = shares$row, weight = shares$weight)
  # A hybrid search also estimates residual covariances, which gimme counts in cov_counts; the edge table reports
  # them as undirected contemporaneous edges (the upper triangle).
  covariances <- reference$cov_counts
  if (!is.null(covariances)) {
    covariances <- pmax(covariances, t(covariances))
    upper <- which(upper.tri(covariances) & covariances != 0, arr.ind = TRUE)
    shares <- rbind(shares, data.frame(case = rep(label, nrow(upper)), network = rep("contemporaneous", nrow(upper)),
                                       from = rownames(covariances)[upper[, "row"]], to = colnames(covariances)[upper[, "col"]],
                                       weight = covariances[upper] / length(subjects)))
  }
  # A count divided by the number of people on both sides.
  expect_reference(cbind(case = label, edges(ours)), shares, reference = "gimme",
                   covers = c("edges.net_gimme()", "fit_gimme()"),
                   quantity = sprintf("%s: share of people with each path", label), tolerance = 1e-12,
                   key = c("case", "network", "from", "to"))
  expect_reference(cbind(case = label, as.data.frame(ours)), shares, reference = "gimme",
                   covers = "as.data.frame.net_gimme()",
                   quantity = sprintf("%s: share of people with each path, the data frame of the fit", label),
                   tolerance = 1e-12, key = c("case", "network", "from", "to"))
  indices <- intersect(c("chisq", "df", "pvalue", "rmsea", "srmr", "nnfi", "cfi", "bic", "aic", "logl"),
                       intersect(names(ours$fit), names(reference$fit)))
  expect_reference(cbind(subject = subjects, ours$fit[indices]), cbind(subject = subjects, reference$fit[indices]),
                   reference = "gimme", covers = "fit_gimme()", quantity = sprintf("%s: fit indices", label),
                   tolerance = 5e-5, key = "subject")
}

test_that("standard, hybrid and VAR searches", {
  skip_without_reference("gimme")
  panel <- ref_panel(n_id = 4L, days = 1L, beeps = 40L, vars = c("A", "B"), seed = 817L)
  modes <- list(standard = list(), hybrid = list(hybrid = TRUE), VAR = list(VAR = TRUE))
  invisible(Map(\(arguments, label) {
    reference <- do.call(run_gimme, c(list(series = person_series(panel, c("A", "B"))), arguments))
    ours <- suppressMessages(do.call(fit_gimme, c(list(data = panel, vars = c("A", "B"), id = "id", day = "day",
                                                       beep = "beep", seed = 1), arguments)))
    compare_gimme(ours, reference, label)
  }, modes, names(modes)))
})

test_that("correction and stopping controls", {
  skip_without_reference("gimme")
  panel <- ref_panel(n_id = 4L, days = 1L, beeps = 40L, vars = c("A", "B"), seed = 818L)
  cases <- list("alpha = 0.1" = list(alpha = 0.1), "FDR corrections" = list(group_correct = "fdr", indiv_correct = "fdr"),
                "Bonferroni paths" = list(group_correct = "Bonferroni Paths"), "group alpha 0.01" = list(group_correct = 0.01),
                "standard stopping" = list(stop_crit = "standard"), "significance stopping" = list(stop_crit = "significance"),
                "standardised" = list(standardize = TRUE), "group cut-off 0.5" = list(groupcutoff = 0.5),
                "fit cut-offs" = list(rmsea_cutoff = 0.1, srmr_cutoff = 0.1, nnfi_cutoff = 0.9, cfi_cutoff = 0.9, n_excellent = 3L),
                "forced path B ~ Alag" = list(paths = "B~Alag"))
  invisible(Map(\(arguments, label) {
    reference <- do.call(run_gimme, c(list(series = person_series(panel, c("A", "B"))), arguments))
    ours <- suppressMessages(do.call(fit_gimme, c(list(data = panel, vars = c("A", "B"), id = "id", day = "day",
                                                       beep = "beep", seed = 1), arguments)))
    compare_gimme(ours, reference, label)
  }, cases, names(cases)))
})

test_that("an exogenous variable, uneven series and a corrected hybrid search", {
  skip_without_reference("gimme")
  abc <- c("A", "B", "C")
  panel <- ref_panel(n_id = 5L, days = 1L, beeps = 50L, vars = abc, seed = 829L)
  reference <- run_gimme(person_series(panel, abc), exogenous = "C")
  ours <- suppressMessages(fit_gimme(panel, vars = abc, id = "id", day = "day", beep = "beep", exogenous = "C", seed = 1))
  compare_gimme(ours, reference, "exogenous C")
  base <- ref_panel(n_id = 5L, days = 1L, beeps = 50L, vars = abc, seed = 830L)
  kept <- c(50L, 43L, 47L, 39L, 45L)
  uneven <- base[base$beep <= kept[base$id], ]
  reference <- run_gimme(person_series(uneven, abc))
  ours <- suppressMessages(fit_gimme(uneven, vars = abc, id = "id", day = "day", beep = "beep", seed = 1))
  compare_gimme(ours, reference, "uneven series")
  hybrid <- list(hybrid = TRUE, group_correct = "fdr", indiv_correct = "fdr", alpha = 0.1, stop_crit = "significance",
                 standardize = TRUE, groupcutoff = 0.6)
  reference <- do.call(run_gimme, c(list(series = person_series(base, abc)), hybrid))
  ours <- suppressMessages(do.call(fit_gimme, c(list(data = base, vars = abc, id = "id", day = "day", beep = "beep",
                                                     seed = 1), hybrid)))
  compare_gimme(ours, reference, "corrected hybrid")
})

test_that("node strengths and network summaries of the path-share networks of a standard search", {
  skip_without_reference("gimme")
  panel <- ref_panel(n_id = 4L, days = 1L, beeps = 40L, vars = c("A", "B"), seed = 817L)
  vars <- c("A", "B")
  reference <- run_gimme(person_series(panel, vars))
  ours <- suppressMessages(fit_gimme(panel, vars = vars, id = "id", day = "day", beep = "beep", seed = 1))
  # gimme's path counts, one row per outcome, divided by the number of people; the networks run from predictor
  # (row) to outcome (column), both directed in a standard search.
  shares <- reference$path_counts / length(reference$path_est_mats)
  layers <- list(temporal = t(shares[vars, paste0(vars, "lag")]), contemporaneous = t(shares[vars, vars]))
  layers <- lapply(layers, \(cells) {
    dimnames(cells) <- list(vars, vars)
    cells
  })
  strengths <- do.call(rbind, Map(\(cells, layer) {
    off <- abs(cells)
    diag(off) <- 0
    data.frame(network = layer, node = vars, strength = rowSums(off) + colSums(off), out_strength = rowSums(off),
               in_strength = colSums(off), self = diag(cells))
  }, layers, names(layers)))
  # Counts divided by the number of people on both sides.
  expect_reference(nodes(ours), strengths, reference = "gimme", covers = c("nodes.net_gimme()", "fit_gimme()"),
                   quantity = "standard search: node strengths of the path shares", tolerance = 1e-12,
                   key = c("network", "node"))
  counts <- do.call(rbind, Map(\(cells, layer) {
    w <- cells[row(cells) != col(cells) & cells != 0]
    data.frame(network = layer, n_nodes = length(vars), n_edges = length(w),
               density = length(w) / (length(vars) * (length(vars) - 1)),
               mean_abs_weight = if (length(w)) mean(abs(w)) else 0, n_positive = sum(w > 0), n_negative = sum(w < 0))
  }, layers, names(layers)))
  expect_reference(summary(ours), counts, reference = "gimme", covers = "summary.net_gimme()",
                   quantity = "standard search: summary of the path-share networks", tolerance = 1e-12, key = "network")
})
