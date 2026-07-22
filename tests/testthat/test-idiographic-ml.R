test_that("fit_ml compares individual and pooled regression models", {
  set.seed(701)
  n_id <- 4
  n_t <- 50
  slopes <- c(-0.8, -0.2, 0.5, 1.1)
  d <- do.call(rbind, lapply(seq_len(n_id), function(id) {
    x1 <- stats::rnorm(n_t)
    x2 <- stats::rnorm(n_t)
    data.frame(
      id = id,
      beep = seq_len(n_t),
      x1 = x1,
      x2 = x2,
      y = slopes[id] * x1 + 0.3 * x2 + stats::rnorm(n_t, sd = 0.25)
    )
  }))

  fit <- fit_ml(
    d, outcome = "y", predictors = c("x1", "x2"), id = "id", beep = "beep",
    model = c("linear", "ridge", "knn"),
    test_prop = 0.25, min_train = 20, standardize = FALSE
  )

  expect_s3_class(fit, "idioml_result")
  expect_named(fit$predictions,
               c("model_scope", "model", "estimator", "subject", "original_row",
                 "observed", "predicted", "residual", "abs_error",
                 "squared_error"))
  expect_setequal(unique(fit$predictions$model_scope),
                  c("individual", "pooled"))
  expect_setequal(unique(fit$predictions$model),
                  c("linear", "ridge", "knn"))
  expect_equal(unique(fit$predictions$estimator), "native")
  expect_equal(
    sort(fit$predictions$original_row[fit$predictions$model_scope == "individual"]),
    sort(fit$predictions$original_row[fit$predictions$model_scope == "pooled"])
  )
  expect_true(any(fit$metrics$subject == ".overall"))
  expect_named(coefs(fit), c("model_scope", "model", "estimator", "subject",
                             "term", "estimate"))
  expect_equal(as.data.frame(fit), fit$predictions)
  expect_output(print(fit), "Idiographic Machine-Learning Result")
  expect_equal(summary(fit), fit$metrics)
})

test_that("fit_individualized_ml alias and ridge handle p greater than n", {
  set.seed(702)
  n_id <- 3
  n_t <- 16
  x <- replicate(10, stats::rnorm(n_id * n_t))
  colnames(x) <- paste0("x", seq_len(ncol(x)))
  d <- data.frame(id = rep(seq_len(n_id), each = n_t),
                  beep = rep(seq_len(n_t), n_id),
                  x)
  d$y <- rowSums(d[paste0("x", 1:3)]) + stats::rnorm(nrow(d), sd = 0.2)

  fit <- fit_individualized_ml(
    d, outcome = "y", predictors = paste0("x", seq_len(10)), id = "id",
    beep = "beep", model = "ridge", lambda = 0.5, test_prop = 0.25,
    min_train = 8
  )

  expect_s3_class(fit, "idioml_result")
  expect_equal(fit$model, "ridge")
  expect_equal(fit$estimators$estimator, "native")
  expect_true(all(is.finite(fit$metrics$rmse)))
})

test_that("fit_ml regression model = all covers native models", {
  set.seed(705)
  d <- data.frame(
    id = rep(1:3, each = 35),
    beep = rep(seq_len(35), 3),
    x1 = stats::rnorm(105),
    x2 = stats::rnorm(105),
    x3 = stats::rnorm(105)
  )
  d$y <- 0.6 * d$x1 - 0.3 * d$x2 + stats::rnorm(105, sd = 0.3)

  fit <- fit_ml(
    d, outcome = "y", predictors = c("x1", "x2", "x3"), id = "id",
    beep = "beep", model = "all", compare = "pooled",
    test_prop = 0.25, min_train = 20, lambda = 0.05, k = 3,
    n_components = 2
  )

  expect_setequal(fit$model,
                  c("mean", "linear", "ridge",
                    "lasso", "elastic", "pcr", "knn", "tree"))
  expect_setequal(unique(fit$metrics$model), fit$model)
  expect_equal(unique(fit$metrics$estimator), "native")
  expect_true(all(is.finite(fit$metrics$rmse)))
})

test_that("fit_ml estimator selects implementation separately from model", {
  set.seed(707)
  d <- data.frame(id = rep(1:2, each = 30),
                  beep = rep(seq_len(30), 2),
                  x = stats::rnorm(60))
  d$y <- 0.5 * d$x + stats::rnorm(60, sd = 0.2)

  fit <- fit_ml(d, outcome = "y", predictors = "x", id = "id",
                beep = "beep", model = "linear",
                estimator = c(linear = "native"),
                compare = "pooled", min_train = 15)

  expect_equal(fit$estimators$model, "linear")
  expect_equal(fit$estimators$estimator, "native")
  expect_error(
    fit_ml(d, outcome = "y", predictors = "x", id = "id", beep = "beep",
           model = "linear", estimator = "some_package"),
    "Unsupported estimator"
  )
})

test_that("idiographic ML supports binary classification", {
  set.seed(703)
  n_id <- 4
  n_t <- 45
  d <- do.call(rbind, lapply(seq_len(n_id), function(id) {
    x1 <- stats::rnorm(n_t)
    x2 <- stats::rnorm(n_t)
    eta <- -0.2 + 0.9 * x1 - 0.4 * x2 + (id - 2.5) * 0.2
    p <- stats::plogis(eta)
    data.frame(id = id, beep = seq_len(n_t), x1 = x1, x2 = x2,
               y = factor(ifelse(stats::runif(n_t) < p, "yes", "no"),
                          levels = c("no", "yes")))
  }))

  fit <- fit_ml(
    d, outcome = "y", predictors = c("x1", "x2"), id = "id", beep = "beep",
    task = "classification", test_prop = 0.25, min_train = 20
  )

  expect_equal(fit$task, "classification")
  expect_equal(fit$positive, "yes")
  expect_named(fit$predictions,
               c("model_scope", "model", "estimator", "subject",
                 "original_row",
                 "observed_class", "predicted_class", "probability",
                 "correct", "brier"))
  expect_true(all(fit$predictions$probability >= 0 &
                    fit$predictions$probability <= 1))
  expect_named(fit$metrics,
               c("model_scope", "model", "estimator", "subject", "n",
                 "accuracy", "brier", "log_loss"))
})

test_that("fit_ml classification model = all covers native models", {
  set.seed(706)
  d <- do.call(rbind, lapply(1:4, function(id) {
    n <- 50
    x1 <- stats::rnorm(n)
    x2 <- stats::rnorm(n)
    p <- stats::plogis(0.8 * x1 - 0.5 * x2)
    data.frame(id = id, beep = seq_len(n), x1 = x1, x2 = x2,
               y = factor(ifelse(stats::runif(n) < p, "yes", "no"),
                          levels = c("no", "yes")))
  }))

  fit <- fit_ml(
    d, outcome = "y", predictors = c("x1", "x2"), id = "id", beep = "beep",
    task = "classification", model = "all", compare = "pooled",
    test_prop = 0.25, min_train = 25, lambda = 0.05, k = 3
  )

  expect_setequal(fit$model,
                  c("majority", "logistic", "ridge", "lasso", "elastic",
                    "lda", "bayes", "knn", "tree"))
  expect_setequal(unique(fit$metrics$model), fit$model)
  expect_equal(unique(fit$metrics$estimator), "native")
  expect_true(all(fit$metrics$accuracy >= 0 & fit$metrics$accuracy <= 1))
})

test_that("predict.idioml_result scores new data when fits are kept", {
  set.seed(704)
  d <- data.frame(
    id = rep(1:2, each = 35),
    beep = rep(seq_len(35), 2),
    x = stats::rnorm(70)
  )
  d$y <- ifelse(d$id == 1, 1, -1) * d$x + stats::rnorm(70, sd = 0.1)
  fit <- fit_ml(
    d, outcome = "y", predictors = "x", id = "id", beep = "beep",
    model = c("linear", "ridge"), keep_fits = TRUE,
    standardize = FALSE, min_train = 20
  )
  new <- data.frame(id = c(1, 2), x = c(0.5, 0.5))

  pooled <- predict(fit, new, scope = "pooled", model = "ridge")
  individual <- predict(fit, new, scope = "individual",
                        model = "linear")

  expect_named(pooled, c("model_scope", "model", "estimator", "subject",
                         "original_row", "predicted"))
  expect_equal(nrow(individual), 2L)
  expect_true(individual$predicted[1] > individual$predicted[2])
})

test_that("fit_ml accepts flexible predictor selectors and direct model args", {
  set.seed(708)
  d <- data.frame(
    id = rep(1:2, each = 30),
    beep = rep(seq_len(30), 2),
    x1 = stats::rnorm(60),
    x2 = stats::rnorm(60),
    x3 = stats::rnorm(60)
  )
  d$y <- d$x1 - d$x3 + stats::rnorm(60, sd = 0.2)

  by_pos <- fit_ml(d, "y", 3:5, "id", model = "ridge", compare = "pooled",
                  lambda = 0.2, min_train = 15)
  by_range <- fit_ml(d, "y", "x1:x3", "id", model = "ridge",
                     compare = "pooled", lambda = 0.2, min_train = 15)
  by_formula <- fit_ml(d, "y", ~ x1 + x2 + x3, "id", model = "ridge",
                       compare = "pooled", lambda = 0.2, min_train = 15)
  by_df <- fit_ml(d, "y", d[c("x1", "x2", "x3")], "id", model = "ridge",
                  compare = "pooled", lambda = 0.2, min_train = 15)

  expect_equal(by_pos$predictors, c("x1", "x2", "x3"))
  expect_equal(by_range$predictors, by_pos$predictors)
  expect_equal(by_formula$predictors, by_pos$predictors)
  expect_equal(by_df$predictors, by_pos$predictors)
  expect_equal(by_pos$config$lambda, 0.2)
  expect_error(
    fit_ml(d, "y", "x1", "id", model = "ridge", nonsense = 1),
    "Unknown model argument"
  )
})
