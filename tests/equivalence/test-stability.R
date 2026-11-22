# estimate_stability(): edge stability of the VAR(1) under a block bootstrap. The resampled blocks are drawn
# inside the function from `seed` with no argument to supply them, so the bootstrap columns are checked
# STATISTICALLY: an independent block bootstrap is written here (blocks of floor(sqrt(n)) consecutive occasions
# drawn with replacement, each kept as its own run so no lag crosses two blocks, the series standardised, the VAR
# refitted by stats::lm()) and run from its own seeds; the package's bootstrap mean and SD of each edge must agree
# with it within the Monte Carlo error. The column `original` is the fit to the whole series and is compared
# exactly.
#
# Monte Carlo tolerance, fixed before the run: with B = 400 resamples on each side, the difference of two
# bootstrap means has standard error sd * sqrt(2 / B) and the difference of two bootstrap SDs about
# sd / sqrt(B - 1); the tolerance is 4 of those standard errors, sd being the largest bootstrap SD of the
# reference. A seed study (20 seeds of the package against 20 of the reference, 2026-11-20) passed 20 of 20 for
# both summaries, the largest difference being 0.65 of the tolerance for the mean and 0.49 for the SD.

items <- c("efficacy", "planning", "effort")
resamples <- 400L

#' An independent block bootstrap of the VAR(1) of one series: the mean and SD of every edge over the resamples
block_bootstrap <- function(series, seed) {
  set.seed(seed)
  blocks <- split(series[items], ceiling(seq_len(nrow(series)) / floor(sqrt(nrow(series)))))
  formula <- stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + ")))
  draws <- vapply(seq_len(resamples), \(draw) {
    chosen <- blocks[sample.int(length(blocks), length(blocks), replace = TRUE)]
    values <- as.data.frame(scale(do.call(rbind, chosen)))
    run <- rep(seq_along(chosen), vapply(chosen, nrow, integer(1)))
    pairs <- do.call(rbind, lapply(split(values, run), ref_lagged))
    model <- stats::lm(formula, data = pairs)
    ref_network(temporal = ref_named(t(stats::coef(model)[-1L, ]), items),
                contemporaneous = ref_named(ref_partial(solve(stats::cov(stats::residuals(model)))), items))$weight
  }, numeric(length(items)^2 + choose(length(items), 2L)))
  cells <- ref_network(temporal = ref_named(diag(3), items), contemporaneous = ref_named(diag(3), items))
  data.frame(cells[c("network", "from", "to")], mean = rowMeans(draws), sd = apply(draws, 1L, stats::sd))
}

test_that("the whole-series column and the stored fit are the least-squares VAR", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  stability <- estimate_stability(learner, vars = items, estimator = "var", beep = "occasion", n_resamples = 20L,
                                  seed = 1L)
  lagged <- ref_lagged(as.data.frame(scale(learner[items])))
  model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + "))),
                     data = lagged)
  whole <- ref_network(temporal = ref_named(t(stats::coef(model)[-1L, ]), items),
                       contemporaneous = ref_named(ref_partial(solve(stats::cov(stats::residuals(model)))), items))
  names(whole)[names(whole) == "weight"] <- "original"
  # Least squares on 77 rows: rounding only.
  expect_reference(as.data.frame(stability), whole, reference = "stats",
                   covers = c("estimate_stability()", "as.data.frame.stability_result()"),
                   quantity = "Tariq, the fit to the whole series", tolerance = 1e-10, key = c("network", "from", "to"))
  # API gap: matrices() returns a list of matrices, so the residual covariance is reached by name.
  expect_reference(matrices(stability, print = FALSE)[["residual_cov"]],
                   ref_named(stats::cov(stats::residuals(model)), items), reference = "stats",
                   covers = "matrices.stability_result()", quantity = "Tariq, residual covariance of the whole series",
                   tolerance = 1e-10)
})

test_that("bootstrap means and SDs agree with an independent block bootstrap (Monte Carlo summary)", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  invisible(lapply(1:3, \(seed) {
    reference <- block_bootstrap(learner, seed = 1000L + seed)
    stability <- estimate_stability(learner, vars = items, estimator = "var", beep = "occasion",
                                    n_resamples = resamples, seed = seed)
    spread <- max(reference$sd)
    expect_reference(summary(stability), subset(reference, select = -sd),
                     reference = "independent: block bootstrap of the stats::lm VAR, written in the test",
                     covers = c("estimate_stability()", "summary.stability_result()"),
                     quantity = sprintf("Monte Carlo summary: bootstrap mean of each edge, seed %d", seed),
                     tolerance = 4 * spread * sqrt(2 / resamples), key = c("network", "from", "to"),
                     note = "Statistical evidence: two independent bootstraps of 400 resamples; tolerance 4 Monte Carlo standard errors.")
    expect_reference(summary(stability), subset(reference, select = -mean),
                     reference = "independent: block bootstrap of the stats::lm VAR, written in the test",
                     covers = c("estimate_stability()", "summary.stability_result()"),
                     quantity = sprintf("Monte Carlo summary: bootstrap SD of each edge, seed %d", seed),
                     tolerance = 4 * spread / sqrt(resamples - 1), key = c("network", "from", "to"),
                     note = "Statistical evidence: two independent bootstraps of 400 resamples; tolerance 4 Monte Carlo standard errors.")
  }))
})

test_that("bootstrap means and SDs agree with a block bootstrap drawn by boot::boot() (Monte Carlo summary)", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  blocks <- split(learner[items], ceiling(seq_len(nrow(learner)) / floor(sqrt(nrow(learner)))))
  formula <- stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items), paste0(items, "_lag", collapse = " + ")))
  # The statistic of one resample of blocks (boot draws the block indices with replacement): the blocks kept as
  # separate runs, the series standardised, the VAR refitted by stats::lm().
  edges_of <- function(block_ids, chosen) {
    picked <- blocks[block_ids[chosen]]
    values <- as.data.frame(scale(do.call(rbind, picked)))
    run <- rep(seq_along(picked), vapply(picked, nrow, integer(1)))
    model <- stats::lm(formula, data = do.call(rbind, lapply(split(values, run), ref_lagged)))
    ref_network(temporal = ref_named(t(stats::coef(model)[-1L, ]), items),
                contemporaneous = ref_named(ref_partial(solve(stats::cov(stats::residuals(model)))), items))$weight
  }
  cells <- ref_network(temporal = ref_named(diag(3), items), contemporaneous = ref_named(diag(3), items))
  invisible(lapply(1:3, \(seed) {
    set.seed(2000L + seed)
    draws <- boot::boot(seq_along(blocks), edges_of, R = resamples)$t
    reference <- data.frame(cells[c("network", "from", "to")], mean = colMeans(draws), sd = apply(draws, 2L, stats::sd))
    stability <- estimate_stability(learner, vars = items, estimator = "var", beep = "occasion",
                                    n_resamples = resamples, seed = seed)
    spread <- max(reference$sd)
    # Tolerances fixed as in the test above: 4 Monte Carlo standard errors of the difference.
    expect_reference(summary(stability), subset(reference, select = -sd), reference = "boot",
                     covers = c("estimate_stability()", "summary.stability_result()"),
                     quantity = sprintf("Monte Carlo summary: bootstrap mean of each edge against boot::boot(), seed %d", seed),
                     tolerance = 4 * spread * sqrt(2 / resamples), key = c("network", "from", "to"),
                     note = "Statistical evidence: 400 resamples on each side; tolerance 4 Monte Carlo standard errors.")
    expect_reference(summary(stability), subset(reference, select = -mean), reference = "boot",
                     covers = c("estimate_stability()", "summary.stability_result()"),
                     quantity = sprintf("Monte Carlo summary: bootstrap SD of each edge against boot::boot(), seed %d", seed),
                     tolerance = 4 * spread / sqrt(resamples - 1), key = c("network", "from", "to"),
                     note = "Statistical evidence: 400 resamples on each side; tolerance 4 Monte Carlo standard errors.")
  }))
})
