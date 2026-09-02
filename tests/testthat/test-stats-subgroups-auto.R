three_group_panel <- function(seed = 11L, n_each = 5L, n_time = 40L) {
  set.seed(seed)
  n_id <- 3L * n_each
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time)
  )
  # Three genuinely distinct groups: they differ on both slopes, so the middle
  # group is not merely "between" the other two.
  s1 <- rep(c(rep(2, n_each), rep(0, n_each), rep(-2, n_each)), each = n_time)
  s2 <- rep(c(rep(0, n_each), rep(2, n_each), rep(0, n_each)), each = n_time)
  d$y <- s1 * d$x1 + s2 * d$x2 + stats::rnorm(nrow(d), sd = 0.3)
  d$truth <- rep(rep(c("A", "B", "C"), each = n_each), each = n_time)
  # A person-level moderator that explains the grouping, and one that does not.
  d$dose <- rep(rep(c(10, 20, 30), each = n_each), each = n_time)
  d$noise_mod <- rep(stats::rnorm(n_id), each = n_time)
  d
}

no_group_panel <- function(seed = 3L, n_id = 30L, n_time = 60L, skew = FALSE) {
  set.seed(seed)
  # ONE population. No subgroups whatsoever -- just continuous variation in the
  # slope, either normal or skewed.
  b <- if (skew) {
    z <- stats::rchisq(n_id, df = 2)   # true skew = sqrt(8/2) = 2.0
    (z - 2) / 2
  } else {
    stats::rnorm(n_id)
  }
  d <- data.frame(id = rep(seq_len(n_id), each = n_time),
                  x = stats::rnorm(n_id * n_time))
  d$y <- b[d$id] * d$x + stats::rnorm(n_id * n_time, sd = 0.5)
  d
}

test_that("k = 'auto' recovers the true number of subgroups", {
  d <- three_group_panel()
  g <- find_subgroups(d, "y", "x1:x2", "id", method = "effect_clustering",
                      k = "auto", k_max = 5L, reps = 25L)

  expect_equal(g$spec$k, 3L)
  expect_true(g$spec$auto)
  expect_true(all(c("k", "model", "bic", "selected") %in% names(g$selection)))
  expect_equal(sum(g$selection$selected), 1L)
  expect_equal(g$selection$k[g$selection$selected], 3L)
  expect_gt(g$test$evidence, 10)   # very strong on Raftery's BIC scale

  # And the assignment matches the planted groups.
  tab <- groups(g)
  truth <- unique(d[c("id", "truth")])
  merged <- merge(tab, truth, by.x = "subject", by.y = "id")
  expect_equal(length(unique(merged$subgroup)), 3L)
  expect_equal(nrow(unique(merged[c("subgroup", "truth")])), 3L)  # 1:1 mapping
})

test_that("test_subgroups can say NO -- there are no subgroups", {
  # The whole point: every clustering method returns groups on request, even
  # when there are none. This is the verb that refuses.
  d <- no_group_panel(seed = 1L)
  t <- test_subgroups(d, "y", "x", "id")

  expect_s3_class(t, "idiostats_subgroup_test")
  expect_equal(t$k, 1L)
  expect_false(t$skewed)
  expect_true(all(c("k", "model", "bic", "selected") %in%
                    names(as.data.frame(t))))
  expect_output(print(t), "no subgroups detected")
})

test_that("the null verdict is calibrated, not lucky", {
  # The test is a statistical procedure, so it is wrong sometimes. What matters
  # is the RATE: it should report one population on most no-subgroup datasets.
  # (Measured at ~90% over 50 replicates during development.)
  skip_on_cran()
  ks <- vapply(1:10, function(s) {
    test_subgroups(no_group_panel(seed = s), "y", "x", "id")$k
  }, integer(1))
  expect_gte(sum(ks == 1L), 7L)
})

test_that("k = 'auto' warns loudly when there are no subgroups", {
  d <- no_group_panel(seed = 1L)
  expect_warning(
    g <- find_subgroups(d, "y", "x", "id", k = "auto", reps = 10L),
    "No subgroups detected"
  )
  expect_equal(g$spec$k, 1L)
  expect_output(print(g), "not supported by the data")
})

test_that("stability is NOT evidence that subgroups exist", {
  # On data with no subgroups at all, consensus stability still scores very
  # high, because slicing a single smooth cloud in half is highly repeatable.
  # This test exists to stop anyone reinstating stability as an existence test.
  d <- no_group_panel(seed = 1L)
  g <- find_subgroups(d, "y", "x", "id", method = "effect_clustering",
                      k = 2L, reps = 20L)
  expect_gt(mean(groups(g)$stability, na.rm = TRUE), 0.7)  # looks convincing...
  expect_equal(test_subgroups(d, "y", "x", "id")$k, 1L)    # ...and is wrong
})

test_that("skew is flagged, and genuine clusters are not mistaken for skew", {
  # Skew manufactures subgroups (60% of runs in simulation vs 10% under
  # normality), so it must be flagged.
  skewed <- test_subgroups(no_group_panel(seed = 9L, skew = TRUE),
                           "y", "x", "id")
  expect_true(skewed$skewed)
  expect_gt(abs(skewed$shape$z_skewness), 2)   # judged against sampling error

  # But REAL subgroups also skew the coefficients whenever the groups are
  # unevenly spaced -- here the x2 slopes are (0, 2, 0), giving skew ~0.7. Skew
  # alone therefore cannot separate shape from structure. Kurtosis breaks the
  # tie: genuine multi-modality is platykurtic (~ -1.5), a skewed unimodal
  # distribution is not. The warning must NOT fire here, or it would shout
  # loudest exactly when the subgroups are real.
  d <- three_group_panel()
  real <- test_subgroups(d, "y", "x1:x2", "id")
  expect_equal(real$k, 3L)
  expect_gt(max(abs(real$shape$skewness)), 0.5)   # it IS skewed ...
  expect_lt(min(real$shape$kurtosis), -0.5)       # ... but platykurtic ...
  expect_false(real$skewed)                       # ... so: no false alarm
})

test_that("model_tree splits people on the moderator that matters", {
  d <- three_group_panel()
  g <- find_subgroups(d, "y", "x1:x2", "id", method = "model_tree",
                      moderators = c("dose", "noise_mod"), k = 3L, reps = 15L)

  expect_equal(g$spec$method, "model_tree")
  tab <- groups(g)
  expect_equal(length(unique(tab$subgroup)), 3L)

  # Each discovered group must correspond to exactly one dose level: the tree
  # found the real moderator and ignored the noise one.
  truth <- unique(d[c("id", "dose")])
  merged <- merge(tab, truth, by.x = "subject", by.y = "id")
  expect_equal(nrow(unique(merged[c("subgroup", "dose")])), 3L)
  expect_gt(mean(tab$stability, na.rm = TRUE), 0.9)
})

test_that("model_tree demands moderators, and they must be person-level", {
  d <- three_group_panel()
  expect_error(
    find_subgroups(d, "y", "x1:x2", "id", method = "model_tree", k = 2L),
    "needs `moderators`"
  )
  # x1 varies within person, so it cannot be a person-level moderator.
  expect_error(
    find_subgroups(d, "y", "x2", "id", method = "model_tree",
                   moderators = "x1", k = 2L),
    "constant within each person"
  )
})

test_that("moderators are never used as predictors", {
  d <- three_group_panel()
  # Even when the moderator is named in `x`, it must be dropped: it is what we
  # split people on, not something the model may lean on.
  g <- find_subgroups(d, "y", c("x1", "x2", "dose"), "id",
                      method = "model_tree", moderators = "dose", k = 2L,
                      reps = 5L)
  expect_setequal(g$spec$x, c("x1", "x2"))
  expect_false("dose" %in% g$spec$x)
})
