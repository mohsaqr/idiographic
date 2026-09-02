two_group_panel <- function(n_each = 3L, n_time = 40L) {
  set.seed(3)
  n_id <- 2L * n_each
  d <- data.frame(
    id = rep(seq_len(n_id), each = n_time),
    time = rep(seq_len(n_time), n_id),
    x1 = stats::rnorm(n_id * n_time),
    x2 = stats::rnorm(n_id * n_time),
    x3 = stats::rnorm(n_id * n_time)
  )
  # Two genuine subgroups: x1 helps one half and hurts the other.
  slope <- rep(c(rep(1, n_each), rep(-1, n_each)), each = n_time)
  d$y <- slope * d$x1 - 0.4 * d$x2 + stats::rnorm(nrow(d), sd = 0.3)
  d$truth <- ifelse(slope > 0, "up", "down")
  d
}

test_that("find_subgroups recovers real structure", {
  d <- two_group_panel()
  g <- find_subgroups(d, "y", "x1:x3", "id", method = "effect_clustering",
                      k = 2, reps = 20)

  expect_s3_class(g, "idiostats_groups")
  expect_named(groups(g), c("subject", "subgroup", "method", "stability",
                            "n_assignments"))
  expect_equal(nrow(groups(g)), 6L)
  expect_length(unique(groups(g)$subgroup), 2L)
  expect_output(print(g), "Idiostats Subgroups")

  # The discovered split must agree with the planted one (up to label swap).
  tab <- groups(g)
  truth <- unique(d[c("id", "truth")])
  merged <- merge(tab, truth, by.x = "subject", by.y = "id")
  agreement <- max(mean(merged$subgroup == "g1" & merged$truth == "up"),
                   mean(merged$subgroup == "g1" & merged$truth == "down"))
  expect_equal(agreement, 0.5)   # the 3 members of one planted group, exactly

  expect_true(all(tab$stability >= 0 & tab$stability <= 1, na.rm = TRUE))
  expect_true(mean(tab$stability, na.rm = TRUE) > 0.5)
})

test_that("every discovery method returns the same tidy shape", {
  d <- two_group_panel()
  methods <- c("effect_clustering", "error_clustering", "repeated_split",
               "random_partition")
  out <- lapply(methods, function(m) {
    groups(find_subgroups(d, "y", "x1:x3", "id", method = m, k = 2, reps = 5))
  })
  expect_true(all(vapply(out, function(tab) {
    identical(names(tab), c("subject", "subgroup", "method", "stability",
                            "n_assignments")) && nrow(tab) == 6L
  }, logical(1))))
})

test_that("fit_subgroups fits pooled, subgroup and individual together", {
  d <- two_group_panel()
  g <- find_subgroups(d, "y", "x1:x3", "id", method = "effect_clustering",
                      k = 2, reps = 10)
  fit <- fit_subgroups(d, "y", "x1:x3", "id", subgroup = g, time = "time",
                       min_train = 20)

  expect_setequal(unique(metrics(fit)$scope),
                  c("pooled", "subgroup", "individual"))

  # Subgroup models must beat pooling when the subgroups are real.
  ov <- metrics(fit, overall = TRUE)
  rmse <- stats::setNames(ov$rmse, ov$scope)
  expect_lt(rmse[["subgroup"]], rmse[["pooled"]])

  # Subgroup coefficients collapse to .all, labelled by their group.
  sub_coefs <- coefs(fit, scope = "subgroup")
  expect_true(all(sub_coefs$subject == ".all"))
  expect_setequal(unique(sub_coefs$subgroup), c("g1", "g2"))

  expect_true(all(metrics(subgroups(fit))$scope == "subgroup"))
  expect_equal(nrow(groups(fit)), 6L)
})

test_that("subgroup can be supplied as a column, a named vector, or a frame", {
  d <- two_group_panel()
  by_col <- fit_lm(d, "y", "x1:x3", "id", subgroup = "truth", scope = "subgroup",
                   time = "time", min_train = 20)

  named <- stats::setNames(unique(d[c("id", "truth")])$truth,
                           unique(d[c("id", "truth")])$id)
  by_vec <- fit_lm(d, "y", "x1:x3", "id", subgroup = named, scope = "subgroup",
                   time = "time", min_train = 20)

  frame <- data.frame(subject = names(named), subgroup = as.character(named),
                      stringsAsFactors = FALSE)
  by_df <- fit_lm(d, "y", "x1:x3", "id", subgroup = frame, scope = "subgroup",
                  time = "time", min_train = 20)

  # Per-person rows carry the group label; the .overall aggregate row spans
  # every subgroup and so is labelled .all.
  per_person <- metrics(by_col)
  per_person <- per_person[per_person$subject != ".overall", , drop = FALSE]
  expect_setequal(unique(per_person$subgroup), c("up", "down"))
  expect_equal(unique(metrics(by_col, overall = TRUE)$subgroup), ".all")

  expect_equal(metrics(by_col, overall = TRUE)$rmse,
               metrics(by_vec, overall = TRUE)$rmse)
  expect_equal(metrics(by_col, overall = TRUE)$rmse,
               metrics(by_df, overall = TRUE)$rmse)

  # The grouping column must not sneak in as a predictor.
  expect_false("truth" %in% by_col$spec$x)
})

test_that("subgroup scope without a mapping is an error", {
  d <- two_group_panel()
  expect_error(
    fit_lm(d, "y", "x1:x3", "id", scope = "subgroup", min_train = 20),
    "no `subgroup` was supplied"
  )
})
