# The descriptive plots draw from the tidy result and return what they drew.

describe_panel <- function() {
  subset(srl, name %in% c("Aisha", "Alice", "Bob"))
}

draw <- function(expr) {
  path <- tempfile(fileext = ".pdf")
  grDevices::pdf(path)
  on.exit({ grDevices::dev.off(); unlink(path) }, add = TRUE)
  force(expr)
}

test_that("plot_descriptives() plots one point per person and variable", {
  d <- describe_persons(describe_panel(), id = "name",
                        vars = c("efficacy", "effort"), time = "day")
  tab <- draw(plot_descriptives(d))
  expect_s3_class(tab, "data.frame")
  expect_equal(nrow(tab), 6L)
  # What is plotted is exactly the result's table: nothing re-computed.
  expect_equal(tab$rmssd, as.data.frame(d)$rmssd)

  one <- draw(plot_descriptives(d, subject = "Bob", variable = "effort"))
  expect_equal(nrow(one), 1L)
  expect_identical(one$subject, "Bob")
})

test_that("plot_descriptives() rejects the wrong input and unknown columns", {
  d <- describe_persons(describe_panel(), id = "name", vars = "efficacy",
                        time = "day")
  expect_error(plot_descriptives(data.frame(a = 1)), "describe_persons")
  expect_error(draw(plot_descriptives(d, stat_x = "nope")), "stat_x")
})

test_that("plot_correlations() sorts by r and keeps every interval", {
  r <- correlate_persons(describe_panel(), id = "name",
                         vars = c("efficacy", "effort", "monitoring"))
  tab <- draw(plot_correlations(r))
  expect_equal(nrow(tab), nrow(as.data.frame(r)))
  expect_false(is.unsorted(tab$r))
  expect_true(all(tab$conf_low <= tab$r & tab$r <= tab$conf_high))

  only_bob <- draw(plot_correlations(r, subject = "Bob"))
  expect_true(all(only_bob$subject == "Bob"))
  expect_error(plot_correlations(data.frame(a = 1)), "correlate_persons")
})

test_that("plot_series() draws the requested persons in time order", {
  d <- describe_panel()
  shuffled <- d[rev(seq_len(nrow(d))), ]
  rows <- draw(plot_series(shuffled, id = "name", time = "day",
                           vars = c("efficacy", "effort"),
                           subject = c("Alice", "Bob")))
  expect_named(rows, c("name", "day", "efficacy", "effort"))
  expect_setequal(unique(rows$name), c("Alice", "Bob"))
  expect_false(is.unsorted(subset(rows, name == "Bob")$day))
  expect_equal(nrow(rows), sum(d$name %in% c("Alice", "Bob")))

  expect_error(plot_series(d, id = "name", time = "day", vars = "efficacy",
                           subject = "Nobody"), "No such person")
  expect_error(plot_series(d, id = "name", time = "day", vars = "name"),
               "numeric")
})

test_that("plot_coefs() draws one sorted row per person for the term", {
  fit <- fit_lm(describe_panel(), y = "effort", x = "efficacy", id = "name",
                time = "day", scope = "individual")
  rows <- draw(plot_coefs(fit, term = "efficacy"))
  expect_equal(nrow(rows), 3L)
  expect_true(all(rows$term == "efficacy"))
  expect_false(is.unsorted(rows$estimate))
  expect_error(draw(plot_coefs(fit, term = "nope")), "No such term")
})
