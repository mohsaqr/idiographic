outlier_panel <- function(seed = 2L) {
  set.seed(seed)
  d <- data.frame(
    id = rep(1:4, each = 50), time = rep(1:50, 4),
    x1 = stats::rnorm(200), x2 = stats::rnorm(200)
  )
  d$y <- 2 * d$x1 - d$x2 + stats::rnorm(200, sd = 0.3)
  # Contaminate 8% of the *training* rows with wild values.
  bad <- sample(which(d$time <= 40), 16)
  d$y[bad] <- d$y[bad] + stats::rnorm(16, mean = 25, sd = 5)
  d$w <- ifelse(seq_len(nrow(d)) %in% bad, 0.01, 1)
  d
}

count_panel <- function(seed = 3L) {
  set.seed(seed)
  d <- data.frame(id = rep(1:4, each = 50), time = rep(1:50, 4),
                  x1 = stats::rnorm(200))
  d$cnt <- stats::rnbinom(200, mu = exp(1 + 0.7 * d$x1), size = 1)  # overdispersed
  d
}

slope_of <- function(fit) coefs(fit, scope = "pooled")$estimate[2]

test_that("robust regression resists outliers that drag OLS off", {
  skip_if_not_installed("MASS")
  d <- outlier_panel()
  ols <- fit_lm(d, "y", "x1:x2", "id", time = "time", scope = "pooled",
                min_train = 20)
  rob <- fit_lm(d, "y", "x1:x2", "id", time = "time", scope = "pooled",
                min_train = 20, estimator = "robust")

  # Truth is 2. The robust fit must be closer, and predict better.
  expect_lt(abs(slope_of(rob) - 2), abs(slope_of(ols) - 2))
  expect_lt(metrics(rob, overall = TRUE)$rmse,
            metrics(ols, overall = TRUE)$rmse)
  expect_equal(unique(metrics(rob)$estimator), "robust")
  expect_equal(rob$spec$estimator, "robust")
})

test_that("case weights are honoured and never used as a predictor", {
  d <- outlier_panel()
  wt <- fit_lm(d, "y", c("x1", "x2"), "id", time = "time", scope = "pooled",
               min_train = 20, weights = "w")

  expect_lt(abs(slope_of(wt) - 2), 0.2)   # downweighting the junk recovers it
  expect_false("w" %in% wt$spec$x)
})

test_that("a bad weights column is rejected", {
  d <- outlier_panel()
  expect_error(fit_lm(d, "y", c("x1", "x2"), "id", weights = "nope"),
               "one column name")
  d$neg <- -1
  expect_error(fit_lm(d, "y", c("x1", "x2"), "id", weights = "neg"),
               "non-negative")
})

test_that("negative binomial reports honest uncertainty for overdispersed counts", {
  skip_if_not_installed("MASS")
  d <- count_panel()
  pois <- fit_glm(d, "cnt", "x1", "id", family = "poisson", time = "time",
                  scope = "pooled", min_train = 20)
  nb <- fit_glm(d, "cnt", "x1", "id", family = "negbin", time = "time",
                scope = "pooled", min_train = 20)

  # Both land near the true 0.7, but Poisson's standard error is far too small
  # under overdispersion -- that is the whole reason negbin exists.
  expect_lt(abs(slope_of(nb) - 0.7), 0.25)
  expect_gt(coefs(nb, scope = "pooled")$std_error[2],
            2 * coefs(pois, scope = "pooled")$std_error[2])

  expect_equal(unique(metrics(nb)$model), "negbin")
  expect_named(metrics(nb),
               c("scope", "model", "estimator", "subject", "subgroup", "n",
                 "rmse", "mae", "bias", "r_squared"))
})

test_that("an unknown family names the ones that exist", {
  d <- count_panel()
  expect_error(fit_glm(d, "cnt", "x1", "id", family = "gamma"),
               "gaussian, binomial, poisson, or negbin")
})
