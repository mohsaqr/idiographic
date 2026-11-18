library(idiographic)
options(width = 120)
learner <- read.csv("../data/esm_learner.csv")
fit <- fit_var(learner, vars = c("efficacy", "planning", "effort"), beep = "occasion")
fit
result <- subset(transform(coefs(fit), edge = paste(network, from, to)), select = c(edge, weight))
result
