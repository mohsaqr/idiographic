# fit_within_between() and what is read from it (coefs(), variance_components(), contextual()): effort regressed
# on the within-person and between-person components of efficacy (Curran & Bauer, 2011), on each learner's
# estimation rows (all but the last ceiling(0.2 n) days), the person means taken over those rows.
#
# The mixed model (estimator = "reml") is fitted inside the package with lme4, so lme4's own fit is declared
# `internal`: it checks the estimation sample, the person means and the design, not the estimation. The
# separate evidence is nlme::lme() (Pinheiro & Bates), a different REML implementation, and, for the
# least-squares estimator, the cluster-robust sandwich written from its definition.

held_out <- 0.2

#' The estimation rows of 36 learners with efficacy split into its person mean and the deviation from it
within_between_rows <- function() {
  ordered <- srl[order(srl$name, srl$day), ]
  train <- do.call(rbind, lapply(split(ordered, ordered$name), \(person) {
    utils::head(person, nrow(person) - ceiling(held_out * nrow(person)))
  }))
  train <- train[stats::complete.cases(train[c("effort", "efficacy")]), ]
  train$efficacy_between <- stats::ave(train$efficacy, train$name)
  train$efficacy_within <- train$efficacy - train$efficacy_between
  train
}

#' A fixed-effects table shaped as coefs() shapes it, with intervals and p-values on t with G - 1 degrees of
#' freedom (G learners), the package's documented convention
fixed_rows <- function(estimate, std_error, clusters) {
  critical <- stats::qt(0.975, df = clusters - 1L)
  data.frame(term = names(estimate), estimate = unname(estimate), std_error = unname(std_error),
             statistic = unname(estimate / std_error),
             p_value = unname(2 * stats::pt(-abs(estimate / std_error), df = clusters - 1L)),
             conf_low = unname(estimate - critical * std_error), conf_high = unname(estimate + critical * std_error))
}

test_that("REML random-intercept model: fixed effects and variance components against nlme", {
  skip_without_reference("nlme")
  fit <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name", time = "day", model = "within_between",
                            estimator = "reml", test_prop = held_out)
  train <- within_between_rows()
  reference <- nlme::lme(effort ~ efficacy_within + efficacy_between, random = ~ 1 | name, data = train,
                         method = "REML", control = nlme::lmeControl(tolerance = 1e-10, msTol = 1e-10))
  estimate <- nlme::fixef(reference)
  std_error <- sqrt(diag(stats::vcov(reference)))
  clusters <- length(unique(train$name))
  # Two optimisers (lme4's over the relative covariance factor, nlme's over log standard deviations) stop at
  # their own convergence criteria on the same REML surface; 1e-5 relative is well inside one standard error
  # and well outside rounding.
  expect_reference(coefs(fit), fixed_rows(estimate, std_error, clusters), reference = "nlme",
                   covers = c("fit_within_between()", "coefs.idiographic_fit()"),
                   quantity = "within and between effects of efficacy", tolerance = 1e-5, measure = "relative",
                   key = "term", note = "Intervals and p-values on t with G - 1 = 35 degrees of freedom, as documented; nlme's own p-values use other degrees of freedom and are not compared.")
  variances <- c(name = as.numeric(nlme::getVarCov(reference)), Residual = reference$sigma^2)
  expect_reference(variance_components(fit),
                   data.frame(level = names(variances), variance = variances, sd = sqrt(variances),
                              icc = variances / sum(variances)),
                   reference = "nlme",
                   covers = c("variance_components()", "variance_components.idiographic_wb()",
                              "variance_components.idiostats_wb()"),
                   quantity = "variance components", tolerance = 1e-5, measure = "relative", key = "level",
                   note = "variance_components.idiostats_wb() is the same function object as variance_components.idiographic_wb().")
  covariance <- stats::vcov(reference)
  contextual_effect <- estimate[["efficacy_between"]] - estimate[["efficacy_within"]]
  contextual_se <- sqrt(covariance["efficacy_between", "efficacy_between"] + covariance["efficacy_within", "efficacy_within"] -
                          2 * covariance["efficacy_between", "efficacy_within"])
  critical <- stats::qt(0.975, df = clusters - 1L)
  expect_reference(contextual(fit),
                   data.frame(variable = "efficacy", within = estimate[["efficacy_within"]],
                              between = estimate[["efficacy_between"]], contextual = contextual_effect,
                              std_error = contextual_se, statistic = contextual_effect / contextual_se,
                              p_value = 2 * stats::pt(-abs(contextual_effect / contextual_se), df = clusters - 1L),
                              conf_low = contextual_effect - critical * contextual_se,
                              conf_high = contextual_effect + critical * contextual_se),
                   reference = "nlme", covers = c("contextual()", "contextual.idiographic_wb()", "contextual.idiostats_wb()"),
                   quantity = "contextual effect, between minus within", tolerance = 1e-5, measure = "relative",
                   key = "variable",
                   note = "contextual.idiostats_wb() is the same function object as contextual.idiographic_wb().")
})

test_that("REML random-intercept model against lme4, the package's own engine (internal)", {
  skip_without_reference("lme4")
  fit <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name", time = "day", model = "within_between",
                            estimator = "reml", test_prop = held_out)
  train <- within_between_rows()
  reference <- lme4::lmer(effort ~ efficacy_within + efficacy_between + (1 | name), data = train, REML = TRUE)
  fixed <- stats::coef(summary(reference))
  variances <- as.data.frame(lme4::VarCorr(reference))
  # The same lme4 fit on both sides; the optimiser's path is the only freedom. 1e-6 absolute on values from
  # 0.01 to about 450.
  expect_reference(coefs(fit), data.frame(term = rownames(fixed), estimate = fixed[, "Estimate"],
                                          std_error = fixed[, "Std. Error"]),
                   reference = "lme4", covers = "fit_within_between()", quantity = "fixed effects, lme4",
                   tolerance = 1e-6, key = "term")
  expect_reference(variance_components(fit), data.frame(level = variances$grp, variance = variances$vcov),
                   reference = "lme4", covers = "variance_components()", quantity = "variance components, lme4",
                   tolerance = 1e-6, key = "level")
})

test_that("least squares with standard errors clustered on the learner", {
  fit <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name", time = "day", model = "within_between",
                            estimator = "ols", test_prop = held_out)
  train <- within_between_rows()
  ols <- stats::lm(effort ~ efficacy_within + efficacy_between, data = train)
  # The CR1 sandwich (Liang & Zeger, 1986) with the small-sample factor G / (G - 1) (Cameron & Miller, 2015).
  X <- stats::model.matrix(ols)
  bread <- solve(crossprod(X))
  scores <- rowsum(X * stats::residuals(ols), train$name)
  clusters <- nrow(scores)
  covariance <- bread %*% crossprod(scores) %*% bread * clusters / (clusters - 1)
  expect_reference(coefs(fit), fixed_rows(stats::coef(ols), sqrt(diag(covariance)), clusters),
                   reference = "independent: least squares with the CR1 cluster-robust sandwich",
                   covers = c("fit_within_between()", "coefs.idiographic_fit()"),
                   quantity = "within and between effects of efficacy, least squares", tolerance = 1e-10, key = "term")
})

test_that("variance components of a variable: the one-way ANOVA estimators and REML", {
  skip_without_reference("nlme")
  two <- c("efficacy", "effort")
  # One-way random-effects ANOVA (Searle, Casella & McCulloch, 1992): the within variance is MSW, the between
  # variance (MSB - MSW) / n0 with n0 = (N - sum n_i^2 / N) / (k - 1), floored at zero; the reliability of a
  # person mean is (MSB - MSW) / MSB, ICC(1, k).
  anova_row <- function(variable) {
    rows <- srl[!is.na(srl[[variable]]), ]
    groups <- split(rows[[variable]], rows$name)
    n <- nrow(rows)
    k <- length(groups)
    sizes <- lengths(groups)
    means <- vapply(groups, mean, numeric(1))
    ms_between <- sum(sizes * (means - mean(rows[[variable]]))^2) / (k - 1)
    ms_within <- sum(vapply(groups, \(g) sum((g - mean(g))^2), numeric(1))) / (n - k)
    n0 <- (n - sum(sizes^2) / n) / (k - 1)
    between <- max(0, (ms_between - ms_within) / n0)
    data.frame(variable = variable, n = n, people = k, var_within = ms_within, var_between = between,
               var_total = ms_within + between, icc = between / (ms_within + between),
               reliability = (ms_between - ms_within) / ms_between)
  }
  expect_reference(variance_components(srl, id = "name", vars = two), do.call(rbind, lapply(two, anova_row)),
                   reference = "independent: one-way random-effects ANOVA estimators", covers = "variance_components.data.frame()",
                   quantity = "efficacy and effort over 36 learners, ANOVA", tolerance = 1e-10, key = "variable")
  reml_row <- function(variable) {
    rows <- srl[!is.na(srl[[variable]]), ]
    model <- nlme::lme(stats::reformulate("1", response = variable), random = ~ 1 | name, data = rows, method = "REML",
                       control = nlme::lmeControl(tolerance = 1e-10, msTol = 1e-10))
    between <- as.numeric(nlme::getVarCov(model))
    within <- model$sigma^2
    n_bar <- nrow(rows) / length(unique(rows$name))
    data.frame(variable = variable, var_within = within, var_between = between, var_total = within + between,
               icc = between / (within + between), reliability = between / (between + within / n_bar))
  }
  # Two REML optimisers (lme4 inside the package, nlme here) stop at their own criteria: 1e-5 relative, as above.
  expect_reference(variance_components(srl, id = "name", vars = two, method = "reml"), do.call(rbind, lapply(two, reml_row)),
                   reference = "nlme", covers = "variance_components.data.frame()",
                   quantity = "efficacy and effort over 36 learners, REML", tolerance = 1e-5, measure = "relative",
                   key = "variable")
})
