# fit_effects() and effects(): treatment effects estimated on held-out rows (the last 30% of each person's
# occasions), written here from their definitions with stats::lm() and stats::glm() on the estimation rows.
#
# Binary treatment, AIPW (Robins, Rotnitzky & Zhao, 1994): one least-squares response surface per arm, a logistic
# propensity held in [0.05, 0.95]; per held-out row the doubly robust score m1 - m0 + A (Y - m1) / e -
# (1 - A) (Y - m0) / (1 - e). Dose, the partially linear score (Robinson, 1988; Chernozhukov et al., 2018): the
# held-out residuals ry of the outcome and rt of the dose on the predictors, theta = sum(rt ry) / sum(rt^2), score
# theta + rt (ry - theta rt) / mean(rt^2); the predicted effect is the least-squares fit of the training ry on
# rt (1, x). ATE / APE is the mean score; GATES the mean score in quarters of the predicted effect;
# top-bottom their difference; BLP the slope of the score on the centred predicted effect. Every standard error
# is the CR1 sandwich over people with the factor G / (G - 1), t on G - 1 degrees of freedom.
#
# The propensity is iteratively reweighted least squares on both sides: idiographic stops when no coefficient
# moves by 1e-6, which after the quadratic convergence of Newton's method leaves it ~1e-12 from the maximum;
# stats::glm() is run here to epsilon = 1e-14. 1e-8 covers both.

predictors <- c("x1", "x2")

#' The panel of the package's example: six people, 40 days, a drug that helps when x1 > 0, and a dose
effects_panel <- function() {
  set.seed(1)
  d <- data.frame(id = rep(1:6, each = 40), day = rep(1:40, 6), x1 = stats::rnorm(240), x2 = stats::rnorm(240))
  d$drug <- stats::rbinom(240, 1, 0.5)
  d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + stats::rnorm(240, sd = 0.5)
  d$dose <- round(stats::runif(240, 0, 10), 1)
  d$sleep <- 0.3 * d$dose + 0.5 * d$x1 + stats::rnorm(240, sd = 0.5)
  d
}

#' Least squares with the CR1 sandwich over clusters: estimate, standard error, interval and p on G - 1 df
clustered <- function(y, X, cluster, contrast = NULL) {
  X <- as.matrix(X)
  bread <- solve(crossprod(X))
  beta <- as.vector(bread %*% crossprod(X, y))
  scores <- rowsum(X * as.vector(y - X %*% beta), cluster)
  G <- nrow(scores)
  V <- bread %*% crossprod(scores) %*% bread * G / (G - 1)
  contrast <- contrast %||% c(1, rep(0, ncol(X) - 1L))
  estimate <- sum(contrast * beta)
  se <- sqrt(as.numeric(t(contrast) %*% V %*% contrast))
  crit <- stats::qt(0.975, df = G - 1)
  data.frame(n = length(y), n_people = G, estimate = estimate, std_error = se, conf_low = estimate - crit * se,
             conf_high = estimate + crit * se, statistic = estimate / se,
             p_value = 2 * stats::pt(-abs(estimate / se), df = G - 1))
}

#' ATE, GATES, top-bottom and BLP of the scores of held-out rows, from their definitions
effect_table <- function(score, cate, cluster, label) {
  rank <- rank(cate, ties.method = "first")
  bin <- pmin(4L, pmax(1L, ceiling(rank / (length(rank) / 4))))
  gates <- lapply(1:4, \(g) cbind(effect = sprintf("GATES:g%d", g),
                                  clustered(score[bin == g], matrix(1, sum(bin == g)), cluster[bin == g])))
  ends <- bin %in% c(1L, 4L)
  top_bottom <- clustered(score[ends], cbind(bin[ends] == 1L, bin[ends] == 4L), cluster[ends], contrast = c(-1, 1))
  blp <- clustered(score, cbind(1, cate - mean(cate)), cluster, contrast = c(0, 1))
  rbind(cbind(effect = label, clustered(score, matrix(1, length(score)), cluster)), do.call(rbind, gates),
        cbind(effect = "GATES:top-bottom", top_bottom), cbind(effect = "BLP:heterogeneity", blp))
}

#' Each person's estimation rows (the first 70%) and held-out rows (the last 30%), stacked
split_rows <- function(d) {
  by_person <- split(d[order(d$id, d$day), ], d$id[order(d$id, d$day)])
  list(train = do.call(rbind, lapply(by_person, \(p) utils::head(p, nrow(p) - ceiling(0.3 * nrow(p))))),
       test = do.call(rbind, lapply(by_person, \(p) utils::tail(p, ceiling(0.3 * nrow(p))))))
}

#' The same ATE, GATES, top-bottom and BLP rows from stats::lm() and sandwich::vcovCL() (type "HC0" with the
#' factor G / (G - 1)), t on G - 1 degrees of freedom by lmtest::coeftest(); the scores are given
sandwich_table <- function(score, cate, cluster, label) {
  rank <- rank(cate, ties.method = "first")
  bin <- pmin(4L, pmax(1L, ceiling(rank / (length(rank) / 4))))
  row_of <- function(effect, model, term, groups) {
    G <- length(unique(groups))
    table <- lmtest::coeftest(model, vcov. = sandwich::vcovCL(model, cluster = groups, type = "HC0", cadjust = TRUE),
                              df = G - 1L)
    crit <- stats::qt(0.975, df = G - 1)
    data.frame(effect = effect, n = stats::nobs(model), n_people = G, estimate = table[term, 1L],
               std_error = table[term, 2L], conf_low = table[term, 1L] - crit * table[term, 2L],
               conf_high = table[term, 1L] + crit * table[term, 2L], statistic = table[term, 3L],
               p_value = table[term, 4L])
  }
  gates <- lapply(1:4, \(g) {
    inside <- bin == g
    row_of(sprintf("GATES:g%d", g), stats::lm(score[inside] ~ 1), "(Intercept)", cluster[inside])
  })
  ends <- bin %in% c(1L, 4L)
  top <- bin[ends] == 4L
  centred <- cate - mean(cate)
  rbind(row_of(label, stats::lm(score ~ 1), "(Intercept)", cluster), do.call(rbind, gates),
        row_of("GATES:top-bottom", stats::lm(score[ends] ~ top), "topTRUE", cluster[ends]),
        row_of("BLP:heterogeneity", stats::lm(score ~ centred), "centred", cluster))
}

test_that("a binary treatment: AIPW scores, the average effect and its heterogeneity", {
  d <- effects_panel()
  fit <- fit_effects(d, y = "mood", treatment = "drug", x = predictors, id = "id", time = "day", scope = "pooled")
  rows <- split_rows(d)
  treated <- stats::lm(mood ~ x1 + x2, data = subset(rows$train, drug == 1))
  control <- stats::lm(mood ~ x1 + x2, data = subset(rows$train, drug == 0))
  propensity <- stats::glm(drug ~ x1 + x2, family = stats::binomial(), data = rows$train,
                           control = stats::glm.control(epsilon = 1e-14, maxit = 100))
  test <- rows$test
  m1 <- unname(stats::predict(treated, newdata = test))
  m0 <- unname(stats::predict(control, newdata = test))
  e <- pmin(pmax(unname(stats::predict(propensity, newdata = test, type = "response")), 0.05), 0.95)
  score <- m1 - m0 + test$drug * (test$mood - m1) / e - (1 - test$drug) * (test$mood - m0) / (1 - e)
  expect_reference(effects(fit), effect_table(score, m1 - m0, test$id, "ATE"),
                   reference = "independent: AIPW scores from stats::lm() and stats::glm(), CR1 sandwich",
                   covers = c("fit_effects()", "effects.idiographic_effects()", "effects.idiostats_effects()"),
                   quantity = "six people, drug on mood", tolerance = 1e-8, key = "effect",
                   note = "effects.idiostats_effects() is the same function object as effects.idiographic_effects().")
  expect_reference(effects(fit), sandwich_table(score, m1 - m0, test$id, "ATE"), reference = "sandwich",
                   covers = c("fit_effects()", "effects.idiographic_effects()", "effects.idiostats_effects()"),
                   quantity = "six people, drug on mood: inference on the AIPW scores by sandwich::vcovCL()",
                   tolerance = 1e-8,
                   note = "The scores are written from their definition (no AIPW implementation on the ci machine); their means, GATES, BLP and clustered standard errors are computed by stats::lm(), sandwich and lmtest.",
                   key = "effect")
})

test_that("a dose: the partially linear score and the per-unit effect", {
  d <- effects_panel()
  fit <- fit_effects(d, y = "sleep", treatment = "dose", x = predictors, id = "id", time = "day", scope = "pooled")
  rows <- split_rows(d)
  outcome <- stats::lm(sleep ~ x1 + x2, data = rows$train)
  dose <- stats::lm(dose ~ x1 + x2, data = rows$train)
  test <- rows$test
  ry <- test$sleep - unname(stats::predict(outcome, newdata = test))
  rt <- test$dose - unname(stats::predict(dose, newdata = test))
  theta <- sum(rt * ry) / sum(rt^2)
  score <- theta + rt * (ry - theta * rt) / mean(rt^2)
  # The predicted effect: the training outcome residuals regressed on the training dose residuals times (1, x).
  basis <- cbind(1, as.matrix(rows$train[predictors])) * stats::residuals(dose)
  beta <- stats::lm.fit(basis, stats::residuals(outcome))$coefficients
  cate <- as.vector(cbind(1, as.matrix(test[predictors])) %*% beta)
  # Least squares throughout: rounding only, 1e-10.
  expect_reference(effects(fit), effect_table(score, cate, test$id, "APE"),
                   reference = "independent: partially linear scores from stats::lm(), CR1 sandwich",
                   covers = c("fit_effects()", "effects.idiographic_effects()"),
                   quantity = "six people, dose on sleep", tolerance = 1e-10, key = "effect")
  expect_reference(effects(fit), sandwich_table(score, cate, test$id, "APE"), reference = "sandwich",
                   covers = c("fit_effects()", "effects.idiographic_effects()"),
                   quantity = "six people, dose on sleep: inference on the partially linear scores by sandwich::vcovCL()",
                   tolerance = 1e-10, key = "effect")
})
