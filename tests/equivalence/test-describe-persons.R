# describe_persons(): within-person descriptive dynamics of each person's series, against their definitions
# written out in base R: level and spread, the root mean square of successive differences (von Neumann et al.,
# 1941; Jahng, Wood & Trull, 2008), the lag-1 autocorrelation over adjacent complete pairs, the probability of
# acute change against the sample's 90th percentile of absolute changes (Jahng, Wood & Trull, 2008), floor and
# ceiling shares, moment skewness and excess kurtosis, the linear time trend and the longest run.
#
# Closed-form sums, quantiles and a two-parameter regression on at most 156 values: the sides can differ only by
# rounding, so 1e-10.

two_items <- c("efficacy", "effort")
six_learners <- subset(srl, name %in% utils::head(unique(srl$name), 6L), select = c(name, day, efficacy, effort))

#' One person's series described from the definitions
#'
#' @param v The values in time order; `day` the occasions. `lowest`, `highest`: the bounds of the scale seen in
#'   the sample. `acute`: the sample's cut-off for an acute change.
describe_series <- function(v, day, lowest, highest, acute) {
  seen <- v[!is.na(v)]
  step <- diff(v)
  step <- step[!is.na(step)]
  adjacent <- !is.na(v[-1L]) & !is.na(v[-length(v)])
  centred <- seen - mean(seen)
  trend <- stats::coef(summary(stats::lm(v ~ day)))
  data.frame(
    n = length(seen), missing = sum(is.na(v)), mean = mean(seen), median = stats::median(seen), sd = stats::sd(seen),
    min = min(seen), max = max(seen),
    rmssd = sqrt(mean(step^2)),
    autocor = stats::cor(v[-length(v)][adjacent], v[-1L][adjacent]),
    span = max(day) - min(day), gap_median = stats::median(diff(day)), gap_max = max(diff(day)),
    p_floor = mean(seen <= lowest), p_ceiling = mean(seen >= highest),
    pac = mean(abs(step) >= acute),
    skew = mean(centred^3) / mean(centred^2)^1.5,
    kurtosis = mean(centred^4) / mean(centred^2)^2 - 3,
    trend = trend["day", "Estimate"], trend_p = trend["day", "Pr(>|t|)"],
    longest_run = max(rle(seen)$lengths))
}

#' Every person's description of one variable
describe_variable <- function(data, variable) {
  people <- split(data, data$name)
  changes <- unlist(lapply(people, \(person) diff(person[[variable]])))
  acute <- stats::quantile(abs(changes), probs = 0.9, na.rm = TRUE, names = FALSE)
  rows <- lapply(people, \(person) {
    describe_series(person[[variable]], person$day, lowest = min(data[[variable]], na.rm = TRUE),
                    highest = max(data[[variable]], na.rm = TRUE), acute = acute)
  })
  data.frame(subject = names(people), variable = variable, do.call(rbind, rows), row.names = NULL)
}

test_that("six learners over 156 days, every descriptive", {
  ours <- describe_persons(six_learners, id = "name", vars = two_items, time = "day", detail = "full")
  theirs <- do.call(rbind, lapply(two_items, \(variable) describe_variable(six_learners, variable)))
  expect_reference(as.data.frame(ours), theirs,
                   reference = "independent: the descriptives from their definitions",
                   covers = "describe_persons()", quantity = "srl, six learners", tolerance = 1e-10,
                   key = c("subject", "variable"),
                   note = "The sixth learner has missing days. Skewness and kurtosis are the population-moment forms.")
})

test_that("the lag-1 autocorrelation is the correlation of adjacent pairs, not the autocorrelation function", {
  ours <- describe_persons(six_learners, id = "name", vars = two_items, time = "day", detail = "full")
  theirs <- do.call(rbind, lapply(two_items, \(variable) {
    people <- split(six_learners, six_learners$name)
    data.frame(subject = names(people), variable = variable,
               autocor = vapply(people, \(person) {
                 stats::acf(person[[variable]], lag.max = 1L, plot = FALSE, na.action = stats::na.pass)$acf[2L]
               }, numeric(1)), row.names = NULL)
  }))
  expect_known_difference(subset(as.data.frame(ours), select = c(subject, variable, autocor)), theirs,
                          reference = "stats", covers = "describe_persons()",
                          quantity = "lag-1 autocorrelation against stats::acf()", tolerance = 1e-10,
                          key = c("subject", "variable"),
                          reason = "describe_persons() correlates each value with the next over adjacent complete pairs (cor()); acf() centres on the whole-series mean and divides the lagged cross-product by the full-series variance, which shrinks the estimate towards zero in a short series.",
                          agrees_with = "cor() over adjacent complete pairs (the comparison above)")
})

test_that("the skewness and kurtosis are the population-moment forms, not the sample-adjusted ones", {
  ours <- describe_persons(six_learners, id = "name", vars = two_items, time = "day", detail = "full")
  # The adjusted Fisher-Pearson forms G1 and G2 (Joanes & Gill, 1998), the convention of SAS and SPSS.
  adjusted <- function(v) {
    v <- v[!is.na(v)]
    n <- length(v)
    centred <- v - mean(v)
    g1 <- mean(centred^3) / mean(centred^2)^1.5
    g2 <- mean(centred^4) / mean(centred^2)^2 - 3
    c(skew = sqrt(n * (n - 1)) / (n - 2) * g1, kurtosis = (n - 1) / ((n - 2) * (n - 3)) * ((n + 1) * g2 + 6))
  }
  theirs <- do.call(rbind, lapply(two_items, \(variable) {
    people <- split(six_learners, six_learners$name)
    data.frame(subject = names(people), variable = variable, do.call(rbind, lapply(people, \(p) adjusted(p[[variable]]))),
               row.names = NULL)
  }))
  expect_known_difference(subset(as.data.frame(ours), select = c(subject, variable, skew, kurtosis)), theirs,
                          reference = "independent: adjusted skewness G1 and kurtosis G2 (Joanes & Gill, 1998)",
                          covers = "describe_persons()", quantity = "skewness and kurtosis, adjusted forms",
                          tolerance = 1e-10, key = c("subject", "variable"),
                          reason = "describe_persons() reports the population-moment forms g1 and g2; the adjusted forms multiply them by factors that depend on n.",
                          agrees_with = "the population-moment forms (the first comparison)")
})

test_that("the summary across people", {
  ours <- describe_persons(six_learners, id = "name", vars = two_items, time = "day", detail = "full")
  theirs <- do.call(rbind, lapply(two_items, \(variable) {
    described <- describe_variable(six_learners, variable)
    data.frame(variable = variable, persons = nrow(described), mean_of_means = mean(described$mean),
               sd_of_means = stats::sd(described$mean), mean_sd_within = mean(described$sd),
               significant_trends = sum(described$trend_p < 0.05), trend_share = mean(described$trend_p < 0.05))
  }))
  expect_reference(summary(ours), theirs,
                   reference = "independent: the descriptives from their definitions",
                   covers = c("describe_persons()", "summary.idiographic_descriptives()", "summary.idiostats_descriptives()"),
                   quantity = "srl, six learners, summary per variable", tolerance = 1e-10, key = "variable",
                   note = "summary.idiostats_descriptives() is the same function object as summary.idiographic_descriptives().")
})
