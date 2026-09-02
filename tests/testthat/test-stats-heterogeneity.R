het_panel <- function(seed = 7L, n_id = 12L, n_t = 30L, re_sd = 1) {
  set.seed(seed)
  n <- n_id * n_t
  d <- data.frame(id = rep(seq_len(n_id), each = n_t),
                  day = rep(seq_len(n_t), n_id),
                  x1 = stats::rnorm(n), x2 = stats::rnorm(n))
  d$drug <- stats::rbinom(n, 1L, 0.5)
  u <- rep(stats::rnorm(n_id, sd = re_sd), each = n_t)  # person random effect
  # The drug gives +2 to people with x1 > 0 and nothing to anyone else.
  d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + u + stats::rnorm(n, sd = 0.5)
  d
}

test_that("cluster-robust standard errors fix the coverage of the ATE", {
  # Rows within a person are correlated. A row-level SE treats 30 occasions as
  # 30 independent facts and covers ~78% of the time instead of 95%.
  set.seed(4)
  covered <- vapply(1:40, function(s) {
    d <- het_panel(seed = s, n_id = 12L, n_t = 30L, re_sd = 1.5)
    d$mood <- 1 * d$drug + 0.5 * d$x1 +
      rep(stats::rnorm(12, sd = 1.5), each = 30) + stats::rnorm(360, sd = 0.5)
    h <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                           treatment = "drug", num_splits = 6L,
                           model = "linear")
    a <- heterogeneity(h, effect = "average")
    a$conf_low <= 1 && a$conf_high >= 1
  }, logical(1))
  expect_gt(mean(covered), 0.9)   # nominal is 0.95; conservative is fine
})

test_that("the standard error is built on people, not rows", {
  d <- het_panel()
  h <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                         treatment = "drug", num_splits = 5L, model = "linear")
  tab <- heterogeneity(h, effect = "average")
  # Half the people are held out in each split, so the inference rests on
  # roughly n_id/2 units -- far fewer than the number of rows.
  expect_lt(tab$n_people, tab$n)
  expect_lte(tab$n_people, 12L)
})

test_that("fit_heterogeneity recovers a known effect and finds who it helps", {
  d <- het_panel()
  h <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                         treatment = "drug", num_splits = 20L,
                         model = c("linear", "ridge", "tree"))

  expect_s3_class(h, "idiostats_heterogeneity")
  avg <- heterogeneity(h, effect = "average")
  expect_lt(abs(avg$estimate - 1), 0.4)      # true ATE ~= 1
  expect_lt(avg$conf_low, 1)
  expect_gt(avg$conf_high, 1)

  # Sorted groups must run from least helped to most helped.
  g <- heterogeneity(h)
  g <- g[grepl("^group:g", g$effect), ]
  expect_gt(g$estimate[nrow(g)], g$estimate[1L])

  # CLAN answers "who is in the top group": the people with high x1.
  cl <- clan(h)
  expect_true("x1" %in% cl$variable)
  expect_gt(cl$estimate[cl$variable == "x1"], 1)
  expect_lt(cl$p_value[cl$variable == "x1"], 0.05)
  expect_named(cl, c("target", "model", "variable", "estimate", "std_error",
                     "conf_low", "conf_high", "p_value", "n", "n_people",
                     "splits"))
})

test_that("the learner is chosen for detecting heterogeneity, not for RMSE", {
  d <- het_panel()
  h <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                         treatment = "drug", num_splits = 10L,
                         model = c("linear", "ridge", "tree"))
  lam <- learners(h)
  expect_named(lam, c("model", "lambda", "lambda_bar"))
  expect_equal(nrow(lam), 3L)
  expect_true(all(lam$lambda >= 0, na.rm = TRUE))
  # The best learner is the one with the largest lambda, and it is what the
  # accessors default to.
  expect_equal(h$spec$best, lam$model[which.max(lam$lambda)])
  expect_equal(unique(heterogeneity(h)$model), h$spec$best)
  expect_equal(length(unique(heterogeneity(h, all_models = TRUE)$model)), 3L)
})

test_that("no heterogeneity is claimed when the effect is constant", {
  d <- het_panel()
  d$mood <- 1 * d$drug + 0.5 * d$x1 + stats::rnorm(nrow(d), sd = 0.5)
  h <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                         treatment = "drug", num_splits = 20L,
                         model = "linear")
  tb <- heterogeneity(h, effect = "group:top-bottom")
  expect_lt(tb$conf_low, 0)
  expect_gt(tb$conf_high, 0)   # the interval covers zero
})

test_that("target = 'error' finds who the model fails", {
  # Half the people are noisy; the model should be able to tell them apart,
  # and x2 marks them.
  set.seed(21)
  n_id <- 12L; n_t <- 30L
  d <- data.frame(id = rep(seq_len(n_id), each = n_t),
                  day = rep(seq_len(n_t), n_id),
                  x1 = stats::rnorm(n_id * n_t))
  noisy <- rep(c(rep(0, n_id / 2), rep(1, n_id / 2)), each = n_t)
  d$x2 <- noisy + stats::rnorm(n_id * n_t, sd = 0.1)   # x2 flags the noisy half
  d$y <- 2 * d$x1 + stats::rnorm(n_id * n_t, sd = 0.3 + 2 * noisy)

  h <- fit_heterogeneity(d, "y", c("x1", "x2"), "id", target = "error",
                         num_splits = 15L, model = c("linear", "tree"))
  expect_equal(h$spec$target, "error")

  g <- heterogeneity(h)
  gg <- g[grepl("^group:g", g$effect), ]
  expect_gt(gg$estimate[nrow(gg)], gg$estimate[1L])   # error really does vary
  expect_lt(heterogeneity(h, effect = "group:top-bottom")$p_value, 0.10)

  # And CLAN names x2 as what marks the unpredictable people.
  cl <- clan(h)
  expect_gt(cl$estimate[cl$variable == "x2"], 0)
})

test_that("target = 'gain' finds who benefits from person-specific modelling", {
  # Nine people follow the majority slope (+1); three are deviant (-3). The
  # pooled model is dominated by the majority, so the nine gain almost nothing
  # from being modelled alone and the three gain a lot. That is what genuine
  # differential gain looks like.
  #
  # (A 6/6 split would NOT work: the pooled slope would land midway and be
  # equally wrong for everyone, so every person would gain the same amount --
  # which the engine correctly reports as *no* heterogeneity.)
  set.seed(5)
  n_id <- 12L; n_t <- 40L
  d <- data.frame(id = rep(seq_len(n_id), each = n_t),
                  day = rep(seq_len(n_t), n_id),
                  x1 = stats::rnorm(n_id * n_t),
                  x2 = stats::rnorm(n_id * n_t))
  d$deviant <- rep(c(rep(0, 9), rep(1, 3)), each = n_t)
  d$y <- ifelse(d$deviant == 1, -3, 1) * d$x1 +
    stats::rnorm(n_id * n_t, sd = 0.4)

  h <- fit_heterogeneity(d, "y", c("x1", "x2"), "id", target = "gain",
                         num_splits = 25L, model = "linear",
                         clan = c("x1", "x2", "deviant"))
  expect_equal(h$spec$target, "gain")
  expect_equal(h$spec$split, "occasion")   # gain forces a within-person split

  expect_gt(heterogeneity(h, effect = "average")$estimate, 0)

  # The top group must gain far more than the bottom, and detectably so.
  g <- heterogeneity(h)
  gg <- g[grepl("^group:g", g$effect), ]
  expect_gt(gg$estimate[nrow(gg)], 2 * gg$estimate[1L])
  expect_lt(heterogeneity(h, effect = "group:top-bottom")$p_value, 0.05)
  expect_lt(heterogeneity(h, effect = "heterogeneity")$p_value, 0.05)

  # And CLAN names exactly who they are: the deviant people.
  cl <- clan(h)
  expect_equal(cl$estimate[cl$variable == "deviant"], 1)
})

test_that("no gain heterogeneity is invented when everyone gains equally", {
  # A 6/6 split of +1 and -3 slopes: the pooled model is equally wrong for
  # both halves, so everybody benefits about the same. The engine must not
  # manufacture heterogeneity here.
  set.seed(31)
  n_id <- 12L; n_t <- 40L
  d <- data.frame(id = rep(seq_len(n_id), each = n_t),
                  day = rep(seq_len(n_t), n_id),
                  x1 = stats::rnorm(n_id * n_t),
                  x2 = stats::rnorm(n_id * n_t))
  half <- rep(c(rep(0, 6), rep(1, 6)), each = n_t)
  d$y <- ifelse(half == 1, -3, 1) * d$x1 + stats::rnorm(n_id * n_t, sd = 0.4)

  h <- fit_heterogeneity(d, "y", c("x1", "x2"), "id", target = "gain",
                         num_splits = 20L, model = "linear")
  expect_gt(heterogeneity(h, effect = "average")$estimate, 0)  # all do gain
  tb <- heterogeneity(h, effect = "group:top-bottom")
  expect_lt(tb$conf_low, 0)
  expect_gt(tb$conf_high, 0)   # but the gain does not differ between them
})

test_that("bad specifications are refused", {
  d <- het_panel()
  expect_error(
    fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate"),
    "needs a `treatment`"
  )
  # The engine estimates a numeric quantity; a class outcome is not one.
  d$label <- ifelse(d$mood > 0, "hi", "lo")
  expect_error(
    fit_heterogeneity(d, "label", c("x1", "x2"), "id", target = "error"),
    "numeric outcome"
  )
})
