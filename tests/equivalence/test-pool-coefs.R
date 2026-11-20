# pool_coefs(), shrink_coefs(): the random-effects pooling of person-specific coefficients (DerSimonian & Laird,
# 1986, with the Hartung & Knapp, 2001, standard error floored at the usual one) and their empirical-Bayes
# shrinkage towards the pooled value, written from the definitions, on the coefficients of stats::lm() fitted to
# each learner's estimation rows (all but the last ceiling(0.2 n) days; the fits are compared in test-fit-lm.R).

held_out <- 0.2
predictors <- c("efficacy", "planning")
ordered <- srl[order(srl$name, srl$day), ]
people <- split(ordered, ordered$name)
person_coefficients <- do.call(rbind, lapply(people, \(person) {
  fit <- stats::lm(effort ~ efficacy + planning, data = utils::head(person, nrow(person) - ceiling(held_out * nrow(person))))
  table <- stats::coef(summary(fit))
  data.frame(subject = person$name[[1L]], term = rownames(table), estimate = table[, 1L], std_error = table[, 2L],
             row.names = NULL)
}))

#' Random-effects pooling of one term's person estimates
#'
#' DerSimonian & Laird (1986) for the between-person variance; the standard error is Hartung & Knapp's (2001),
#' not allowed below the usual random-effects one when `floored`, with t on k - 1 degrees of freedom.
pool_term <- function(part, floored = TRUE) {
  k <- nrow(part)
  w <- 1 / part$std_error^2
  q <- sum(w * (part$estimate - sum(w * part$estimate) / sum(w))^2)
  tau2 <- max(0, (q - (k - 1)) / (sum(w) - sum(w^2) / sum(w)))
  w_star <- 1 / (part$std_error^2 + tau2)
  estimate <- sum(w_star * part$estimate) / sum(w_star)
  usual <- sqrt(1 / sum(w_star))
  hartung_knapp <- sqrt(sum(w_star * (part$estimate - estimate)^2) / ((k - 1) * sum(w_star)))
  std_error <- if (floored) max(hartung_knapp, usual) else usual
  critical <- stats::qt(0.975, df = k - 1)
  data.frame(term = part$term[[1L]], k = k, estimate = estimate, std_error = std_error,
             conf_low = estimate - critical * std_error, conf_high = estimate + critical * std_error,
             p_value = 2 * stats::pt(-abs(estimate / std_error), df = k - 1), tau = sqrt(tau2),
             i2 = max(0, (q - (k - 1)) / q), q = q, q_p = stats::pchisq(q, df = k - 1, lower.tail = FALSE),
             sd_observed = stats::sd(part$estimate))
}

test_that("random-effects pooling of the person coefficients", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  by_term <- split(person_coefficients, person_coefficients$term)
  # Closed-form weighted sums; the Q statistics reach 1,000, whose rounding is of the order of 1e-12.
  expect_reference(pool_coefs(fit), do.call(rbind, lapply(by_term, pool_term)),
                   reference = "independent: DerSimonian-Laird pooling, Hartung-Knapp SE floored at the usual one",
                   covers = "pool_coefs()", quantity = "three terms over 36 learners", tolerance = 1e-8, key = "term")
  usual <- lapply(by_term, pool_term, floored = FALSE)
  expect_known_difference(pool_coefs(fit), do.call(rbind, lapply(usual, \(row) subset(row, select = c(term, std_error)))),
                          reference = "independent: DerSimonian-Laird pooling, usual standard error",
                          covers = "pool_coefs()", quantity = "pooled standard error, the usual form", tolerance = 1e-8,
                          key = "term",
                          reason = "pool_coefs() uses the Hartung-Knapp standard error, floored at the usual random-effects one sqrt(1 / sum(w*)), which treats tau^2 as known and under-covers.",
                          agrees_with = "the usual standard error wherever it exceeds the Hartung-Knapp one")
})

test_that("empirical-Bayes shrinkage of the person coefficients towards the pooled value", {
  fit <- fit_lm(srl, y = "effort", x = predictors, id = "name", time = "day", scope = "individual",
                test_prop = held_out)
  shrunken <- do.call(rbind, lapply(split(person_coefficients, person_coefficients$term), \(part) {
    pooled <- pool_term(part)
    weight <- pooled$tau^2 / (pooled$tau^2 + part$std_error^2)
    data.frame(subject = part$subject, term = part$term, estimate = part$estimate, std_error = part$std_error,
               weight = weight, shrunken = pooled$estimate + weight * (part$estimate - pooled$estimate))
  }))
  expect_reference(shrink_coefs(fit), shrunken,
                   reference = "independent: empirical-Bayes posterior mean under DerSimonian-Laird",
                   covers = "shrink_coefs()", quantity = "three terms over 36 learners", tolerance = 1e-8,
                   key = c("subject", "term"))
})
