options(width = 120)
learner <- read.csv("../data/esm_learner.csv")
items <- c("efficacy", "planning", "effort")
stopifnot(diff(learner$occasion) == 1)
z <- as.data.frame(scale(learner[items]))
today <- z[-1, ]
yesterday <- setNames(z[-nrow(z), ], paste0(items, "_lag"))
fit <- lm(cbind(efficacy, planning, effort) ~ efficacy_lag + planning_lag + effort_lag,
          data = cbind(today, yesterday))
fit
# coef(): one row per predictor, one column per outcome.
beta <- coef(fit)[-1, ]
partial <- -cov2cor(solve(cov(residuals(fit))))
pair <- which(upper.tri(partial), arr.ind = TRUE)
result <- data.frame(
  edge = c(paste("temporal", rep(items, times = 3), rep(items, each = 3)),
           paste("contemporaneous", items[pair[, "row"]], items[pair[, "col"]])),
  weight = c(as.vector(beta), partial[pair]))
result
