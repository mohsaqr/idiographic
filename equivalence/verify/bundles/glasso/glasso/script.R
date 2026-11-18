options(width = 120)
library(glasso)
diary <- read.csv("../data/esm_srl.csv")
correlations <- cor(subset(diary, select = -c(name, occasion)), use = "complete.obs")
fit <- glasso(correlations, rho = 0.1, penalize.diagonal = FALSE, thr = 1e-12, maxit = 1e4)
items <- colnames(correlations)
precision <- fit$wi
partial <- -cov2cor(precision)
pair <- which(upper.tri(precision), arr.ind = TRUE)
result <- data.frame(edge = paste(items[pair[, "row"]], items[pair[, "col"]]),
                     precision = precision[pair], weight = partial[pair])
result
