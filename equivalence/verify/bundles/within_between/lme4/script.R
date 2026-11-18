options(width = 120)
library(lme4)
srl <- read.csv("../data/srl.csv")
# All but the last ceiling(0.2 n) days of each learner, then the complete rows.
first_days <- function(d) head(d, nrow(d) - ceiling(0.2 * nrow(d)))
train <- do.call(rbind, lapply(split(srl, srl$name), first_days))
train <- train[complete.cases(train[c("effort", "efficacy")]), ]
train$efficacy_between <- ave(train$efficacy, train$name)
train$efficacy_within <- train$efficacy - train$efficacy_between
fit <- lmer(effort ~ efficacy_within + efficacy_between + (1 | name), data = train, REML = TRUE)
summary(fit)
fixed <- coef(summary(fit))
random <- as.data.frame(VarCorr(fit))
result <- data.frame(
  quantity = c(paste(rownames(fixed), "estimate"), paste(rownames(fixed), "std_error"),
               paste(random$grp, "variance")),
  value = c(fixed[, "Estimate"], fixed[, "Std. Error"], random$vcov))
result
