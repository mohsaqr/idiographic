library(idiographic)
options(width = 120)
srl <- read.csv("../data/srl_pair.csv")
prepared <- preprocess_panel(srl, id = "name", time = "day", vars = c("efficacy", "effort"),
                             detrend = "person", detrend_alpha = 1, center = "person", scale = "person",
                             lag = 1, keep_all = FALSE)
head(prepared)
result <- na.omit(subset(transform(prepared, occasion = paste(name, day)), select = -c(name, day)))
summary(result)
