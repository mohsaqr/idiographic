library(idiographic)
options(width = 120)
diary <- read.csv("../data/esm_srl.csv")
fit <- fit_mlvar(diary, vars = c("efficacy", "planning", "effort"), id = "name", beep = "occasion")
fit
result <- subset(transform(edges(fit, include_self = TRUE), edge = paste(network, from, to)),
                 select = c(edge, weight))
result
