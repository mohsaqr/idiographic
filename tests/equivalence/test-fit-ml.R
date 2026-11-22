# fit_ml(): the machine-learning interface, through its linear and logistic learners (the package's own
# least-squares and IRLS solvers), against stats::lm() and stats::glm() on the same estimation rows (all but
# the last 20% of each person's occasions), unstandardised; and the held-out predictions and their errors.
# The other learners call their packages (rpart, mgcv, MASS, xgboost, ...) and are not compared here.

held_out <- 0.2

simulated <- function() {
  set.seed(907)
  frame <- data.frame(id = rep(1:4, each = 40), beep = rep(seq_len(40), 4), x1 = stats::rnorm(160), x2 = stats::rnorm(160))
  frame$y <- 0.4 + 0.7 * frame$x1 - 0.3 * frame$x2 + stats::rnorm(160, sd = 0.2)
  frame$class <- factor(ifelse(0.8 * frame$x1 - 0.5 * frame$x2 + stats::rnorm(160) > 0, "yes", "no"), levels = c("no", "yes"))
  frame$original_row <- seq_len(nrow(frame))
  frame
}

estimation <- function(frame) {
  do.call(rbind, lapply(split(frame, frame$id), \(person) utils::head(person, nrow(person) - ceiling(held_out * nrow(person)))))
}

test_that("the pooled linear learner is least squares on the estimation rows", {
  frame <- simulated()
  fit <- fit_ml(frame, outcome = "y", predictors = c("x1", "x2"), id = "id", beep = "beep", task = "regression",
                model = "linear", compare = "pooled", test_prop = held_out, standardize = FALSE, keep_fits = TRUE)
  reference <- stats::lm(y ~ x1 + x2, data = estimation(frame))
  # Least squares on 128 rows on both sides; 1e-12 relative, the old test's bound (testthat's relative tolerance).
  expect_reference(coefs(fit), data.frame(term = names(stats::coef(reference)), estimate = unname(stats::coef(reference))),
                   reference = "stats", covers = c("fit_ml()", "coefs.idioml_result()"),
                   quantity = "pooled linear model, four people", tolerance = 1e-12, measure = "relative", key = "term")
  legacy <- list(fit_idiographic_ml = fit_idiographic_ml, fit_individualized_ml = fit_individualized_ml)
  invisible(Map(\(fitter, name) {
    same <- fitter(frame, outcome = "y", predictors = c("x1", "x2"), id = "id", beep = "beep", task = "regression",
                   model = "linear", compare = "pooled", test_prop = held_out, standardize = FALSE)
    expect_reference(coefs(same), data.frame(term = names(stats::coef(reference)), estimate = unname(stats::coef(reference))),
                     reference = "stats", covers = sprintf("%s()", name),
                     quantity = sprintf("pooled linear model through %s()", name), tolerance = 1e-12, measure = "relative",
                     key = "term")
  }, legacy, names(legacy)))
  test_rows <- frame[!frame$original_row %in% estimation(frame)$original_row, ]
  predicted <- data.frame(original_row = test_rows$original_row, observed = test_rows$y,
                          predicted = unname(stats::predict(reference, newdata = test_rows)))
  predicted$residual <- predicted$observed - predicted$predicted
  expect_reference(as.data.frame(fit), predicted, reference = "stats",
                   covers = c("fit_ml()", "as.data.frame.idioml_result()"), quantity = "held-out predictions",
                   tolerance = 1e-10, key = "original_row")
  expect_reference(predict(fit, newdata = frame),
                   data.frame(original_row = frame$original_row, predicted = unname(stats::predict(reference, newdata = frame))),
                   reference = "stats", covers = "predict.idioml_result()", quantity = "predictions for every row",
                   tolerance = 1e-10, key = "original_row")
  errors <- function(part, subject) {
    data.frame(subject = subject, n = nrow(part), mae = mean(abs(part$residual)), rmse = sqrt(mean(part$residual^2)),
               bias = mean(part$residual), r_squared = 1 - sum(part$residual^2) / sum((part$observed - mean(part$observed))^2))
  }
  predicted$subject <- as.character(test_rows$id)
  expected <- rbind(do.call(rbind, Map(errors, split(predicted, predicted$subject), sort(unique(predicted$subject)))),
                    errors(predicted, ".overall"))
  expect_reference(summary(fit), expected,
                   reference = "independent: RMSE, MAE, mean error and 1 - SSE / SST",
                   covers = "summary.idioml_result()", quantity = "held-out prediction errors", tolerance = 1e-10,
                   key = "subject")
  by_forecast <- rbind(do.call(rbind, lapply(split(predicted, predicted$subject), \(part) {
    cbind(subject = part$subject[[1L]], forecast_errors(part$observed, part$predicted))
  })), cbind(subject = ".overall", forecast_errors(predicted$observed, predicted$predicted)))
  expect_reference(summary(fit), by_forecast, reference = "forecast", covers = "summary.idioml_result()",
                   quantity = "held-out ME, RMSE and MAE by forecast::accuracy()", tolerance = 1e-10, key = "subject")
})

test_that("the pooled logistic learner is the maximum-likelihood logistic regression", {
  frame <- simulated()
  fit <- fit_ml(frame, outcome = "class", predictors = c("x1", "x2"), id = "id", beep = "beep", task = "classification",
                model = "logistic", compare = "pooled", test_prop = held_out, standardize = FALSE)
  train <- estimation(frame)
  reference <- stats::glm(I(class == "yes") ~ x1 + x2, family = stats::binomial(), data = train)
  # 1e-12 relative, the old test's bound against stats::glm.fit() (testthat's relative tolerance).
  expect_reference(coefs(fit), data.frame(term = c("(Intercept)", "x1", "x2"), estimate = unname(stats::coef(reference))),
                   reference = "stats", covers = c("fit_ml()", "coefs.idioml_result()"),
                   quantity = "pooled logistic model, four people", tolerance = 1e-12, measure = "relative", key = "term")
})
