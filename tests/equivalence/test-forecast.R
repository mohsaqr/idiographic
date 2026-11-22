# validate_forecast(): rolling-origin one-step forecasts of the VAR(1). At each origin the VAR is refitted by
# least squares (stats::lm()) on the training blocks, standardised with the training means and SDs; each
# occasion of the next block is forecast from the previous occasion (the last training occasion for the first).
# The errors per variable and overall are then RMSE, MAE and the mean error.
#
# Least squares on at most 70 rows: rounding only, 1e-10.

items <- c("efficacy", "planning", "effort")

test_that("one-step forecasts of one learner's diary from three origins", {
  learner <- subset(esm_srl, name == "Tariq", select = c(occasion, efficacy, planning, effort))
  stopifnot("the occasions are consecutive" = all(diff(learner$occasion) == 1L))
  learner$original_row <- seq_len(nrow(learner))
  rownames(learner) <- NULL
  forecast <- validate_forecast(learner, vars = items, estimator = "var", beep = "occasion", block_size = 10L,
                                initial = 5L)
  # Blocks of ten occasions (the eighth holds eight); training ends after block 5, 6 and 7.
  block <- ceiling(seq_len(nrow(learner)) / 10)
  expected <- do.call(rbind, lapply(5:7, \(train_end) {
    train <- learner[block <= train_end, ]
    test <- learner[block == train_end + 1L, ]
    centre <- colMeans(train[items])
    spread <- vapply(train[items], stats::sd, numeric(1))
    standardise <- function(rows) as.data.frame(sweep(sweep(as.matrix(rows[items]), 2L, centre), 2L, spread, "/"))
    model <- stats::lm(stats::as.formula(sprintf("cbind(%s) ~ %s", toString(items),
                                                  paste0(items, "_lag", collapse = " + "))),
                       data = ref_lagged(standardise(train)))
    both <- standardise(rbind(train, test))
    previous <- stats::setNames(both[nrow(train) - 1L + seq_len(nrow(test)), ], paste0(items, "_lag"))
    current <- both[nrow(train) + seq_len(nrow(test)), ]
    predicted <- stats::predict(model, newdata = previous)
    do.call(rbind, lapply(items, \(v) {
      data.frame(split = train_end - 4L, original_row = test$original_row, variable = v, observed = current[[v]],
                 predicted = unname(predicted[, v]), residual = current[[v]] - unname(predicted[, v]))
    }))
  }))
  expect_reference(as.data.frame(forecast), expected, reference = "stats",
                   covers = c("validate_forecast()", "as.data.frame.forecast_result()"),
                   quantity = "Tariq, blocks of ten occasions, three origins", tolerance = 1e-10,
                   key = c("split", "original_row", "variable"))
  errors <- function(part, label) {
    data.frame(variable = label, n = nrow(part), mae = mean(abs(part$residual)), rmse = sqrt(mean(part$residual^2)),
               bias = mean(part$residual))
  }
  metrics <- rbind(do.call(rbind, lapply(items, \(v) errors(subset(expected, variable == v), v))),
                   errors(expected, ".overall"))
  expect_reference(summary(forecast), metrics,
                   reference = "independent: RMSE, MAE and mean error of the stats::lm forecasts",
                   covers = c("validate_forecast()", "summary.forecast_result()"), quantity = "Tariq, forecast errors",
                   tolerance = 1e-10, key = "variable")
  by_forecast <- rbind(do.call(rbind, lapply(items, \(v) {
    part <- subset(expected, variable == v)
    cbind(variable = v, forecast_errors(part$observed, part$predicted))
  })), cbind(variable = ".overall", forecast_errors(expected$observed, expected$predicted)))
  expect_reference(summary(forecast), by_forecast, reference = "forecast",
                   covers = c("validate_forecast()", "summary.forecast_result()"),
                   quantity = "Tariq, forecast ME, RMSE and MAE by forecast::accuracy()", tolerance = 1e-10,
                   key = "variable")
})
