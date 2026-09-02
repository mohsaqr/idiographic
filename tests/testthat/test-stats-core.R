make_panel <- function(classification = FALSE, n_id = 4L, n_time = 40L) {
  set.seed(1)
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time),
    x3 = stats::rnorm(n_id * n_time)
  )
  eta <- 0.8 * d$x1 - 0.4 * d$x2 +
    rep(seq(-1, 1, length.out = n_id), each = n_time)
  if (classification) {
    d$y <- factor(ifelse(stats::runif(nrow(d)) < stats::plogis(eta),
                         "yes", "no"), levels = c("no", "yes"))
  } else {
    d$y <- eta + stats::rnorm(nrow(d), sd = 0.3)
  }
  d
}

test_that("fit_lm returns uniform tidy outputs", {
  d <- make_panel()
  fit <- fit_lm(d, "y", "x1:x3", "id", time = "time", min_train = 20)

  expect_s3_class(fit, "idiostats_fit")
  expect_named(metrics(fit),
               c("scope", "model", "estimator", "subject", "subgroup", "n",
                 "rmse", "mae", "bias", "r_squared"))
  expect_named(predictions(fit),
               c("scope", "model", "estimator", "subject", "subgroup", "row",
                 "observed", "predicted", "residual"))
  expect_named(coefs(fit),
               c("scope", "model", "estimator", "subject", "subgroup",
                 "term", "estimate", "std_error", "statistic", "p_value"))
  expect_true(any(metrics(fit)$scope == "pooled"))
  expect_true(any(metrics(fit)$scope == "individual"))
  expect_true(all(metrics(fit, scope = "pooled")$scope == "pooled"))
  expect_true(all(metrics(fit, overall = TRUE)$subject == ".overall"))
  expect_equal(nrow(metrics(fit, scope = "individual", sort_by = "rmse",
                            n = 2)), 2L)
  expect_true(all(coefs(fit, model = "lm", n = 2)$model == "lm"))
  expect_equal(nrow(predictions(fit, n = 3)), 3L)
  expect_output(print(fit), "Idiostats Fit")
})

test_that("pooled predictions keep the real person ID but pooled coefs collapse", {
  d <- make_panel()
  fit <- fit_lm(d, "y", "x1:x3", "id", time = "time", min_train = 20)

  # scope says which model made the row; subject says whose rows they are.
  pooled_pred <- predictions(fit, scope = "pooled")
  expect_setequal(unique(pooled_pred$subject), as.character(unique(d$id)))

  # One pooled model -> one coefficient set, filed under .all.
  expect_true(all(coefs(fit, scope = "pooled")$subject == ".all"))
  expect_setequal(unique(coefs(fit, scope = "individual")$subject),
                  as.character(unique(d$id)))
})

test_that("fit_glm supports binomial outcomes", {
  d <- make_panel(classification = TRUE)
  fit <- fit_glm(d, "y", c("x1", "x2"), "id", family = "binomial",
                 time = "time", min_train = 20)

  expect_equal(fit$spec$task, "classification")
  expect_named(metrics(fit),
               c("scope", "model", "estimator", "subject", "subgroup", "n",
                 "accuracy", "brier", "log_loss"))
  expect_named(predictions(fit),
               c("scope", "model", "estimator", "subject", "subgroup", "row",
                 "observed", "predicted", "probability"))
})

test_that("fit_ml supports native models and flexible selectors", {
  d <- make_panel()
  a <- fit_ml(d, "y", 3:5, "id", model = c("mean", "ridge", "knn"),
              time = "time", scope = "pooled", min_train = 20, lambda = 0.2,
              k = 3, tune = TRUE)
  b <- fit_ml(d, "y", ~ x1 + x2 + x3, "id", model = "ridge",
              time = "time", scope = "pooled", min_train = 20)
  cc <- fit_ml(d, "y", d[c("x1", "x2", "x3")], "id", model = "ridge",
               time = "time", scope = "pooled", min_train = 20)

  expect_setequal(a$spec$model, c("mean", "ridge", "knn"))
  expect_equal(a$spec$x, c("x1", "x2", "x3"))
  expect_equal(b$spec$x, a$spec$x)
  expect_equal(cc$spec$x, a$spec$x)
  expect_true(all(metrics(a)$rmse >= 0))
  expect_equal(best_model(a)$subject, ".overall")
  expect_equal(nrow(best_model(a)), 1L)
  expect_true(all(metrics(individuals(a))$scope == "individual"))
  expect_true(all(metrics(pooled(a))$scope == "pooled"))
  expect_true(all(metrics(overall(a))$subject == ".overall"))
  expect_named(importance(a), c("scope", "model", "estimator", "subject",
                                "subgroup", "variable", "importance"))
  expect_named(tuning(a), c("scope", "model", "estimator", "subject",
                            "subgroup", "parameter", "value", "n", "rmse",
                            "mae", "accuracy", "brier", "rank"))
  expect_true(any(tuning(a, model = "ridge")$rank == 1L))
  expect_true(nrow(diagnostics(a, model = "ridge", n = 5)) <= 5)
  expect_silent(plot_importance(a, model = "ridge", n = 3))
  expect_silent(plot_diagnostics(a, model = "ridge", type = "residuals"))
  expect_silent(plot_tuning(a, model = "ridge"))
  expect_silent(plot_metrics(a))
})

test_that("person() views focus on one person", {
  d <- make_panel()
  a <- fit_ml(d, "y", "x1:x3", "id", model = "ridge", time = "time",
              min_train = 20)
  expect_true(all(metrics(person(a, "1"))$subject == "1"))
  expect_true(all(metrics(person(a, "1"))$scope == "individual"))
  expect_setequal(unique(metrics(people(a, c("1", "2")))$subject),
                  c("1", "2"))
})

test_that("compare returns overall tidy rows", {
  d <- make_panel()
  lm_fit <- fit_lm(d, "y", "x1:x2", "id", scope = "pooled", min_train = 20)
  ml_fit <- fit_ml(d, "y", "x1:x2", "id", scope = "pooled", model = "ridge",
                   min_train = 20)

  cmp <- compare(lm_fit, ml_fit)
  expect_named(cmp, c("fit", "method", "scope", "model", "estimator",
                      "subject", "subgroup", "n", "rmse", "mae", "bias",
                      "r_squared"))
  expect_equal(nrow(cmp), 2L)
})

test_that("failures are collected, not thrown", {
  d <- make_panel()
  d <- d[!(d$id == 1 & d$time > 12), ]   # person 1 is too short to model
  fit <- fit_lm(d, "y", "x1:x3", "id", time = "time", min_train = 20)

  expect_s3_class(fit, "idiostats_fit")
  expect_true("1" %in% fit$failures$subject)
  expect_false("1" %in% metrics(fit, scope = "individual")$subject)
})

test_that("the srl dataset ships with the package", {
  expect_s3_class(srl, "data.frame")
  expect_equal(dim(srl), c(5616L, 11L))
  expect_true(all(c("name", "day", "effort", "efficacy") %in% names(srl)))
})
