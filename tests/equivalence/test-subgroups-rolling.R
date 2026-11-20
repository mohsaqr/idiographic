# fit_subgroups() and groups(): regressions per supplied subgroup of people, and the subgroup each person is in;
# fit_rolling(): rolling-origin evaluation, each fold's regressions refitted on the rows before its origin. Both
# against stats::lm() on the same rows; the standard errors of a pooled or subgroup model are the CR1
# cluster-robust sandwich over people (Liang & Zeger, 1986) with the factor G / (G - 1) and t on G - 1 degrees of
# freedom (Cameron & Miller, 2015), as test-fit-lm.R establishes for the pooled model.
#
# Least squares by QR on at most 4,500 rows: rounding only, 1e-10.

held_out <- 0.2
predictors <- c("efficacy", "planning")
indexed <- transform(srl, row = seq_len(nrow(srl)), cohort = ifelse(name < "J", "early", "late"))
ordered <- indexed[order(indexed$name, indexed$day), ]
people <- split(ordered, ordered$name)
first_rows <- function(person) utils::head(person, nrow(person) - ceiling(held_out * nrow(person)))

#' Least squares with standard errors clustered on the person (CR1, G / (G - 1), t on G - 1 df)
clustered_lm <- function(train) {
  train <- train[stats::complete.cases(train[c("effort", predictors)]), ]
  model <- stats::lm(effort ~ efficacy + planning, data = train)
  X <- stats::model.matrix(model)
  bread <- solve(crossprod(X))
  scores <- rowsum(X * stats::residuals(model), train$name)
  clusters <- nrow(scores)
  std_error <- sqrt(diag(bread %*% crossprod(scores) %*% bread * clusters / (clusters - 1)))
  estimate <- stats::coef(model)
  data.frame(term = names(estimate), estimate = unname(estimate), std_error = unname(std_error),
             statistic = unname(estimate / std_error),
             p_value = unname(2 * stats::pt(-abs(estimate / std_error), df = clusters - 1L)))
}

test_that("one regression per supplied subgroup, with standard errors clustered on the person", {
  fit <- fit_subgroups(indexed, y = "effort", x = predictors, id = "name", subgroup = "cohort", time = "day",
                       test_prop = held_out)
  estimation <- do.call(rbind, lapply(people, first_rows))
  theirs <- do.call(rbind, lapply(c("early", "late"), \(cohort) {
    cbind(scope = "subgroup", subgroup = cohort, clustered_lm(estimation[estimation$cohort == cohort, ]))
  }))
  expect_reference(subset(coefs(fit), scope == "subgroup"), theirs,
                   reference = "independent: least squares with the CR1 cluster-robust sandwich",
                   covers = c("fit_subgroups()", "coefs.idiographic_fit()"),
                   quantity = "two cohorts of learners, effort on efficacy and planning", tolerance = 1e-10,
                   key = c("scope", "subgroup", "term"))
  pooled <- cbind(scope = "pooled", subgroup = ".all", clustered_lm(estimation))
  expect_reference(subset(coefs(fit), scope == "pooled"), pooled,
                   reference = "independent: least squares with the CR1 cluster-robust sandwich",
                   covers = "fit_subgroups()", quantity = "the pooled model beside the subgroups", tolerance = 1e-10,
                   key = c("scope", "subgroup", "term"))
  membership <- unique(indexed[c("name", "cohort")])
  supplied <- data.frame(subject = membership$name, subgroup = membership$cohort)
  expect_reference(groups(fit), supplied, reference = "independent: the subgroup column of the data",
                   covers = c("groups()", "groups.idiographic_fit()", "groups.idiostats_fit()"),
                   quantity = "the subgroup of each learner", tolerance = 0, key = "subject",
                   note = "groups.idiostats_fit() is the same function object as groups.idiographic_fit().")
})

test_that("each rolling fold refits the regressions on the rows before its origin", {
  fit <- fit_rolling(indexed, y = "effort", x = predictors, id = "name", method = "lm", time = "day",
                     scope = "individual", initial = 120L, assess = 6L, step = 6L, folds = 3L)
  origins <- 120L + (seq_len(3L) - 1L) * 6L
  folds <- do.call(rbind, lapply(seq_along(origins), \(fold) {
    do.call(rbind, lapply(people, \(person) {
      train <- utils::head(person, origins[[fold]])
      model <- stats::lm(effort ~ efficacy + planning, data = train)
      test <- person[origins[[fold]] + seq_len(6L), ]
      test <- test[stats::complete.cases(test[c("effort", predictors)]), ]
      predicted <- as.vector(stats::predict(model, newdata = test))
      data.frame(fold = fold, subject = test$name, row = test$row, observed = test$effort, predicted = predicted,
                 residual = test$effort - predicted)
    }))
  }))
  expect_reference(predictions(fit), folds, reference = "stats", covers = c("fit_rolling()", "predictions()"),
                   quantity = "36 learners, three folds of six days from day 121", tolerance = 1e-10,
                   key = c("fold", "subject", "row"))
  overall <- with(folds, data.frame(subject = ".overall", n = length(residual), rmse = sqrt(mean(residual^2)),
                                    mae = mean(abs(residual)), bias = mean(residual)))
  expect_reference(subset(metrics(fit), subject == ".overall"), overall,
                   reference = "independent: RMSE, MAE and mean error of the stats::lm predictions",
                   covers = "fit_rolling()", quantity = "36 learners, errors over the three folds", tolerance = 1e-10,
                   key = "subject")
})
