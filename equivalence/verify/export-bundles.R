# Exports idiographic comparison cases as bundles for Prova Verify (format:
# plan/24-verify.md in the prova repository), with Prova's R writer.
#
# Every side of a case is an R script, stored in the bundle and run there in its
# own R process: its console is the side's raw output and the table it leaves in
# `result` holds the side's values. The references are the packages that the
# test suite of idiographic already checks against (stats, graphicalVAR, glasso,
# mlVAR, lme4) and, where no package reference exists, a base-R computation
# written from the published definition.
#
# Run from the project root:
#   PROVA_VERIFY_R=<prova>/reporters/verify.R \
#     Rscript equivalence/verify/export-bundles.R [case ...]
source(Sys.getenv("PROVA_VERIFY_R", file.path("..", "prova", "reporters", "verify.R")))

.verify_base <- file.path("equivalence", "verify")
.verify_generator <- "idiographic equivalence/verify/export-bundles.R"

#' One of the package's bundled data sets, read from `data/` without attaching
#' the package
#' @param name `"srl"` or `"esm_srl"`.
#' @return The data frame.
.verify_dataset <- function(name) {
  scope <- new.env()
  load(file.path("data", paste0(name, ".rda")), envir = scope)
  get(name, envir = scope)
}

#' The data files the cases read, written to a temporary folder
#'
#' All are cut from the bundled `esm_srl` (41 learners, daily diary) and `srl`
#' (36 learners, 156 days), sorted by learner and occasion.
#' @return A named character vector of file paths.
.verify_data <- function() {
  folder <- file.path(tempdir(), "idiographic-verify")
  dir.create(folder, showWarnings = FALSE)
  esm <- .verify_dataset("esm_srl")
  esm <- esm[order(esm$name, esm$occasion), ]
  srl <- .verify_dataset("srl")
  srl <- srl[order(srl$name, srl$day), c("name", "day", "efficacy", "planning", "effort")]
  learners <- unique(srl$name)
  files <- list(
    # One learner with 78 consecutive, complete occasions, and a graphical VAR that keeps 11 of 12 edges
    # (most learners keep 2 to 7, which leaves little to compare).
    esm_learner.csv = esm[esm$name == "Tariq", c("occasion", "efficacy", "planning", "effort")],
    esm_srl.csv = esm[c("name", "occasion", "efficacy", "value", "planning", "monitoring", "effort", "regulation")],
    srl.csv = srl,
    # The first six learners; the sixth has missing days.
    srl_learners.csv = srl[srl$name %in% learners[seq_len(6L)], c("name", "day", "efficacy", "effort")],
    srl_pair.csv = srl[srl$name %in% learners[c(1L, 6L)], c("name", "day", "efficacy", "effort")]
  )
  paths <- file.path(folder, names(files))
  Map(function(table, path) utils::write.csv(table, path, row.names = FALSE), files, paths)
  stats::setNames(paths, names(files))
}

#' A script's lines as one string
#'
#' verify_run() drops the `library(<package>)` line of a side loaded from source
#' with `setdiff()`, which also drops every repeated line of a script (a second
#' `}`, a second `result`). Handing the lines over as one element keeps them.
#' @param lines The script's lines.
#' @return One string.
.verify_lines <- function(lines) paste(c("options(width = 120)", lines), collapse = "\n")

.idiographic <- function(script, key = NULL) {
  verify_side("idiographic", package = "idiographic", primary = TRUE, load = ".", key = key,
              script = c("library(idiographic)", .verify_lines(script)))
}
.reference <- function(id, package, script, key = NULL, name = package) {
  verify_side(id, name = name, package = package, authority = "open-source", key = key,
              script = .verify_lines(script))
}
.base <- function(script, key = NULL) {
  verify_side("base", name = "Base R, from the definition", package = "base", authority = "independent",
              key = key, script = .verify_lines(script))
}

#' Every case: its words, data, tolerance, reference packages and scripts
#'
#' A script's paths are relative to its own folder inside the bundle. Each
#' tolerance was fixed before the case was first run; the comment beside it says
#' why that value.
#' @return A named list of cases.
.verify_cases <- function() {
  list(
    var_ols = list(
      title = "Person-specific VAR(1) by least squares",
      description = "A lag-1 vector autoregression of three daily self-regulation items for one learner (78 consecutive days), on standardised series. Temporal weights are the regression coefficients of each item on yesterday's items; contemporaneous weights are the partial correlations of the residuals.",
      covers = c("fit_var()", "coefs()"),
      data = c("One learner, daily diary" = "esm_learner.csv"),
      needs = character(),
      # Closed-form least squares on 77 rows, solved by QR on both sides: the
      # sides can differ only by rounding, so 1e-10.
      tolerance = 1e-10,
      sides = list(
        .idiographic(key = "edge", c(
          "learner <- read.csv(\"../data/esm_learner.csv\")",
          "fit <- fit_var(learner, vars = c(\"efficacy\", \"planning\", \"effort\"), beep = \"occasion\")",
          "fit",
          "result <- subset(transform(coefs(fit), edge = paste(network, from, to)), select = c(edge, weight))",
          "result")),
        .reference("stats", "stats", key = "edge", c(
          "learner <- read.csv(\"../data/esm_learner.csv\")",
          "items <- c(\"efficacy\", \"planning\", \"effort\")",
          "stopifnot(diff(learner$occasion) == 1)",
          "z <- as.data.frame(scale(learner[items]))",
          "today <- z[-1, ]",
          "yesterday <- setNames(z[-nrow(z), ], paste0(items, \"_lag\"))",
          "fit <- lm(cbind(efficacy, planning, effort) ~ efficacy_lag + planning_lag + effort_lag,",
          "          data = cbind(today, yesterday))",
          "fit",
          "# coef(): one row per predictor, one column per outcome.",
          "beta <- coef(fit)[-1, ]",
          "partial <- -cov2cor(solve(cov(residuals(fit))))",
          "pair <- which(upper.tri(partial), arr.ind = TRUE)",
          "result <- data.frame(",
          "  edge = c(paste(\"temporal\", rep(items, times = 3), rep(items, each = 3)),",
          "           paste(\"contemporaneous\", items[pair[, \"row\"]], items[pair[, \"col\"]])),",
          "  weight = c(as.vector(beta), partial[pair]))",
          "result")))),
    graphical_var = list(
      title = "Regularised graphical VAR",
      description = "The same learner and items, estimated as a graphical VAR: lasso-penalised temporal coefficients and a graphical-lasso contemporaneous network, with both penalties chosen by BIC (EBIC with gamma = 0) over a 15 x 15 grid. Both sides get the same grid size, gamma and data.",
      covers = c("fit_graphical_var()", "coefs()"),
      data = c("One learner, daily diary" = "esm_learner.csv"),
      needs = "graphicalVAR",
      # Both sides iterate (coordinate descent inside an alternating scheme) to
      # their own convergence thresholds, so they agree to those thresholds and
      # not to rounding. 1e-4 is the bound of the package's own fixture test
      # (tests/testthat/test-expanded-equivalence.R).
      tolerance = 1e-4,
      sides = list(
        .idiographic(key = "edge", c(
          "learner <- read.csv(\"../data/esm_learner.csv\")",
          "fit <- fit_graphical_var(learner, vars = c(\"efficacy\", \"planning\", \"effort\"), beep = \"occasion\",",
          "                         n_lambda = 15, gamma = 0)",
          "fit",
          "result <- subset(transform(coefs(fit), edge = paste(network, from, to)), select = c(edge, weight))",
          "result")),
        .reference("graphicalvar", "graphicalVAR", key = "edge", c(
          "library(graphicalVAR)",
          "learner <- read.csv(\"../data/esm_learner.csv\")",
          "items <- c(\"efficacy\", \"planning\", \"effort\")",
          "fit <- graphicalVAR(learner, vars = items, beepvar = \"occasion\", nLambda = 15, gamma = 0,",
          "                    verbose = FALSE)",
          "summary(fit)",
          "# fit$beta: one row per outcome, an intercept column, then one column per lagged predictor.",
          "beta <- fit$beta[, -1]",
          "pair <- which(upper.tri(fit$PCC), arr.ind = TRUE)",
          "result <- data.frame(",
          "  edge = c(paste(\"temporal\", rep(items, each = 3), rep(items, times = 3)),",
          "           paste(\"contemporaneous\", items[pair[, \"row\"]], items[pair[, \"col\"]])),",
          "  weight = c(as.vector(beta), fit$PCC[pair]))",
          "result")))),
    glasso = list(
      title = "Graphical lasso at a fixed penalty",
      description = "The graphical lasso of the correlation matrix of six diary items (2,790 complete rows) at rho = 0.1 with the diagonal unpenalised: the off-diagonal precision entries and the partial correlations they imply.",
      covers = c("glasso_fit()", "as.data.frame.glasso_result()"),
      data = c("Daily diary, 41 learners" = "esm_srl.csv"),
      needs = "glasso",
      # A convex problem with one solution; both sides are run to tight
      # convergence (glasso with thr = 1e-12), and 1e-6 is the bound of the
      # package's own grid test against the Fortran kernel.
      tolerance = 1e-6,
      sides = list(
        .idiographic(key = "edge", c(
          "diary <- read.csv(\"../data/esm_srl.csv\")",
          "correlations <- cor(subset(diary, select = -c(name, occasion)), use = \"complete.obs\")",
          "fit <- glasso_fit(correlations, rho = 0.1)",
          "fit",
          "result <- subset(transform(as.data.frame(fit), edge = paste(from, to)), select = c(edge, precision, weight))",
          "result")),
        .reference("glasso", "glasso", key = "edge", c(
          "library(glasso)",
          "diary <- read.csv(\"../data/esm_srl.csv\")",
          "correlations <- cor(subset(diary, select = -c(name, occasion)), use = \"complete.obs\")",
          "fit <- glasso(correlations, rho = 0.1, penalize.diagonal = FALSE, thr = 1e-12, maxit = 1e4)",
          "items <- colnames(correlations)",
          "precision <- fit$wi",
          "partial <- -cov2cor(precision)",
          "pair <- which(upper.tri(precision), arr.ind = TRUE)",
          "result <- data.frame(edge = paste(items[pair[, \"row\"]], items[pair[, \"col\"]]),",
          "                     precision = precision[pair], weight = partial[pair])",
          "result")))),
    mlvar = list(
      title = "Multilevel VAR with fixed effects",
      description = "A two-step multilevel VAR(1) of three diary items across 41 learners, with fixed temporal and contemporaneous effects: the temporal fixed effects, the contemporaneous partial correlations of the residuals and the between-learner partial correlations of the means.",
      covers = c("fit_mlvar()", "edges()"),
      data = c("Daily diary, 41 learners" = "esm_srl.csv"),
      needs = "mlVAR",
      # Both sides fit the same node-wise mixed models with lme4, so they should
      # agree far below any estimate's standard error; 1e-8 is the bound of the
      # package's own equivalence tests against mlVAR.
      tolerance = 1e-8,
      sides = list(
        .idiographic(key = "edge", c(
          "diary <- read.csv(\"../data/esm_srl.csv\")",
          "fit <- fit_mlvar(diary, vars = c(\"efficacy\", \"planning\", \"effort\"), id = \"name\", beep = \"occasion\")",
          "fit",
          "result <- subset(transform(edges(fit, include_self = TRUE), edge = paste(network, from, to)),",
          "                 select = c(edge, weight))",
          "result")),
        .reference("mlvar", "mlVAR", key = "edge", c(
          "library(mlVAR)",
          "diary <- read.csv(\"../data/esm_srl.csv\")",
          "items <- c(\"efficacy\", \"planning\", \"effort\")",
          "fit <- mlVAR(diary, vars = items, idvar = \"name\", beepvar = \"occasion\", estimator = \"lmer\",",
          "             temporal = \"fixed\", contemporaneous = \"fixed\", scale = FALSE, verbose = FALSE)",
          "summary(fit)",
          "# Beta: one row per outcome, one column per lagged predictor.",
          "beta <- fit$results$Beta$mean[, , 1]",
          "contemporaneous <- fit$results$Theta$pcor$mean",
          "between <- fit$results$Omega_mu$pcor$mean",
          "pair <- which(upper.tri(between), arr.ind = TRUE)",
          "undirected <- paste(items[pair[, \"row\"]], items[pair[, \"col\"]])",
          "result <- data.frame(",
          "  edge = c(paste(\"temporal\", rep(items, each = 3), rep(items, times = 3)),",
          "           paste(\"contemporaneous\", undirected), paste(\"between\", undirected)),",
          "  weight = c(as.vector(beta), contemporaneous[pair], between[pair]))",
          "result")))),
    describe_persons = list(
      title = "Within-person descriptive dynamics",
      description = "Per-learner descriptives of two daily items for six learners over 156 days: level and spread, the root mean square successive difference, the lag-1 autocorrelation (inertia) over adjacent pairs, the probability of acute change against the sample's 90th percentile of absolute changes, floor and ceiling shares, moment skewness and excess kurtosis, the linear time trend and the longest run of repeated values.",
      covers = "describe_persons()",
      data = c("Six learners, 156 days" = "srl_learners.csv"),
      needs = character(),
      # Closed-form sums, quantiles and a two-parameter regression on at most
      # 156 values: the sides can differ only by rounding, so 1e-10.
      tolerance = 1e-10,
      sides = list(
        .idiographic(key = "series", c(
          "srl <- read.csv(\"../data/srl_learners.csv\")",
          "described <- describe_persons(srl, id = \"name\", vars = c(\"efficacy\", \"effort\"), time = \"day\",",
          "                              detail = \"full\")",
          "as.data.frame(described)",
          "result <- subset(transform(described, series = paste(subject, variable)), select = -c(subject, variable))")),
        .base(key = "series", c(
          "srl <- read.csv(\"../data/srl_learners.csv\")",
          "# One learner's series `v` on days `day`, in day order. `lowest` and `highest` are the bounds of the",
          "# scale seen in the sample and `acute` the sample's cutoff for an acute change (Jahng, Wood & Trull, 2008).",
          "describe_series <- function(v, day, lowest, highest, acute) {",
          "  seen <- v[!is.na(v)]",
          "  step <- diff(v)",
          "  step <- step[!is.na(step)]",
          "  adjacent <- !is.na(v[-1]) & !is.na(v[-length(v)])",
          "  centred <- seen - mean(seen)",
          "  trend <- coef(summary(lm(v ~ day)))",
          "  data.frame(",
          "    n = length(seen), missing = sum(is.na(v)), mean = mean(seen), median = median(seen), sd = sd(seen),",
          "    min = min(seen), max = max(seen),",
          "    rmssd = sqrt(mean(step^2)),",
          "    autocor = cor(v[-length(v)][adjacent], v[-1][adjacent]),",
          "    span = max(day) - min(day), gap_median = median(diff(day)), gap_max = max(diff(day)),",
          "    p_floor = mean(seen <= lowest), p_ceiling = mean(seen >= highest),",
          "    pac = mean(abs(step) >= acute),",
          "    skew = mean(centred^3) / mean(centred^2)^1.5,",
          "    kurtosis = mean(centred^4) / mean(centred^2)^2 - 3,",
          "    trend = trend[\"day\", \"Estimate\"], trend_p = trend[\"day\", \"Pr(>|t|)\"],",
          "    longest_run = max(rle(seen)$lengths))",
          "}",
          "describe_variable <- function(variable) {",
          "  learners <- split(srl, srl$name)",
          "  changes <- unlist(lapply(learners, function(d) diff(d[[variable]])))",
          "  acute <- quantile(abs(changes), probs = 0.9, na.rm = TRUE)",
          "  rows <- lapply(learners, function(d) {",
          "    describe_series(d[[variable]], d$day, lowest = min(srl[[variable]], na.rm = TRUE),",
          "                    highest = max(srl[[variable]], na.rm = TRUE), acute = acute)",
          "  })",
          "  data.frame(series = paste(names(learners), variable), do.call(rbind, rows))",
          "}",
          "result <- do.call(rbind, lapply(c(\"efficacy\", \"effort\"), describe_variable))",
          "print(result, row.names = FALSE)")))),
    preprocess_panel = list(
      title = "Detrending, person-centring, scaling and lagging",
      description = "Two learners' daily series prepared for a within-person model: each learner's own linear time trend removed unconditionally, the result centred on the learner's mean and divided by the learner's standard deviation, and a lag-1 copy made by day. One of the two learners has missing days. Every prepared value is compared, on the days where the value and its lag both exist.",
      covers = "preprocess_panel()",
      data = c("Two learners, 156 days" = "srl_pair.csv"),
      needs = character(),
      # Residuals of a two-parameter regression, a mean and a standard deviation:
      # closed form on both sides, so 1e-10.
      tolerance = 1e-10,
      sides = list(
        .idiographic(key = "occasion", c(
          "srl <- read.csv(\"../data/srl_pair.csv\")",
          "prepared <- preprocess_panel(srl, id = \"name\", time = \"day\", vars = c(\"efficacy\", \"effort\"),",
          "                             detrend = \"person\", detrend_alpha = 1, center = \"person\", scale = \"person\",",
          "                             lag = 1, keep_all = FALSE)",
          "head(prepared)",
          "result <- na.omit(subset(transform(prepared, occasion = paste(name, day)), select = -c(name, day)))",
          "summary(result)")),
        .reference("stats", "stats", key = "occasion", c(
          "srl <- read.csv(\"../data/srl_pair.csv\")",
          "# The residual of the learner's own regression on day, as a z-score within the learner.",
          "standardised_residual <- function(v, day) {",
          "  residual <- residuals(lm(v ~ day, na.action = na.exclude))",
          "  (residual - mean(residual, na.rm = TRUE)) / sd(residual, na.rm = TRUE)",
          "}",
          "prepare <- function(d) {",
          "  efficacy <- standardised_residual(d$efficacy, d$day)",
          "  effort <- standardised_residual(d$effort, d$day)",
          "  yesterday <- match(d$day - 1, d$day)",
          "  data.frame(efficacy = efficacy, effort = effort, efficacy_lag1 = efficacy[yesterday],",
          "             effort_lag1 = effort[yesterday], occasion = paste(d$name, d$day))",
          "}",
          "prepared <- do.call(rbind, lapply(split(srl, srl$name), prepare))",
          "head(prepared)",
          "result <- na.omit(prepared)",
          "summary(result)")))),
    person_regression = list(
      title = "Person-specific regressions and their random-effects pooling",
      description = "A separate regression of effort on efficacy and planning for each of 36 learners, estimated on the first 80% of each learner's days (the last ceiling(0.2 n) days are held out), and the pooling of the 36 coefficients per term: DerSimonian-Laird between-person variance, Q and I2, with the Hartung-Knapp standard error floored at the usual random-effects standard error.",
      covers = c("fit_lm()", "coefs()", "pool_coefs()"),
      data = c("36 learners, 156 days" = "srl.csv"),
      needs = character(),
      # Least squares and closed-form weighted sums. The largest compared values
      # are Q statistics above 1,000, which carry rounding of the order of 1e-10,
      # so 1e-8 absolute.
      tolerance = 1e-8,
      sides = list(
        .idiographic(c(
          "srl <- read.csv(\"../data/srl.csv\")",
          "fit <- fit_lm(srl, y = \"effort\", x = c(\"efficacy\", \"planning\"), id = \"name\", time = \"day\",",
          "              scope = \"individual\", test_prop = 0.2)",
          "person <- coefs(fit)",
          "head(person, 9)",
          "pooled <- pool_coefs(fit)",
          "pooled",
          "result <- rbind(",
          "  with(person, data.frame(quantity = paste(subject, term, \"estimate\"), kind = \"person estimate\", value = estimate)),",
          "  with(person, data.frame(quantity = paste(subject, term, \"std_error\"), kind = \"person std_error\", value = std_error)),",
          "  with(pooled, data.frame(quantity = paste(\"pooled\", term, \"estimate\"), kind = \"pooled estimate\", value = estimate)),",
          "  with(pooled, data.frame(quantity = paste(\"pooled\", term, \"std_error\"), kind = \"pooled std_error\", value = std_error)),",
          "  with(pooled, data.frame(quantity = paste(\"pooled\", term, \"tau\"), kind = \"tau\", value = tau)),",
          "  with(pooled, data.frame(quantity = paste(\"pooled\", term, \"i2\"), kind = \"i2\", value = i2)),",
          "  with(pooled, data.frame(quantity = paste(\"pooled\", term, \"q\"), kind = \"q\", value = q)))")),
        .reference("stats", "stats", name = "stats::lm and base R, from the definition", c(
          "srl <- read.csv(\"../data/srl.csv\")",
          "# Each learner's own regression on all but the last ceiling(0.2 n) days.",
          "own_fit <- function(d) lm(effort ~ efficacy + planning, data = head(d, nrow(d) - ceiling(0.2 * nrow(d))))",
          "fits <- lapply(split(srl, srl$name), own_fit)",
          "person <- do.call(rbind, lapply(names(fits), function(learner) {",
          "  table <- coef(summary(fits[[learner]]))",
          "  data.frame(subject = learner, term = rownames(table), estimate = table[, \"Estimate\"],",
          "             std_error = table[, \"Std. Error\"], row.names = NULL)",
          "}))",
          "head(person, 9)",
          "# DerSimonian & Laird (1986) for one term; the standard error is Hartung & Knapp's (2001), not allowed",
          "# below the usual random-effects standard error.",
          "pool <- function(d) {",
          "  k <- nrow(d)",
          "  w <- 1 / d$std_error^2",
          "  q <- sum(w * (d$estimate - weighted.mean(d$estimate, w))^2)",
          "  tau2 <- max(0, (q - (k - 1)) / (sum(w) - sum(w^2) / sum(w)))",
          "  w <- 1 / (d$std_error^2 + tau2)",
          "  estimate <- weighted.mean(d$estimate, w)",
          "  hartung_knapp <- sqrt(sum(w * (d$estimate - estimate)^2) / ((k - 1) * sum(w)))",
          "  data.frame(term = d$term[1], estimate = estimate, std_error = max(hartung_knapp, sqrt(1 / sum(w))),",
          "             tau = sqrt(tau2), i2 = max(0, (q - (k - 1)) / q), q = q)",
          "}",
          "pooled <- do.call(rbind, lapply(split(person, person$term), pool))",
          "print(pooled, row.names = FALSE)",
          "measures <- c(\"estimate\", \"std_error\", \"tau\", \"i2\", \"q\")",
          "result <- rbind(",
          "  data.frame(quantity = paste(person$subject, person$term, \"estimate\"), value = person$estimate),",
          "  data.frame(quantity = paste(person$subject, person$term, \"std_error\"), value = person$std_error),",
          "  data.frame(quantity = paste(\"pooled\", rep(pooled$term, times = 5), rep(measures, each = 3)),",
          "             value = unlist(pooled[measures], use.names = FALSE)))")))),
    within_between = list(
      title = "Within-person and between-person effects, REML mixed model",
      description = "Effort regressed on the within-person and between-person components of efficacy with a random intercept per learner, by REML, on the first 80% of each learner's days (36 learners). Person means are taken over those estimation rows. Compared: the fixed effects with their standard errors and the two variance components.",
      covers = c("fit_within_between()", "coefs()", "variance_components()"),
      data = c("36 learners, 156 days" = "srl.csv"),
      needs = "lme4",
      # The package fits this model with lme4, so the reference checks the
      # estimation sample, the person means and the design, and the two fits may
      # differ only through the optimiser's path on an identical problem. 1e-6
      # absolute on estimates that range from 0.01 to about 450.
      tolerance = 1e-6,
      sides = list(
        .idiographic(c(
          "srl <- read.csv(\"../data/srl.csv\")",
          "fit <- fit_within_between(srl, y = \"effort\", x = \"efficacy\", id = \"name\", time = \"day\",",
          "                          model = \"within_between\", estimator = \"reml\", test_prop = 0.2)",
          "fit",
          "fixed <- coefs(fit)",
          "random <- as.data.frame(variance_components(fit))",
          "result <- rbind(",
          "  with(fixed, data.frame(quantity = paste(term, \"estimate\"), kind = \"fixed effect\", value = estimate)),",
          "  with(fixed, data.frame(quantity = paste(term, \"std_error\"), kind = \"standard error\", value = std_error)),",
          "  with(random, data.frame(quantity = paste(level, \"variance\"), kind = \"variance component\", value = variance)))",
          "result")),
        .reference("lme4", "lme4", c(
          "library(lme4)",
          "srl <- read.csv(\"../data/srl.csv\")",
          "# All but the last ceiling(0.2 n) days of each learner, then the complete rows.",
          "first_days <- function(d) head(d, nrow(d) - ceiling(0.2 * nrow(d)))",
          "train <- do.call(rbind, lapply(split(srl, srl$name), first_days))",
          "train <- train[complete.cases(train[c(\"effort\", \"efficacy\")]), ]",
          "train$efficacy_between <- ave(train$efficacy, train$name)",
          "train$efficacy_within <- train$efficacy - train$efficacy_between",
          "fit <- lmer(effort ~ efficacy_within + efficacy_between + (1 | name), data = train, REML = TRUE)",
          "summary(fit)",
          "fixed <- coef(summary(fit))",
          "random <- as.data.frame(VarCorr(fit))",
          "result <- data.frame(",
          "  quantity = c(paste(rownames(fixed), \"estimate\"), paste(rownames(fixed), \"std_error\"),",
          "               paste(random$grp, \"variance\")),",
          "  value = c(fixed[, \"Estimate\"], fixed[, \"Std. Error\"], random$vcov))",
          "result"))))
  )
}

#' Export one case
#'
#' A case whose reference package is not installed is not exported; it is
#' reported with a classed message and a row of `NA` counts.
#' @param name The case's name.
#' @param data The data files, from `.verify_data()`.
#' @return One row: the bundle, its sides and how its compared values came out.
export_case <- function(name, data) {
  cases <- .verify_cases()
  stopifnot("`name` must be one exported case" = length(name) == 1L && name %in% names(cases))
  case <- cases[[name]]
  bundle <- file.path(.verify_base, "bundles", name)
  absent <- case$needs[!vapply(case$needs, requireNamespace, logical(1), quietly = TRUE)]
  if (length(absent)) {
    message(messageCondition(
      sprintf("Case `%s` skipped: reference package %s is not installed.\n", name, toString(absent)),
      class = "idiographic_verify_reference_missing"))
    return(data.frame(bundle = bundle, sides = NA_integer_, compared = NA_integer_, agree = NA_integer_,
                      disagree = NA_integer_, missing = NA_integer_))
  }
  files <- stats::setNames(unname(data[unname(case$data)]), names(case$data))
  verify_export(bundle = bundle, title = case$title, description = case$description, sides = case$sides,
                data = files, tolerance = case$tolerance, covers = case$covers, generator = .verify_generator)
}

requested <- commandArgs(trailingOnly = TRUE)
if (length(requested) == 0L) requested <- names(.verify_cases())
.verify_files <- .verify_data()
print(do.call(rbind, lapply(requested, export_case, data = .verify_files)), row.names = FALSE)
