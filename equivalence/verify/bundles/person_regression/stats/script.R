options(width = 120)
srl <- read.csv("../data/srl.csv")
# Each learner's own regression on all but the last ceiling(0.2 n) days.
own_fit <- function(d) lm(effort ~ efficacy + planning, data = head(d, nrow(d) - ceiling(0.2 * nrow(d))))
fits <- lapply(split(srl, srl$name), own_fit)
person <- do.call(rbind, lapply(names(fits), function(learner) {
  table <- coef(summary(fits[[learner]]))
  data.frame(subject = learner, term = rownames(table), estimate = table[, "Estimate"],
             std_error = table[, "Std. Error"], row.names = NULL)
}))
head(person, 9)
# DerSimonian & Laird (1986) for one term; the standard error is Hartung & Knapp's (2001), not allowed
# below the usual random-effects standard error.
pool <- function(d) {
  k <- nrow(d)
  w <- 1 / d$std_error^2
  q <- sum(w * (d$estimate - weighted.mean(d$estimate, w))^2)
  tau2 <- max(0, (q - (k - 1)) / (sum(w) - sum(w^2) / sum(w)))
  w <- 1 / (d$std_error^2 + tau2)
  estimate <- weighted.mean(d$estimate, w)
  hartung_knapp <- sqrt(sum(w * (d$estimate - estimate)^2) / ((k - 1) * sum(w)))
  data.frame(term = d$term[1], estimate = estimate, std_error = max(hartung_knapp, sqrt(1 / sum(w))),
             tau = sqrt(tau2), i2 = max(0, (q - (k - 1)) / q), q = q)
}
pooled <- do.call(rbind, lapply(split(person, person$term), pool))
print(pooled, row.names = FALSE)
measures <- c("estimate", "std_error", "tau", "i2", "q")
result <- rbind(
  data.frame(quantity = paste(person$subject, person$term, "estimate"), value = person$estimate),
  data.frame(quantity = paste(person$subject, person$term, "std_error"), value = person$std_error),
  data.frame(quantity = paste("pooled", rep(pooled$term, times = 5), rep(measures, each = 3)),
             value = unlist(pooled[measures], use.names = FALSE)))
