# fit_heterogeneity(), heterogeneity(), clan(), learners(): generic machine-learning inference on heterogeneity
# (Chernozhukov, Demirer, Duflo & Fernandez-Val, 2020), here with the target "error" (how badly a person's
# occasions are predicted) and the linear learner. The splits of the people into an auxiliary and a main half are
# drawn inside the function with no argument to supply them, so the results are checked STATISTICALLY: the same
# procedure is written here independently and run from its own seeds, and the package's medians over splits must
# agree with it within the Monte Carlo error.
#
# The procedure, per split: half of the people (round(G / 2)) drawn as the auxiliary sample; on it the outcome is
# fitted by least squares and the absolute residuals by least squares on the same predictors (the proxy); on the
# main sample the score is the absolute prediction error. BLP: the score on (1, proxy - mean(proxy)); GATES: the
# score on the four quarter indicators of the proxy; top-bottom: their difference; CLAN: each predictor on
# (1, top-quarter indicator) within the top and bottom quarters; lambda = slope^2 var(proxy), lambda_bar = sum of
# share x GATES^2. All regressions by least squares; each reported number is the median over splits.
#
# Monte Carlo tolerance, fixed before the run: with S = 200 splits on each side, a median over splits has standard
# error about 1.2533 sd / sqrt(S), sd the SD over the reference's splits, so the difference of two independent
# medians has 1.2533 sd sqrt(2 / S); the tolerance is 4 of those. Seed study (2026-11-20, package seeds 1-10
# against reference seeds 1001-1010, S = 200): all 11 quantities within the tolerance on 10 of 10 seeds; the
# largest difference was 0.44 of the tolerance (the average), the others 0.14 to 0.38.

predictors <- c("efficacy", "planning")
splits <- 200L

#' One split of the independent procedure: every quantity as a named vector
one_split <- function(data) {
  people <- unique(data$name)
  auxiliary <- data$name %in% sample(people, round(length(people) / 2))
  aux <- data[auxiliary, ]
  main <- data[!auxiliary, ]
  outcome <- stats::lm(effort ~ efficacy + planning, data = aux)
  aux$miss <- abs(aux$effort - stats::fitted(outcome))
  proxy_fit <- stats::lm(miss ~ efficacy + planning, data = aux)
  score <- abs(main$effort - unname(stats::predict(outcome, newdata = main)))
  proxy <- unname(stats::predict(proxy_fit, newdata = main))
  rank <- rank(proxy, ties.method = "first")
  quarter <- pmin(4L, pmax(1L, ceiling(rank / (length(rank) / 4))))
  blp <- stats::lm.fit(cbind(1, proxy - mean(proxy)), score)$coefficients
  gates <- vapply(1:4, \(g) mean(score[quarter == g]), numeric(1))
  ends <- quarter %in% c(1L, 4L)
  clan <- vapply(predictors, \(v) {
    mean(main[[v]][quarter == 4L]) - mean(main[[v]][quarter == 1L])
  }, numeric(1))
  c(average = blp[[1L]], heterogeneity = blp[[2L]], stats::setNames(gates, sprintf("group:g%d", 1:4)),
    "group:top-bottom" = gates[[4L]] - gates[[1L]], clan,
    lambda = blp[[2L]]^2 * stats::var(proxy), lambda_bar = sum(tabulate(quarter, 4L) / length(quarter) * gates^2))
}

#' The independent procedure over S splits: the median and the SD over splits of every quantity
independent_medians <- function(data, seed) {
  set.seed(seed)
  draws <- vapply(seq_len(splits), \(s) one_split(data), numeric(11))
  data.frame(quantity = rownames(draws), median = apply(draws, 1L, stats::median), sd = apply(draws, 1L, stats::sd))
}

test_that("medians over splits agree with an independent run of the procedure (Monte Carlo summary)", {
  data <- srl[stats::complete.cases(srl[c("effort", predictors)]), c("name", "effort", predictors)]
  invisible(lapply(1:3, \(seed) {
    reference <- independent_medians(data, seed = 1000L + seed)
    set.seed(seed)
    fit <- fit_heterogeneity(data, y = "effort", x = predictors, id = "name", target = "error", model = "linear",
                             num_splits = splits)
    tolerance <- function(quantity) 4 * 1.2533 * sqrt(2 / splits) * reference$sd[reference$quantity == quantity]
    median_of <- function(quantity) reference$median[reference$quantity == quantity]
    effects <- c("average", "heterogeneity", sprintf("group:g%d", 1:4), "group:top-bottom")
    invisible(lapply(effects, \(effect) {
      expect_reference(heterogeneity(fit, effect = effect), data.frame(effect = effect, estimate = median_of(effect)),
                       reference = "independent: generic ML inference written in the test (Chernozhukov et al., 2020)",
                       covers = c("fit_heterogeneity()", "heterogeneity()"),
                       quantity = sprintf("Monte Carlo summary: median over splits, %s, seed %d", effect, seed),
                       tolerance = tolerance(effect), key = "effect",
                       note = "Statistical evidence: two independent runs of 200 splits; tolerance 4 Monte Carlo standard errors of the difference of two medians.")
    }))
    invisible(lapply(predictors, \(v) {
      expect_reference(subset(clan(fit), variable == v), data.frame(variable = v, estimate = median_of(v)),
                       reference = "independent: generic ML inference written in the test (Chernozhukov et al., 2020)",
                       covers = c("clan()", "fit_heterogeneity()"),
                       quantity = sprintf("Monte Carlo summary: median CLAN difference of %s, seed %d", v, seed),
                       tolerance = tolerance(v), key = "variable",
                       note = "Statistical evidence: tolerance 4 Monte Carlo standard errors.")
    }))
    invisible(lapply(c("lambda", "lambda_bar"), \(column) {
      expected <- stats::setNames(data.frame("linear", median_of(column)), c("model", column))
      expect_reference(learners(fit), expected,
                       reference = "independent: generic ML inference written in the test (Chernozhukov et al., 2020)",
                       covers = c("learners()", "fit_heterogeneity()"),
                       quantity = sprintf("Monte Carlo summary: median %s, seed %d", column, seed),
                       tolerance = tolerance(column), key = "model",
                       note = "Statistical evidence: tolerance 4 Monte Carlo standard errors.")
    }))
  }))
})
