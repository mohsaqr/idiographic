# Generic heterogeneity inference.
#
# The machinery of Chernozhukov, Demirer, Duflo and Fernandez-Val (2020),
# generalized past treatment effects. The insight of that paper is that any
# person-varying quantity can be studied the same way: build a machine-learning
# *proxy* for it on one sample, then do classical inference about the proxy's
# behaviour on a second, held-out sample. Nothing in that argument is specific to
# a treatment.
#
# So the quantity is pluggable. `target` chooses what varies across people:
#   cate  -- how much a treatment helped        (the classical case)
#   error -- how predictable a person is        (for whom does the model work?)
#   gain  -- how much person-specific modelling beats pooling for this person
#            (for whom is idiographic modelling worth it at all?)
#
# Each target yields, per held-out row, a score `psi` (an unbiased estimate of
# the quantity) and a `proxy` (the ML prediction of it). Everything downstream --
# sorted groups, the heterogeneity test, CLAN, the learner criterion -- is shared.
#
# Two departures from GenericML, both forced by panel data:
#
# 1. Persons, not rows, are the independent units. Rows within a person are
#    correlated, so a row-level standard error is far too small: with a person
#    random effect it under-covers badly (78% instead of 95%). All inference is
#    clustered on the person.
# 2. Splits are over *persons* by default, for the same reason.

#' Study how something varies across people
#'
#' Estimates a person-varying quantity, tests whether it genuinely varies, sorts
#' people by it, and describes who sits at the extremes.
#'
#' What varies is chosen by `target`:
#' \describe{
#'   \item{`cate`}{How much a `treatment` helped. Needs `treatment`.}
#'   \item{`error`}{How predictable each person is. Sorted groups run from the
#'     people the model serves best to the people it fails.}
#'   \item{`gain`}{How much a person-specific model beats a pooled one for this
#'     person -- for whom idiographic modelling actually pays off. Positive means
#'     modelling them alone helped.}
#' }
#'
#' The reported quantities, for any target:
#' \describe{
#'   \item{`average`}{The quantity, averaged over everyone. For `cate` this is
#'     the ATE.}
#'   \item{`group:g1..gK`}{Sorted groups, from the lowest value of the quantity
#'     to the highest.}
#'   \item{`group:top-bottom`}{The gap between the extremes. If its interval
#'     excludes zero, the quantity genuinely differs across people.}
#'   \item{`heterogeneity`}{The slope of the held-out scores on the proxy. A
#'     significant slope means the variation is real and predictable, not noise.}
#' }
#'
#' Inference follows the paper: the data are split many times, each split is
#' analysed separately, and results are aggregated by median with a conservative
#' interval and a doubled p-value. A single split is seed-dependent, which is the
#' problem this design exists to solve. Standard errors are clustered on the
#' person throughout.
#'
#' Note that these splits are *random*, not time-ordered. The question here is
#' whether a quantity varies across people, not whether the future can be
#' forecast; [fit_rolling()] is the verb for the latter.
#'
#' @inheritParams fit_lm
#' @param target What varies across people: `"cate"`, `"error"`, or `"gain"`.
#' @param treatment Binary treatment column. Required when `target = "cate"`.
#' @param model Candidate models for the proxy. The winner is chosen by how well
#'   it *detects* heterogeneity (see [learners()]), not by prediction error.
#' @param estimator Backend for the proxy models. See [fit_ml()].
#' @param num_splits Number of random splits. More splits, less seed-dependence.
#' @param prop_aux Share of the sample used to learn the proxy in each split.
#' @param n_groups Number of sorted groups.
#' @param clan Person-level columns to describe the extreme groups with. Defaults
#'   to the predictors.
#' @param split `"person"` (persons are the independent units) or `"occasion"`
#'   (split rows within each person). `gain` requires `"occasion"`, since a
#'   person needs rows in both halves to have a model of their own.
#' @param conf_level Confidence level.
#' @param ... Passed to the proxy models.
#' @return An `idiographic_heterogeneity` object. See [heterogeneity()], [clan()],
#'   and [learners()].
#' @references Chernozhukov, V., Demirer, M., Duflo, E., & Fernandez-Val, I.
#'   (2020). Generic Machine Learning Inference on Heterogeneous Treatment
#'   Effects in Randomized Experiments. arXiv:1712.04802.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:10, each = 30), day = rep(1:30, 10),
#'                 x1 = rnorm(300), x2 = rnorm(300))
#' d$drug <- rbinom(300, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(300, sd = 0.5)
#'
#' het <- fit_heterogeneity(d, y = "mood", x = c("x1", "x2"), id = "id",
#'                          target = "cate", treatment = "drug",
#'                          num_splits = 20)
#' heterogeneity(het)
#' clan(het)
#' @export
fit_heterogeneity <- function(data, y, x, id,
                              target = c("cate", "error", "gain"),
                              treatment = NULL, model = c("linear", "ridge",
                                                          "tree"),
                              estimator = "native", time = NULL,
                              num_splits = 100L, prop_aux = 0.5, n_groups = 4L,
                              clan = NULL, split = c("person", "occasion"),
                              conf_level = 0.95, ...) {
  target <- match.arg(target)
  split <- match.arg(split)
  # The registry knows which backends exist, so the list is not duplicated here.
  if (!(is.character(estimator) && length(estimator) == 1L &&
        (estimator == "auto" || estimator %in% .idio_registry()$estimator))) {
    stop("`estimator` must be \"auto\" or one of: ",
         paste(sort(unique(.idio_registry()$estimator)), collapse = ", "), ".",
         call. = FALSE)
  }
  .idio_count(num_splits, "num_splits")
  .idio_count(n_groups, "n_groups")
  .idio_proportion(prop_aux, "prop_aux")

  if (target == "cate" && is.null(treatment)) {
    stop("`target = \"cate\"` needs a `treatment` column.", call. = FALSE)
  }
  if (target == "gain") {
    # A person needs rows in both halves to have a model of their own.
    split <- "occasion"
  }

  data <- .idio_check_data(data, y, id)
  x <- .idio_resolve_x(data, x, exclude = c(y, id, treatment),
                       soft_exclude = time)
  keep <- stats::complete.cases(data[c(y, x, treatment)])
  data <- data[keep, , drop = FALSE]
  if (!is.null(time)) data <- data[.idio_order(data, id, time), , drop = FALSE]

  if (!is.null(treatment)) {
    t_info <- .idio_binary_outcome(data[[treatment]])
    data[[treatment]] <- t_info$y
  } else {
    t_info <- NULL
  }
  if (!is.numeric(data[[y]])) {
    stop("`fit_heterogeneity()` needs a numeric outcome.", call. = FALSE)
  }

  clan_vars <- clan %||% x
  clan_vars <- intersect(clan_vars, names(data))
  models <- .idio_ml_models(model, "regression", estimator)
  control <- .idio_ml_control(lambda = 1, alpha = 0.5, k = 5L, ncomp = 2L,
                              mtry = NULL, num_trees = 200L, cost = 1,
                              p = length(x))
  control <- utils::modifyList(control, list(...))

  spec <- list(y = y, x = x, id = id, treatment = treatment, target = target,
               n_groups = as.integer(n_groups), clan = clan_vars,
               conf_level = conf_level, split = split)

  # Every split is an independent replication of the same analysis.
  per_split <- lapply(seq_len(num_splits), function(s) {
    parts <- .idio_split_sample(data, id, prop_aux, split)
    if (is.null(parts)) return(NULL)
    out <- lapply(models, function(m) {
      tryCatch(
        .idio_hetero_once(parts$aux, parts$main, spec, m, estimator, control),
        error = function(e) NULL
      )
    })
    stats::setNames(out, models)
  })
  per_split <- per_split[!vapply(per_split, is.null, logical(1))]
  if (!length(per_split)) {
    stop("No split could be analysed. Check `min` sample sizes and `prop_aux`.",
         call. = FALSE)
  }

  lambda <- .idio_lambda_table(per_split, models)
  best <- .idio_best_learner(lambda)

  het <- .idio_aggregate_splits(per_split, models, "targets", spec)
  cla <- .idio_aggregate_splits(per_split, models, "clan", spec)

  structure(list(
    spec = c(spec, list(models = models, estimator = estimator,
                        num_splits = length(per_split), best = best)),
    heterogeneity = het,
    clan = cla,
    lambda = lambda
  ), class = c("idiographic_heterogeneity", "idiostats_heterogeneity"))
}

# ------------------------------------------------------------------ splits ----

#' Split the sample; persons are the independent units unless told otherwise
#' @noRd
.idio_split_sample <- function(data, id, prop_aux, split) {
  ids <- as.character(data[[id]])
  if (split == "person") {
    persons <- unique(ids)
    if (length(persons) < 4L) return(NULL)
    n_aux <- max(2L, round(length(persons) * prop_aux))
    if (n_aux >= length(persons) - 1L) return(NULL)
    aux_ids <- sample(persons, n_aux)
    in_aux <- ids %in% aux_ids
  } else {
    # Split rows inside each person, so every person appears in both halves.
    # Sample the ROW INDICES themselves: building a logical vector per group and
    # trying to unscramble it afterwards silently mis-maps rows whenever the
    # panel is unbalanced.
    aux_rows <- unlist(lapply(split(seq_along(ids), ids), function(i) {
      n_aux <- max(1L, min(round(length(i) * prop_aux), length(i) - 1L))
      sample(i, n_aux)
    }), use.names = FALSE)
    in_aux <- seq_along(ids) %in% aux_rows
  }
  aux <- data[in_aux, , drop = FALSE]
  main <- data[!in_aux, , drop = FALSE]
  if (!nrow(aux) || !nrow(main)) return(NULL)
  list(aux = aux, main = main)
}

# ------------------------------------------------------------------ targets ---

#' Score and proxy for one split and one candidate model
#' @noRd
.idio_hetero_once <- function(aux, main, spec, model, estimator, control) {
  built <- switch(spec$target,
    cate = .idio_target_cate(aux, main, spec, model, estimator, control),
    error = .idio_target_error(aux, main, spec, model, estimator, control),
    gain = .idio_target_gain(aux, main, spec, model, estimator, control)
  )
  # A target may drop rows it cannot score (`gain` needs people who have a model
  # of their own). The cluster vector and CLAN must be aligned to the rows that
  # SURVIVED, not to the rows we started with -- otherwise the person labels are
  # recycled against the scores and every standard error is quietly wrong.
  main <- main[built$rows %||% seq_len(nrow(main)), , drop = FALSE]
  psi <- built$psi
  proxy <- built$proxy
  cluster <- as.character(main[[spec$id]])
  stopifnot(length(psi) == nrow(main), length(proxy) == nrow(main))

  if (!length(psi) || !stats::sd(proxy, na.rm = TRUE) > 0) return(NULL)

  targets <- .idio_generic_targets(psi, proxy, cluster, spec)
  bin <- .idio_rank_bins(proxy, spec$n_groups)
  clan <- .idio_clan(main, bin, cluster, spec)

  list(targets = targets$table, clan = clan,
       lambda = targets$lambda, lambda_bar = targets$lambda_bar)
}

#' cate: how much the treatment helped. Doubly robust AIPW score.
#' @noRd
.idio_target_cate <- function(aux, main, spec, model, estimator, control) {
  tr <- aux[[spec$treatment]]
  if (length(unique(tr)) < 2L) stop("One treatment arm only.", call. = FALSE)
  x <- spec$x
  mu1 <- .idio_ml_fit(aux[tr == 1L, , drop = FALSE], spec$y, x, model,
                      "regression", control, estimator)
  mu0 <- .idio_ml_fit(aux[tr == 0L, , drop = FALSE], spec$y, x, model,
                      "regression", control, estimator)
  ps <- .idio_ml_fit(aux, spec$treatment, x, "logistic", "classification",
                     control, "native")

  m1 <- .idio_ml_predict(mu1, main[x])
  m0 <- .idio_ml_predict(mu0, main[x])
  e <- pmin(pmax(.idio_ml_predict(ps, main[x]), 0.05), 0.95)
  tt <- main[[spec$treatment]]
  obs <- as.numeric(main[[spec$y]])

  proxy <- m1 - m0
  psi <- proxy + tt * (obs - m1) / e - (1 - tt) * (obs - m0) / (1 - e)
  list(psi = psi, proxy = proxy)
}

#' error: how predictable a person is. Held-out absolute error.
#' @noRd
.idio_target_error <- function(aux, main, spec, model, estimator, control) {
  x <- spec$x
  fit <- .idio_ml_fit(aux, spec$y, x, model, "regression", control, estimator)
  psi <- abs(as.numeric(main[[spec$y]]) - .idio_ml_predict(fit, main[x]))

  # The proxy predicts how badly the model will miss, from the covariates alone.
  aux2 <- aux
  aux2$.idio_err <- abs(as.numeric(aux[[spec$y]]) -
                          .idio_ml_predict(fit, aux[x]))
  pfit <- .idio_ml_fit(aux2, ".idio_err", x, model, "regression", control,
                       estimator)
  list(psi = psi, proxy = .idio_ml_predict(pfit, main[x]))
}

#' gain: how much a person-specific model beats the pooled one, for this person.
#' @noRd
.idio_target_gain <- function(aux, main, spec, model, estimator, control) {
  x <- spec$x
  y <- spec$y
  id <- spec$id
  pooled <- .idio_ml_fit(aux, y, x, model, "regression", control, estimator)

  aux_ids <- as.character(aux[[id]])
  main_ids <- as.character(main[[id]])
  people <- intersect(unique(aux_ids), unique(main_ids))
  if (!length(people)) stop("No person has rows in both halves.", call. = FALSE)

  own <- lapply(people, function(p) {
    rows <- aux[aux_ids == p, , drop = FALSE]
    if (nrow(rows) <= length(x) + 1L) return(NULL)
    tryCatch(.idio_ml_fit(rows, y, x, model, "regression", control, estimator),
             error = function(e) NULL)
  })
  names(own) <- people
  own <- own[!vapply(own, is.null, logical(1))]
  if (!length(own)) stop("No person had enough rows for their own model.",
                         call. = FALSE)

  usable <- main_ids %in% names(own)
  main <- main[usable, , drop = FALSE]
  main_ids <- main_ids[usable]
  obs <- as.numeric(main[[y]])

  err_pooled <- abs(obs - .idio_ml_predict(pooled, main[x]))
  err_own <- abs(obs - vapply(seq_len(nrow(main)), function(i) {
    .idio_ml_predict(own[[main_ids[i]]], main[i, x, drop = FALSE])
  }, numeric(1)))

  # Positive psi = modelling this person alone beat pooling them in.
  psi <- err_pooled - err_own

  # The proxy is the same gain measured inside the auxiliary half: does the
  # apparent benefit of going individual carry over to held-out rows?
  aux_gain <- vapply(names(own), function(p) {
    rows <- aux[aux_ids == p, , drop = FALSE]
    o <- as.numeric(rows[[y]])
    mean(abs(o - .idio_ml_predict(pooled, rows[x]))) -
      mean(abs(o - .idio_ml_predict(own[[p]], rows[x])))
  }, numeric(1))

  list(psi = psi, proxy = unname(aux_gain[main_ids]),
       rows = which(usable))
}

# ---------------------------------------------------------------- inference ---

#' Sorted groups, the heterogeneity slope, and the learner criteria
#' @noRd
.idio_generic_targets <- function(psi, proxy, cluster, spec) {
  conf <- spec$conf_level
  centered <- proxy - mean(proxy)

  # Heterogeneity test: regress the held-out score on the proxy. A non-zero
  # slope means the proxy really does track how people differ.
  blp <- .idio_cluster_lm(psi, cbind(1, centered), cluster, conf)
  rows <- list(
    .idio_target_row("average", blp[1L, ], conf),
    .idio_target_row("heterogeneity", blp[2L, ], conf)
  )

  bin <- .idio_rank_bins(proxy, spec$n_groups)
  dummies <- vapply(seq_len(spec$n_groups), function(g) as.numeric(bin == g),
                    numeric(length(bin)))
  gates <- .idio_cluster_lm(psi, dummies, cluster, conf)
  rows <- c(rows, lapply(seq_len(spec$n_groups), function(g) {
    .idio_target_row(paste0("group:g", g), gates[g, ], conf)
  }))

  # Top minus bottom, with the covariance between them accounted for.
  contrast <- rep(0, spec$n_groups)
  contrast[spec$n_groups] <- 1
  contrast[1L] <- -1
  diff <- .idio_cluster_contrast(psi, dummies, cluster, contrast, conf)
  rows <- c(rows, list(.idio_target_row("group:top-bottom", diff, conf)))

  shares <- colMeans(dummies)
  list(
    table = do.call(rbind, rows),
    # Lambda: how much heterogeneity this learner's proxy actually detects.
    lambda = blp[2L, "estimate"]^2 * stats::var(proxy),
    lambda_bar = sum(shares * gates[, "estimate"]^2)
  )
}

.idio_target_row <- function(label, est, conf) {
  data.frame(effect = label, estimate = unname(est["estimate"]),
             std_error = unname(est["se"]), conf_low = unname(est["lo"]),
             conf_high = unname(est["hi"]), p_value = unname(est["p"]),
             n = unname(est["n"]), n_people = unname(est["clusters"]),
             stringsAsFactors = FALSE)
}

#' Rank-based bins: robust to a proxy with few distinct values
#' @noRd
.idio_rank_bins <- function(v, k) {
  r <- rank(v, ties.method = "first")
  pmin(k, pmax(1L, ceiling(r / (length(r) / k))))
}

#' CLAN: who is in the extreme groups?
#'
#' Compares the average of each variable between the most- and least-affected
#' groups. This is what turns "the top group gains 2.0" into "the top group is
#' the people with high x1".
#'
#' @noRd
.idio_clan <- function(main, bin, cluster, spec) {
  top <- max(bin)
  keep <- bin %in% c(1L, top)
  if (sum(keep) < 4L) return(NULL)
  ind <- as.numeric(bin[keep] == top)
  cl <- cluster[keep]

  rows <- lapply(spec$clan, function(v) {
    val <- suppressWarnings(as.numeric(main[[v]][keep]))
    if (all(is.na(val)) || stats::sd(val, na.rm = TRUE) == 0) return(NULL)
    est <- .idio_cluster_lm(val, cbind(1, ind), cl, spec$conf_level)
    data.frame(
      effect = v,
      estimate = unname(est[2L, "estimate"]),   # top group minus bottom group
      std_error = unname(est[2L, "se"]),
      conf_low = unname(est[2L, "lo"]), conf_high = unname(est[2L, "hi"]),
      p_value = unname(est[2L, "p"]), n = unname(est[2L, "n"]),
      n_people = unname(est[2L, "clusters"]), stringsAsFactors = FALSE
    )
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(NULL)
  do.call(rbind, rows)
}

#' Least squares with standard errors clustered on the person
#'
#' Rows within a person are correlated. A row-level standard error treats 40
#' occasions from one person as 40 independent facts, which they are not: with a
#' person-level random effect the naive interval covers 78% of the time instead
#' of 95%. The cluster-robust sandwich fixes that.
#'
#' @noRd
.idio_cluster_lm <- function(y, X, cluster, conf) {
  X <- as.matrix(X)
  n <- nrow(X)
  k <- ncol(X)
  xtx <- crossprod(X)
  bread <- tryCatch(solve(xtx), error = function(e) MASS_ginv(xtx))
  beta <- as.numeric(bread %*% crossprod(X, y))
  resid <- y - as.numeric(X %*% beta)

  sand <- .idio_sandwich(X, resid, cluster, bread)
  V <- sand$V

  se <- sqrt(pmax(diag(V), 0))
  n_cl <- sand$n_clusters
  df <- sand$df
  crit <- stats::qt(1 - (1 - conf) / 2, df = df)
  stat <- ifelse(se > 0, beta / se, NA_real_)

  cbind(estimate = beta, se = se, lo = beta - crit * se, hi = beta + crit * se,
        p = 2 * stats::pt(-abs(stat), df = df), n = n, clusters = n_cl)
}

#' A linear combination of coefficients, with the same clustered variance
#' @noRd
.idio_cluster_contrast <- function(y, X, cluster, contrast, conf) {
  X <- as.matrix(X)
  n <- nrow(X)
  bread <- tryCatch(solve(crossprod(X)),
                    error = function(e) MASS_ginv(crossprod(X)))
  beta <- as.numeric(bread %*% crossprod(X, y))
  resid <- y - as.numeric(X %*% beta)
  sand <- .idio_sandwich(X, resid, cluster, bread)
  V <- sand$V
  n_cl <- sand$n_clusters

  est <- sum(contrast * beta)
  se <- sqrt(max(as.numeric(t(contrast) %*% V %*% contrast), 0))
  df <- sand$df
  crit <- stats::qt(1 - (1 - conf) / 2, df = df)
  stat <- if (se > 0) est / se else NA_real_
  c(estimate = est, se = se, lo = est - crit * se, hi = est + crit * se,
    p = 2 * stats::pt(-abs(stat), df = df), n = n, clusters = n_cl)
}

#' Sandwich variance, clustered when clustering is possible
#'
#' With more than one cluster this is the usual clustered sandwich. With
#' **one** cluster it must not be: the clustered meat is
#' `(X'e)(X'e)'`, and `X'e` is exactly zero by the normal equations, so the
#' variance collapses to zero and every standard error comes out at ~1e-16 with
#' a p-value of ~0. That is what happens at individual scope, where a unit is
#' one person and therefore one cluster.
#'
#' A single cluster carries no between-cluster information, so there the
#' fallback is the heteroskedasticity-robust row-level sandwich (HC1) -- the
#' rows really are all the information there is -- with degrees of freedom from
#' the rows rather than from the clusters.
#'
#' @noRd
.idio_sandwich <- function(X, resid, cluster, bread) {
  n <- nrow(X)
  k <- ncol(X)
  groups <- split(seq_len(n), cluster)
  n_cl <- length(groups)

  if (n_cl > 1L) {
    meat <- Reduce(`+`, lapply(groups, function(i) {
      tcrossprod(crossprod(X[i, , drop = FALSE], resid[i]))
    }))
    correction <- n_cl / (n_cl - 1L)
    df <- max(n_cl - 1L, 1L)
  } else {
    meat <- crossprod(X * resid)
    correction <- if (n > k) n / (n - k) else 1
    df <- max(n - k, 1L)
  }
  list(V = bread %*% meat %*% bread * correction, n_clusters = n_cl, df = df)
}

# A tiny pseudo-inverse so a singular design degrades rather than throws.
MASS_ginv <- function(m) {
  s <- svd(m)
  keep <- s$d > max(1e-10 * s$d[1L], 0)
  s$v[, keep, drop = FALSE] %*%
    (t(s$u[, keep, drop = FALSE]) / s$d[keep])
}

# --------------------------------------------------------------- aggregate ----

#' Lower and upper median (Comment 4.2 of the paper)
#' @noRd
.idio_med <- function(v) {
  v <- sort(v[is.finite(v)])
  n <- length(v)
  if (!n) return(c(lower = NA_real_, upper = NA_real_, median = NA_real_))
  lower <- v[floor((n + 1) / 2)]
  upper <- v[ceiling((n + 1) / 2)]
  c(lower = lower, upper = upper, median = mean(c(lower, upper)))
}

#' Aggregate one quantity across splits
#'
#' The point estimate is the median across splits. The interval is deliberately
#' conservative: its lower bound is the *upper* median of the lower bounds and
#' its upper bound is the *lower* median of the upper bounds. The p-value is
#' doubled, which is the price of median-aggregating over random splits.
#'
#' @noRd
.idio_aggregate_splits <- function(per_split, models, what, spec) {
  rows <- lapply(models, function(m) {
    tabs <- lapply(per_split, function(s) s[[m]][[what]])
    tabs <- tabs[!vapply(tabs, is.null, logical(1))]
    if (!length(tabs)) return(NULL)
    all <- do.call(rbind, tabs)

    labels <- unique(all$effect)
    out <- lapply(labels, function(lab) {
      sub <- all[all$effect == lab, , drop = FALSE]
      data.frame(
        target = spec$target, model = m, effect = lab,
        estimate = .idio_med(sub$estimate)[["median"]],
        std_error = .idio_med(sub$std_error)[["median"]],
        conf_low = .idio_med(sub$conf_low)[["upper"]],
        conf_high = .idio_med(sub$conf_high)[["lower"]],
        p_value = min(1, 2 * .idio_med(sub$p_value)[["median"]]),
        n = round(.idio_med(sub$n)[["median"]]),
        n_people = round(.idio_med(sub$n_people)[["median"]]),
        splits = nrow(sub), stringsAsFactors = FALSE
      )
    })
    do.call(rbind, out)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) return(.idio_empty_hetero())
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out
}

.idio_empty_hetero <- function() {
  data.frame(target = character(), model = character(), effect = character(),
             estimate = numeric(), std_error = numeric(), conf_low = numeric(),
             conf_high = numeric(), p_value = numeric(), n = numeric(),
             n_people = numeric(), splits = integer(),
             stringsAsFactors = FALSE)
}

#' Median lambda per learner: which proxy actually detects the heterogeneity
#' @noRd
.idio_lambda_table <- function(per_split, models) {
  rows <- lapply(models, function(m) {
    lam <- vapply(per_split, function(s) s[[m]]$lambda %||% NA_real_,
                  numeric(1))
    bar <- vapply(per_split, function(s) s[[m]]$lambda_bar %||% NA_real_,
                  numeric(1))
    data.frame(model = m,
               lambda = .idio_med(lam)[["median"]],
               lambda_bar = .idio_med(bar)[["median"]],
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  out <- out[order(-out$lambda), , drop = FALSE]
  rownames(out) <- NULL
  out
}

.idio_best_learner <- function(lambda) {
  if (!nrow(lambda) || all(is.na(lambda$lambda))) return(NA_character_)
  lambda$model[which.max(lambda$lambda)]
}

# ---------------------------------------------------------------- accessors ---

#' Tidy heterogeneity results
#'
#' @param x An [fit_heterogeneity()] result.
#' @param effect,model Optional filters. `model` defaults to the learner that
#'   best detects heterogeneity.
#' @param all_models Logical. Return every candidate learner instead of the best.
#' @param ... Ignored.
#' @return A data frame.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300))
#' d$drug <- rbinom(300, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
#' het <- fit_heterogeneity(d, "mood", "x1", "id", target = "cate",
#'                          treatment = "drug", num_splits = 10)
#' heterogeneity(het)
#' @export
heterogeneity <- function(x, effect = NULL, model = NULL, all_models = FALSE,
                          ...) {
  if (!inherits(x, "idiostats_heterogeneity")) {
    stop("heterogeneity() needs a fit_heterogeneity() result.", call. = FALSE)
  }
  tab <- x$heterogeneity
  if (!isTRUE(all_models)) {
    tab <- tab[tab$model %in% (model %||% x$spec$best), , drop = FALSE]
  } else if (!is.null(model)) {
    tab <- tab[tab$model %in% model, , drop = FALSE]
  }
  if (!is.null(effect)) tab <- tab[tab$effect %in% effect, , drop = FALSE]
  rownames(tab) <- NULL
  tab
}

#' Who is in the extreme groups
#'
#' Compares the average of each variable between the people the quantity is
#' highest for and the people it is lowest for. Turns "the top group gains 2.0"
#' into "the top group is the people with high `x1`".
#'
#' @param x An [fit_heterogeneity()] result.
#' @param model Optional learner. Defaults to the best one.
#' @param all_models Logical. Return every candidate learner.
#' @param ... Ignored.
#' @return A data frame: one row per variable, the top-minus-bottom difference.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300), x2 = rnorm(300))
#' d$drug <- rbinom(300, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
#' het <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
#'                          treatment = "drug", num_splits = 10)
#' clan(het)
#' @export
clan <- function(x, model = NULL, all_models = FALSE, ...) {
  if (!inherits(x, "idiostats_heterogeneity")) {
    stop("clan() needs a fit_heterogeneity() result.", call. = FALSE)
  }
  tab <- x$clan
  if (!isTRUE(all_models)) {
    tab <- tab[tab$model %in% (model %||% x$spec$best), , drop = FALSE]
  } else if (!is.null(model)) {
    tab <- tab[tab$model %in% model, , drop = FALSE]
  }
  names(tab)[names(tab) == "effect"] <- "variable"
  rownames(tab) <- NULL
  tab
}

#' How well each learner detects heterogeneity
#'
#' `lambda` and `lambda_bar` measure how much variation a learner's proxy
#' actually finds. The best learner is the one that finds the most -- which is
#' **not** the one with the lowest prediction error. A model can predict the
#' outcome well and still be useless at telling people apart.
#'
#' @param x An [fit_heterogeneity()] result.
#' @param ... Ignored.
#' @return A data frame, best first.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300))
#' d$drug <- rbinom(300, 1, 0.5)
#' d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
#' het <- fit_heterogeneity(d, "mood", "x1", "id", target = "cate",
#'                          treatment = "drug", num_splits = 10)
#' learners(het)
#' @export
learners <- function(x, ...) {
  if (!inherits(x, "idiostats_heterogeneity")) {
    stop("learners() needs a fit_heterogeneity() result.", call. = FALSE)
  }
  x$lambda
}

#' @export
print.idiostats_heterogeneity <- function(x, ...) {
  what <- switch(x$spec$target,
                 cate = "treatment effect",
                 error = "predictability (held-out error)",
                 gain = "gain from person-specific modelling")
  cat("Idiographic Heterogeneity\n")
  cat(sprintf("  Varies:      %s\n", what))
  cat(sprintf("  Outcome:     %s\n", x$spec$y))
  if (!is.null(x$spec$treatment)) {
    cat(sprintf("  Treatment:   %s\n", x$spec$treatment))
  }
  cat(sprintf("  Splits:      %d (%s-level, person-clustered SEs)\n",
              x$spec$num_splits, x$spec$split))
  cat(sprintf("  Learners:    %s | best: %s\n",
              paste(x$spec$models, collapse = ", "), x$spec$best))

  tab <- heterogeneity(x)
  avg <- tab[tab$effect == "average", , drop = FALSE]
  if (nrow(avg)) {
    cat(sprintf("  Average:     %.4f [%.4f, %.4f], p = %.3f\n",
                avg$estimate[1L], avg$conf_low[1L], avg$conf_high[1L],
                avg$p_value[1L]))
  }
  tb <- tab[tab$effect == "group:top-bottom", , drop = FALSE]
  if (nrow(tb)) {
    cat(sprintf("  Top-bottom:  %.4f [%.4f, %.4f], p = %.3f\n",
                tb$estimate[1L], tb$conf_low[1L], tb$conf_high[1L],
                tb$p_value[1L]))
  }
  het <- tab[tab$effect == "heterogeneity", , drop = FALSE]
  if (nrow(het)) {
    verdict <- if (isTRUE(het$p_value[1L] < 0.05)) {
      "real"
    } else {
      "not detected"
    }
    cat(sprintf("  Heterogeneity: %s (p = %.3f)\n", verdict, het$p_value[1L]))
  }
  cat("  Use heterogeneity(), clan(), learners()\n")
  invisible(x)
}
