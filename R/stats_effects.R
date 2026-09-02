#' Estimate treatment effects and their heterogeneity
#'
#' Answers a different question from the other fitters: not "how well can we
#' predict this person" but "how much did the treatment help, and for whom".
#'
#' In repeated-measures data the treatment usually varies *within* a person over
#' time, so a person-specific treatment effect is estimable. `fit_effects()`
#' reports one effect per scope: the pooled effect, the effect inside each
#' subgroup, and the effect for each individual.
#'
#' @section Treatment types:
#' The treatment type is detected from the column and can be named outright
#' with `treatment_type`:
#' \describe{
#'   \item{`binary`}{Two levels, or 0/1. Estimated by **AIPW**: two response
#'     surfaces and a propensity model are fitted on the training rows and
#'     applied to the held-out rows to build one doubly robust score per row.
#'     A wrong outcome model or a wrong propensity model can each be tolerated
#'     -- not both. The reported effect is `ATE`.}
#'   \item{`multiarm`}{Three or more unordered arms. The same AIPW score is
#'     built for every arm, with a one-versus-rest propensity, and each arm is
#'     contrasted against `reference`. One set of effects is reported per
#'     contrast, distinguished by the `contrast` column.}
#'   \item{`continuous`}{A dose. AIPW does not apply -- there are no two
#'     surfaces to difference -- so the estimator is the partially linear
#'     double-ML (Robinson) score: `E[Y|X]` and `E[T|X]` are fitted on the
#'     training rows and the effect is the regression of one held-out residual
#'     on the other. The reported effect is `APE`, the change in the outcome
#'     per **one unit** of treatment. **Read the note below on what it
#'     averages.**}
#' }
#'
#' @section What `APE` averages:
#' If the dose effect is the same for everyone, `APE` is that effect. If it
#' varies, `APE` is **not** the plain average `E[tau(X)]`: the partially linear
#' estimator returns the *variance-weighted* average
#'
#' \deqn{\frac{E[\mathrm{Var}(T \mid X)\,\tau(X)]}{E[\mathrm{Var}(T \mid X)]},}
#'
#' which leans towards the people whose dose varies most, because they carry
#' the most information about its effect. The difference is not small: with
#' residualized doses of -1, 1, -3, 3 and true effects of 0, 0, 10, 10, the
#' plain average is 5 while this estimator returns 9.
#'
#' This is the standard target of the partially linear model and it is the
#' right quantity for a summary. It is simply not the same question as "what
#' would the average person gain from one more unit". When the dose effect
#' varies -- and `GATES` in the same output will tell you whether it does --
#' report it as a projection, not as a population mean.
#' A numeric treatment with more than two distinct values is read as a dose.
#' Pass `treatment_type = "multiarm"` to treat its values as unordered arms
#' instead.
#'
#' A two-level non-numeric outcome is modelled on the probability scale, so the
#' reported effect is a risk difference. A 0/1 numeric outcome is modelled as a
#' linear probability, which estimates the same risk difference.
#'
#' @section Reported effects:
#' \describe{
#'   \item{`ATE` / `APE`}{The average treatment effect, or for a dose the
#'     average partial effect per unit.}
#'   \item{`GATES:g1..gK`}{Sorted effect groups. Rows are ranked by their
#'     predicted effect and cut into `n_groups` bins; `g1` is the least-helped
#'     bin and `gK` the most-helped. `GATES:top-bottom` is their difference: if
#'     its confidence interval excludes zero, the treatment genuinely helps some
#'     more than others.}
#'   \item{`BLP:heterogeneity`}{The slope of the held-out scores on the
#'     predicted effect. A significant slope means the predicted heterogeneity
#'     is real and not noise.}
#' }
#'
#' @inheritParams fit_lm
#' @param treatment Treatment column: two levels, several levels, or a dose.
#' @param model Outcome model used for the response surfaces. Any model from
#'   [fit_ml()]; `"auto"` picks the simple linear or logistic model for the
#'   estimator in use.
#' @param estimator Backend for the outcome *and* propensity models. See
#'   [fit_ml()].
#' @param treatment_type One of `"auto"`, `"binary"`, `"multiarm"`,
#'   `"continuous"`.
#' @param reference Arm to contrast against, for a multi-arm treatment.
#'   Defaults to the first level.
#' @param propensity Model for the treatment given the predictors. `"auto"`
#'   follows `estimator`. For a dose this is the `E[T|X]` regression.
#' @param trim Propensity values are held inside `[trim, 1 - trim]` so a
#'   near-zero denominator cannot dominate the score.
#' @param n_groups Number of sorted effect groups for GATES.
#' @param conf_level Confidence level for the reported intervals.
#' @param ... Passed to the outcome models, e.g. `lambda` or `k`.
#' @return An `idiostats_effects` object, which is also an `idiostats_fit`: the
#'   usual accessors work, and [effects()] returns the effect table.
#' @examples
#' set.seed(1)
#' d <- data.frame(
#'   id = rep(1:6, each = 40), day = rep(1:40, 6),
#'   x1 = rnorm(240), x2 = rnorm(240)
#' )
#' d$drug <- rbinom(240, 1, 0.5)
#' # The drug helps people with a high x1 and does nothing for the rest.
#' d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(240, sd = 0.5)
#'
#' fit <- fit_effects(d, y = "mood", treatment = "drug", x = c("x1", "x2"),
#'                    id = "id", time = "day", scope = "pooled")
#' effects(fit)
#'
#' # A dose rather than a switch: the effect is reported per unit of dose.
#' d$dose <- round(runif(240, 0, 10), 1)
#' d$sleep <- 0.3 * d$dose + 0.5 * d$x1 + rnorm(240, sd = 0.5)
#' dose_fit <- fit_effects(d, y = "sleep", treatment = "dose",
#'                         x = c("x1", "x2"), id = "id", time = "day",
#'                         scope = "pooled")
#' effects(dose_fit, effect = "APE")
#' @export
fit_effects <- function(data, y, treatment, x, id, time = NULL, scope = "both",
                        subgroup = NULL, model = "auto",
                        estimator = "native", treatment_type = "auto",
                        reference = NULL, propensity = "auto", trim = 0.05,
                        n_groups = 4L, conf_level = 0.95,
                        test_prop = 0.3, min_train = 10L, min_test = 4L, ...) {
  # The registry knows which backends exist, so the list is not duplicated here.
  if (!(is.character(estimator) && length(estimator) == 1L &&
        (estimator == "auto" || estimator %in% .idio_registry()$estimator))) {
    stop("`estimator` must be \"auto\" or one of: ",
         paste(sort(unique(.idio_registry()$estimator)), collapse = ", "), ".",
         call. = FALSE)
  }
  .idio_count(n_groups, "n_groups")
  if (!(is.numeric(conf_level) && length(conf_level) == 1L &&
        conf_level > 0 && conf_level < 1)) {
    stop("`conf_level` must be a number between 0 and 1.", call. = FALSE)
  }
  if (!(is.numeric(trim) && length(trim) == 1L && trim > 0 && trim < 0.5)) {
    stop("`trim` must be a number between 0 and 0.5.", call. = FALSE)
  }
  if (!(is.character(treatment) && length(treatment) == 1L)) {
    stop("`treatment` must be one column name in `data`.", call. = FALSE)
  }

  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, test_prop = test_prop,
                        min_train = min_train, min_test = min_test,
                        task = "auto", exclude = treatment)
  if (!treatment %in% names(prep$data)) {
    stop("`treatment` must be one column name in `data`.", call. = FALSE)
  }
  t_info <- .idio_treatment_info(prep$data[[treatment]], treatment_type,
                                 reference)
  prep$data[[treatment]] <- t_info$code

  model <- .idio_ml_models(.idio_default_model(model, estimator, prep$task),
                           prep$task, estimator)
  if (length(model) != 1L) {
    stop("`model` must name a single outcome model.", call. = FALSE)
  }
  prop_task <- if (t_info$type == "continuous") "regression" else "classification"
  prop_model <- .idio_ml_models(
    .idio_default_model(propensity, estimator, prop_task), prop_task, estimator)
  if (length(prop_model) != 1L) {
    stop("`propensity` must name a single model.", call. = FALSE)
  }

  control <- .idio_ml_control(lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                              mtry = NULL, num_trees = 500L, cost = 1,
                              p = length(prep$x))
  control <- utils::modifyList(control, list(...))

  done <- lapply(prep$units, function(unit) {
    res <- tryCatch(
      .idio_effects_unit(prep, unit, y, treatment, id, t_info, model,
                         prop_model, estimator, control, n_groups, conf_level,
                         trim),
      error = function(e) e
    )
    if (inherits(res, "error")) {
      return(.idio_tag_error(res, unit, model, estimator))
    }
    res$key <- .idio_unit_key(unit, model)
    res
  })

  out <- .idio_assemble(done, prep$failures, prep$task, prep$y_info,
                        spec = NULL)
  ok <- !vapply(done, inherits, logical(1), "error")
  eff <- do.call(rbind, lapply(done[ok], `[[`, "effects"))
  rownames(eff) <- NULL

  out$effects <- eff %||% .idio_empty_effects()
  out$spec <- .idio_spec("effects", model, estimator, y, prep$x, id,
                         prep$scopes, prep$task, time, prep$groups)
  out$spec$treatment <- treatment
  out$spec$treatment_type <- t_info$type
  out$spec$treated <- t_info$positive
  out$spec$arms <- t_info$arms
  out$spec$reference <- t_info$reference
  out$spec$propensity <- prop_model
  out$spec$n_groups <- as.integer(n_groups)
  class(out) <- c("idiostats_effects", "idiostats_fit")
  out
}

# ------------------------------------------------------- treatment coding ----

#' Classify and code the treatment column
#'
#' A two-valued treatment is binary however it is stored; a numeric treatment
#' with more distinct values is a dose; anything else with three or more levels
#' is a set of unordered arms. Binary coding is delegated to
#' `.idio_binary_outcome()` so the positive class is chosen the same way
#' everywhere -- by sorted level, never by order of appearance.
#'
#' @noRd
.idio_treatment_info <- function(t, type = "auto", reference = NULL) {
  type <- match.arg(type, c("auto", "binary", "continuous", "multiarm"))
  ok <- !is.na(t)
  if (!any(ok)) stop("`treatment` is entirely missing.", call. = FALSE)
  if (is.logical(t)) t <- as.integer(t)
  numeric_t <- is.numeric(t)

  arms <- if (is.factor(t)) {
    levels(t)[levels(t) %in% as.character(t[ok])]
  } else if (numeric_t) {
    as.character(sort(unique(t[ok])))
  } else {
    sort(unique(as.character(t[ok])))
  }
  n_arms <- length(arms)
  if (n_arms < 2L) {
    stop("`treatment` takes only one value, so no effect is estimable.",
         call. = FALSE)
  }

  if (type == "auto") {
    type <- if (n_arms == 2L) "binary" else if (numeric_t) "continuous" else
      "multiarm"
  }
  if (type == "continuous" && !numeric_t) {
    stop("A continuous treatment must be a numeric column.", call. = FALSE)
  }
  if (type == "binary" && n_arms != 2L) {
    stop("A binary treatment needs exactly two observed levels; `",
         "treatment` has ", n_arms, ".", call. = FALSE)
  }

  if (type == "continuous") {
    return(list(type = type, arms = character(0), reference = NA_character_,
                positive = NA_character_, code = as.numeric(t),
                labels = as.character(t)))
  }
  if (type == "binary") {
    # `.idio_binary_outcome()` codes 0/1; the arm machinery indexes 1..K, so
    # the control level is arm 1 and the positive level is arm 2.
    info <- .idio_binary_outcome(t)
    return(list(type = type, arms = info$levels, reference = info$levels[1L],
                positive = info$positive, code = info$y + 1L,
                labels = as.character(t)))
  }

  ref <- reference %||% arms[1L]
  if (!(length(ref) == 1L && as.character(ref) %in% arms)) {
    stop("`reference` must be one of the treatment arms: ",
         paste(arms, collapse = ", "), ".", call. = FALSE)
  }
  list(type = type, arms = arms, reference = as.character(ref),
       positive = NA_character_,
       code = match(as.character(t), arms), labels = as.character(t))
}

#' Resolve `"auto"` to the plainest model the estimator offers for a task
#' @noRd
.idio_default_model <- function(model, estimator, task) {
  if (!identical(model, "auto")) return(model)
  if (estimator == "native") {
    return(if (task == "regression") "linear" else "logistic")
  }
  .idio_ml_choices(task, estimator)[1L]
}

# --------------------------------------------------------------- one unit ----

#' Estimate the effects for one unit from held-out scores
#' @noRd
.idio_effects_unit <- function(prep, unit, y, treatment, id, t_info, model,
                               prop_model, estimator, control, n_groups,
                               conf_level, trim) {
  train <- .idio_unit_rows(prep$data, unit, c("train", "valid"))
  test <- .idio_unit_rows(prep$data, unit, "test")
  if (!nrow(test)) stop("No held-out rows for this unit.", call. = FALSE)
  x <- prep$x
  task <- prep$task

  res <- if (t_info$type == "continuous") {
    .idio_continuous_scores(train, test, y, x, treatment, task, model,
                            prop_model, control, estimator)
  } else {
    .idio_arm_scores(train, test, y, x, treatment, t_info, task, model,
                     prop_model, control, estimator, trim)
  }

  pred <- .idio_prediction_rows(res$predicted, test, y, id, unit, model,
                                estimator, task, prep$y_info)
  pred$treatment <- if (t_info$type == "continuous") {
    as.numeric(test[[treatment]])
  } else {
    t_info$arms[test[[treatment]]]
  }
  # With several contrasts these columns carry the first one; the effect table
  # is where every contrast is reported.
  pred$cate <- res$contrasts[[1L]]$cate
  pred$score <- res$contrasts[[1L]]$score

  # Rows within a person are not independent. When a unit spans several people
  # (pooled, subgroup) the person is the sampling unit and the standard error
  # must be clustered on it -- a row-level SE covers only ~78% of the time.
  # An individual unit is one person, so there its rows are all we have.
  cluster <- as.character(test[[id]])
  rows <- do.call(rbind, lapply(res$contrasts, function(cc) {
    .idio_effect_rows(cc$score, cc$cate, unit, model, estimator, n_groups,
                      conf_level, cluster, cc$label, cc$ate_label)
  }))

  list(fit = res$fits, pred = pred,
       coefs = .idio_coef_rows(res$coef, unit, model, estimator),
       effects = rows)
}

# ------------------------------------------------------------ AIPW (arms) ----

#' Doubly robust scores for a binary or multi-arm treatment
#'
#' One response surface per arm plus a propensity, all fitted on the training
#' rows and applied to the held-out rows. Each non-reference arm is contrasted
#' against the reference.
#'
#' @noRd
.idio_arm_scores <- function(train, test, y, x, treatment, t_info, task, model,
                             prop_model, control, estimator, trim) {
  arms <- t_info$arms
  k_arms <- length(arms)
  a_train <- train[[treatment]]
  a_test <- test[[treatment]]
  if (length(unique(a_train)) < k_arms) {
    stop(if (k_arms == 2L) {
      "Both treated and untreated rows are needed to estimate an effect."
    } else {
      "Every treatment arm needs training rows to estimate an effect."
    }, call. = FALSE)
  }

  mu <- lapply(seq_len(k_arms), function(k) {
    .idio_ml_fit(train[a_train == k, , drop = FALSE], y, x, model, task,
                 control, estimator)
  })
  m <- matrix(unlist(lapply(mu, .idio_ml_predict, newx = test[x])),
              nrow = nrow(test))
  ps <- .idio_arm_propensity(train, x, a_train, test, k_arms, prop_model,
                             control, estimator, trim)

  obs <- as.numeric(test[[y]])
  received <- cbind(seq_len(nrow(test)), a_test)
  indicator <- matrix(0, nrow(test), k_arms)
  indicator[received] <- 1

  # Doubly robust: unbiased if either the outcome models or the propensity
  # model is right.
  score <- m + indicator * (obs - m) / ps$e

  ref <- match(t_info$reference, arms)
  others <- setdiff(seq_len(k_arms), ref)
  contrasts <- lapply(others, function(k) {
    list(label = paste(arms[k], "vs", arms[ref]),
         ate_label = "ATE",
         score = score[, k] - score[, ref],
         cate = m[, k] - m[, ref])
  })

  list(fits = list(mu = mu, propensity = ps$fits),
       predicted = m[received],
       contrasts = contrasts,
       coef = .idio_contrast_coef(mu, others, ref, arms))
}

#' Probability of each arm, trimmed away from zero
#'
#' Two arms get one model and its complement, which keeps the binary case
#' exactly as it was. More arms get one-versus-rest models, normalized to sum
#' to one.
#'
#' @noRd
.idio_arm_propensity <- function(train, x, a_train, test, k_arms, prop_model,
                                 control, estimator, trim) {
  # A floor of `trim` on every arm is only feasible while trim < 1/k_arms.
  # Silently capping an infeasible request would change the inverse weights
  # without saying so, so it is refused; the default adapts downwards instead.
  if (trim >= 1 / k_arms) {
    stop("`trim` must be below 1/", k_arms, " for a ", k_arms,
         "-arm treatment; every arm needs room for a propensity of at least ",
         "`trim`.", call. = FALSE)
  }
  lo <- min(trim, 1 / (2 * k_arms))
  arm_fit <- function(k) {
    d <- train
    d$.idio_arm <- as.integer(a_train == k)
    .idio_ml_fit(d, ".idio_arm", x, prop_model, "classification", control,
                 estimator)
  }
  if (k_arms == 2L) {
    fit <- arm_fit(2L)
    p <- pmin(pmax(.idio_ml_predict(fit, test[x]), lo), 1 - lo)
    return(list(e = cbind(1 - p, p), fits = list(fit)))
  }
  fits <- lapply(seq_len(k_arms), arm_fit)
  p <- matrix(unlist(lapply(fits, .idio_ml_predict, newx = test[x])),
              nrow = nrow(test))
  p <- p / rowSums(p)
  # Trimming must touch ONLY the rows that violate the floor. Shrinking every
  # row towards the uniform would change propensities that were already valid,
  # and AIPW needs the true P(A = a | X) in its denominator -- moving a correct
  # propensity is exactly what destroys the double robustness the score is for.
  violates <- apply(p, 1L, min) < lo
  if (any(violates)) {
    weight <- lo * k_arms
    p[violates, ] <- (1 - weight) * p[violates, , drop = FALSE] +
      weight / k_arms
  }
  list(e = p, fits = fits)
}

#' Coefficient difference between each arm's surface and the reference's
#'
#' For a linear outcome model this is the effect surface: how each predictor
#' modifies the treatment effect.
#'
#' @noRd
.idio_contrast_coef <- function(mu, others, ref, arms) {
  base <- mu[[ref]]$coef
  parts <- lapply(others, function(k) {
    ck <- mu[[k]]$coef
    if (is.null(ck) || is.null(base) || !identical(names(ck), names(base))) {
      return(NULL)
    }
    d <- ck - base
    if (length(others) > 1L) {
      names(d) <- paste0(arms[k], " vs ", arms[ref], ": ", names(d))
    }
    d
  })
  parts <- parts[!vapply(parts, is.null, logical(1))]
  if (!length(parts)) return(numeric(0))
  unlist(parts)
}

# ------------------------------------------------------- DML (continuous) ----

#' Partially linear double-ML scores for a dose
#'
#' AIPW needs two response surfaces to difference, which a dose does not have.
#' The Robinson score residualises both the outcome and the treatment on the
#' predictors and regresses one held-out residual on the other, giving the
#' average change in the outcome per one unit of treatment. Writing it as one
#' score per row -- mean theta by construction -- lets the clustered standard
#' errors and the GATES machinery be reused unchanged.
#'
#' @noRd
.idio_continuous_scores <- function(train, test, y, x, treatment, task, model,
                                    prop_model, control, estimator) {
  if (task != "regression") {
    stop("A continuous treatment needs a numeric outcome.", call. = FALSE)
  }
  m_fit <- .idio_ml_fit(train, y, x, model, "regression", control, estimator)
  g_fit <- .idio_ml_fit(train, treatment, x, prop_model, "regression", control,
                        estimator)

  m_test <- .idio_ml_predict(m_fit, test[x])
  ry <- as.numeric(test[[y]]) - m_test
  rt <- as.numeric(test[[treatment]]) - .idio_ml_predict(g_fit, test[x])
  denom <- mean(rt^2)
  if (!is.finite(denom) || denom <= .Machine$double.eps) {
    stop("The treatment does not vary once the predictors are accounted for.",
         call. = FALSE)
  }
  theta <- sum(rt * ry) / sum(rt^2)
  score <- theta + rt * (ry - theta * rt) / denom

  # The heterogeneity proxy is fitted on the training rows: using the held-out
  # rows to build the ranking and then to test it is the leakage GATES exists
  # to avoid.
  ry_train <- as.numeric(train[[y]]) - .idio_ml_predict(m_fit, train[x])
  rt_train <- as.numeric(train[[treatment]]) - .idio_ml_predict(g_fit,
                                                                train[x])
  beta <- .idio_rlearner_beta(ry_train, rt_train, as.matrix(train[x]), x)
  cate <- as.numeric(cbind(1, as.matrix(test[x])) %*% beta)

  list(fits = list(outcome = m_fit, treatment = g_fit),
       predicted = m_test,
       contrasts = list(list(label = "per unit", ate_label = "APE",
                             score = score, cate = cate)),
       coef = beta)
}

#' Linear dose-effect surface, by the R-learner least squares
#'
#' Minimising sum((ry - theta(X) * rt)^2) over theta(X) = b0 + b'X is ordinary
#' least squares of the outcome residual on the treatment residual interacted
#' with the predictors.
#'
#' @noRd
.idio_rlearner_beta <- function(ry, rt, X, x) {
  basis <- cbind(1, X) * rt
  colnames(basis) <- c("(Intercept)", x)
  beta <- tryCatch(stats::setNames(qr.coef(qr(basis), ry), colnames(basis)),
                   error = function(e) NULL)
  if (is.null(beta)) {
    return(stats::setNames(rep(0, ncol(basis)), colnames(basis)))
  }
  beta[!is.finite(beta)] <- 0
  beta
}

# ---------------------------------------------------------- effect tables ----

#' ATE/APE, GATES and the BLP heterogeneity slope for one contrast
#' @noRd
.idio_effect_rows <- function(score, cate, unit, model, estimator, n_groups,
                              conf_level, cluster, contrast, ate_label) {
  rows <- list(.idio_one_effect(ate_label, score, unit, model, estimator,
                                conf_level, cluster, contrast))

  # GATES needs enough held-out rows to fill the bins, and a predicted effect
  # that actually varies -- otherwise the sort is meaningless.
  usable <- length(score) >= 2L * n_groups &&
    stats::sd(cate, na.rm = TRUE) > .Machine$double.eps
  if (usable) {
    # Bin on ranks, not on quantile breaks: a predicted effect with few distinct
    # values (a stump gives two) collides on quantiles but always ranks cleanly.
    r <- rank(cate, ties.method = "first")
    bin <- pmin(n_groups, pmax(1L, ceiling(r / (length(r) / n_groups))))

    gates <- lapply(seq_len(n_groups), function(g) {
      .idio_one_effect(paste0("GATES:g", g), score[bin == g], unit, model,
                       estimator, conf_level, cluster[bin == g], contrast)
    })
    rows <- c(rows, gates)

    top <- bin == n_groups
    bottom <- bin == 1L
    if (sum(top) > 1L && sum(bottom) > 1L) {
      keep <- top | bottom
      diff <- .idio_cluster_contrast(score[keep],
                                     cbind(as.numeric(bottom[keep]),
                                           as.numeric(top[keep])),
                                     cluster[keep], c(-1, 1), conf_level)
      rows <- c(rows, list(.idio_effect_row("GATES:top-bottom",
                                            diff[["estimate"]], diff[["se"]],
                                            sum(keep), unit, model, estimator,
                                            conf_level, diff[["clusters"]],
                                            contrast, k = 2L)))
    }

    # Best linear predictor: does the predicted effect track the real one?
    blp <- tryCatch({
      est <- .idio_cluster_lm(score, cbind(1, cate - mean(cate)), cluster,
                              conf_level)
      .idio_effect_row("BLP:heterogeneity", est[2L, "estimate"],
                       est[2L, "se"], length(score), unit, model, estimator,
                       conf_level, est[2L, "clusters"], contrast, k = 2L)
    }, error = function(e) NULL)
    if (!is.null(blp)) rows <- c(rows, list(blp))
  }

  do.call(rbind, rows)
}

#' Mean of the held-out scores, with the person as the sampling unit
#'
#' With several people the variance is clustered on the person; with one person
#' (an individual unit) the rows are all the information there is.
#'
#' @noRd
.idio_one_effect <- function(label, score, unit, model, estimator, conf_level,
                             cluster, contrast) {
  n <- length(score)
  if (!n) {
    return(.idio_effect_row(label, NA_real_, NA_real_, 0L, unit, model,
                            estimator, conf_level, 0L, contrast))
  }
  est <- .idio_cluster_lm(score, matrix(1, nrow = n), cluster, conf_level)
  .idio_effect_row(label, est[1L, "estimate"], est[1L, "se"], n, unit, model,
                   estimator, conf_level, est[1L, "clusters"], contrast)
}

.idio_effect_row <- function(label, est, se, n, unit, model, estimator,
                             conf_level, n_people, contrast, k = 1L) {
  # Degrees of freedom come from the number of independent units -- people, not
  # rows -- whenever there is more than one of them. With a single person the
  # rows are all there is, and then `k` matters: an intercept-only mean has one
  # parameter, but the BLP slope and the top-bottom contrast come from
  # two-parameter regressions.
  df <- max(if (n_people > 1L) n_people - 1L else n - k, 1L)
  crit <- stats::qt(1 - (1 - conf_level) / 2, df = df)
  stat <- if (is.finite(se) && se > 0) est / se else NA_real_
  data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = unit$subject, subgroup = unit$subgroup,
    effect = label, contrast = contrast,
    n = as.integer(n), n_people = as.integer(n_people),
    estimate = est, std_error = se,
    conf_low = est - crit * se, conf_high = est + crit * se,
    statistic = stat,
    p_value = if (is.na(stat)) NA_real_ else 2 * stats::pt(-abs(stat), df = df),
    stringsAsFactors = FALSE
  )
}

.idio_empty_effects <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(), effect = character(),
             contrast = character(),
             n = integer(), n_people = integer(), estimate = numeric(),
             std_error = numeric(),
             conf_low = numeric(), conf_high = numeric(),
             statistic = numeric(), p_value = numeric(),
             stringsAsFactors = FALSE)
}

#' Tidy treatment effects
#'
#' A method on the `stats::effects()` generic, so it does not mask anything.
#'
#' @param object An [fit_effects()] result.
#' @param effect Optional filter on the effect label, e.g. `"ATE"`.
#' @param contrast Optional filter on the contrast, e.g. `"b vs a"`.
#' @param scope,subject,subgroup Optional filters.
#' @param sort_by Optional column to sort by.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A data frame of effects with confidence intervals.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:6, each = 40), day = rep(1:40, 6),
#'                 x1 = rnorm(240), x2 = rnorm(240))
#' d$drug <- rbinom(240, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(240, sd = 0.5)
#' fit <- fit_effects(d, "mood", "drug", c("x1", "x2"), "id", scope = "pooled")
#' effects(fit, effect = "ATE")
#' @export
effects.idiostats_effects <- function(object, effect = NULL, contrast = NULL,
                                      scope = NULL, subject = NULL,
                                      subgroup = NULL, sort_by = NULL,
                                      decreasing = FALSE, n = NULL, ...) {
  tab <- object$effects
  if (!is.null(effect)) tab <- tab[tab$effect %in% effect, , drop = FALSE]
  if (!is.null(contrast)) {
    tab <- tab[tab$contrast %in% contrast, , drop = FALSE]
  }
  .idio_filter_table(tab, scope = scope, subject = subject,
                     subgroup = subgroup, sort_by = sort_by,
                     decreasing = decreasing, n = n)
}

#' @export
print.idiostats_effects <- function(x, ...) {
  cat("Idiostats Treatment Effects\n")
  cat(sprintf("  Outcome:     %s\n", x$spec$y))
  treat <- switch(x$spec$treatment_type,
    binary = sprintf("%s (treated = %s)", x$spec$treatment, x$spec$treated),
    multiarm = sprintf("%s (%d arms, reference = %s)", x$spec$treatment,
                       length(x$spec$arms), x$spec$reference),
    sprintf("%s (continuous)", x$spec$treatment)
  )
  cat(sprintf("  Treatment:   %s\n", treat))
  cat(sprintf("  Predictors:  %d (%s)\n", length(x$spec$x),
              paste(x$spec$x, collapse = ", ")))
  cat(sprintf("  ID:          %s\n", x$spec$id))
  cat(sprintf("  Scope:       %s\n", paste(x$spec$scope, collapse = " + ")))
  cat(sprintf("  Model:       %s [%s], propensity %s, %s scores\n",
              x$spec$model, x$spec$estimator, x$spec$propensity,
              if (x$spec$treatment_type == "continuous") "DML" else "AIPW"))

  headline <- x$effects[x$effects$effect %in% c("ATE", "APE") &
                          x$effects$scope == "pooled", , drop = FALSE]
  if (nrow(headline)) {
    for (i in seq_len(nrow(headline))) {
      cat(sprintf("  Pooled %-3s:  %.4f [%.4f, %.4f], p = %.4f%s\n",
                  headline$effect[i], headline$estimate[i],
                  headline$conf_low[i], headline$conf_high[i],
                  headline$p_value[i],
                  if (x$spec$treatment_type == "multiarm") {
                    paste0("  (", headline$contrast[i], ")")
                  } else {
                    ""
                  }))
    }
  }
  het <- x$effects[x$effects$effect == "GATES:top-bottom" &
                     x$effects$scope == "pooled", , drop = FALSE]
  if (nrow(het)) {
    cat(sprintf("  Top-bottom:  %.4f [%.4f, %.4f], p = %.4f\n",
                het$estimate[1L], het$conf_low[1L], het$conf_high[1L],
                het$p_value[1L]))
  }
  if (nrow(x$failures)) {
    cat(sprintf("  Failures:    %d (see $failures)\n", nrow(x$failures)))
  }
  cat("  Use effects(), plot_effects(), metrics()\n")
  invisible(x)
}

#' Plot sorted treatment-effect groups
#'
#' Draws the GATES groups with their confidence intervals: a rising staircase
#' whose ends do not overlap is heterogeneity you can act on.
#'
#' @param x An [fit_effects()] result.
#' @param contrast Which contrast to draw, when the treatment has several arms.
#'   Defaults to the first.
#' @param scope,subject,subgroup Optional filters.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:6, each = 40), day = rep(1:40, 6),
#'                 x1 = rnorm(240), x2 = rnorm(240))
#' d$drug <- rbinom(240, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(240, sd = 0.5)
#' fit <- fit_effects(d, "mood", "drug", c("x1", "x2"), "id", scope = "pooled")
#' plot_effects(fit)
#' @export
plot_effects <- function(x, scope = "pooled", contrast = NULL, subject = NULL,
                         subgroup = NULL, ...) {
  if (!inherits(x, "idiostats_effects")) {
    stop("plot_effects() needs a fit_effects() result.", call. = FALSE)
  }
  tab <- effects(x, scope = scope, contrast = contrast, subject = subject,
                 subgroup = subgroup)
  tab <- tab[grepl("^GATES:g", tab$effect), , drop = FALSE]
  if (nrow(tab) && is.null(contrast)) {
    tab <- tab[tab$contrast == tab$contrast[1L], , drop = FALSE]
  }
  if (!nrow(tab)) {
    plot.new()
    title("No sorted effect groups available")
    return(invisible(tab))
  }

  at <- seq_len(nrow(tab))
  ylim <- range(c(tab$conf_low, tab$conf_high), na.rm = TRUE)
  op <- par(mar = c(5, 4, 3, 1))
  on.exit(par(op), add = TRUE)
  main <- if (x$spec$treatment_type == "multiarm") {
    sprintf("Sorted group effects (GATES): %s", tab$contrast[1L])
  } else {
    "Sorted group effects (GATES)"
  }
  plot(at, tab$estimate, ylim = ylim, xaxt = "n", pch = 19,
       xlab = "Sorted effect group (least helped to most helped)",
       ylab = "Treatment effect", main = main, ...)
  arrows(at, tab$conf_low, at, tab$conf_high, angle = 90, code = 3,
         length = 0.05, col = "grey40")
  axis(1, at = at, labels = sub("^GATES:", "", tab$effect))
  abline(h = 0, col = "firebrick", lwd = 2, lty = 2)
  invisible(tab)
}
