# What is read from a fitted panel regression: best_model(), compare(), compare_predictions(), diagnostics(),
# importance(method = "coefficient"), summarize_importance(), and fit_ml_panel() with tuning(). The models are
# refitted here with stats::lm() on each person's estimation rows (all but the last ceiling(0.2 n) occasions,
# in time order) and pooled over people; every derived number is then written from its definition.
#
# Least squares by QR on at most 4,500 rows, then sums and means of the residuals: rounding only, 1e-10.

held_out <- 0.2
predictors <- c("efficacy", "planning")

indexed <- transform(srl, row = seq_len(nrow(srl)))
ordered <- indexed[order(indexed$name, indexed$day), ]
people <- split(ordered, ordered$name)
first_rows <- function(person) utils::head(person, nrow(person) - ceiling(held_out * nrow(person)))
last_rows <- function(person) utils::tail(person, ceiling(held_out * nrow(person)))

person_models <- lapply(people, \(person) stats::lm(effort ~ efficacy + planning, data = first_rows(person)))
pooled_model <- stats::lm(effort ~ efficacy + planning, data = do.call(rbind, lapply(people, first_rows)))

#' The held-out predictions of one model per person (or one model for everybody), on the complete held-out rows
held_out_predictions <- function(models) {
  do.call(rbind, Map(\(person, model) {
    rows <- last_rows(person)
    rows <- rows[stats::complete.cases(rows[c("effort", predictors)]), ]
    predicted <- as.vector(stats::predict(model, newdata = rows))
    data.frame(subject = rows$name, row = rows$row, observed = rows$effort, predicted = predicted,
               residual = rows$effort - predicted)
  }, people, models))
}

individual <- held_out_predictions(person_models)
pooled <- held_out_predictions(rep(list(pooled_model), length(people)))

#' RMSE, MAE, mean error and 1 - SSE / SST of a table of predictions
prediction_errors <- function(part, subject) {
  data.frame(subject = subject, n = nrow(part), rmse = sqrt(mean(part$residual^2)), mae = mean(abs(part$residual)),
             bias = mean(part$residual),
             r_squared = 1 - sum(part$residual^2) / sum((part$observed - mean(part$observed))^2))
}
per_person_errors <- function(predicted) {
  do.call(rbind, Map(prediction_errors, split(predicted, predicted$subject), sort(unique(predicted$subject))))
}

test_that("best_model() is the overall row with the smallest held-out RMSE", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "both", test_prop = held_out)
  overall <- rbind(cbind(scope = "pooled", prediction_errors(pooled, ".overall")),
                   cbind(scope = "individual", prediction_errors(individual, ".overall")))
  smallest <- overall[which.min(overall$rmse), ]
  expect_reference(best_model(fit), smallest, reference = "independent: the smallest RMSE of the stats::lm predictions",
                   covers = c("best_model()", "best_model.idiographic_fit()", "best_model.idiostats_fit()"),
                   quantity = "36 learners, pooled and individual", tolerance = 1e-10, key = "scope",
                   note = "best_model.idiostats_fit() is the same function object as best_model.idiographic_fit().")
  expect_reference(best_model(fit, scope = "pooled"), subset(overall, scope == "pooled"),
                   reference = "independent: the smallest RMSE of the stats::lm predictions",
                   covers = "best_model.idiographic_fit()", quantity = "36 learners, pooled only", tolerance = 1e-10,
                   key = "scope")
})

test_that("compare_predictions() is the per-person gain in RMSE over the pooled model", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "both", test_prop = held_out)
  own <- per_person_errors(individual)
  reference <- per_person_errors(pooled)
  gains <- data.frame(subject = own$subject, n = own$n, value = own$rmse, reference_value = reference$rmse,
                      gain = reference$rmse - own$rmse)
  expect_reference(compare_predictions(fit), gains, reference = "independent: RMSE of the stats::lm predictions, per person",
                   covers = "compare_predictions()", quantity = "36 learners, RMSE gain over the pooled model",
                   tolerance = 1e-10, key = "subject")
  own_mae <- data.frame(subject = own$subject, value = own$mae, reference_value = reference$mae,
                        gain = reference$mae - own$mae)
  expect_reference(compare_predictions(fit, metric = "mae"), own_mae,
                   reference = "independent: RMSE of the stats::lm predictions, per person",
                   covers = "compare_predictions()", quantity = "36 learners, MAE gain over the pooled model",
                   tolerance = 1e-10, key = "subject")
})

test_that("diagnostics() are the residuals, their absolute and squared values and the residual over its SD", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  expected <- transform(individual, abs_error = abs(residual), squared_error = residual^2,
                        std_residual = residual / stats::ave(residual, subject, FUN = stats::sd))
  expect_reference(diagnostics(fit), expected,
                   reference = "independent: residuals of the stats::lm predictions",
                   covers = c("diagnostics()", "diagnostics.idiographic_fit()", "diagnostics.idiostats_fit()"),
                   quantity = "36 learners, held-out residuals", tolerance = 1e-10, key = c("subject", "row"),
                   note = "std_residual divides by the SD of the person's held-out residuals without centring them.")
})

test_that("coefficient importance is the absolute coefficient, and its mean over people", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  absolute <- do.call(rbind, Map(\(model, subject) {
    data.frame(subject = subject, variable = predictors, importance = unname(abs(stats::coef(model)[predictors])))
  }, person_models, names(person_models)))
  expect_reference(importance(fit), absolute, reference = "independent: absolute stats::lm coefficients",
                   covers = c('importance(method = "coefficient")', "importance.idiographic_fit()",
                              "importance.idiostats_fit()"),
                   quantity = "36 learners, |coefficient|", tolerance = 1e-10, key = c("subject", "variable"))
  averaged <- data.frame(variable = predictors, n_subjects = length(person_models),
                         importance = vapply(predictors, \(v) mean(subset(absolute, variable == v)$importance), numeric(1)))
  expect_reference(summarize_importance(fit), averaged, reference = "independent: absolute stats::lm coefficients",
                   covers = 'summarize_importance(method = "coefficient")',
                   quantity = "mean |coefficient| over 36 learners", tolerance = 1e-10, key = "variable")
})

test_that("compare() stacks the overall errors of each fit", {
  linear <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                   test_prop = held_out)
  ml <- fit_ml_panel(srl, "effort", predictors, "name", time = "day", scope = "individual", model = "linear",
                     test_prop = held_out)
  # fit_ml_panel()'s linear learner is least squares on standardised predictors: the same predictions.
  overall <- prediction_errors(individual, ".overall")
  expected <- rbind(cbind(fit = 1L, model = "lm", overall), cbind(fit = 2L, model = "linear", overall))
  expect_reference(compare(linear, ml), expected, reference = "independent: errors of the stats::lm predictions",
                   covers = "compare()", quantity = "fit_lm() and fit_ml_panel(), individual models",
                   tolerance = 1e-10, key = c("fit", "model"))
})

test_that("compare() of a regression and a classification fit", {
  linear <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                   test_prop = held_out)
  binary <- transform(srl, high_effort = as.integer(effort > 60))
  logistic <- fit_glm(binary, y = "high_effort", x = "efficacy", id = "name", family = "binomial", time = "day",
                      scope = "individual", test_prop = held_out)
  # Documented to accept fits of fit_lm() and fit_glm(); it should return one row per fit with the metric columns
  # each has.
  expect_defect_error(compare(linear, logistic),
                      defect = "compare() stops ('numbers of columns of arguments do not match') when a regression and a classification fit are compared: rbind() of metric tables with different columns; FINDINGS.md",
                      covers = "compare()", quantity = "fit_lm() and a logistic fit_glm()")
})

test_that("fit_ml_panel(): the linear learner, and ridge tuned on the validation block", {
  three <- subset(srl, name %in% c("Aisha", "Alice", "Anika"))
  by_person <- split(three[order(three$name, three$day), ], three$name[order(three$name, three$day)])
  standardised <- function(train, rows) {
    centre <- colMeans(train[predictors])
    spread <- vapply(train[predictors], stats::sd, numeric(1))
    cbind("(Intercept)" = 1, sweep(sweep(as.matrix(rows[predictors]), 2L, centre), 2L, spread, "/"))
  }
  linear <- fit_ml_panel(three, "effort", predictors, "name", time = "day", scope = "individual", model = "linear",
                         test_prop = held_out)
  theirs <- do.call(rbind, lapply(by_person, \(person) {
    train <- first_rows(person)
    model <- stats::lm.fit(standardised(train, train), train$effort)
    data.frame(subject = person$name[[1L]], term = c("(Intercept)", predictors), estimate = unname(model$coefficients))
  }))
  expect_reference(coefs(linear), theirs, reference = "stats",
                   covers = c("fit_ml_panel()", "coefs.idiographic_fit()"),
                   quantity = "three learners, least squares on standardised predictors", tolerance = 1e-10,
                   key = c("subject", "term"))
  # Tuning: of the estimation rows, the last ceiling(0.2 m) form the validation block; each lambda's ridge
  # (X'X + lambda P) b = X'y, intercept unpenalised, is fitted on the rest with predictors standardised on it.
  ridge <- fit_ml_panel(three, "effort", predictors, "name", time = "day", scope = "individual", model = "ridge",
                        tune = TRUE, test_prop = held_out)
  grid <- c(0, 0.01, 0.1, 0.5, 1, 2, 5, 10)
  validation <- do.call(rbind, lapply(by_person, \(person) {
    estimation <- first_rows(person)
    n_valid <- ceiling(held_out * nrow(estimation))
    train <- utils::head(estimation, nrow(estimation) - n_valid)
    valid <- utils::tail(estimation, n_valid)
    X <- standardised(train, train)
    penalty <- diag(c(0, rep(1, length(predictors))))
    do.call(rbind, lapply(grid, \(lambda) {
      beta <- solve(crossprod(X) + lambda * penalty, crossprod(X, train$effort))
      residual <- valid$effort - as.vector(standardised(train, valid) %*% beta)
      data.frame(subject = person$name[[1L]], value = as.character(lambda), n = n_valid,
                 rmse = sqrt(mean(residual^2)), mae = mean(abs(residual)))
    }))
  }))
  expect_reference(tuning(ridge), validation, reference = "independent: ridge regression written out (closed form)",
                   covers = c("tuning()", "tuning.idiographic_fit()", "tuning.idiostats_fit()", "fit_ml_panel()"),
                   quantity = "three learners, validation errors per lambda", tolerance = 1e-10,
                   key = c("subject", "value"))
})

test_that("permutation importance of a fit_lm() fit", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  # Documented for any idiographic fit ("model-agnostic"); it works on fit_ml() fits
  # (test-importance-permutation.R). On a fit_lm() fit it should return one row per learner and predictor.
  set.seed(1)
  expect_defect_error(importance(fit, method = "permutation", repeats = 5L),
                      defect = "importance(method = 'permutation') stops ('argument is of length zero') on a fit_lm() fit: the stored lm objects are passed to the machine-learning predictor, which expects a fit with a `type`; FINDINGS.md",
                      covers = 'importance(method = "permutation")', quantity = "36 learners, fit_lm() individual models")
})
