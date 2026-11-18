options(width = 120)
srl <- read.csv("../data/srl_pair.csv")
# The residual of the learner's own regression on day, as a z-score within the learner.
standardised_residual <- function(v, day) {
  residual <- residuals(lm(v ~ day, na.action = na.exclude))
  (residual - mean(residual, na.rm = TRUE)) / sd(residual, na.rm = TRUE)
}
prepare <- function(d) {
  efficacy <- standardised_residual(d$efficacy, d$day)
  effort <- standardised_residual(d$effort, d$day)
  yesterday <- match(d$day - 1, d$day)
  data.frame(efficacy = efficacy, effort = effort, efficacy_lag1 = efficacy[yesterday],
             effort_lag1 = effort[yesterday], occasion = paste(d$name, d$day))
}
prepared <- do.call(rbind, lapply(split(srl, srl$name), prepare))
head(prepared)
result <- na.omit(prepared)
summary(result)
