library(idiographic)
options(width = 120)
srl <- read.csv("../data/srl.csv")
fit <- fit_within_between(srl, y = "effort", x = "efficacy", id = "name", time = "day",
                          model = "within_between", estimator = "reml", test_prop = 0.2)
fit
fixed <- coefs(fit)
random <- as.data.frame(variance_components(fit))
result <- rbind(
  with(fixed, data.frame(quantity = paste(term, "estimate"), kind = "fixed effect", value = estimate)),
  with(fixed, data.frame(quantity = paste(term, "std_error"), kind = "standard error", value = std_error)),
  with(random, data.frame(quantity = paste(level, "variance"), kind = "variance component", value = variance)))
result
