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
  # One group, full covariances: the unpenalised Gaussian maximum likelihood on both sides (no ridge since 0.4.0.9009).
  expect_reference(subset(as.data.frame(test), k == 1L & model %in% c("EEE", "VVV"), select = c(k, model, loglik)),
                   subset(full, select = c(k, model, loglik)), reference = "mclust",
                   covers = "test_subgroups()", quantity = "36 learners, one group, full covariance models",
                   tolerance = 1e-10, key = c("k", "model"))
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

test_that("the partitions equal stats::kmeans() on the person slopes and flexmix's mixture of regressions", {
  data <- planted_panel()
  slopes <- vapply(split(data, data$id), \(person) stats::coef(stats::lm(y ~ x, data = person))[["x"]], numeric(1))
  invisible(lapply(1:3, \(seed) {
    set.seed(seed)
    clustered <- find_subgroups(data, y = "y", x = "x", id = "id", k = 2, reps = 20)
    set.seed(1000 + seed)
    # effect_clustering: k-means (10 starts) on the standardised person slopes, as documented.
    by_kmeans <- stats::kmeans(scale(slopes), centers = 2L, nstart = 10L, iter.max = 50L)$cluster
    kmeans_table <- data.frame(subject = names(slopes), subgroup = as.character(by_kmeans), stability = 1)
    expect_reference(with_first(groups(clustered)), with_first(kmeans_table), reference = "stats",
                     covers = c("find_subgroups()", "groups()", "groups.idiographic_groups()",
                                "groups.idiostats_groups()"),
                     quantity = sprintf("effect clustering against stats::kmeans(), membership, seed %d", seed),
                     tolerance = 0, key = "subject",
                     note = "Membership is compared as 'in the same subgroup as person 1', so the labels may differ; stability 1 is the planted partition's (test above).")
    # fit_subgroups() with the partition found: groups() of the fit is that partition.
    fit <- fit_subgroups(data, y = "y", x = "x", id = "id", subgroup = clustered, time = "day")
    expect_reference(with_first(transform(groups(fit), stability = 1)), with_first(kmeans_table), reference = "stats",
                     covers = c("groups()", "groups.idiographic_fit()", "groups.idiostats_fit()", "fit_subgroups()"),
                     quantity = sprintf("fit_subgroups() on the partition found, against stats::kmeans(), seed %d", seed),
                     tolerance = 0, key = "subject")
    set.seed(seed)
    mixture <- find_subgroups(data, y = "y", x = "x", id = "id", method = "mixture_regression", k = 2, reps = 10)
    set.seed(1000 + seed)
    # flexmix: a mixture of two linear regressions with the person as the grouping (y ~ x | id), best of 5 EM runs.
    reference <- flexmix::stepFlexmix(y ~ x | id, data = data, k = 2, nrep = 5, verbose = FALSE)
    posterior <- flexmix::posterior(reference)
    first_row <- !duplicated(data$id)
    flexmix_table <- data.frame(subject = as.character(data$id[first_row]),
                                subgroup = as.character(flexmix::clusters(reference)[first_row]),
                                posterior = apply(posterior[first_row, , drop = FALSE], 1L, max))
    expect_reference(with_first(transform(as.data.frame(mixture), stability = posterior)),
                     with_first(transform(flexmix_table, stability = posterior)), reference = "flexmix",
                     covers = c("find_subgroups()", "as.data.frame.idiographic_groups()",
                                "as.data.frame.idiostats_groups()"),
                     quantity = sprintf("mixture regression against flexmix, membership and posterior, seed %d", seed),
                     tolerance = 1e-8, key = "subject",
                     note = "The posterior of the assigned component is put in the stability column of both sides for the comparison.")
  }))
})
