# Builds data/submissions.rda: a simulated binary outcome with two latent
# types of learners, for fit_glm() and subgroup examples.
# Run from the package root: Rscript data-raw/submissions.R
set.seed(2026)
n_learners <- 40
n_days <- 80
type <- rep(c("engaged", "avoidant"), each = n_learners / 2)
# Engaged learners submit more on motivated days, avoidant learners less.
slope <- ifelse(type == "engaged", 1.2, -0.6) + stats::rnorm(n_learners, sd = 0.15)
intercept <- stats::rnorm(n_learners, mean = -0.2, sd = 0.3)
average_motivation <- stats::rnorm(n_learners, sd = 0.5)

submissions <- data.frame(
  learner = rep(seq_len(n_learners), each = n_days),
  day = rep(seq_len(n_days), times = n_learners),
  type = rep(type, each = n_days)
)
submissions <- transform(
  submissions,
  motivation = rep(average_motivation, each = n_days) +
    stats::rnorm(n_learners * n_days)
)
submissions <- transform(
  submissions,
  submitted = stats::rbinom(
    nrow(submissions), size = 1,
    prob = stats::plogis(rep(intercept, each = n_days) +
                           rep(slope, each = n_days) * motivation)
  )
)
save(submissions, file = "data/submissions.rda", compress = "xz")
