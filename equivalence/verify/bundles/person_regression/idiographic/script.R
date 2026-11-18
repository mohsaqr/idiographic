library(idiographic)
options(width = 120)
srl <- read.csv("../data/srl.csv")
fit <- fit_lm(srl, y = "effort", x = c("efficacy", "planning"), id = "name", time = "day",
              scope = "individual", test_prop = 0.2)
person <- coefs(fit)
head(person, 9)
pooled <- pool_coefs(fit)
pooled
result <- rbind(
  with(person, data.frame(quantity = paste(subject, term, "estimate"), kind = "person estimate", value = estimate)),
  with(person, data.frame(quantity = paste(subject, term, "std_error"), kind = "person std_error", value = std_error)),
  with(pooled, data.frame(quantity = paste("pooled", term, "estimate"), kind = "pooled estimate", value = estimate)),
  with(pooled, data.frame(quantity = paste("pooled", term, "std_error"), kind = "pooled std_error", value = std_error)),
  with(pooled, data.frame(quantity = paste("pooled", term, "tau"), kind = "tau", value = tau)),
  with(pooled, data.frame(quantity = paste("pooled", term, "i2"), kind = "i2", value = i2)),
  with(pooled, data.frame(quantity = paste("pooled", term, "q"), kind = "q", value = q)))
