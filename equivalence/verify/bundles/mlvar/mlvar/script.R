options(width = 120)
library(mlVAR)
diary <- read.csv("../data/esm_srl.csv")
items <- c("efficacy", "planning", "effort")
fit <- mlVAR(diary, vars = items, idvar = "name", beepvar = "occasion", estimator = "lmer",
             temporal = "fixed", contemporaneous = "fixed", scale = FALSE, verbose = FALSE)
summary(fit)
# Beta: one row per outcome, one column per lagged predictor.
beta <- fit$results$Beta$mean[, , 1]
contemporaneous <- fit$results$Theta$pcor$mean
between <- fit$results$Omega_mu$pcor$mean
pair <- which(upper.tri(between), arr.ind = TRUE)
undirected <- paste(items[pair[, "row"]], items[pair[, "col"]])
result <- data.frame(
  edge = c(paste("temporal", rep(items, each = 3), rep(items, times = 3)),
           paste("contemporaneous", undirected), paste("between", undirected)),
  weight = c(as.vector(beta), contemporaneous[pair], between[pair]))
result
