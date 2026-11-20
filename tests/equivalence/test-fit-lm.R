# fit_lm(), fit_glm() and what is read from them: the person-specific and pooled regressions against
# stats::lm() and stats::glm() on each person's estimation rows (all but the last ceiling(0.2 n) occasions);
# their held-out predictions and prediction errors; the cluster-robust standard errors of the pooled models,
# written from the definitions. The pooling and shrinkage of the person coefficients are in test-pool-coefs.R.

held_out <- 0.2
predictors <- c("efficacy", "planning")

#' Each person's estimation rows: all but the last ceiling(0.2 n) occasions, in time order
first_rows <- function(person) utils::head(person, nrow(person) - ceiling(held_out * nrow(person)))

#' Each person's held-out rows
last_rows <- function(person) utils::tail(person, ceiling(held_out * nrow(person)))

# `row` is the row of the input data, which predictions() reports for each held-out occasion.
indexed <- transform(srl, row = seq_len(nrow(srl)))
people <- split(indexed[order(indexed$name, indexed$day), ], indexed$name[order(indexed$name, indexed$day)])

#' One person's coefficient table from summary()
coefficient_rows <- function(fit, subject) {
  table <- stats::coef(summary(fit))
  data.frame(subject = subject, term = rownames(table), estimate = table[, 1L], std_error = table[, 2L],
             statistic = table[, 3L], p_value = table[, 4L], row.names = NULL)
}

person_fits <- lapply(people, \(person) stats::lm(effort ~ efficacy + planning, data = first_rows(person)))
person_coefficients <- do.call(rbind, Map(coefficient_rows, person_fits, names(person_fits)))

test_that("person-specific regressions equal stats::lm() on each person's estimation rows", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  # Least squares by QR on at most 125 rows: rounding only.
  expect_reference(coefs(fit), person_coefficients, reference = "stats",
                   covers = c("fit_lm()", "coefs()", "coefs.idiographic_fit()", "coefs.idiostats_fit()"),
                   quantity = "36 learners, effort on efficacy and planning", tolerance = 1e-10,
                   key = c("subject", "term"),
                   note = "coefs.idiostats_fit() is the same function object as coefs.idiographic_fit().")
})

test_that("held-out predictions and their errors", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  predicted <- do.call(rbind, Map(\(person, model) {
    rows <- last_rows(person)
    rows <- rows[stats::complete.cases(rows[c("effort", predictors)]), ]
    data.frame(subject = rows$name, row = rows$row, observed = rows$effort,
               predicted = as.vector(stats::predict(model, newdata = rows)))
  }, people, person_fits))
  predicted$residual <- predicted$observed - predicted$predicted
  expect_reference(predictions(fit), predicted, reference = "stats",
                   covers = c("predictions()", "predictions.idiographic_fit()", "predictions.idiostats_fit()",
                              "as.data.frame.idiographic_fit()", "as.data.frame.idiostats_fit()"),
                   quantity = "held-out predictions", tolerance = 1e-10, key = c("subject", "row"))
  expect_reference(as.data.frame(fit), predicted, reference = "stats",
                   covers = c("as.data.frame.idiographic_fit()", "as.data.frame.idiostats_fit()"),
                   quantity = "held-out predictions, the data frame of the fit", tolerance = 1e-10,
                   key = c("subject", "row"))
  errors <- function(part, subject) {
    data.frame(subject = subject, n = nrow(part), rmse = sqrt(mean(part$residual^2)), mae = mean(abs(part$residual)),
               bias = mean(part$residual),
               r_squared = 1 - sum(part$residual^2) / sum((part$observed - mean(part$observed))^2))
  }
  per_person <- do.call(rbind, Map(errors, split(predicted, predicted$subject), sort(unique(predicted$subject))))
  expected <- rbind(per_person, errors(predicted, ".overall"))
  expect_reference(metrics(fit), expected,
                   reference = "independent: RMSE, MAE, mean error and 1 - SSE / SST",
                   covers = c("metrics()", "metrics.idiographic_fit()", "metrics.idiostats_fit()"),
                   quantity = "held-out prediction errors", tolerance = 1e-10, key = "subject")
  expect_reference(summary(fit), expected,
                   reference = "independent: RMSE, MAE, mean error and 1 - SSE / SST",
                   covers = c("summary.idiographic_fit()", "summary.idiostats_fit()"),
                   quantity = "held-out prediction errors, the summary of the fit", tolerance = 1e-10, key = "subject")
})

test_that("the pooled regression, with standard errors clustered on the person", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "pooled", test_prop = held_out)
  train <- do.call(rbind, lapply(people, first_rows))
  train <- train[stats::complete.cases(train[c("effort", predictors)]), ]
  pooled <- stats::lm(effort ~ efficacy + planning, data = train)
  # The CR1 sandwich (Liang & Zeger, 1986) with the small-sample factor G / (G - 1) and t on G - 1 degrees of
  # freedom (Cameron & Miller, 2015), G the number of learners.
  X <- stats::model.matrix(pooled)
  bread <- solve(crossprod(X))
  scores <- rowsum(X * stats::residuals(pooled), train$name)
  clusters <- nrow(scores)
  covariance <- bread %*% crossprod(scores) %*% bread * clusters / (clusters - 1)
  estimate <- stats::coef(pooled)
  std_error <- sqrt(diag(covariance))
  clustered <- data.frame(term = names(estimate), estimate = estimate, std_error = std_error,
                          statistic = estimate / std_error,
                          p_value = 2 * stats::pt(-abs(estimate / std_error), df = clusters - 1L))
  expect_reference(coefs(fit), clustered,
                   reference = "independent: least squares with the CR1 cluster-robust sandwich",
                   covers = c("fit_lm()", "coefs.idiographic_fit()"), quantity = "pooled model, 36 learners",
                   tolerance = 1e-10, key = "term")
  # Stata's CR1, and sandwich::vcovCL(type = "HC1"), multiply also by (N - 1) / (N - K).
  observations <- nrow(X)
  stata <- transform(clustered, std_error = std_error * sqrt((observations - 1) / (observations - ncol(X))))
  expect_known_difference(coefs(fit), subset(stata, select = c(term, std_error)),
                          reference = "independent: least squares with Stata's CR1 sandwich",
                          covers = "fit_lm()", quantity = "pooled model, Stata's small-sample factor",
                          tolerance = 1e-10, key = "term",
                          reason = "fit_lm() scales the clustered sandwich by G / (G - 1) only; Stata's CR1 also multiplies by (N - 1) / (N - K), a factor of 1.0005 here.",
                          agrees_with = "the factor G / (G - 1) alone (the comparison above)")
})

test_that("logistic and Poisson person-specific models equal stats::glm()", {
  binary <- transform(srl, high_effort = as.integer(effort > 60))
  people_binary <- split(binary[order(binary$name, binary$day), ], binary$name[order(binary$name, binary$day)])
  logistic <- fit_glm(binary, y = "high_effort", x = "efficacy", id = "name", family = "binomial", time = "day",
                      scope = "individual", test_prop = held_out)
  theirs <- do.call(rbind, Map(\(person, subject) {
    coefficient_rows(stats::glm(high_effort ~ efficacy, family = stats::binomial(), data = first_rows(person)), subject)
  }, people_binary, names(people_binary)))
  # Iteratively reweighted least squares on both sides, to glm.control()'s epsilon of 1e-8 on the deviance.
  expect_reference(coefs(logistic), theirs, reference = "stats", covers = c("fit_glm()", "coefs.idiographic_fit()"),
                   quantity = "logistic, 36 learners", tolerance = 1e-8, key = c("subject", "term"))
  # `help` is a 0-100 rating; tenths of it, rounded, make a count.
  counted <- transform(srl, help_count = round(help / 10))
  people_counted <- split(counted[order(counted$name, counted$day), ], counted$name[order(counted$name, counted$day)])
  counts <- fit_glm(counted, y = "help_count", x = "efficacy", id = "name", family = "poisson", time = "day",
                    scope = "individual", test_prop = held_out)
  theirs <- do.call(rbind, Map(\(person, subject) {
    coefficient_rows(stats::glm(help_count ~ efficacy, family = stats::poisson(), data = first_rows(person)), subject)
  }, people_counted, names(people_counted)))
  expect_reference(coefs(counts), theirs, reference = "stats", covers = c("fit_glm()", "coefs.idiographic_fit()"),
                   quantity = "Poisson, 36 learners", tolerance = 1e-8, key = c("subject", "term"))
})

test_that("the pooled logistic model, with standard errors clustered on the person", {
  binary <- transform(indexed, high_effort = as.integer(effort > 60))
  by_person <- split(binary[order(binary$name, binary$day), ], binary$name[order(binary$name, binary$day)])
  fit <- fit_glm(binary, y = "high_effort", x = "efficacy", id = "name", family = "binomial", time = "day",
                 scope = "pooled", test_prop = held_out)
  train <- do.call(rbind, lapply(by_person, first_rows))
  train <- train[stats::complete.cases(train[c("high_effort", "efficacy")]), ]
  pooled <- stats::glm(high_effort ~ efficacy, family = stats::binomial(), data = train)
  # The CR1 sandwich of a GLM: bread (X'WX)^-1, scores X' w r with the working weights and residuals, the factor
  # G / (G - 1), and the normal distribution for the test (Cameron & Miller, 2015).
  X <- stats::model.matrix(pooled)
  w <- stats::weights(pooled, "working")
  bread <- solve(crossprod(X, X * w))
  scores <- rowsum(X * (w * stats::residuals(pooled, "working")), train$name)
  clusters <- nrow(scores)
  std_error <- sqrt(diag(bread %*% crossprod(scores) %*% bread * clusters / (clusters - 1)))
  estimate <- stats::coef(pooled)
  # IRLS to glm.control()'s epsilon of 1e-8 on the deviance on both sides.
  expect_reference(coefs(fit), data.frame(term = names(estimate), estimate = unname(estimate), std_error = unname(std_error),
                                          statistic = unname(estimate / std_error),
                                          p_value = unname(2 * stats::pnorm(-abs(estimate / std_error)))),
                   reference = "independent: logistic regression with the CR1 cluster-robust sandwich",
                   covers = c("fit_glm()", "coefs.idiographic_fit()"), quantity = "pooled logistic model, 36 learners",
                   tolerance = 1e-8, key = "term")
})
