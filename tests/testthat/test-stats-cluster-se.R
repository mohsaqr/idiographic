# Pooled and subgroup models stack many occasions per person; their standard
# errors must be clustered on the person, not computed as if rows were
# independent.

cluster_panel <- function(seed = 11L, n_id = 30L, n_time = 40L) {
  set.seed(seed)
  id <- rep(seq_len(n_id), each = n_time)
  person_level <- stats::rnorm(n_id, sd = 1.5)[id]
  x <- person_level + stats::rnorm(n_id * n_time)
  y <- 0.4 * x + person_level + stats::rnorm(n_id * n_time)
  data.frame(id = id, t = rep(seq_len(n_time), n_id), x = x, y = y,
             event = stats::rbinom(n_id * n_time, 1, stats::plogis(0.5 * x)))
}

# Hand-rolled CR1 (G / (G - 1)) sandwich, independent of the package helper.
cr1_se <- function(X, score_resid, cluster, bread) {
  G <- length(unique(cluster))
  meat <- Reduce(`+`, lapply(split(seq_len(nrow(X)), cluster), \(i) {
    u <- crossprod(X[i, , drop = FALSE], score_resid[i])
    u %*% t(u)
  }))
  sqrt(diag(bread %*% meat %*% bread) * G / (G - 1))
}

train_rows <- function(d, prop = 0.8) {
  do.call(rbind, lapply(split(d, d$id), \(p) {
    p <- p[order(p$t), ]
    utils::head(p, floor(nrow(p) * prop))
  }))
}

test_that("pooled lm standard errors are clustered on the person", {
  d <- cluster_panel()
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "t", scope = "pooled")
  got <- coefs(fit)

  tr <- train_rows(d)
  m <- stats::lm(y ~ x, data = tr)
  X <- stats::model.matrix(m)
  expected <- cr1_se(X, stats::residuals(m), tr$id, solve(crossprod(X)))
  expect_equal(got$estimate, unname(stats::coef(m)),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(got$std_error, unname(expected),
               tolerance = sqrt(.Machine$double.eps))
  # Clustering matters here: the naive standard error is much smaller.
  naive <- summary(m)$coefficients[, 2]
  expect_true(all(got$std_error > naive))
  expect_equal(got$p_value,
               2 * stats::pt(-abs(got$statistic), df = 30 - 1))
})

test_that("pooled glm standard errors are clustered on the person", {
  d <- cluster_panel()
  fit <- fit_glm(d, y = "event", x = "x", id = "id", family = "binomial",
                 time = "t", scope = "pooled")
  got <- coefs(fit)
  tr <- train_rows(d)
  m <- stats::glm(event ~ x, data = tr, family = stats::binomial())
  X <- stats::model.matrix(m)
  w <- stats::weights(m, "working")
  expected <- cr1_se(X, w * stats::residuals(m, "working"), tr$id,
                     solve(crossprod(X, X * w)))
  expect_equal(got$std_error, unname(expected),
               tolerance = sqrt(.Machine$double.eps))
  expect_equal(got$p_value, 2 * stats::pnorm(-abs(got$statistic)))
})

test_that("person-specific models keep their own standard errors", {
  d <- cluster_panel()
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "t",
                scope = "individual")
  one <- coefs(fit, subject = "1")
  own <- subset(train_rows(d), id == 1)
  m <- stats::lm(y ~ x, data = own)
  expect_equal(one$std_error, unname(summary(m)$coefficients[, 2]),
               tolerance = sqrt(.Machine$double.eps))
})

test_that("coefs() filters by term and rejects unknown terms", {
  d <- cluster_panel()
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "t", scope = "both")
  only_x <- coefs(fit, scope = "individual", term = "x")
  expect_true(all(only_x$term == "x"))
  expect_equal(nrow(only_x), 30L)
  expect_error(coefs(fit, term = "nope"), "No such term")
})
