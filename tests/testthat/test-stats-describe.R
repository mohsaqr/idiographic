# Person-level descriptives. Every statistic is checked against an independent
# computation, and the sd/rmssd distinction is pinned by construction: a slow
# drift and a fast oscillation must come out in OPPOSITE orders on the two.

drift_vs_oscillate <- function(seed = 1L, n_time = 40L) {
  set.seed(seed)
  rbind(
    data.frame(id = "drifter", day = seq_len(n_time),
               v = seq(20, 80, length.out = n_time) +
                 stats::rnorm(n_time, sd = 0.5), stringsAsFactors = FALSE),
    data.frame(id = "oscillator", day = seq_len(n_time),
               v = 50 + 10 * rep(c(-1, 1), n_time / 2) +
                 stats::rnorm(n_time, sd = 0.5), stringsAsFactors = FALSE)
  )
}

test_that("sd and rmssd measure different things", {
  d <- drift_vs_oscillate()
  out <- describe_persons(d, "id", vars = "v", time = "day")
  drift <- out[out$subject == "drifter", ]
  osc <- out[out$subject == "oscillator", ]

  # The whole reason both are reported: the orderings disagree.
  expect_gt(drift$sd, osc$sd)
  expect_lt(drift$rmssd, osc$rmssd)

  # Inertia: a drift carries over almost perfectly, an alternation inverts.
  expect_gt(drift$autocor, 0.9)
  expect_lt(osc$autocor, -0.9)
})

test_that("every statistic matches an independent computation", {
  d <- drift_vs_oscillate()
  out <- describe_persons(d, "id", vars = "v", time = "day")
  for (who in c("drifter", "oscillator")) {
    v <- d$v[d$id == who]
    row <- out[out$subject == who, ]
    expect_equal(row$mean, mean(v))
    expect_equal(row$sd, stats::sd(v))
    expect_equal(row$rmssd, sqrt(mean(diff(v)^2)))
    expect_equal(row$autocor, stats::cor(v[-length(v)], v[-1L]))
    expect_equal(row$n, length(v))
  }
})

test_that("successive differences respect time order and person boundaries", {
  # Rows deliberately shuffled: the statistics must be identical either way,
  # because `time` says what "successive" means, not row position.
  d <- drift_vs_oscillate()
  shuffled <- d[sample(nrow(d)), , drop = FALSE]
  ordered <- describe_persons(d, "id", vars = "v", time = "day")
  jumbled <- describe_persons(shuffled, "id", vars = "v", time = "day")
  expect_equal(jumbled$rmssd, ordered$rmssd)
  expect_equal(jumbled$autocor, ordered$autocor)

  # One person's last occasion must never difference against the next
  # person's first. Two flat but far-apart people have zero within-person
  # change, however the rows are arranged.
  flat <- data.frame(id = rep(c("a", "b"), each = 5L),
                     day = rep(1:5, 2L),
                     v = rep(c(0, 100), each = 5L), stringsAsFactors = FALSE)
  expect_equal(describe_persons(flat, "id", vars = "v",
                                time = "day")$rmssd, c(0, 0))
})

test_that("missing occasions are counted, not silently absorbed", {
  d <- drift_vs_oscillate()
  d$v[c(3L, 7L, 50L)] <- NA
  out <- describe_persons(d, "id", vars = "v", time = "day")
  expect_equal(sum(out$missing), 3L)
  expect_equal(sum(out$n), nrow(d) - 3L)
  expect_true(all(is.finite(out$rmssd)))    # gaps skipped, not treated as jumps

  # A person with a single usable occasion has no spread and no change.
  sparse <- data.frame(id = c(rep("a", 10L), "b"), day = c(1:10, 1),
                       v = c(stats::rnorm(10), 5), stringsAsFactors = FALSE)
  b <- describe_persons(sparse, "id", vars = "v", time = "day")
  b <- b[b$subject == "b", ]
  expect_equal(b$n, 1L)
  expect_true(is.na(b$sd))
  expect_true(is.na(b$rmssd))
  expect_true(is.na(b$autocor))
})

test_that("spacing is reported so irregular occasions are visible", {
  d <- data.frame(id = "a", day = c(1, 2, 3, 40, 41), v = stats::rnorm(5),
                  stringsAsFactors = FALSE)
  out <- describe_persons(d, "id", vars = "v", time = "day")
  expect_equal(out$span, 40)
  expect_equal(out$gap_median, 1)
  expect_equal(out$gap_max, 37)          # the gap that makes "lag 1" ambiguous

  # Without `time` there is nothing to say about spacing, so those columns go.
  no_time <- describe_persons(d, "id", vars = "v")
  expect_false(any(c("span", "gap_median", "gap_max") %in% names(no_time)))
})

test_that("correlate_persons matches cor.test person by person", {
  set.seed(2)
  n <- 30L
  d <- data.frame(id = rep(c("p1", "p2"), each = n), a = stats::rnorm(2 * n),
                  stringsAsFactors = FALSE)
  d$b <- ifelse(d$id == "p1", 0.8, -0.6) * d$a + stats::rnorm(2 * n, sd = 0.6)

  out <- correlate_persons(d, "id", vars = c("a", "b"))
  expect_equal(nrow(out), 2L)
  for (who in c("p1", "p2")) {
    truth <- stats::cor.test(d$a[d$id == who], d$b[d$id == who])
    row <- out[out$subject == who, ]
    expect_equal(row$r, unname(truth$estimate))
    expect_equal(row$p_value, truth$p.value)
    expect_equal(row$conf_low, truth$conf.int[1L], tolerance = 1e-6)
    expect_equal(row$conf_high, truth$conf.int[2L], tolerance = 1e-6)
  }
  # The two people genuinely disagree in sign.
  expect_gt(out$r[out$subject == "p1"], 0)
  expect_lt(out$r[out$subject == "p2"], 0)
})

test_that("a person-specific correlation is already a within-person one", {
  # Correlation is invariant to shifting location, so person-centering the
  # data first must not move these numbers -- while the POOLED correlation
  # can differ completely, which is the point.
  set.seed(5)
  n_id <- 12L
  n_time <- 25L
  person <- rep(seq_len(n_id), each = n_time)
  level <- stats::rnorm(n_id, sd = 5)[person]
  d <- data.frame(id = person, day = rep(seq_len(n_time), n_id),
                  a = level + stats::rnorm(n_id * n_time))
  d$b <- -level + 0.9 * (d$a - level) + stats::rnorm(n_id * n_time, sd = 0.3)

  raw <- correlate_persons(d, "id", vars = c("a", "b"))
  centered <- correlate_persons(
    preprocess_panel(d, id = "id", vars = c("a", "b"), center = "person"),
    "id", vars = c("a", "b"))
  expect_equal(centered$r, raw$r, tolerance = 1e-8)

  # Within each person the association is positive; pooled it is negative.
  expect_true(all(raw$r > 0))
  expect_lt(stats::cor(d$a, d$b), 0)
})

test_that("descriptive verbs validate their inputs", {
  d <- drift_vs_oscillate()
  expect_error(describe_persons(d, "nope", vars = "v"), "`id` must be one")
  expect_error(correlate_persons(d, "id", vars = "v"),
               "at least two columns")
  expect_error(correlate_persons(d, "id", vars = "v", conf_level = 2),
               "`conf_level` must be")
  expect_output(print(describe_persons(d, "id", vars = "v")),
                "PERSON DESCRIPTIVES")
  expect_output(print(correlate_persons(drift_vs_oscillate(), "id")),
                "PERSON-SPECIFIC CORRELATIONS")
})

test_that("filtering and sorting happen in arguments, never in brackets", {
  # A person can be asked for by name rather than sliced out of the result.
  one <- describe_persons(srl, "name", time = "day", subject = "Aisha")
  expect_equal(unique(one$subject), "Aisha")
  expect_equal(nrow(one), 9L)                       # all nine measures

  several <- describe_persons(srl, "name", time = "day",
                              subject = c("Aisha", "Bob"))
  expect_setequal(unique(several$subject), c("Aisha", "Bob"))
  expect_error(describe_persons(srl, "name", subject = "Nobody"),
               "No such person")

  # Variable, sort and truncation are arguments too.
  top <- describe_persons(srl, "name", time = "day", variable = "effort",
                          sort_by = "rmssd", decreasing = TRUE, n = 5L)
  expect_equal(nrow(top), 5L)
  expect_equal(unique(top$variable), "effort")
  expect_true(!is.unsorted(rev(top$rmssd)))         # genuinely sorted
  expect_error(describe_persons(srl, "name", sort_by = "nope"),
               "`sort_by` must name one column")
  expect_error(describe_persons(srl, "name", variable = "nope"),
               "No such variable")

  # `id` is positional, so the common call needs no argument names at all.
  expect_equal(nrow(describe_persons(srl, "name", vars = "effort")), 36L)

  # The same arguments work on the correlation verb.
  pair <- correlate_persons(srl, "name", vars = c("effort", "efficacy"),
                            subject = "Aisha")
  expect_equal(nrow(pair), 1L)
  expect_equal(pair$subject, "Aisha")
  strongest <- correlate_persons(srl, "name", vars = c("effort", "efficacy"),
                                 sort_by = "r", decreasing = TRUE, n = 3L)
  expect_equal(nrow(strongest), 3L)
  expect_true(!is.unsorted(rev(strongest$r)))
})

test_that("detail = 'full' exposes bounds, shape and trend", {
  d <- drift_vs_oscillate()
  basic <- describe_persons(d, "id", vars = "v", time = "day")
  full <- describe_persons(d, "id", vars = "v", time = "day", detail = "full")

  extra <- c("p_floor", "p_ceiling", "skew", "kurtosis", "trend", "trend_p",
             "longest_run")
  expect_false(any(extra %in% names(basic)))
  expect_true(all(extra %in% names(full)))
  # The basic columns are untouched by asking for more.
  expect_equal(full$sd, basic$sd)
  expect_equal(full$rmssd, basic$rmssd)

  # The drifter has a real linear trend; the oscillator does not.
  expect_lt(full$trend_p[full$subject == "drifter"], 0.001)
  expect_gt(full$trend_p[full$subject == "oscillator"], 0.05)
  expect_gt(full$trend[full$subject == "drifter"], 1)
})

test_that("floor and ceiling are measured against the scale, not the person", {
  # Someone pinned at the bottom must not look like they span the range just
  # because their own min and max are all they have.
  d <- data.frame(
    id = rep(c("stuck", "roaming"), each = 20L),
    day = rep(seq_len(20L), 2L),
    v = c(rep(0, 18L), 5, 10, seq(0, 100, length.out = 20L)),
    stringsAsFactors = FALSE)
  out <- describe_persons(d, "id", vars = "v", time = "day", detail = "full")
  stuck <- out[out$subject == "stuck", ]
  roaming <- out[out$subject == "roaming", ]

  expect_equal(stuck$p_floor, 0.9)
  expect_equal(stuck$p_ceiling, 0)          # never reaches the SCALE ceiling
  expect_lt(roaming$p_floor, 0.1)
  expect_gt(roaming$p_ceiling, 0)

  # Straightlining shows up as a long run of identical values.
  expect_equal(stuck$longest_run, 18L)
  expect_equal(roaming$longest_run, 1L)
})

test_that("skew and kurtosis match their textbook definitions", {
  set.seed(7)
  v <- c(stats::rexp(60), 20)                 # deliberately skewed
  d <- data.frame(id = "a", day = seq_along(v), v = v,
                  stringsAsFactors = FALSE)
  out <- describe_persons(d, "id", vars = "v", time = "day", detail = "full")

  centred <- v - mean(v)
  spread <- sqrt(sum(centred^2) / length(v))
  expect_equal(out$skew, sum(centred^3) / length(v) / spread^3)
  expect_equal(out$kurtosis, sum(centred^4) / length(v) / spread^4 - 3)
  expect_gt(out$skew, 1)
})

test_that("pac counts how OFTEN change is large, rmssd how large it is", {
  # Same overall volatility, opposite shapes: one person has four enormous
  # swings among calm days, the other is uniformly jumpy. rmssd squares, so the
  # explosive person wins on it; pac counts, so the jumpy person wins on that.
  set.seed(3)
  n <- 200L
  d <- data.frame(
    id = rep(c("explosive", "jumpy"), each = n),
    day = rep(seq_len(n), 2L),
    v = c(c(stats::rnorm(n - 4L, sd = 1), 40, -40, 40, -40),
          stats::rnorm(n, sd = 5.9)),
    stringsAsFactors = FALSE)

  out <- describe_persons(d, "id", vars = "v", time = "day", detail = "full")
  explosive <- out[out$subject == "explosive", ]
  jumpy <- out[out$subject == "jumpy", ]

  expect_gt(explosive$rmssd, jumpy$rmssd)     # bigger changes ...
  expect_lt(explosive$pac, jumpy$pac)         # ... but far rarer
})

test_that("the acute-change cutoff is a property of the whole sample", {
  # By construction the cutoff is the 90th percentile of everyone's successive
  # changes, so across the sample about 10% of changes must clear it.
  out <- describe_persons(srl, "name", time = "day", variable = "effort",
                          detail = "full")
  weights <- out$n - 1L
  expect_equal(sum(out$pac * weights) / sum(weights), 0.1, tolerance = 0.02)

  # A different quantile moves it in the expected direction.
  loose <- describe_persons(srl, "name", time = "day", variable = "effort",
                            detail = "full", pac_quantile = 0.75)
  expect_gt(mean(loose$pac), mean(out$pac))

  # Asking about ONE person must not redefine what "acute" means: the cutoff
  # comes from everyone, so their pac is unchanged by the filter.
  alone <- describe_persons(srl, "name", time = "day", variable = "effort",
                            detail = "full", subject = "Aisha")
  expect_equal(alone$pac, out$pac[out$subject == "Aisha"])

  # An explicit cutoff makes pac comparable across datasets, and a higher bar
  # can only ever be cleared less often.
  low <- describe_persons(srl, "name", time = "day", variable = "effort",
                          detail = "full", pac_cutoff = 20)
  high <- describe_persons(srl, "name", time = "day", variable = "effort",
                           detail = "full", pac_cutoff = 60)
  expect_true(all(high$pac <= low$pac))
  expect_gt(mean(low$pac), mean(high$pac))
  expect_error(describe_persons(srl, "name", detail = "full",
                                pac_quantile = 2),
               "`pac_quantile` must be")
})

test_that("pac direction distinguishes rises from falls", {
  # A sawtooth that climbs slowly and drops sharply: large FALLS are common,
  # large RISES are not.
  v <- as.numeric(rep(c(1, 2, 3, 4, 5, -20), times = 20L))
  d <- data.frame(id = "a", day = seq_along(v), v = v, stringsAsFactors = FALSE)
  up <- describe_persons(d, "id", vars = "v", time = "day", detail = "full",
                         pac_direction = "increase")$pac
  down <- describe_persons(d, "id", vars = "v", time = "day", detail = "full",
                           pac_direction = "decrease")$pac
  expect_lt(up, down)
})

test_that("a subsetted result prints as the data frame it has become", {
  # `[.data.frame` keeps the class but drops columns and attributes, so the
  # structured print method must fall back rather than fail.
  out <- describe_persons(srl, "name", time = "day", variable = "effort",
                          detail = "full")
  expect_output(print(out[, c("subject", "sd", "rmssd", "pac")]), "explosive|Aisha|subject")
  expect_silent(invisible(capture.output(print(out[0, ]))))
})
