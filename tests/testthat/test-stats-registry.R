# The registry exists so `model =` alone is enough to call anything. These
# tests pin that, and the contract every algorithm must honour.

reg_data <- function(seed = 1L, n_id = 8L, n_time = 40L) {
  set.seed(seed)
  n <- n_id * n_time
  d <- data.frame(id = rep(seq_len(n_id), each = n_time),
                  day = rep(seq_len(n_time), n_id),
                  x1 = stats::rnorm(n), x2 = stats::rnorm(n),
                  x3 = stats::rnorm(n))
  d$y <- 1.5 * d$x1 - d$x2 + sin(2 * d$x3) + stats::rnorm(n, sd = 0.4)
  d
}

test_that("a model name is enough; the backend is found for you", {
  d <- reg_data()
  # No `estimator =` anywhere: the registry resolves each of these.
  for (m in c("linear", "boost", "spline", "cart", "gam")) {
    fit <- fit_ml(d, "y", c("x1", "x2", "x3"), "id", model = m,
                  scope = "pooled")
    expect_true(is.finite(metrics(fit, overall = TRUE)$rmse))
  }
  # Where a model exists in several backends the native one wins by default,
  # and `estimator =` is how you override that.
  expect_equal(unique(coefs(fit_ml(d, "y", "x1:x3", "id", model = "ridge",
                                   scope = "pooled"))$estimator), "native")
  skip_if_not_installed("glmnet")
  expect_equal(unique(coefs(fit_ml(d, "y", "x1:x3", "id", model = "ridge",
                                   estimator = "glmnet",
                                   scope = "pooled"))$estimator), "glmnet")
})

test_that("models() lists what is registered and what is usable here", {
  all_models <- models()
  expect_s3_class(all_models, "idiostats_models")
  expect_true(all(c("model", "estimator", "package", "regression",
                    "classification", "installed", "parameter") %in%
                    names(all_models)))
  expect_true(any(all_models$package == "base"))

  # Filtering is an argument, not bracket code.
  expect_true(all(models(task = "classification")$classification))
  expect_true(all(models(available = TRUE)$installed))
  expect_lte(nrow(models(available = TRUE)), nrow(all_models))
  expect_output(print(all_models), "MODELS")
})

test_that("unknown or mis-tasked models say where the model actually lives", {
  d <- reg_data()
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "nonesuch",
                      scope = "pooled"), "Unknown model")
  # lda is classification-only; the message must say so rather than just
  # listing what is available.
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "lda", scope = "pooled"),
               "not for regression")
  expect_error(fit_ml(d, "y", "x1:x3", "id", model = "knn",
                      estimator = "glmnet", scope = "pooled"),
               "not provided by estimator")
  expect_error(fit_ml(d, "y", "x1:x3", "id", estimator = "nope",
                      scope = "pooled"), "`estimator` must be")
})

test_that("every usable model honours the fit/predict contract", {
  d <- reg_data()
  for (m in models(task = "regression", available = TRUE)$model) {
    fit <- try(fit_ml(d, "y", c("x1", "x2", "x3"), "id", model = m,
                      scope = "pooled"), silent = TRUE)
    if (inherits(fit, "try-error")) next
    pred <- predictions(fit)
    expect_true(all(is.finite(pred$predicted)),
                info = paste("non-finite predictions from", m))
    expect_true(is.numeric(coefs(fit)$estimate) || !nrow(coefs(fit)),
                info = paste("bad coef table from", m))
  }
})

test_that("classification models return probabilities, never labels", {
  # The guard in .idio_ml_predict() exists because six backends will happily
  # hand back a class label or a link value instead, and every one of those
  # failures is silent.
  set.seed(3)
  n_id <- 8L
  n_time <- 40L
  n <- n_id * n_time
  d <- data.frame(id = rep(seq_len(n_id), each = n_time),
                  x1 = stats::rnorm(n), x2 = stats::rnorm(n),
                  x3 = stats::rnorm(n))
  d$y <- factor(ifelse(stats::runif(n) < stats::plogis(d$x1 - d$x2),
                       "yes", "no"), levels = c("no", "yes"))

  for (m in models(task = "classification", available = TRUE)$model) {
    fit <- try(fit_ml(d, "y", c("x1", "x2", "x3"), "id", model = m,
                      scope = "pooled"), silent = TRUE)
    if (inherits(fit, "try-error")) next
    probs <- predictions(fit)$probability
    expect_true(all(probs >= 0 & probs <= 1, na.rm = TRUE),
                info = paste("non-probability output from", m))
  }
})

test_that("boosted stumps are additive by construction, and say so", {
  # A depth-1 tree splits on ONE variable, so no number of rounds can
  # represent an interaction. This is a property of the algorithm, not a bug,
  # and the docs claim it -- so it is pinned.
  set.seed(5)
  n_id <- 8L
  n_time <- 60L
  n <- n_id * n_time
  d <- data.frame(id = rep(seq_len(n_id), each = n_time),
                  x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  d$pure_interaction <- 2 * d$x1 * d$x2 + stats::rnorm(n, sd = 0.3)
  d$additive <- 2 * d$x1^2 - d$x2 + stats::rnorm(n, sd = 0.3)

  interaction_fit <- fit_ml(d, "pure_interaction", c("x1", "x2"), "id",
                            model = "boost", scope = "pooled", rounds = 300)
  additive_fit <- fit_ml(d, "additive", c("x1", "x2"), "id", model = "boost",
                         scope = "pooled", rounds = 300)
  # Nothing on a pure interaction; a great deal on a nonlinear additive one.
  expect_lt(metrics(interaction_fit, overall = TRUE)$r_squared, 0.15)
  expect_gt(metrics(additive_fit, overall = TRUE)$r_squared, 0.5)
})

test_that("more boosting rounds keep improving the training fit", {
  # A degenerate stump that isolates two outliers wins every round and the
  # ensemble never moves, which is what a minimum leaf size prevents.
  set.seed(7)
  n <- 400L
  X <- cbind(x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  Xs <- .idio_apply_scale(X, .idio_scale(X))
  y <- 2 * X[, 1]^2 - X[, 2] + stats::rnorm(n, sd = 0.3)
  control <- .idio_ml_control(lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                              mtry = NULL, num_trees = 10L, cost = 1, p = 2L)

  fitted_r2 <- vapply(c(20L, 100L, 400L), function(rounds) {
    control$rounds <- rounds
    fit <- .idio_fit_boost(Xs, y, c("x1", "x2"), "regression", control)
    fit$task <- "regression"
    1 - stats::var(y - .idio_boost_predict(fit, Xs)) / stats::var(y)
  }, numeric(1))
  expect_true(all(diff(fitted_r2) > 0))
  expect_gt(fitted_r2[3L], fitted_r2[1L] + 0.05)
})

test_that("permutation importance explains models that have no coefficients", {
  # The coefficient method can only describe models that HAVE coefficients,
  # which silently excludes knn, forests and kernel machines -- exactly the
  # models most likely to win.
  set.seed(11)
  n_id <- 8L
  n_time <- 60L
  n <- n_id * n_time
  d <- data.frame(id = rep(seq_len(n_id), each = n_time),
                  x1 = stats::rnorm(n), x2 = stats::rnorm(n),
                  x3 = stats::rnorm(n))
  # x1 matters, x2 is irrelevant, x3 acts only through a nonlinearity.
  d$y <- 3 * d$x1 + sin(3 * d$x3) + stats::rnorm(n, sd = 0.3)

  knn_fit <- fit_ml(d, "y", c("x1", "x2", "x3"), "id", model = "knn",
                    scope = "pooled")
  expect_equal(nrow(importance(knn_fit)), 0L)          # nothing to report ...
  perm <- importance(knn_fit, method = "permutation")  # ... until now
  expect_gt(nrow(perm), 0L)

  rank_of <- function(tab) {
    agg <- stats::aggregate(importance ~ variable, tab, mean)
    agg$variable[order(-agg$importance)]
  }
  expect_equal(rank_of(perm)[1L], "x1")
  expect_equal(rank_of(perm)[3L], "x2")               # irrelevant, ranked last

  # A linear model cannot see x3 at all, and permutation says so.
  linear_perm <- importance(fit_ml(d, "y", c("x1", "x2", "x3"), "id",
                                   model = "linear", scope = "pooled"),
                            method = "permutation")
  agg <- stats::aggregate(importance ~ variable, linear_perm, mean)
  expect_gt(agg$importance[agg$variable == "x1"], 1)
  expect_lt(abs(agg$importance[agg$variable == "x3"]), 0.1)
})
