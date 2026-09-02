# A mixture of regressions must recover planted classes of PEOPLE, agree with
# an independent implementation, and -- most importantly -- not be trusted to
# choose k, because its BIC over-extracts on continuous heterogeneity.

class_panel <- function(seed = 3L, slopes = c(1, -1.5), sizes = c(45L, 15L),
                        n_time = 25L, noise = 0.7) {
  set.seed(seed)
  n_id <- sum(sizes)
  cls <- rep(seq_along(sizes), times = sizes)
  person <- rep(seq_len(n_id), each = n_time)
  d <- data.frame(id = person, day = rep(seq_len(n_time), n_id),
                  x = stats::rnorm(n_id * n_time), stringsAsFactors = FALSE)
  d$y <- slopes[cls][person] * d$x + stats::rnorm(n_id * n_time, sd = noise)
  attr(d, "truth") <- cls
  d
}

test_that("mixture_regression recovers planted classes of people", {
  d <- class_panel()
  g <- find_subgroups(d, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = 2, reps = 10)
  tab <- groups(g)
  assigned <- tab$subgroup[match(as.character(seq_along(attr(d, "truth"))),
                                 tab$subject)]
  agreement <- table(attr(d, "truth"), assigned)
  # Perfect recovery, up to the arbitrary labelling of the components.
  expect_equal(sum(apply(agreement, 1L, max)), length(attr(d, "truth")))

  # The component regressions recover both slopes.
  comp <- g$mixture$components
  slopes <- sort(comp$estimate[comp$term == "x"])
  expect_lt(abs(slopes[1L] - (-1.5)), 0.2)
  expect_lt(abs(slopes[2L] - 1), 0.2)

  # A mixture states how sure it is of each assignment.
  expect_true("posterior" %in% names(tab))
  expect_true(all(tab$posterior >= 0.5 & tab$posterior <= 1))
  expect_gt(mean(tab$posterior), 0.95)
})

test_that("mixture_regression matches flexmix", {
  skip_if_not_installed("flexmix")
  d <- class_panel()
  d$id <- factor(d$id)

  set.seed(1)
  fx <- flexmix::flexmix(y ~ x | id, k = 2, data = d)
  g <- find_subgroups(d, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = 2, reps = 2)

  # Read the slots rather than logLik()/BIC(): those are S4 methods that only
  # dispatch once flexmix is attached, and the slots are what they return.
  expect_lt(abs(g$mixture$loglik - fx@logLik), 0.01)
  expect_equal(g$mixture$n_par, fx@df)     # same parameter count, so BIC is
  expect_lt(abs(g$mixture$bic -            # comparable term for term
                  (-2 * fx@logLik + fx@df * log(nrow(d)))), 0.01)

  # And the same people end up together.
  fx_person <- as.integer(tapply(flexmix::clusters(fx), d$id,
                                 function(z) z[1L]))
  tab <- groups(g)
  mine <- as.integer(factor(tab$subgroup[match(levels(d$id), tab$subject)]))
  agreement <- max(mean(mine == fx_person), mean(mine != fx_person))
  expect_equal(agreement, 1)
})

test_that("mixture_regression places people an individual fit cannot", {
  # Two occasions is too few for a person-specific regression with an
  # intercept and a slope, but the mixture pools within components.
  d <- class_panel()
  short <- do.call(rbind, lapply(split(d, d$id), function(z) z[1:2, ]))
  short <- rbind(d[d$id <= 40, ], short[short$id > 40, ])

  g <- find_subgroups(short, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = 2, reps = 5)
  expect_equal(nrow(groups(g)), length(unique(short$id)))
  expect_true(all(is.finite(groups(g)$posterior)))
})

test_that("the mixture's own BIC is reported but never chooses k", {
  # THE point of this test. On data with no subgroups -- one population whose
  # slopes merely vary continuously -- the mixture BIC prefers two components,
  # while test_subgroups() correctly answers one population.
  set.seed(9)
  n_id <- 60L
  n_time <- 25L
  person <- rep(seq_len(n_id), each = n_time)
  slopes <- stats::rnorm(n_id, mean = 1, sd = 0.25)[person]
  d <- data.frame(id = person, x = stats::rnorm(n_id * n_time))
  d$y <- slopes * d$x + stats::rnorm(n_id * n_time, sd = 0.7)

  subjects <- sort(unique(as.character(d$id)))
  bic <- .idio_mixreg_sweep(d, "y", "x", "id", subjects, 4L)
  expect_gt(bic$k, 1L)                       # the mixture over-extracts ...
  expect_equal(test_subgroups(d, "y", "x", "id", k_max = 4L)$k, 1L)  # ... this does not

  # So k = "auto" must follow test_subgroups(), and warn.
  expect_warning(
    g <- find_subgroups(d, y = "y", x = "x", id = "id",
                        method = "mixture_regression", k = "auto",
                        k_max = 4L, reps = 3),
    "No subgroups detected")
  expect_equal(g$spec$k, 1L)

  # The mixture's BIC table is still reported, for comparison only.
  expect_true(is.data.frame(g$mixture_bic))
  expect_true(all(c("k", "loglik", "bic") %in% names(g$mixture_bic)))
})

test_that("mixture_regression still finds real classes under k = auto", {
  d <- class_panel()
  g <- find_subgroups(d, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = "auto", k_max = 4L,
                      reps = 3)
  expect_equal(g$spec$k, 2L)
  expect_equal(length(unique(groups(g)$subgroup)), 2L)
})

test_that("mixture_regression feeds fit_subgroups like any other method", {
  d <- class_panel()
  g <- find_subgroups(d, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = 2, reps = 5)
  fit <- fit_subgroups(d, y = "y", x = "x", id = "id", subgroup = g)
  expect_s3_class(fit, "idiostats_fit")
  expect_true(all(c("pooled", "subgroup", "individual") %in%
                    unique(metrics(fit)$scope)))
  # Subgroup models beat the pooled model, because the classes are real.
  overall <- metrics(fit, overall = TRUE)
  pooled_rmse <- overall$rmse[overall$scope == "pooled"]
  sub_rmse <- overall$rmse[overall$scope == "subgroup"]
  expect_lt(sub_rmse, pooled_rmse)
})

test_that("an EM run that only ran out of iterations is not called converged", {
  d <- class_panel()
  g <- find_subgroups(d, y = "y", x = "x", id = "id",
                      method = "mixture_regression", k = 2, reps = 3)
  expect_true(g$mixture$converged)
  expect_lt(g$mixture$iterations, 300L)

  # Forced to stop after one iteration, it must say so rather than present the
  # unfinished assignments as a solution.
  subjects <- sort(unique(as.character(d$id)))
  expect_warning(
    stopped <- .idio_mixreg(d, "y", "x", "id", subjects, k = 2L, maxit = 1L),
    "hit `maxit`")
  expect_false(stopped$converged)
})
