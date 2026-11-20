# importance(method = "permutation") and summarize_importance(method = "permutation"): how much the held-out RMSE
# of each person's model grows when one predictor is shuffled among that person's held-out rows, averaged over
# `repeats` shuffles. The shuffles are drawn inside the function with no argument to supply them, so the result
# is checked STATISTICALLY: the same procedure is written here independently (each person's least-squares model
# on the first 80% of the occasions, as fit_ml_panel()'s linear learner, test-fit-views.R) and run from its own
# seeds.
#
# Monte Carlo tolerance, fixed before the run: with R = 500 shuffles on each side, the difference of the two mean
# RMSEs has standard error sd sqrt(2 / R), sd the SD of the permuted RMSE over the reference's shuffles (the
# largest over people and predictors); the tolerance is 4 of those. Seed study (2026-11-20, package seeds 1-10
# against reference seeds 1001-1010): within the tolerance on 10 of 10 seeds for both verbs, the largest
# difference 0.41 of the tolerance (importance) and 0.21 (summarize_importance).

predictors <- c("efficacy", "planning")
repeats <- 500L

#' The independent permutation importance: per person and predictor, the mean permuted RMSE minus the RMSE, and
#' the SD of the permuted RMSE over the shuffles
permutation_reference <- function(data, seed) {
  set.seed(seed)
  by_person <- split(data[order(data$name, data$day), ], data$name[order(data$name, data$day)])
  do.call(rbind, lapply(by_person, \(person) {
    estimation <- utils::head(person, nrow(person) - ceiling(0.2 * nrow(person)))
    held_out <- utils::tail(person, ceiling(0.2 * nrow(person)))
    model <- stats::lm(effort ~ efficacy + planning, data = estimation)
    rmse <- function(rows) sqrt(mean((rows$effort - stats::predict(model, newdata = rows))^2))
    do.call(rbind, lapply(predictors, \(v) {
      permuted <- vapply(seq_len(repeats), \(r) {
        shuffled <- held_out
        shuffled[[v]] <- sample(shuffled[[v]])
        rmse(shuffled)
      }, numeric(1))
      data.frame(subject = person$name[[1L]], variable = v, importance = mean(permuted) - rmse(held_out),
                 sd = stats::sd(permuted))
    }))
  }))
}

test_that("permutation importance agrees with an independent run of the procedure (Monte Carlo summary)", {
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"))
  fit <- fit_ml_panel(three, "effort", predictors, "name", time = "day", scope = "individual", model = "linear")
  invisible(lapply(1:3, \(seed) {
    reference <- permutation_reference(three, seed = 1000L + seed)
    tolerance <- 4 * max(reference$sd) * sqrt(2 / repeats)
    set.seed(seed)
    expect_reference(importance(fit, method = "permutation", repeats = repeats), subset(reference, select = -sd),
                     reference = "independent: permutation importance written in the test",
                     covers = c('importance(method = "permutation")', "importance.idiographic_fit()"),
                     quantity = sprintf("Monte Carlo summary: RMSE increase per learner and predictor, seed %d", seed),
                     tolerance = tolerance, key = c("subject", "variable"),
                     note = "Statistical evidence: two independent runs of 500 shuffles; tolerance 4 Monte Carlo standard errors.")
    averaged <- data.frame(variable = predictors, n_subjects = 3L,
                           importance = vapply(predictors, \(v) mean(subset(reference, variable == v)$importance), numeric(1)))
    set.seed(seed)
    expect_reference(summarize_importance(fit, method = "permutation", repeats = repeats), averaged,
                     reference = "independent: permutation importance written in the test",
                     covers = 'summarize_importance(method = "permutation")',
                     quantity = sprintf("Monte Carlo summary: mean RMSE increase over three learners, seed %d", seed),
                     tolerance = tolerance, key = "variable",
                     note = "Statistical evidence: tolerance 4 Monte Carlo standard errors of one learner's mean, so conservative for the mean of three.")
  }))
})
