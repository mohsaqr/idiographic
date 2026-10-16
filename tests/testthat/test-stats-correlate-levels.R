# Within- vs between-person correlations (Fisher, Medaglia & Jeronimus, 2018).

lv_data <- function() subset(srl, name %in% unique(srl$name)[1:15])

test_that("each correlation equals a hand computation", {
  d <- lv_data()
  lv <- correlate_levels(d, id = "name", vars = c("efficacy", "effort"),
                         time = "day")
  tab <- as.data.frame(lv)

  person <- unique(d$name)[1]
  own <- d[d$name == person, ]
  own <- own[order(own$day), ]
  expect_equal(
    subset(tab, level == "within" & unit == person)$r,
    stats::cor(own$efficacy, own$effort, use = "complete.obs"),
    tolerance = sqrt(.Machine$double.eps))

  # Occasion 3 = every person's third observation in time order.
  third <- do.call(rbind, lapply(split(d, d$name), \(p) p[order(p$day), ][3, ]))
  expect_equal(
    subset(tab, level == "between" & unit == "3")$r,
    stats::cor(third$efficacy, third$effort, use = "complete.obs"),
    tolerance = sqrt(.Machine$double.eps))
})

test_that("there is one within row per person and one between row per occasion", {
  d <- lv_data()
  lv <- correlate_levels(d, id = "name", vars = c("efficacy", "effort", "monitoring"),
                         time = "day")
  tab <- as.data.frame(lv)
  n_pairs <- 3L
  expect_equal(sum(tab$level == "within"), 15L * n_pairs)
  expect_equal(sum(tab$level == "between"), 156L * n_pairs)
  expect_named(tab, c("level", "unit", "x", "y", "n", "r"))
  expect_true(all(abs(tab$r) <= 1))
})

test_that("summary() is consistent with the correlations it summarises", {
  lv <- correlate_levels(lv_data(), id = "name", vars = c("efficacy", "effort"),
                         time = "day")
  s <- summary(lv)
  tab <- as.data.frame(lv)
  expect_equal(nrow(s), 1L)
  expect_equal(s$sd_within, stats::sd(subset(tab, level == "within")$r))
  expect_equal(s$sd_ratio, s$sd_within / s$sd_between)
  expect_equal(s$mean_difference, s$mean_within - s$mean_between)
  expect_identical(as.data.frame(lv, what = "summary"), s)
})

test_that("results do not depend on the stored row order", {
  d <- lv_data()
  set.seed(1)
  shuffled <- d[sample(nrow(d)), ]
  a <- summary(correlate_levels(d, id = "name", vars = c("efficacy", "effort"),
                                time = "day"))
  b <- summary(correlate_levels(shuffled, id = "name",
                                vars = c("efficacy", "effort"), time = "day"))
  expect_equal(a, b, tolerance = sqrt(.Machine$double.eps))
})

test_that("lag_adjust correlates first-order auto/cross-lag residuals", {
  d <- lv_data()
  lv <- correlate_levels(d, id = "name", vars = c("efficacy", "effort"),
                         time = "day", lag_adjust = TRUE)
  person <- unique(d$name)[2]
  own <- d[d$name == person, ]
  own <- own[order(own$day), ]
  n <- nrow(own)
  lag <- \(v) c(NA, v[-n])
  f <- data.frame(a = own$efficacy, b = own$effort,
                  a1 = lag(own$efficacy), b1 = lag(own$effort))
  ra <- rep(NA_real_, n); rb <- rep(NA_real_, n)
  ok_a <- stats::complete.cases(f[c("a", "a1", "b1")])
  ok_b <- stats::complete.cases(f[c("b", "b1", "a1")])
  ra[ok_a] <- stats::residuals(stats::lm(a ~ a1 + b1, data = f[ok_a, ]))
  rb[ok_b] <- stats::residuals(stats::lm(b ~ b1 + a1, data = f[ok_b, ]))
  expect_equal(
    subset(as.data.frame(lv), level == "within" & unit == person)$r,
    stats::cor(ra, rb, use = "complete.obs"),
    tolerance = sqrt(.Machine$double.eps))
  # Between-person correlations are unaffected by the adjustment.
  raw <- correlate_levels(d, id = "name", vars = c("efficacy", "effort"),
                          time = "day")
  expect_equal(summary(lv)$sd_between, summary(raw)$sd_between)
})

test_that("bad input fails clearly and the plot returns its summary", {
  expect_error(correlate_levels(srl, id = "name", vars = "efficacy"),
               "at least two")
  expect_error(correlate_levels(srl, id = "name", vars = c("efficacy", "effort"),
                                lag_adjust = NA), "lag_adjust")
  expect_error(plot_levels(data.frame(a = 1)), "correlate_levels")

  lv <- correlate_levels(lv_data(), id = "name", vars = c("efficacy", "effort"),
                         time = "day")
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  out <- plot_levels(lv)
  grDevices::dev.off()
  unlink(path)
  expect_equal(out, summary(lv))
})
