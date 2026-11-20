# test_subgroups(): Gaussian mixtures of the standardised person coefficients, k = 1..k_max under six covariance
# models, ranked by BIC; against mclust::mclustBIC() (Scrucca, Fop, Murphy & Raftery, 2016) on the same
# coefficients. find_subgroups(): partitions people; its clustering starts and its resamples are drawn inside the
# function, so it is checked by PROPERTIES that hold for any draw on a panel with a planted, well-separated
# partition.

predictors <- c("efficacy", "planning")

#' Each learner's least-squares coefficients of effort on the predictors, standardised over learners
person_coefficients <- function(data) {
  slopes <- t(vapply(split(data, data$name), \(person) {
    stats::coef(stats::lm(effort ~ efficacy + planning, data = person))[predictors]
  }, numeric(2)))
  scale(slopes)
}

#' mclust's log-likelihood, parameter count and BIC (on the -2 log L + npar log n scale) of one mixture,
#' with EM run to a relative change of 1e-12
mclust_fit <- function(coefficients, k, model) {
  bic <- mclust::mclustBIC(coefficients, G = k, modelNames = model, verbose = FALSE,
                           control = mclust::emControl(tol = c(1e-12, 1e-12), itmax = c(1e5, 1e5)))
  npar <- mclust::nMclustParams(model, ncol(coefficients), k)
  data.frame(k = k, model = model, loglik = (bic[1L, 1L] + npar * log(nrow(coefficients))) / 2, npar = npar,
             bic = -bic[1L, 1L])
}

test_that("the mixture log-likelihoods of one and two groups equal mclust's", {
  skip_without_reference("mclust")
  data <- srl[stats::complete.cases(srl[c("effort", predictors)]), ]
  test <- test_subgroups(data, y = "effort", x = predictors, id = "name")
  coefficients <- person_coefficients(data)
  diagonal <- c("EII", "VII", "EEI", "VVI")
  one <- do.call(rbind, lapply(diagonal, \(model) mclust_fit(coefficients, 1L, model)))
  # One group: the closed-form Gaussian maximum likelihood on both sides, rounding only.
  expect_reference(subset(as.data.frame(test), k == 1L & model %in% diagonal), one, reference = "mclust",
                   covers = c("test_subgroups()", "as.data.frame.idiographic_subgroup_test()",
                              "as.data.frame.idiostats_subgroup_test()"),
                   quantity = "36 learners, one group, diagonal covariance models", tolerance = 1e-10,
                   key = c("k", "model"),
                   note = "as.data.frame.idiographic_subgroup_test() is the same function object as as.data.frame.idiostats_subgroup_test().")
  two <- do.call(rbind, lapply(diagonal, \(model) mclust_fit(coefficients, 2L, model)))
  # Two groups: EM on both sides; idiographic stops when the log-likelihood changes by less than 1e-6, which
  # leaves it a few 1e-6 below the maximum mclust reaches at 1e-12. 1e-5.
  expect_reference(subset(as.data.frame(test), k == 2L & model %in% diagonal), two, reference = "mclust",
                   covers = "test_subgroups()", quantity = "36 learners, two groups, diagonal covariance models",
                   tolerance = 1e-5, key = c("k", "model"))
  full <- do.call(rbind, lapply(c("EEE", "VVV"), \(model) mclust_fit(coefficients, 1L, model)))
  expect_known_difference(subset(as.data.frame(test), k == 1L & model %in% c("EEE", "VVV"), select = c(k, model, loglik)),
                          subset(full, select = c(k, model, loglik)), reference = "mclust",
                          covers = "test_subgroups()", quantity = "36 learners, one group, full covariance models",
                          tolerance = 1e-10, key = c("k", "model"),
                          reason = "test_subgroups() adds a ridge of 1e-4 times the mean coefficient variance to a full covariance matrix (EEE, VVV); mclust estimates it without one. The log-likelihood is 3.5e-7 lower here.")
})

#' A panel of 20 people, 40 days: people 1-10 have slope +1 of y on x, people 11-20 slope -1
planted_panel <- function() {
  set.seed(77)
  d <- data.frame(id = rep(1:20, each = 40), day = rep(1:40, 20), x = stats::rnorm(800))
  d$y <- ifelse(d$id <= 10, 1, -1) * d$x + stats::rnorm(800, sd = 0.3)
  d
}

#' Whether each person is put in the same subgroup as person 1, from a table of subject and subgroup
with_first <- function(table) {
  first <- table$subgroup[table$subject == "1"]
  data.frame(subject = table$subject, with_first = table$subgroup == first, stability = table$stability)
}

test_that("find_subgroups() recovers a planted partition for any draw (Monte Carlo summary)", {
  data <- planted_panel()
  planted <- data.frame(subject = as.character(1:20), with_first = 1:20 <= 10, stability = 1)
  # Seed study (2026-11-20, seeds 1-20): both methods recovered the planted partition with stability 1 for every
  # person on 20 of 20 seeds, and every mixture posterior was 1 to machine precision.
  invisible(lapply(1:3, \(seed) {
    set.seed(seed)
    clustered <- find_subgroups(data, y = "y", x = "x", id = "id", k = 2, reps = 20)
    expect_reference(with_first(groups(clustered)), planted,
                     reference = "independent: the planted partition of the simulated panel",
                     covers = c("find_subgroups()", "groups.idiographic_groups()", "groups.idiostats_groups()"),
                     quantity = sprintf("Monte Carlo summary: effect clustering, membership and stability, seed %d", seed),
                     tolerance = 0, key = "subject",
                     note = "A property that holds for any draw on this panel: the groups are separated by slopes +1 and -1.")
    set.seed(seed)
    mixture <- find_subgroups(data, y = "y", x = "x", id = "id", method = "mixture_regression", k = 2, reps = 10)
    expect_reference(with_first(as.data.frame(mixture)), planted,
                     reference = "independent: the planted partition of the simulated panel",
                     covers = c("find_subgroups()", "as.data.frame.idiographic_groups()",
                                "as.data.frame.idiostats_groups()"),
                     quantity = sprintf("Monte Carlo summary: mixture regression, membership and stability, seed %d", seed),
                     tolerance = 0, key = "subject")
  }))
})
