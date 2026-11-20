# preprocess_panel(), split_wb(), split_levels(): preparing panel series for a within-person model: each
# person's own linear time trend removed, the result centred on the person's mean and divided by the person's
# standard deviation, a lag-1 copy made by day; and the split of a variable into its person mean (between) and
# the deviation from it (within). Against stats::lm() residuals and the definitions in base R.
#
# Residuals of a two-parameter regression, means and standard deviations: closed form, so 1e-10.

two_items <- c("efficacy", "effort")
ordered <- srl[order(srl$name, srl$day), ]

test_that("detrended, person-centred, person-scaled and lagged series of two learners", {
  pair <- subset(ordered, name %in% unique(ordered$name)[c(1L, 6L)], select = c(name, day, efficacy, effort))
  ours <- preprocess_panel(pair, id = "name", time = "day", vars = two_items, detrend = "person", detrend_alpha = 1,
                           center = "person", scale = "person", lag = 1, keep_all = FALSE)
  # The residual of the learner's own regression on day, as a z-score within the learner.
  standardised_residual <- function(v, day) {
    residual <- stats::residuals(stats::lm(v ~ day, na.action = stats::na.exclude))
    (residual - mean(residual, na.rm = TRUE)) / stats::sd(residual, na.rm = TRUE)
  }
  theirs <- do.call(rbind, lapply(split(pair, pair$name), \(person) {
    efficacy <- standardised_residual(person$efficacy, person$day)
    effort <- standardised_residual(person$effort, person$day)
    yesterday <- match(person$day - 1L, person$day)
    data.frame(name = person$name, day = person$day, efficacy = efficacy, effort = effort,
               efficacy_lag1 = efficacy[yesterday], effort_lag1 = effort[yesterday])
  }))
  # The comparison is of the days where the value and its lag both exist; the other cells are missing on both
  # sides and not comparable.
  expect_reference(stats::na.omit(ours), stats::na.omit(theirs), reference = "stats", covers = "preprocess_panel()",
                   quantity = "two learners, 156 days, one with missing days", tolerance = 1e-10, key = c("name", "day"))
})

test_that("a variable split into its person mean and the deviation from it", {
  six <- subset(ordered, name %in% utils::head(unique(ordered$name), 6L), select = c(name, day, efficacy, effort))
  theirs <- transform(six, efficacy_between = stats::ave(efficacy, name, FUN = \(v) mean(v, na.rm = TRUE)),
                      effort_between = stats::ave(effort, name, FUN = \(v) mean(v, na.rm = TRUE)))
  theirs <- transform(theirs, efficacy_within = efficacy - efficacy_between, effort_within = effort - effort_between)
  theirs <- subset(theirs, select = c(name, day, efficacy_within, effort_within, efficacy_between, effort_between))
  expect_reference(split_wb(six, id = "name", vars = two_items, time = "day"), theirs,
                   reference = "independent: person means and deviations from them", covers = "split_wb()",
                   quantity = "six learners, efficacy and effort", tolerance = 1e-10, key = c("name", "day"),
                   note = "A missing value stays missing in the within component; both sides leave it NA (not comparable).")
  expect_reference(split_levels(six, id = "name", vars = two_items, time = "day"), theirs,
                   reference = "independent: person means and deviations from them", covers = "split_levels()",
                   quantity = "six learners, efficacy and effort, split_levels()", tolerance = 1e-10, key = c("name", "day"))
})
