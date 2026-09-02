# Meta-analytic pooling exists to separate REAL between-person spread from
# estimation error, so every test plants a known tau and checks that the two
# are told apart.

pool_panel <- function(seed = 4L, tau = 0.30, n_id = 40L, n_time = 25L,
                       noise = 1) {
  set.seed(seed)
  person <- rep(seq_len(n_id), each = n_time)
  beta <- stats::rnorm(n_id, mean = 1, sd = tau)[person]
  d <- data.frame(id = person, day = rep(seq_len(n_time), n_id),
                  x = stats::rnorm(n_id * n_time), stringsAsFactors = FALSE)
  d$y <- beta * d$x + stats::rnorm(n_id * n_time, sd = noise)
  d
}

pooled_slope <- function(d) {
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "day",
                scope = "individual")
  pool_coefs(fit, term = "x")
}

test_that("tau recovers the true between-person spread", {
  out <- pooled_slope(pool_panel(tau = 0.30))
  expect_equal(nrow(out), 1L)
  expect_lt(abs(out$tau - 0.30), 0.08)
  expect_lt(abs(out$estimate - 1), 0.15)
  # Deliberately NOT asserting that this one interval covers 1: coverage is a
  # property of the procedure across replications, not of a single seed, and
  # at 94% one draw in sixteen will miss. It is verified by simulation instead.
  expect_lt(out$conf_low, out$conf_high)

  # The observed spread is LARGER than the real one, because it also contains
  # each person's estimation error. That gap is the whole point of the verb.
  expect_gt(out$sd_observed, out$tau)
  expect_gt(out$i2, 0.4)

  # A larger planted tau is recovered as larger.
  bigger <- pooled_slope(pool_panel(seed = 5L, tau = 0.60))
  expect_gt(bigger$tau, out$tau)
  expect_lt(abs(bigger$tau - 0.60), 0.15)
})

test_that("apparent spread with no real heterogeneity is called noise", {
  # Every person has the SAME slope of 1. Their estimates still scatter,
  # entirely from estimation error, and `tau` must stay near zero while
  # `sd_observed` does not.
  out <- pooled_slope(pool_panel(tau = 0))
  expect_gt(out$sd_observed, 0.1)          # visible spread ...
  expect_lt(out$tau, 0.15)                 # ... almost none of it real
  expect_lt(out$tau, out$sd_observed / 2)
  expect_lt(abs(out$estimate - 1), 0.15)
})

test_that("shrinkage pulls noisy people in and leaves well-measured ones", {
  d <- pool_panel(tau = 0.30)
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "day",
                scope = "individual")
  sh <- shrink_coefs(fit, term = "x")

  expect_equal(nrow(sh), length(unique(d$id)))
  expect_true(all(sh$weight >= 0 & sh$weight <= 1))
  # Every shrunken estimate lies between the raw one and the pooled effect.
  pooled <- pool_coefs(fit, term = "x")$estimate
  expect_true(all(sh$shrunken >= pmin(sh$estimate, pooled) - 1e-8 &
                    sh$shrunken <= pmax(sh$estimate, pooled) + 1e-8))
  # Shrunken estimates are less spread out than the raw ones, which is the
  # correction for the estimation error the raw spread contains.
  expect_lt(stats::sd(sh$shrunken), stats::sd(sh$estimate))
  # The worse a person is measured, the harder they are pulled in.
  expect_lt(stats::cor(sh$std_error, sh$weight), 0)
})

test_that("with no real heterogeneity everyone shrinks to the pooled effect", {
  d <- pool_panel(tau = 0, n_id = 15L, n_time = 60L)
  fit <- fit_lm(d, y = "y", x = "x", id = "id", time = "day",
                scope = "individual")
  sh <- shrink_coefs(fit, term = "x")
  pooled <- pool_coefs(fit, term = "x")
  # tau near zero means each person's own estimate carries little weight.
  expect_lt(mean(sh$weight), 0.5)
  expect_lt(stats::sd(sh$shrunken), stats::sd(sh$estimate) / 2)
  expect_true(all(abs(sh$shrunken - pooled$estimate) <
                    abs(sh$estimate - pooled$estimate) + 1e-8))
})

test_that("pooling refuses fits that cannot support it", {
  d <- pool_panel()
  # fit_ml reports no standard errors, so pooling would silently treat every
  # person as equally well measured.
  ml <- fit_ml(d, y = "y", x = "x", id = "id", model = "linear",
               scope = "individual")
  expect_error(pool_coefs(ml), "standard errors")

  # Pooling is across people, so a pooled-only fit has nothing to pool.
  only_pooled <- fit_lm(d, y = "y", x = "x", id = "id", scope = "pooled")
  expect_error(pool_coefs(only_pooled), "scope = \\\"individual\\\"")
  expect_error(pool_coefs(d), "must be an idiostats fit")
})

test_that("pooled output keeps a readable shape", {
  fit <- fit_lm(pool_panel(), y = "y", x = "x", id = "id", time = "day",
                scope = "individual")
  out <- pool_coefs(fit)
  expect_s3_class(out, "idiostats_pooled")
  expect_true(all(c("term", "k", "estimate", "std_error", "conf_low",
                    "conf_high", "p_value", "tau", "i2", "q", "q_p",
                    "sd_observed") %in% names(out)))
  expect_output(print(out), "POOLED PERSON EFFECTS")
  expect_output(print(shrink_coefs(fit)), "SHRUNKEN PERSON EFFECTS")

  # The Hartung-Knapp interval can only be wider than the textbook one.
  meta <- .idio_meta(c(1, 1.4, 0.7, 1.2), c(0.2, 0.25, 0.3, 0.2), 0.95)
  expect_gte(meta$se, meta$se_naive)
})
