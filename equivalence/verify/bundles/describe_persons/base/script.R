options(width = 120)
srl <- read.csv("../data/srl_learners.csv")
# One learner's series `v` on days `day`, in day order. `lowest` and `highest` are the bounds of the
# scale seen in the sample and `acute` the sample's cutoff for an acute change (Jahng, Wood & Trull, 2008).
describe_series <- function(v, day, lowest, highest, acute) {
  seen <- v[!is.na(v)]
  step <- diff(v)
  step <- step[!is.na(step)]
  adjacent <- !is.na(v[-1]) & !is.na(v[-length(v)])
  centred <- seen - mean(seen)
  trend <- coef(summary(lm(v ~ day)))
  data.frame(
    n = length(seen), missing = sum(is.na(v)), mean = mean(seen), median = median(seen), sd = sd(seen),
    min = min(seen), max = max(seen),
    rmssd = sqrt(mean(step^2)),
    autocor = cor(v[-length(v)][adjacent], v[-1][adjacent]),
    span = max(day) - min(day), gap_median = median(diff(day)), gap_max = max(diff(day)),
    p_floor = mean(seen <= lowest), p_ceiling = mean(seen >= highest),
    pac = mean(abs(step) >= acute),
    skew = mean(centred^3) / mean(centred^2)^1.5,
    kurtosis = mean(centred^4) / mean(centred^2)^2 - 3,
    trend = trend["day", "Estimate"], trend_p = trend["day", "Pr(>|t|)"],
    longest_run = max(rle(seen)$lengths))
}
describe_variable <- function(variable) {
  learners <- split(srl, srl$name)
  changes <- unlist(lapply(learners, function(d) diff(d[[variable]])))
  acute <- quantile(abs(changes), probs = 0.9, na.rm = TRUE)
  rows <- lapply(learners, function(d) {
    describe_series(d[[variable]], d$day, lowest = min(srl[[variable]], na.rm = TRUE),
                    highest = max(srl[[variable]], na.rm = TRUE), acute = acute)
  })
  data.frame(series = paste(names(learners), variable), do.call(rbind, rows))
}
result <- do.call(rbind, lapply(c("efficacy", "effort"), describe_variable))
print(result, row.names = FALSE)
