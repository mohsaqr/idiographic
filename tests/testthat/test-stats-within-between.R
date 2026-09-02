# A within-between model must recover TWO different truths from one fit, so
# every test plants a within effect and a between effect that differ.

wb_panel <- function(seed = 1L, n_id = 30L, n_time = 30L,
                     within_eff = 1, between_eff = -2, sd_person = 3,
                     sd_within = 1, noise = 0.5) {
  set.seed(seed)
  n <- n_id * n_time
  person <- rep(seq_len(n_id), each = n_time)
  level <- stats::rnorm(n_id, sd = sd_person)[person]
  dev <- stats::rnorm(n, sd = sd_within)
  d <- data.frame(
    id = person, day = rep(seq_len(n_time), n_id),
    x = level + dev,
    stringsAsFactors = FALSE
  )
  # y responds to the two components with DIFFERENT coefficients.
  d$y <- within_eff * dev + between_eff * level + stats::rnorm(n, sd = noise)
  d
}

test_that("variance_components recovers a known ICC", {
  set.seed(11)
  # 150 people: the between-person variance is estimated from that many person
  # means, so its sampling error is ~sqrt(2/(k-1)) in relative terms. With 40
  # people that is ~23% and a tight tolerance would be testing luck.
  n_id <- 150L
  n_time <- 30L
  person <- rep(seq_len(n_id), each = n_time)
  # Between SD 3, within SD 1 => ICC = 9 / 10 = 0.9
  d <- data.frame(id = person,
                  v = stats::rnorm(n_id, sd = 3)[person] +
                    stats::rnorm(n_id * n_time, sd = 1))
  vc <- variance_components(d, vars = "v", id = "id")

  expect_s3_class(vc, "idiostats_variance")
  expect_equal(nrow(vc), 1L)
  expect_lt(abs(vc$icc - 0.9), 0.03)
  expect_lt(abs(vc$var_within - 1), 0.05)
  expect_lt(abs(vc$var_between - 9), 1.5)
  expect_equal(vc$people, n_id)
  expect_gt(vc$reliability, 0.95)      # 30 occasions per person

  # A variable that is pure noise within a person has an ICC near zero.
  d$w <- stats::rnorm(nrow(d))
  expect_lt(variance_components(d, vars = "w", id = "id")$icc, 0.1)
})

test_that("variance_components handles unbalanced panels and edge cases", {
  set.seed(12)
  d <- data.frame(id = rep(letters[1:6], times = c(2, 5, 9, 3, 20, 7)))
  d$v <- stats::rnorm(nrow(d), mean = match(d$id, letters) * 2)
  vc <- variance_components(d, vars = "v", id = "id")
  expect_true(is.finite(vc$icc))
  expect_gt(vc$icc, 0.5)               # the planted level differences dominate

  # A constant column has no variance anywhere.
  d$flat <- 1
  flat <- variance_components(d, vars = "flat", id = "id")
  expect_true(is.na(flat$icc) || flat$icc == 0)

  # One person cannot support a between-person estimate.
  one <- data.frame(id = rep("a", 10), v = stats::rnorm(10))
  expect_true(is.na(variance_components(one, vars = "v", id = "id")$icc))

  d$label <- "a"
  expect_error(variance_components(d, vars = "label", id = "id"),
               "must be numeric")
})

test_that("preprocess_panel(decompose = TRUE) keeps both halves", {
  d <- wb_panel()
  out <- preprocess_panel(d, id = "id", vars = "x", decompose = TRUE)

  expect_true(all(c("x", "x_within", "x_between") %in% names(out)))
  # The two halves reconstruct the original exactly.
  expect_equal(out$x_within + out$x_between, out$x, tolerance = 1e-10)
  # The between part is constant inside a person; the within part averages 0.
  n_people <- length(unique(out$id))
  expect_equal(as.vector(tapply(out$x_between, out$id, stats::sd)),
               rep(0, n_people), tolerance = 1e-10)
  expect_equal(as.vector(tapply(out$x_within, out$id, mean)),
               rep(0, n_people), tolerance = 1e-10)

  # Centering discards the between half, so the two options are exclusive.
  expect_error(preprocess_panel(d, id = "id", vars = "x", center = "person",
                          decompose = TRUE),
               "Choose one")
})

test_that("fit_within_between separates a within effect from a between effect", {
  # Truth: within = +1, between = -2. A pooled model that ignores the split
  # cannot report both, and lands somewhere between them.
  d <- wb_panel(within_eff = 1, between_eff = -2)
  fit <- fit_within_between(d, y = "y", x = "x", id = "id", time = "day")

  ctx <- contextual(fit)
  expect_equal(nrow(ctx), 1L)
  expect_lt(abs(ctx$within - 1), 0.15)
  expect_lt(abs(ctx$between - (-2)), 0.3)

  # The contextual effect is between - within = -3, and it is detected.
  expect_lt(abs(ctx$contextual - (-3)), 0.4)
  expect_lt(ctx$p_value, 0.01)
  expect_lt(ctx$conf_high, 0)

  # A single pooled slope is dominated by the between-person variation (which
  # is the larger of the two here) and gets the within-person process not just
  # wrong in size but wrong in SIGN -- the whole reason to split them.
  pooled_slope <- unname(coef(lm(y ~ x, data = d))[2L])
  expect_lt(pooled_slope, 0)
  expect_gt(abs(pooled_slope - 1), 2)      # nowhere near the within effect
})

test_that("no contextual effect is claimed when the two processes agree", {
  # within == between, so the gap is zero and must not be called significant.
  d <- wb_panel(seed = 3L, within_eff = 1.5, between_eff = 1.5)
  fit <- fit_within_between(d, y = "y", x = "x", id = "id", time = "day")

  ctx <- contextual(fit)
  expect_lt(ctx$conf_low, 0)
  expect_gt(ctx$conf_high, 0)          # the interval covers zero
  expect_gt(ctx$p_value, 0.05)
  expect_lt(abs(ctx$within - ctx$between), 0.5)
})

test_that("fit_within_between keeps the shared fit contract", {
  d <- wb_panel()
  fit <- fit_within_between(d, y = "y", x = "x", id = "id", time = "day")

  expect_s3_class(fit, "idiostats_wb")
  expect_s3_class(fit, "idiostats_fit")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
  expect_true(all(c("scope", "model", "estimator", "subject", "subgroup",
                    "term", "component") %in% names(coefs(fit))))
  expect_setequal(unique(coefs(fit)$component), c(".none", "within", "between"))
  # The printed form separates the two coefficient sets into blocks; a single
  # flat dump is the wrong shape for a model with two kinds of coefficient.
  expect_output(print(fit), "WITHIN EFFECTS")
  expect_output(print(fit), "BETWEEN EFFECTS")
  expect_output(print(fit), "CONTEXTUAL EFFECTS")
  expect_silent(plot_components(fit))

  # Metrics are held out, as everywhere else in the package.
  expect_lt(nrow(predictions(fit)), nrow(d))
})

test_that("a between term cannot be estimated at individual scope", {
  d <- wb_panel()
  expect_error(fit_within_between(d, "y", "x", "id", scope = "individual"),
               "constant inside a person")
  expect_error(fit_within_between(d, "y", "x", "id", scope = "both"),
               "constant inside a person")
})

test_that("a person-constant predictor is allowed and reported as pure between", {
  # Theoph's Wt is the real-world case: a person-level covariate that a
  # person-specific model must refuse but a within-between model welcomes.
  d <- wb_panel()
  set.seed(9)
  d$trait <- stats::rnorm(length(unique(d$id)))[d$id]   # constant per person
  d$y <- d$y + 2 * d$trait

  fit <- fit_within_between(d, y = "y", x = c("x", "trait"), id = "id",
                            time = "day")
  ctx <- contextual(fit, variable = "trait")
  expect_equal(nrow(ctx), 1L)
  # It has no within-person variation, so only the between half is estimable.
  expect_true(is.na(ctx$within))
  expect_true(is.na(ctx$contextual))
  expect_lt(abs(ctx$between - 2), 0.5)

  # The plain fitters still refuse it at individual scope.
  expect_error(fit_lm(d, "y", c("x", "trait"), "id", scope = "individual"),
               "constant")
})

test_that("a single cluster does not collapse the standard errors", {
  # Regression test. With one cluster the clustered meat is (X'e)(X'e)', and
  # X'e is exactly zero by the normal equations -- so every standard error came
  # out at ~1e-16 with a p-value of ~0. That is precisely the individual-scope
  # case, where a unit is one person and therefore one cluster. It must fall
  # back to the row-level (HC1) sandwich instead.
  set.seed(1)
  n <- 50L
  X <- cbind(1, stats::rnorm(n))
  y <- as.numeric(X %*% c(1, 2) + stats::rnorm(n))

  est <- .idio_wb_ols(y, X, list(rep("only", n)), 0.95)
  se <- sqrt(diag(est$V))
  expect_true(all(se > 0.05))                     # not 1e-16
  expect_equal(est$df, n - ncol(X))               # rows, not clusters

  # HC1 on homoskedastic data lands close to the ordinary OLS standard errors.
  ols <- summary(lm(y ~ X[, 2]))$coefficients[, 2]
  expect_lt(max(abs(se - ols)), 0.02)

  # Same story through .idio_cluster_lm(), which fit_effects() uses.
  cl <- .idio_cluster_lm(y, X, rep("only", n), 0.95)
  expect_true(all(cl[, "se"] > 0.05))
  expect_lt(max(abs(cl[, "se"] - ols)), 0.02)

  # And it reaches the public surface: per-person effects need real SEs.
  d <- wb_panel()
  pp <- fit_within_between(d, "y", "x", "id", time = "day", model = "within",
                           scope = "individual")
  cf <- coefs(pp)
  cf <- cf[cf$component == "within", , drop = FALSE]
  # The planted within effect is strong, so genuinely small p-values are
  # correct here. What signalled the collapsed sandwich was the magnitude:
  # standard errors of ~1e-17 and t statistics of ~1e16.
  expect_true(all(cf$std_error > 0.01))
  expect_true(all(abs(cf$statistic) < 1e3))
})

test_that("the four parameterizations agree where they must", {
  d <- wb_panel()
  wb <- contextual(fit_within_between(d, "y", "x", "id", time = "day",
                                      model = "within_between"))
  ctx <- contextual(fit_within_between(d, "y", "x", "id", time = "day",
                                       model = "contextual"))

  # `contextual` is a re-parameterization, not a different model: the person
  # mean's coefficient IS between - within, so every number must match.
  expect_equal(ctx$within, wb$within, tolerance = 1e-8)
  expect_equal(ctx$between, wb$between, tolerance = 1e-8)
  expect_equal(ctx$contextual, wb$contextual, tolerance = 1e-8)
  expect_equal(ctx$std_error, wb$std_error, tolerance = 1e-8)

  # Single-component models report that component and nothing to compare it to.
  win <- contextual(fit_within_between(d, "y", "x", "id", time = "day",
                                       model = "within"))
  expect_equal(win$within, wb$within, tolerance = 1e-8)
  expect_true(is.na(win$between))
  expect_true(is.na(win$contextual))

  btw <- contextual(fit_within_between(d, "y", "x", "id", time = "day",
                                       model = "between"))
  expect_true(is.na(btw$within))
  expect_true(is.na(btw$contextual))
  expect_lt(abs(btw$between - (-2)), 0.3)
})

test_that("individual scope is available only for the within model", {
  d <- wb_panel()
  per_person <- fit_within_between(d, "y", "x", "id", time = "day",
                                   model = "within", scope = "individual")
  expect_equal(nrow(contextual(per_person)), length(unique(d$id)))
  expect_true(all(is.finite(contextual(per_person)$within)))

  for (m in c("within_between", "between", "contextual")) {
    expect_error(
      fit_within_between(d, "y", "x", "id", model = m, scope = "individual"),
      "cannot be estimated at individual scope")
  }
})

test_that("two-way clustering widens the interval and cuts the df", {
  d <- wb_panel()
  d$course <- rep(paste0("c", 1:5), length.out = nrow(d))

  one <- contextual(fit_within_between(d, "y", "x", "id", time = "day"))
  two <- contextual(fit_within_between(d, "y", "x", "id", time = "day",
                                       cluster = c("id", "course")))

  # Point estimates are unchanged; only the variance differs.
  expect_equal(two$contextual, one$contextual, tolerance = 1e-8)
  expect_gt(two$std_error, one$std_error)
  # Degrees of freedom come from the SMALLER cluster count (5 courses), so the
  # interval is wider still.
  expect_gt(two$conf_high - two$conf_low, one$conf_high - one$conf_low)

  expect_error(fit_within_between(d, "y", "x", "id",
                                  cluster = c("id", "course", "day")),
               "at most two")
  expect_error(fit_within_between(d, "y", "x", "id", cluster = "nope"),
               "not found in `data`")
})

test_that("mixed estimators fit crossed random effects", {
  skip_if_not_installed("lme4")
  set.seed(21)
  d <- wb_panel(seed = 21L, n_id = 40L, n_time = 25L)
  d$course <- rep(paste0("c", 1:5), length.out = nrow(d))
  d$y <- d$y + rnorm(5, sd = 2)[as.integer(factor(d$course))]

  fit <- fit_within_between(d, "y", "x", "id", time = "day",
                            estimator = "reml", random = "course")
  ctx <- contextual(fit)
  expect_lt(abs(ctx$within - 1), 0.2)
  expect_lt(abs(ctx$between - (-2)), 0.3)

  # The model's own variance components, one row per grouping level.
  vc <- variance_components(fit)
  expect_s3_class(vc, "idiostats_variance")
  expect_setequal(vc$level, c("id", "course", "Residual"))
  expect_true(all(vc$variance >= 0))
  expect_equal(sum(vc$icc), 1, tolerance = 1e-8)
  # The planted course effect is the largest component.
  expect_equal(vc$level[which.max(vc$variance)], "course")

  expect_equal(fit_within_between(d, "y", "x", "id", estimator = "ml",
                                  random = "course")$spec$estimator, "ml")

  # An OLS fit has no random effects to report.
  expect_error(variance_components(fit_within_between(d, "y", "x", "id")),
               "need `estimator|no random effects|reml")
})

test_that("random and cluster belong to different estimators", {
  d <- wb_panel()
  d$course <- rep(paste0("c", 1:5), length.out = nrow(d))
  expect_error(fit_within_between(d, "y", "x", "id", random = "course"),
               "needs a mixed estimator")
  expect_error(fit_within_between(d, "y", "x", "id", estimator = "reml",
                                  cluster = "course"),
               "applies to `estimator = \"ols\"`")
})

test_that("variance_components has a REML method that agrees with the ANOVA", {
  skip_if_not_installed("lme4")
  set.seed(31)
  n_id <- 60L
  person <- rep(seq_len(n_id), each = 25L)
  d <- data.frame(id = person,
                  v = stats::rnorm(n_id, sd = 3)[person] +
                    stats::rnorm(n_id * 25L, sd = 1))

  a <- variance_components(d, vars = "v", id = "id", method = "anova")
  r <- variance_components(d, vars = "v", id = "id", method = "reml")
  expect_lt(abs(a$icc - r$icc), 0.02)         # balanced data: they agree
  expect_lt(abs(r$icc - 0.9), 0.05)
})

test_that("contextual() and variance accessors filter without bracket code", {
  d <- wb_panel()
  d$z <- stats::rnorm(nrow(d))
  fit <- fit_within_between(d, y = "y", x = c("x", "z"), id = "id",
                            time = "day")

  expect_equal(nrow(contextual(fit, variable = "x")), 1L)
  expect_equal(nrow(contextual(fit, n = 1L)), 1L)
  expect_equal(contextual(fit, sort_by = "contextual")$variable[1L], "x")

  vc <- variance_components(d, vars = c("x", "z"), id = "id")
  expect_equal(nrow(vc), 2L)
  expect_gt(vc$icc[vc$variable == "x"], vc$icc[vc$variable == "z"])
  expect_output(print(vc), "VARIANCE COMPONENTS")
  expect_silent(plot_variance(vc))
})

test_that("aliased predictors are reported as NA, not split arbitrarily", {
  # A generalized inverse still returns numbers for a collinear design, but the
  # split between aliased columns is arbitrary: rescaling a duplicate changes
  # the reported coefficients without changing the fit at all.
  d <- wb_panel()
  d$dup <- 2 * d$x

  fit <- fit_within_between(d, "y", x = c("x", "dup"), id = "id", time = "day")
  cf <- coefs(fit)
  keep <- cf[cf$variable == "x", ]
  drop <- cf[cf$variable == "dup", ]

  expect_true(all(is.finite(keep$estimate)))
  expect_true(all(is.na(drop$estimate)))
  expect_true(all(is.na(drop$std_error)))
  # The identified predictor still recovers both truths.
  expect_lt(abs(keep$estimate[keep$component == "within"] - 1), 0.15)
  expect_lt(abs(keep$estimate[keep$component == "between"] + 2), 0.3)

  # Rescaling the duplicate must not change anything that is reported.
  d$dup <- 7 * d$x
  again <- coefs(fit_within_between(d, "y", x = c("x", "dup"), id = "id",
                                    time = "day"))
  expect_equal(again$estimate, cf$estimate)
})

test_that("rows with a missing cluster id leave the estimation sample", {
  # split() drops NA groups, so such a row would sit in X'X and the residuals
  # while contributing nothing to the sandwich meat -- the coefficient and its
  # variance would then come from different samples.
  d <- wb_panel()
  d$grp <- rep(c("g1", "g2", NA), length.out = nrow(d))

  fit <- fit_within_between(d, "y", "x", id = "id", time = "day",
                            cluster = c("id", "grp"))
  ctx <- contextual(fit)
  expect_true(is.finite(ctx$std_error))
  expect_gt(ctx$std_error, 0)

  # The estimate still recovers the planted contextual effect of -3, so the
  # rows were dropped from the whole estimation rather than only from the
  # variance. (It is NOT identical to filtering the data beforehand: that also
  # moves the person means and the train/test boundary.)
  expect_lt(abs(ctx$contextual - (-3)), 0.4)

  # A cluster column that is entirely missing leaves nothing to fit on.
  d$empty <- NA_character_
  expect_error(fit_within_between(d, "y", "x", id = "id", time = "day",
                                  cluster = c("id", "empty")),
               "Too few complete training rows")
})
