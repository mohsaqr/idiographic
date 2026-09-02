effect_panel <- function(seed = 1L, true_eff = 1, hetero = FALSE,
                         n_id = 8L, n_time = 50L) {
  set.seed(seed)
  n <- n_id * n_time
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    day = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n),
    x2 = stats::rnorm(n)
  )
  d$drug <- stats::rbinom(n, 1L, 0.5)
  eff <- if (hetero) 2 * (d$x1 > 0) else true_eff
  d$mood <- eff * d$drug + 0.5 * d$x1 + stats::rnorm(n, sd = 0.5)
  d
}

test_that("fit_effects recovers a known average treatment effect", {
  d <- effect_panel(true_eff = 1)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")

  ate <- effects(fit, effect = "ATE")
  expect_equal(nrow(ate), 1L)
  expect_lt(abs(ate$estimate - 1), 0.3)
  expect_lt(ate$conf_low, 1)
  expect_gt(ate$conf_high, 1)     # the interval covers the truth
  expect_lt(ate$p_value, 0.05)
})

test_that("fit_effects finds nothing when there is nothing to find", {
  d <- effect_panel(true_eff = 0)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")

  ate <- effects(fit, effect = "ATE")
  expect_lt(ate$conf_low, 0)
  expect_gt(ate$conf_high, 0)     # the interval covers zero
})

test_that("GATES separates who the treatment helps", {
  # Truth: the drug gives +2 to people with x1 > 0 and nothing to anyone else.
  d <- effect_panel(hetero = TRUE)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled", model = "tree")

  eff <- effects(fit)
  expect_true(all(c("ATE", "GATES:g1", "GATES:g4", "GATES:top-bottom",
                    "BLP:heterogeneity") %in% eff$effect))

  g1 <- eff[eff$effect == "GATES:g1", ]
  g4 <- eff[eff$effect == "GATES:g4", ]
  expect_lt(g1$estimate, g4$estimate)          # sorted groups are ordered
  expect_gt(g1$conf_low, -1); expect_lt(g1$conf_high, 1)   # bottom ~ no effect
  expect_gt(g4$estimate, 1)                    # top group is genuinely helped

  # Heterogeneity is detected.
  expect_lt(eff[eff$effect == "GATES:top-bottom", ]$p_value, 0.01)
  expect_lt(eff[eff$effect == "BLP:heterogeneity", ]$p_value, 0.01)
})

test_that("no heterogeneity is claimed when the effect is constant", {
  d <- effect_panel(true_eff = 1)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")

  tb <- effects(fit, effect = "GATES:top-bottom")
  expect_gt(tb$conf_low, -1)
  expect_lt(tb$conf_low, 0)   # interval covers zero: no real heterogeneity
  expect_gt(tb$conf_high, 0)
})

test_that("the positive class does not depend on row order", {
  # Regression test: the positive class used to be taken in order of
  # appearance, which silently inverted the sign of every effect when the
  # first row happened to be treated.
  a <- .idio_binary_outcome(c(0, 1, 1, 0))
  b <- .idio_binary_outcome(c(1, 0, 0, 1))
  expect_equal(a$positive, b$positive)
  expect_equal(a$positive, "1")

  yes_no <- .idio_binary_outcome(c("yes", "no", "no"))
  no_yes <- .idio_binary_outcome(c("no", "yes", "yes"))
  expect_equal(yes_no$positive, no_yes$positive)

  # A factor keeps the user's declared order: the last level is the success.
  f <- .idio_binary_outcome(factor(c("hi", "lo"), levels = c("lo", "hi")))
  expect_equal(f$positive, "hi")

  # End to end: shuffling the rows must not flip the estimated effect.
  d <- effect_panel(true_eff = 1)
  shuffled <- d[order(-d$drug, d$id, d$day), ]
  e1 <- effects(fit_effects(d, "mood", "drug", c("x1", "x2"), "id",
                            time = "day", scope = "pooled"), effect = "ATE")
  e2 <- effects(fit_effects(shuffled, "mood", "drug", c("x1", "x2"), "id",
                            time = "day", scope = "pooled"), effect = "ATE")
  expect_equal(e1$estimate, e2$estimate, tolerance = 1e-8)
})

test_that("effects are estimated per person and per subgroup", {
  d <- effect_panel(hetero = TRUE)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "both")

  per_person <- effects(fit, effect = "ATE", scope = "individual")
  expect_equal(nrow(per_person), length(unique(d$id)))
  expect_true(all(is.finite(per_person$estimate)))

  # n_people is the number of independent units behind the standard error:
  # rows within a person are not independent, so the SE is clustered on them.
  expect_named(effects(fit),
               c("scope", "model", "estimator", "subject", "subgroup",
                 "effect", "contrast", "n", "n_people", "estimate",
                 "std_error", "conf_low", "conf_high", "statistic", "p_value"))
})

test_that("per-person effects report usable standard errors", {
  # Regression test for a bug that shipped in 0.4.0: an individual unit is one
  # person and therefore one cluster, and a one-cluster clustered sandwich is
  # identically zero -- so every per-person effect reported std_error ~1e-16
  # and p ~1e-214. The Monte Carlo missed it because it only tested pooled.
  d <- effect_panel(true_eff = 1)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "both")

  per_person <- effects(fit, effect = "ATE", scope = "individual")
  expect_true(all(per_person$std_error > 1e-6))
  expect_true(all(per_person$p_value > 1e-12))
  # With ~15 held-out rows each, per-person intervals must be much wider than
  # the pooled one rather than absurdly narrower.
  pooled_se <- effects(fit, effect = "ATE", scope = "pooled")$std_error
  expect_true(all(per_person$std_error > pooled_se))
})

test_that("fit_effects keeps the shared fit contract", {
  d <- effect_panel(true_eff = 1)
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")

  expect_s3_class(fit, "idiostats_effects")
  expect_s3_class(fit, "idiostats_fit")
  # The usual accessors still work: metrics describe the outcome model.
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$rmse)))
  expect_true(all(c("treatment", "cate", "score") %in% names(predictions(fit))))
  expect_output(print(fit), "Idiographic Treatment Effects")
  expect_silent(plot_effects(fit))

  # The treatment must never be used as its own predictor.
  expect_false("drug" %in% fit$spec$x)
})

test_that("a continuous treatment recovers a dose effect under confounding", {
  # The dose depends on x1 and so does the outcome, so the naive slope is
  # biased upward. The partially linear DML score must recover 0.3.
  set.seed(4)
  d <- effect_panel(seed = 4, n_id = 10L, n_time = 40L)
  d$dose <- 2 * d$x1 + rnorm(nrow(d))
  d$sleep <- 0.3 * d$dose + 1.5 * d$x1 + rnorm(nrow(d), sd = 0.5)

  naive <- unname(coef(lm(sleep ~ dose, data = d))[2L])
  expect_gt(naive, 0.5)                     # the confounded slope is inflated

  fit <- fit_effects(d, y = "sleep", treatment = "dose", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")
  ape <- effects(fit, effect = "APE")
  expect_equal(nrow(ape), 1L)
  expect_lt(abs(ape$estimate - 0.3), 0.1)   # de-confounded
  expect_lt(ape$conf_low, 0.3)
  expect_gt(ape$conf_high, 0.3)
  expect_equal(ape$contrast, "per unit")

  # A dose reports APE, never ATE: it is an effect per unit, not a difference.
  expect_false("ATE" %in% effects(fit)$effect)
  expect_equal(fit$spec$treatment_type, "continuous")
})

test_that("multi-arm propensities respect the trimming floor", {
  # Clamping and then renormalizing can push a value back under the floor, so
  # the floor was not actually enforced. Mixing towards the uniform does
  # enforce it, and still leaves every row summing to one.
  set.seed(8)
  d <- effect_panel(seed = 8, n_id = 10L, n_time = 40L)
  # Assignment depends strongly on x1, so some rows get extreme propensities.
  strength <- 3 * d$x1
  probs <- cbind(1, exp(strength), exp(2 * strength))
  probs <- probs / rowSums(probs)
  u <- runif(nrow(d))
  d$arm <- c("a", "b", "c")[1L + (u > probs[, 1L]) +
                              (u > probs[, 1L] + probs[, 2L])]
  d$out <- ifelse(d$arm == "b", 1, ifelse(d$arm == "c", 2, 0)) +
    0.5 * d$x1 + rnorm(nrow(d), sd = 0.5)

  train <- d[seq_len(300), , drop = FALSE]
  test <- d[301:400, , drop = FALSE]
  info <- .idio_treatment_info(d$arm)
  train$arm <- info$code[seq_len(300)]
  control <- .idio_ml_control(lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                              mtry = NULL, num_trees = 10L, cost = 1, p = 2L)
  ps <- .idio_arm_propensity(train, c("x1", "x2"), train$arm, test, 3L,
                             "logistic", control, "native", trim = 0.05)

  floor_at <- min(0.05, 1 / (2 * 3))
  expect_gte(min(ps$e), floor_at - 1e-12)
  expect_equal(as.vector(rowSums(ps$e)), rep(1, nrow(test)), tolerance = 1e-10)
})

test_that("a multi-arm treatment reports one contrast per arm", {
  set.seed(5)
  d <- effect_panel(seed = 5, n_id = 10L, n_time = 40L)
  d$arm <- sample(c("a", "b", "c"), nrow(d), replace = TRUE)
  d$out <- ifelse(d$arm == "b", 1, ifelse(d$arm == "c", 2, 0)) +
    0.5 * d$x1 + rnorm(nrow(d), sd = 0.5)

  fit <- fit_effects(d, y = "out", treatment = "arm", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")
  ate <- effects(fit, effect = "ATE")
  expect_equal(nrow(ate), 2L)                       # b vs a and c vs a
  expect_setequal(ate$contrast, c("b vs a", "c vs a"))

  b <- effects(fit, effect = "ATE", contrast = "b vs a")
  cc <- effects(fit, effect = "ATE", contrast = "c vs a")
  expect_lt(abs(b$estimate - 1), 0.3)
  expect_lt(abs(cc$estimate - 2), 0.3)

  # The reference arm is the user's to choose.
  ref_b <- fit_effects(d, y = "out", treatment = "arm", x = c("x1", "x2"),
                       id = "id", time = "day", scope = "pooled",
                       reference = "b")
  expect_setequal(effects(ref_b, effect = "ATE")$contrast,
                  c("a vs b", "c vs b"))
  expect_lt(abs(effects(ref_b, effect = "ATE",
                        contrast = "a vs b")$estimate + 1), 0.3)

  expect_error(fit_effects(d, "out", "arm", c("x1", "x2"), "id",
                           reference = "zzz"), "must be one of the treatment")
})

test_that("a binary outcome gives a risk difference", {
  set.seed(6)
  d <- effect_panel(seed = 6, n_id = 10L, n_time = 40L)
  d$drug <- rbinom(nrow(d), 1L, 0.5)
  lin <- -0.2 + 1.5 * d$drug + d$x1
  d$sick <- factor(ifelse(runif(nrow(d)) < plogis(lin), "yes", "no"),
                   levels = c("no", "yes"))
  truth <- mean(plogis(-0.2 + 1.5 + d$x1) - plogis(-0.2 + d$x1))

  fit <- fit_effects(d, y = "sick", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "pooled")
  ate <- effects(fit, effect = "ATE")
  expect_gt(ate$estimate, 0)
  expect_lt(abs(ate$estimate), 1)            # a risk difference is bounded
  expect_lt(abs(ate$estimate - truth), 0.1)

  # The outcome model is a classifier, so the usual classification metrics
  # describe it.
  expect_equal(fit$spec$task, "classification")
  expect_true(all(is.finite(metrics(fit, overall = TRUE)$brier)))
  expect_true("probability" %in% names(predictions(fit)))
})

test_that("the propensity model follows the estimator and can be named", {
  d <- effect_panel(true_eff = 1)
  fit <- fit_effects(d, "mood", "drug", c("x1", "x2"), "id", time = "day",
                     scope = "pooled")
  expect_equal(fit$spec$propensity, "logistic")   # native default, unchanged

  named <- fit_effects(d, "mood", "drug", c("x1", "x2"), "id", time = "day",
                       scope = "pooled", propensity = "lasso")
  expect_equal(named$spec$propensity, "lasso")
  expect_lt(abs(effects(named, effect = "ATE")$estimate - 1), 0.3)

  expect_error(
    fit_effects(d, "mood", "drug", c("x1", "x2"), "id", propensity = "nope"),
    "Unknown model")
})

test_that("the treatment type is detected, and can be overridden", {
  d <- effect_panel(true_eff = 1)
  expect_equal(.idio_treatment_info(c(0, 1, 1, 0))$type, "binary")
  expect_equal(.idio_treatment_info(c(1.5, 2.5, 3.5, 9))$type, "continuous")
  expect_equal(.idio_treatment_info(c("a", "b", "c"))$type, "multiarm")

  # A numeric dose with few values reads as a dose; say so to get arms.
  expect_equal(.idio_treatment_info(c(0, 1, 2))$type, "continuous")
  expect_equal(.idio_treatment_info(c(0, 1, 2), type = "multiarm")$type,
               "multiarm")

  expect_error(.idio_treatment_info(rep(1, 5)), "only one value")
  expect_error(.idio_treatment_info(c("a", "b", "c"), type = "continuous"),
               "must be a numeric")
  expect_error(.idio_treatment_info(c("a", "b", "c"), type = "binary"),
               "exactly two observed levels")

  # A three-valued numeric dose can be forced into unordered arms end to end.
  d$dose <- rep(c(0, 1, 2), length.out = nrow(d))
  d$y2 <- d$dose + rnorm(nrow(d), sd = 0.5)
  armed <- fit_effects(d, "y2", "dose", c("x1", "x2"), "id", time = "day",
                       scope = "pooled", treatment_type = "multiarm")
  expect_setequal(effects(armed, effect = "ATE")$contrast,
                  c("1 vs 0", "2 vs 0"))

  expect_error(fit_effects(d, "mood", "drug", c("x1", "x2"), "id", trim = 0.9),
               "`trim` must be")
})

test_that("a unit with only one treatment arm fails cleanly", {
  d <- effect_panel(true_eff = 1)
  d$drug[d$id == 1] <- 1L    # person 1 is always treated
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
                     id = "id", time = "day", scope = "both")

  expect_true("1" %in% fit$failures$subject)
  expect_false("1" %in% effects(fit, scope = "individual")$subject)
  expect_true(nrow(effects(fit, scope = "pooled")) > 0L)   # pooled survives
})
