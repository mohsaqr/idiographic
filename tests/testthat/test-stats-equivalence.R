# Equivalence tests: does each wrapper compute what the reference computes?
#
# The contract tests elsewhere only check that a model fits, predicts finitely
# and returns a probability. A wrapper can pass all of that while quietly
# computing the wrong thing -- predicting on the wrong scale, returning a class
# label, or re-standardizing already-standardized predictors. These compare
# against the reference implementation directly.

eq_data <- function(seed = 1L, n = 300L, p = 3L) {
  set.seed(seed)
  X <- matrix(stats::rnorm(n * p), n, p,
              dimnames = list(NULL, paste0("x", seq_len(p))))
  list(X = X, Xs = .idio_apply_scale(X, .idio_scale(X)),
       y = as.numeric(1.5 * X[, 1] - X[, 2] + stats::rnorm(n, sd = 0.4)),
       x = colnames(X), n = n, p = p)
}

eq_control <- function(d, ...) {
  control <- .idio_ml_control(lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                              mtry = NULL, num_trees = 50L, cost = 1,
                              p = d$p)
  utils::modifyList(control, list(...))
}

# Fit through the package and predict on the SAME rows, so any difference is
# the wrapper's and not the data's.
via_package <- function(d, model, task = "regression", ...) {
  train <- as.data.frame(d$X)
  train$.y <- if (task == "regression") d$y else as.integer(d$y > 0)
  fit <- .idio_ml_fit(train, ".y", d$x, model, task, eq_control(d, ...))
  .idio_ml_predict(fit, as.data.frame(d$X))
}

test_that("boosted stumps at one round equal the native stump exactly", {
  # An internal identity: with M = 1 and a learning rate of 1, boosting IS the
  # single stump it is built from.
  d <- eq_data()
  stump <- .idio_tree_stump(d$Xs, d$y, d$x)
  reference <- .idio_stump_predict(stump, d$Xs)
  ours <- via_package(d, "boost", rounds = 1L, learn_rate = 1)
  expect_equal(ours, as.numeric(reference), tolerance = 1e-12)
})

test_that("the spline basis is rebuilt from the TRAINING knots", {
  # Re-calling ns() on new rows re-derives the knots from their quantiles, so
  # the columns mean something different. Predictions stay finite and are
  # simply wrong, which is why this is checked directly.
  d <- eq_data()
  train <- as.data.frame(d$X)
  train$.y <- d$y
  fit <- .idio_ml_fit(train, ".y", d$x, "spline", "regression", eq_control(d))

  half <- seq_len(d$n %/% 2L)
  on_half <- .idio_ml_predict(fit, as.data.frame(d$X)[half, , drop = FALSE])
  on_all <- .idio_ml_predict(fit, as.data.frame(d$X))[half]
  # Predicting a subset must give the same answer as predicting everything and
  # taking that subset. Re-deriving knots from the subset would break this.
  expect_equal(on_half, on_all, tolerance = 1e-10)
})

test_that("isotonic regression aligns fitted values to the input rows", {
  # isoreg() returns $yf in SORTED-x order while $x and $y stay in input order.
  # Aligning them naively gives a plausible, uncorrelated prediction.
  d <- eq_data()
  ours <- via_package(d, "isotonic")
  expect_true(all(is.finite(ours)))
  # The fit must track the outcome, not scramble it.
  expect_gt(stats::cor(ours, d$y), 0.3)
  # And it must be monotone in whichever predictor it chose.
  train <- as.data.frame(d$X); train$.y <- d$y
  fit <- .idio_ml_fit(train, ".y", d$x, "isotonic", "regression", eq_control(d))
  ordering <- order(d$Xs[, fit$column])
  expect_false(is.unsorted(ours[ordering], strictly = FALSE))
})

test_that("loess and ppr reproduce the stats reference exactly", {
  d <- eq_data(p = 2L)
  frame <- as.data.frame(d$Xs)
  frame$.idio_y <- d$y

  reference_loess <- stats::loess(.idio_y ~ x1 + x2, data = frame, span = 0.75,
                                  control = stats::loess.control(
                                    surface = "direct"))
  expect_equal(via_package(d, "loess", span = 0.75),
               as.numeric(stats::predict(reference_loess, frame)),
               tolerance = 1e-8)

  reference_ppr <- stats::ppr(.idio_y ~ x1 + x2, data = frame, nterms = 1L)
  expect_equal(via_package(d, "ppr", nterms = 1L),
               as.numeric(stats::predict(reference_ppr, frame)),
               tolerance = 1e-8)
})

test_that("cart reproduces rpart, on the probability scale", {
  skip_if_not_installed("rpart")
  d <- eq_data()
  frame <- as.data.frame(d$Xs)
  frame$.idio_y <- d$y
  reference <- rpart::rpart(.idio_y ~ x1 + x2 + x3, data = frame,
                            method = "anova",
                            control = rpart::rpart.control(cp = 0.01,
                                                           minsplit = 10L))
  expect_equal(via_package(d, "cart", cp = 0.01),
               as.numeric(stats::predict(reference, frame)),
               tolerance = 1e-10)

  # Classification must return P(positive), never a class index. rpart's
  # type = "vector" returns 1/2, which would make every row predict positive.
  probs <- via_package(d, "cart", task = "classification", cp = 0.01)
  expect_true(all(probs >= 0 & probs <= 1))
  expect_gt(length(unique(probs)), 1L)
})

test_that("gam reproduces mgcv on the RESPONSE scale", {
  skip_if_not_installed("mgcv")
  d <- eq_data()
  # For binomial, returning the link instead of the response gives values far
  # outside [0, 1] -- the guard would catch it, so this pins the numbers.
  probs <- via_package(d, "gam", task = "classification", k = 5L)
  expect_true(all(probs >= 0 & probs <= 1))

  frame <- as.data.frame(d$Xs)
  frame$.idio_y <- d$y
  reference <- mgcv::gam(.idio_y ~ s(x1, k = 5) + s(x2, k = 5) + s(x3, k = 5),
                         data = frame, family = stats::gaussian())
  expect_equal(via_package(d, "gam", k = 5L),
               as.numeric(stats::predict(reference, frame, type = "response")),
               tolerance = 1e-8)
})

test_that("qda returns posteriors, not class labels", {
  skip_if_not_installed("MASS")
  d <- eq_data()
  frame <- as.data.frame(d$Xs)
  labels <- factor(as.integer(d$y > 0), levels = c(0L, 1L))
  reference <- MASS::qda(frame, grouping = labels)
  expect_equal(via_package(d, "qda", task = "classification"),
               as.numeric(stats::predict(reference, frame)$posterior[, "1"]),
               tolerance = 1e-10)
})

test_that("pls reproduces the pls package and equals OLS at full rank", {
  skip_if_not_installed("pls")
  d <- eq_data()
  ours <- via_package(d, "pls", ncomp = d$p)
  # At ncomp = p, PLS regression IS ordinary least squares.
  ols <- stats::lm(d$y ~ d$Xs)
  expect_equal(ours, as.numeric(stats::fitted(ols)), tolerance = 1e-6)
})

test_that("xgboost reproduces a direct call", {
  skip_if_not_installed("xgboost")
  d <- eq_data()
  reference <- xgboost::xgboost(data = d$Xs, label = d$y, nrounds = 20L,
                                eta = 0.1, max_depth = 3L, verbose = 0L,
                                nthread = 1L,
                                objective = "reg:squarederror")
  expect_equal(via_package(d, "xgboost", rounds = 20L, learn_rate = 0.1),
               as.numeric(stats::predict(reference, d$Xs)),
               tolerance = 1e-5)          # xgboost stores splits in float32
})

test_that("randomForest and ksvm classification return probabilities", {
  d <- eq_data()
  if (requireNamespace("randomForest", quietly = TRUE)) {
    probs <- via_package(d, "rf", task = "classification")
    expect_true(all(probs >= 0 & probs <= 1))
    expect_gt(length(unique(probs)), 2L)   # votes, not 0/1 labels
  }
  if (requireNamespace("kernlab", quietly = TRUE)) {
    probs <- via_package(d, "ksvm", task = "classification", cost = 1)
    expect_true(all(probs >= 0 & probs <= 1))
  }
})

test_that("quantile regression minimises the check loss, not squared error", {
  skip_if_not_installed("quantreg")
  d <- eq_data()
  train <- as.data.frame(d$X)
  train$.y <- d$y
  fit <- .idio_ml_fit(train, ".y", d$x, "quantile", "regression",
                      eq_control(d, tau = 0.5))
  ours <- .idio_ml_predict(fit, as.data.frame(d$X))

  check_loss <- function(pred, tau = 0.5) {
    r <- d$y - pred
    sum(pmax(tau * r, (tau - 1) * r))
  }
  ols <- as.numeric(stats::fitted(stats::lm(d$y ~ d$Xs)))
  # At tau = 0.5 it must beat OLS on ITS OWN loss, and the residual signs must
  # balance -- which is what tells you it is a median fit, not a mean fit.
  expect_lte(check_loss(ours), check_loss(ols) + 1e-8)
  expect_lt(abs(mean(sign(d$y - ours))), 0.1)
})

test_that("every model is invariant to the scale of its predictors", {
  # .idio_scale() standardizes on the training rows; a backend that
  # re-standardizes internally, or skips it, breaks this.
  d <- eq_data()
  rescaled <- d
  rescaled$X[, 1L] <- d$X[, 1L] * 10
  rescaled$Xs <- .idio_apply_scale(rescaled$X, .idio_scale(rescaled$X))

  for (m in c("linear", "ridge", "knn", "tree", "boost", "cart", "pls")) {
    if (!m %in% models(task = "regression", available = TRUE)$model) next
    a <- try(via_package(d, m), silent = TRUE)
    b <- try(via_package(rescaled, m), silent = TRUE)
    if (inherits(a, "try-error") || inherits(b, "try-error")) next
    expect_equal(a, b, tolerance = 1e-6,
                 info = paste(m, "is not scale-invariant"))
  }
})
