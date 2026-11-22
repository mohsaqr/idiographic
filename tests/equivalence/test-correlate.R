# correlate_persons() and correlate_levels(): person-specific correlations with their Fisher-z intervals and t
# tests, against stats::cor.test() on each person's complete pairs; and the comparison of within-person
# correlations (one per person, over occasions) with between-person correlations (one per occasion, over the
# persons observed at that position in their series) (Hamaker, 2012), written from the definition.
#
# Sums of products on at most 156 values: rounding only, so 1e-10.

three <- c("efficacy", "effort", "planning")
pairs <- utils::combn(three, 2L, simplify = FALSE)
ordered <- srl[order(srl$name, srl$day), ]

test_that("person-specific correlations equal stats::cor.test() on each learner", {
  ours <- correlate_persons(srl, id = "name", vars = three, time = "day")
  theirs <- do.call(rbind, lapply(split(ordered, ordered$name), \(person) {
    do.call(rbind, lapply(pairs, \(pair) {
      complete <- stats::complete.cases(person[pair])
      test <- stats::cor.test(person[[pair[[1L]]]][complete], person[[pair[[2L]]]][complete])
      data.frame(subject = person$name[[1L]], x = pair[[1L]], y = pair[[2L]], n = sum(complete),
                 r = unname(test$estimate), conf_low = test$conf.int[[1L]], conf_high = test$conf.int[[2L]],
                 p_value = test$p.value)
    }))
  }))
  expect_reference(as.data.frame(ours), theirs, reference = "stats", covers = "correlate_persons()",
                   quantity = "36 learners, three pairs", tolerance = 1e-10, key = c("subject", "x", "y"))
})

test_that("within-person and between-person correlations", {
  ours <- correlate_levels(srl, id = "name", vars = three, time = "day")
  position <- stats::ave(seq_len(nrow(ordered)), ordered$name, FUN = seq_along)
  correlation_rows <- function(rows, level, unit) {
    do.call(rbind, lapply(pairs, \(pair) {
      complete <- stats::complete.cases(rows[pair])
      data.frame(level = level, unit = unit, x = pair[[1L]], y = pair[[2L]], n = sum(complete),
                 r = stats::cor(rows[[pair[[1L]]]][complete], rows[[pair[[2L]]]][complete]))
    }))
  }
  within <- do.call(rbind, lapply(split(ordered, ordered$name), \(person) {
    correlation_rows(person, "within", person$name[[1L]])
  }))
  by_occasion <- split(ordered, position)
  between <- do.call(rbind, Map(\(occasion, unit) correlation_rows(occasion, "between", unit),
                                by_occasion, names(by_occasion)))
  theirs <- rbind(within, between)
  expect_reference(as.data.frame(ours), theirs,
                   reference = "independent: Pearson correlations per person and per occasion",
                   covers = c("correlate_levels()", "as.data.frame.idiographic_level_correlations()"),
                   quantity = "36 learners, 156 occasions", tolerance = 1e-10, key = c("level", "unit", "x", "y"))
  summarise <- function(level_rows) {
    within_r <- level_rows$r[level_rows$level == "within"]
    between_r <- level_rows$r[level_rows$level == "between"]
    data.frame(x = level_rows$x[[1L]], y = level_rows$y[[1L]], n_within = length(within_r), mean_within = mean(within_r),
               median_within = stats::median(within_r), sd_within = stats::sd(within_r), n_between = length(between_r),
               mean_between = mean(between_r), median_between = stats::median(between_r), sd_between = stats::sd(between_r),
               mean_difference = mean(within_r) - mean(between_r), sd_ratio = stats::sd(within_r) / stats::sd(between_r))
  }
  expect_reference(summary(ours), do.call(rbind, lapply(split(theirs, paste(theirs$x, theirs$y)), summarise)),
                   reference = "independent: Pearson correlations per person and per occasion",
                   covers = c("correlate_levels()", "summary.idiographic_level_correlations()"),
                   quantity = "36 learners, summary per pair", tolerance = 1e-10, key = c("x", "y"))
})

test_that("lag-adjusted within-person correlations correlate the residuals of the lag-1 regressions", {
  ours <- correlate_levels(srl, id = "name", vars = c("efficacy", "effort"), time = "day", lag_adjust = TRUE)
  # Each variable regressed on both variables at the previous occasion, within the person; the within-person
  # correlation is that of the two residual series over the occasions where both exist.
  theirs <- do.call(rbind, lapply(split(ordered, ordered$name), \(person) {
    n <- nrow(person)
    previous <- \(v) c(NA, v[-n])
    frame <- data.frame(a = person$efficacy, b = person$effort, a1 = previous(person$efficacy), b1 = previous(person$effort))
    residual_a <- stats::residuals(stats::lm(a ~ a1 + b1, data = frame, na.action = stats::na.exclude))
    residual_b <- stats::residuals(stats::lm(b ~ b1 + a1, data = frame, na.action = stats::na.exclude))
    complete <- stats::complete.cases(residual_a, residual_b)
    data.frame(level = "within", unit = person$name[[1L]], x = "efficacy", y = "effort", n = sum(complete),
               r = stats::cor(residual_a[complete], residual_b[complete]))
  }))
  expect_reference(subset(as.data.frame(ours), level == "within"), theirs, reference = "stats",
                   covers = "correlate_levels()", quantity = "36 learners, lag-adjusted within-person correlations",
                   tolerance = 1e-10, key = c("level", "unit", "x", "y"))
})

test_that("within- and between-person correlations by psych::statsBy(), summarised by psych::describeBy()", {
  ours <- correlate_levels(srl, id = "name", vars = three, time = "day")
  position <- stats::ave(seq_len(nrow(ordered)), ordered$name, FUN = seq_along)
  # The correlation of each pair within each group, from psych::statsBy()'s per-group correlation matrices
  by_group <- function(frame, group, level) {
    groups <- psych::statsBy(frame, group = group, cors = TRUE, use = "pairwise")$r
    do.call(rbind, Map(\(cells, unit) {
      do.call(rbind, lapply(pairs, \(pair) {
        data.frame(level = level, unit = unit, x = pair[[1L]], y = pair[[2L]], r = cells[pair[[1L]], pair[[2L]]])
      }))
    }, groups, names(groups)))
  }
  within <- by_group(ordered[c("name", three)], "name", "within")
  between <- by_group(data.frame(occasion = position, ordered[three]), "occasion", "between")
  theirs <- rbind(within, between)
  expect_reference(as.data.frame(ours), theirs, reference = "psych",
                   covers = c("correlate_levels()", "as.data.frame.idiographic_level_correlations()"),
                   quantity = "36 learners, 156 occasions, psych::statsBy()", tolerance = 1e-10,
                   key = c("level", "unit", "x", "y"))
  described <- do.call(rbind, lapply(pairs, \(pair) {
    rows <- theirs[theirs$x == pair[[1L]] & theirs$y == pair[[2L]], ]
    levels <- psych::describeBy(rows$r, group = rows$level, mat = TRUE)
    w <- levels[levels$group1 == "within", ]
    b <- levels[levels$group1 == "between", ]
    data.frame(x = pair[[1L]], y = pair[[2L]], n_within = w$n, mean_within = w$mean, median_within = w$median,
               sd_within = w$sd, n_between = b$n, mean_between = b$mean, median_between = b$median, sd_between = b$sd,
               mean_difference = w$mean - b$mean, sd_ratio = w$sd / b$sd)
  }))
  expect_reference(summary(ours), described, reference = "psych",
                   covers = c("correlate_levels()", "summary.idiographic_level_correlations()"),
                   quantity = "36 learners, summary per pair, psych::describeBy()", tolerance = 1e-10, key = c("x", "y"))
})
