test_that("summary() of describe_persons() gives one row per variable", {
  vars <- c("efficacy", "effort")
  d <- describe_persons(srl, id = "name", vars = vars, time = "day",
                        detail = "full")
  s <- summary(d)
  tab <- as.data.frame(d)
  expect_equal(s$variable, vars)
  expect_equal(s$persons, c(36L, 36L))
  expect_equal(s$significant_trends[1],
               sum(subset(tab, variable == "efficacy")$trend_p < 0.05))
  expect_equal(s$trend_share, s$significant_trends / s$persons)
  expect_equal(s$mean_of_means[2], mean(subset(tab, variable == "effort")$mean))
  # A stricter alpha can only find fewer trends.
  expect_true(all(summary(d, alpha = 0.01)$significant_trends <=
                    s$significant_trends))
  # Without detail = "full" the trend columns are missing, not invented.
  basic <- summary(describe_persons(srl, id = "name", vars = vars))
  expect_true(all(is.na(basic$significant_trends)))
  expect_error(summary(d, alpha = 2), "alpha")
})

test_that("keep_all = FALSE returns only id, time, variables and new parts", {
  out <- split_levels(srl, id = "name", vars = "efficacy", time = "day",
                      keep_all = FALSE)
  expect_named(out, c("name", "day", "efficacy", "efficacy_within",
                      "efficacy_between"))
  lagged <- preprocess_panel(srl, id = "name", time = "day", vars = "effort",
                             lag = 1, keep_all = FALSE)
  expect_named(lagged, c("name", "day", "effort", "effort_lag1"))
  expect_true(is.na(head(lagged, 1)$effort_lag1))
  expect_equal(ncol(split_levels(srl, id = "name", vars = "efficacy")),
               ncol(srl) + 2L)
})
