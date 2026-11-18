options(width = 120)
library(graphicalVAR)
learner <- read.csv("../data/esm_learner.csv")
items <- c("efficacy", "planning", "effort")
fit <- graphicalVAR(learner, vars = items, beepvar = "occasion", nLambda = 15, gamma = 0,
                    verbose = FALSE)
summary(fit)
# fit$beta: one row per outcome, an intercept column, then one column per lagged predictor.
beta <- fit$beta[, -1]
pair <- which(upper.tri(fit$PCC), arr.ind = TRUE)
result <- data.frame(
  edge = c(paste("temporal", rep(items, each = 3), rep(items, times = 3)),
           paste("contemporaneous", items[pair[, "row"]], items[pair[, "col"]])),
  weight = c(as.vector(beta), fit$PCC[pair]))
result
