library(idiographic)
options(width = 120)
diary <- read.csv("../data/esm_srl.csv")
correlations <- cor(subset(diary, select = -c(name, occasion)), use = "complete.obs")
fit <- glasso_fit(correlations, rho = 0.1)
fit
result <- subset(transform(as.data.frame(fit), edge = paste(from, to)), select = c(edge, precision, weight))
result
