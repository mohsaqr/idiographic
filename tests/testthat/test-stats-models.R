reg_panel <- function(n_id = 3L, n_time = 60L) {
  set.seed(5)
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time),
    x3 = stats::rnorm(n_id * n_time)
  )
  d$y <- 0.9 * d$x1 - 0.5 * d$x2 + stats::rnorm(nrow(d), sd = 0.3)
  d
}

cls_panel <- function(n_id = 3L, n_time = 60L) {
  d <- reg_panel(n_id, n_time)
  set.seed(6)
  p <- stats::plogis(0.9 * d$x1 - 0.5 * d$x2)
  d$y <- factor(ifelse(stats::runif(nrow(d)) < p, "yes", "no"),
                levels = c("no", "yes"))
  d
}

test_that("every native regression model fits and predicts", {
  d <- reg_panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = "all", time = "time",
                scope = "pooled", min_train = 20)

  expect_setequal(unique(metrics(fit)$model),
                  models(task = "regression", available = TRUE)$model)
  expect_true(all(c("mean", "linear", "ridge", "lasso", "elastic", "pcr",
                    "knn", "tree") %in% unique(metrics(fit)$model)))
  ov <- metrics(fit, overall = TRUE)
  expect_true(all(is.finite(ov$rmse)))
  # Every real model must beat the mean baseline on learnable data.
  baseline <- ov$rmse[ov$model == "mean"]
  expect_true(all(ov$rmse[ov$model %in% c("linear", "ridge", "lasso",
                                          "elastic", "pcr")] < baseline))
})

test_that("every native classification model fits and predicts", {
  d <- cls_panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = "all", time = "time",
                scope = "pooled", min_train = 20)

  # `model = "all"` means every model usable here, so the expectation comes
  # from the registry rather than a frozen list that must be edited whenever
  # an algorithm is added.
  expect_setequal(unique(metrics(fit)$model),
                  models(task = "classification", available = TRUE)$model)
  expect_true(all(c("majority", "logistic", "ridge", "lasso", "elastic",
                    "lda", "bayes", "knn", "tree") %in%
                    unique(metrics(fit)$model)))
  ov <- metrics(fit, overall = TRUE)
  expect_true(all(ov$accuracy >= 0 & ov$accuracy <= 1))
  expect_true(all(is.finite(ov$brier)))
  probs <- predictions(fit)$probability
  expect_true(all(probs >= 0 & probs <= 1))
})

test_that("the native elastic-net solver matches a known optimum", {
  set.seed(42)
  n <- 200L
  X <- scale(matrix(stats::rnorm(n * 6L), n, 6L))
  beta <- c(2, -1.5, 0, 0, 0.8, 0)
  y <- as.numeric(X %*% beta) + stats::rnorm(n, sd = 0.5)

  # Unpenalized limit must reproduce ordinary least squares.
  ours <- idiographic:::.idio_enet_fit(X, y, lambda = 0, alpha = 0,
                                     family = "gaussian")
  ols <- unname(stats::coef(stats::lm(y ~ X)))
  expect_equal(ours, ols, tolerance = 1e-6)

  # Lasso must zero out the irrelevant predictors and lower the objective
  # relative to a shrunk-to-zero solution.
  lasso <- idiographic:::.idio_enet_fit(X, y, lambda = 25, alpha = 1,
                                      family = "gaussian")
  expect_true(sum(abs(lasso[-1]) < 1e-8) >= 2L)

  obj <- function(b) {
    0.5 * sum((y - b[1] - X %*% b[-1])^2) + 25 * sum(abs(b[-1]))
  }
  expect_lt(obj(lasso), obj(c(mean(y), rep(0, 6))))
  expect_lt(obj(lasso), obj(ols))
})

test_that("tunable models expose their parameter", {
  d <- reg_panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = c("lasso", "pcr", "knn"),
                time = "time", scope = "pooled", min_train = 20, tune = TRUE)
  tab <- tuning(fit)
  params <- unique(tab[c("model", "parameter")])
  expect_equal(params$parameter[params$model == "lasso"], "lambda")
  expect_equal(params$parameter[params$model == "pcr"], "ncomp")
  expect_equal(params$parameter[params$model == "knn"], "k")
})

test_that("unsupported models are rejected with a helpful message", {
  d <- reg_panel()
  # A classification-only model asked for on a numeric outcome says so, and
  # says that it exists for the other task rather than just "unknown".
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "lda", scope = "pooled",
                      min_train = 20),
               "not for regression")
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "nonesuch",
                      scope = "pooled", min_train = 20),
               "Unknown model")
  # Naming a backend that does not provide the model explains where it lives.
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "knn",
                      estimator = "glmnet", scope = "pooled", min_train = 20),
               "not provided by estimator")
})

test_that("glmnet backend works when installed", {
  skip_if_not_installed("glmnet")
  d <- reg_panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = "lasso", estimator = "glmnet",
                time = "time", scope = "pooled", min_train = 20)
  expect_equal(unique(metrics(fit)$estimator), "glmnet")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
  expect_true(nrow(coefs(fit)) > 0L)
})

test_that("ranger backend works when installed", {
  skip_if_not_installed("ranger")
  d <- reg_panel()
  fit <- fit_ml(d, "y", "x1:x3", "id", model = "forest", estimator = "ranger",
                time = "time", scope = "pooled", min_train = 20,
                num_trees = 50L)
  expect_equal(unique(metrics(fit)$model), "forest")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
  # ranger importance flows into the shared importance() verb.
  expect_true(nrow(importance(fit)) > 0L)
})

test_that("e1071 backend works for regression and classification", {
  skip_if_not_installed("e1071")
  d <- reg_panel()
  reg <- fit_ml(d, "y", "x1:x3", "id", model = "svm", estimator = "e1071",
                time = "time", scope = "pooled", min_train = 20)
  expect_true(all(is.finite(metrics(reg, overall = TRUE)$rmse)))

  dc <- cls_panel()
  cls <- fit_ml(dc, "y", "x1:x3", "id", model = c("svm", "bayes"),
                estimator = "e1071", time = "time", scope = "pooled",
                min_train = 20)
  ov <- metrics(cls, overall = TRUE)
  expect_setequal(ov$model, c("svm", "bayes"))
  expect_true(all(ov$accuracy >= 0 & ov$accuracy <= 1))
})
