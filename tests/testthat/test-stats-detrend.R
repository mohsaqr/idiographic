# Detrending removes a linear time trend but must not remove anything else:
# not the level, not a series too short to support a trend, and not a trend
# that is only noise.

trend_panel <- function(seed = 1L, n_id = 12L, n_time = 30L, slope = 0.5,
                        level = 10) {
  set.seed(seed)
  person <- rep(seq_len(n_id), each = n_time)
  day <- rep(seq_len(n_time), n_id)
  data.frame(
    id = person, day = day,
    v = level + slope * day + stats::rnorm(n_id * n_time, sd = 1),
    flat = level + stats::rnorm(n_id * n_time, sd = 1),
    stringsAsFactors = FALSE
  )
}

test_that("detrending removes a planted trend and keeps the level", {
  d <- trend_panel(slope = 0.5, level = 10)
  out <- preprocess_panel(d, id = "id", time = "day", vars = "v", detrend = "person")

  raw_slope <- unname(coef(lm(v ~ day, data = d))[2L])
  new_slope <- unname(coef(lm(v ~ day, data = out))[2L])
  expect_gt(raw_slope, 0.4)
  expect_lt(abs(new_slope), 0.02)          # the trend is gone

  # The level survives: detrending removes the slope, not the mean, so that
  # `detrend` and `center` remain independent choices.
  expect_equal(mean(out$v), mean(d$v), tolerance = 1e-8)
  expect_gt(mean(out$v), 9)
})

test_that("a trend that is not significant is left alone", {
  d <- trend_panel(slope = 0)
  out <- preprocess_panel(d, id = "id", time = "day", vars = "flat",
                    detrend = "person")
  # With alpha = 0.05 and no real trend, most people keep their raw series.
  unchanged <- tapply(seq_len(nrow(d)), d$id, function(i) {
    isTRUE(all.equal(d$flat[i], out$flat[i]))
  })
  expect_gt(mean(unlist(unchanged)), 0.8)

  # alpha = 1 detrends unconditionally, so every person changes.
  always <- preprocess_panel(d, id = "id", time = "day", vars = "flat",
                       detrend = "person", detrend_alpha = 1)
  expect_false(isTRUE(all.equal(d$flat, always$flat)))
})

test_that("person and grand detrending are different operations", {
  # Everyone rises, but each person rises at their own rate.
  set.seed(4)
  n_id <- 10L
  n_time <- 30L
  person <- rep(seq_len(n_id), each = n_time)
  day <- rep(seq_len(n_time), n_id)
  slopes <- seq(-1, 1, length.out = n_id)[person]
  d <- data.frame(id = person, day = day,
                  v = slopes * day + stats::rnorm(n_id * n_time, sd = 0.5))

  per_person <- preprocess_panel(d, id = "id", time = "day", vars = "v",
                           detrend = "person")
  grand <- preprocess_panel(d, id = "id", time = "day", vars = "v",
                      detrend = "grand")

  person_slope <- function(dat) {
    max(abs(vapply(split(dat, dat$id), function(z) {
      unname(coef(lm(v ~ day, data = z))[2L])
    }, numeric(1))))
  }
  # Within-person detrending flattens every person; a single grand trend
  # cannot, because the people are rising at different rates.
  expect_lt(person_slope(per_person), 0.05)
  expect_gt(person_slope(grand), 0.5)
})

test_that("detrending refuses what it cannot do and skips what it should", {
  d <- trend_panel()
  expect_error(preprocess_panel(d, id = "id", vars = "v", detrend = "person"),
               "`detrend` needs `time`")
  expect_error(preprocess_panel(d, id = "id", time = "day", vars = "v",
                          detrend = "person", detrend_alpha = 0),
               "`detrend_alpha` must be")

  d$label <- "a"
  expect_error(preprocess_panel(d, id = "id", time = "day", vars = c("v", "label"),
                          detrend = "person"),
               "must be numeric|not: label")

  # A person with fewer than three occasions cannot support a trend and is
  # returned untouched rather than silently flattened.
  short <- data.frame(id = c("a", "a", rep("b", 30)),
                      day = c(1, 2, seq_len(30)),
                      v = c(5, 9, 1 + 0.5 * seq_len(30) + rnorm(30, sd = 0.3)))
  out <- preprocess_panel(short, id = "id", time = "day", vars = "v",
                    detrend = "person")
  expect_equal(out$v[1:2], short$v[1:2])
  expect_lt(abs(unname(coef(lm(v ~ day, data = subset(out, id == "b")))[2L])),
            0.02)
})

test_that("time is read on its own scale, not as level codes", {
  # Regression test. A trend is a slope per unit of TIME, so irregular spacing
  # has to survive. as.numeric() on a factor returns level codes, which would
  # replace days 1, 2, 5, 40, 100 with ranks 1, 2, 3, 4, 5 and leave part of
  # the trend behind.
  set.seed(1)
  n_id <- 6L
  days <- c(1, 2, 5, 10, 20, 40, 41, 42, 80, 100)
  d <- data.frame(id = rep(seq_len(n_id), each = length(days)),
                  day = rep(days, n_id))
  d$v <- 10 + 0.5 * d$day + stats::rnorm(nrow(d), sd = 0.5)
  d$as_factor <- factor(d$day)
  d$as_date <- as.Date("2026-01-01") + d$day

  residual_slope <- function(out) {
    abs(unname(coef(lm(v ~ day, data = out))[2L]))
  }
  for (column in c("day", "as_factor", "as_date")) {
    out <- preprocess_panel(d, id = "id", time = column, vars = "v",
                      detrend = "person")
    expect_lt(residual_slope(out), 0.01)
  }

  # A character date cannot be read as a number, and must say so rather than
  # coercing to NA and quietly doing nothing at all.
  d$stamp <- format(d$as_date)
  expect_error(preprocess_panel(d, id = "id", time = "stamp", vars = "v",
                          detrend = "person"),
               "must be numeric, a Date/POSIXct")
})

test_that("detrending composes with the other transforms", {
  d <- trend_panel(slope = 0.5)
  out <- preprocess_panel(d, id = "id", time = "day", vars = "v",
                    detrend = "person", center = "person", lag = 1)
  expect_true(all(c("v", "v_lag1") %in% names(out)))
  # Detrended first, then person-centered: each person now averages zero.
  expect_equal(as.vector(tapply(out$v, out$id, mean)),
               rep(0, length(unique(out$id))), tolerance = 1e-8)
})
