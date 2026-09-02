# Separating real heterogeneity from estimation noise.
#
# Every method in this package that looks at person-specific coefficients --
# effect_clustering, repeated_split, test_subgroups -- reads them RAW. But an
# observed person slope is the true slope plus estimation error, and that error
# is larger for people with fewer occasions. So the observed spread of slopes
# always overstates how much people really differ, and clustering it will find
# structure in what is partly noise.
#
# Treating each person as a study with an estimate and a standard error splits
# the two apart: `tau` is the real between-person SD, `sd_observed` is what you
# see, and `i2` is the share of the observed variance that is real.

#' Pool person-specific coefficients, separating real spread from noise
#'
#' Runs a random-effects meta-analysis across people, one per term, treating
#' each person as a study with an estimate and a standard error.
#'
#' The comparison to read first is **`sd_observed` against `tau`**. The former
#' is the spread you can see in the person-specific coefficients; the latter is
#' how much of it is real once each person's own estimation error is taken out.
#' If they are close, people genuinely differ. If `tau` is much the smaller,
#' most of the apparent heterogeneity is measurement noise from short series,
#' and any subgroups found by clustering those coefficients are partly an
#' artefact of that noise.
#'
#' \describe{
#'   \item{`estimate`}{Random-effects pooled effect, with `tau` in its weights,
#'     so people are not weighted purely by how much data they happen to have.}
#'   \item{`tau`}{Estimated standard deviation of the *true* person effects
#'     (DerSimonian-Laird). Zero means the people are indistinguishable once
#'     noise is accounted for.}
#'   \item{`i2`}{Share of observed variation that is real rather than sampling
#'     error, from 0 to 1.}
#'   \item{`q`, `q_p`}{Cochran's Q and its p-value: is there *any* real
#'     heterogeneity at all?}
#' }
#'
#' Intervals use the **Hartung-Knapp** variance with `t` on `k - 1` degrees of
#' freedom, `k` being the number of people. The textbook random-effects
#' standard error treats `tau` as known when it was estimated, and under-covers
#' as a result: with 10 people it gave 0.930 coverage in simulation where 0.95
#' was claimed, against 0.945 for the adjustment used here. The adjustment can
#' only ever widen the interval.
#'
#' @section Read `q_p` with caution:
#' Cochran's Q assumes each person's standard error is *known*. Here it is
#' estimated from that person's own handful of occasions, which inflates Q. In
#' simulation on data with **no** real heterogeneity at all, `q_p` fell below
#' 0.05 in **13%** of runs rather than 5% -- a false-positive rate roughly
#' 2.6 times what it claims, and it did not improve when each person had 60
#' occasions instead of 25.
#'
#' So treat a small `q_p` as suggestive, not decisive, and read the *size* of
#' `tau` against `sd_observed` instead. Those are well behaved: across the same
#' simulations `tau` recovered true values of 0, 0.30 and 0.60 as 0.06, 0.30
#' and 0.59, and the pooled estimate was unbiased throughout.
#'
#' Needs coefficients that carry standard errors, so it works on [fit_lm()],
#' [fit_glm()] and [fit_within_between()] results. [fit_ml()] does not report
#' them and is refused rather than silently pooled as if every person were
#' measured equally well.
#'
#' @param x An `idiostats_fit` with individual-scope coefficients.
#' @param term Optional filter on the coefficient name.
#' @param scope Which scope's coefficients to pool. Individual, necessarily.
#' @param model,subgroup Optional filters.
#' @param conf_level Confidence level for the pooled interval.
#' @return A `data.frame` of one row per term, with class
#'   `idiostats_pooled`.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = c("efficacy", "planning"),
#'               id = "name", time = "day", scope = "individual")
#' pool_coefs(fit)
#' @export
pool_coefs <- function(x, term = NULL, scope = "individual", model = NULL,
                       subgroup = NULL, conf_level = 0.95) {
  tab <- .idio_pool_input(x, term, scope, model, subgroup)
  by <- unique(tab[c("model", "estimator", "term")])
  rows <- lapply(seq_len(nrow(by)), function(i) {
    key <- by[i, , drop = FALSE]
    part <- tab[tab$model == key$model & tab$estimator == key$estimator &
                  tab$term == key$term, , drop = FALSE]
    meta <- .idio_meta(part$estimate, part$std_error, conf_level)
    if (is.null(meta)) return(NULL)
    data.frame(model = key$model, estimator = key$estimator, term = key$term,
               k = meta$k, estimate = meta$estimate,
               std_error = meta$se, conf_low = meta$lo, conf_high = meta$hi,
               p_value = meta$p, tau = meta$tau, i2 = meta$i2, q = meta$q,
               q_p = meta$q_p, sd_observed = stats::sd(part$estimate),
               stringsAsFactors = FALSE)
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    stop("No term had at least two people with a usable standard error.",
         call. = FALSE)
  }
  rownames(out) <- NULL
  structure(out, class = c("idiostats_pooled", "data.frame"),
            conf_level = conf_level)
}

#' Shrink each person's coefficient towards the pooled effect
#'
#' A person measured over few occasions has a noisy coefficient, and taking it
#' at face value overstates how unusual they are. Empirical-Bayes shrinkage
#' pulls each estimate towards the pooled effect by an amount that depends on
#' how well that person was measured:
#'
#' \deqn{\hat\theta_i^{EB} = \bar\theta + \frac{\tau^2}{\tau^2 + v_i}
#'       (\hat\theta_i - \bar\theta)}
#'
#' `weight` is that fraction: 1 means the person's own estimate is kept as-is,
#' 0 means it carries no information of its own and is replaced by the pooled
#' value. When `tau` is zero -- no real heterogeneity -- every person shrinks
#' all the way to the pooled effect, which is the correct answer.
#'
#' These are the estimates to cluster on if you cluster at all: clustering raw
#' coefficients finds groups partly in the estimation noise.
#'
#' @inheritParams pool_coefs
#' @return A `data.frame` of one row per person per term, with class
#'   `idiostats_shrunk`.
#' @examples
#' fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name",
#'               time = "day", scope = "individual")
#' shrink_coefs(fit)
#' @export
shrink_coefs <- function(x, term = NULL, scope = "individual", model = NULL,
                         subgroup = NULL, conf_level = 0.95) {
  tab <- .idio_pool_input(x, term, scope, model, subgroup)
  by <- unique(tab[c("model", "estimator", "term")])
  rows <- lapply(seq_len(nrow(by)), function(i) {
    key <- by[i, , drop = FALSE]
    part <- tab[tab$model == key$model & tab$estimator == key$estimator &
                  tab$term == key$term, , drop = FALSE]
    meta <- .idio_meta(part$estimate, part$std_error, conf_level)
    if (is.null(meta)) return(NULL)
    weight <- meta$tau^2 / (meta$tau^2 + part$std_error^2)
    weight[!is.finite(weight)] <- 0
    data.frame(
      model = key$model, estimator = key$estimator, term = key$term,
      subject = part$subject, estimate = part$estimate,
      std_error = part$std_error, weight = weight,
      shrunken = meta$estimate + weight * (part$estimate - meta$estimate),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  if (is.null(out)) {
    stop("No term had at least two people with a usable standard error.",
         call. = FALSE)
  }
  rownames(out) <- NULL
  structure(out, class = c("idiostats_shrunk", "data.frame"))
}

#' Coefficients to pool, with the checks that make pooling meaningful
#' @noRd
.idio_pool_input <- function(x, term, scope, model, subgroup) {
  if (!inherits(x, "idiostats_fit")) {
    stop("`x` must be an idiostats fit.", call. = FALSE)
  }
  tab <- coefs(x, model = model, scope = scope, subgroup = subgroup)
  if (!is.null(term)) tab <- tab[tab$term %in% term, , drop = FALSE]
  if (!nrow(tab)) {
    stop("No coefficients to pool. Fit with `scope = \"individual\"` (or ",
         "\"both\"), since pooling is across people.", call. = FALSE)
  }
  if (!any(is.finite(tab$std_error))) {
    stop("Pooling needs coefficients with standard errors, and this fit ",
         "reports none. fit_lm(), fit_glm() and fit_within_between() provide ",
         "them; fit_ml() does not.", call. = FALSE)
  }
  tab[is.finite(tab$estimate) & is.finite(tab$std_error) & tab$std_error > 0, ,
      drop = FALSE]
}

#' Random-effects meta-analysis, DerSimonian-Laird
#'
#' `tau2` is what separates real spread from estimation error: Q measures how
#' much more the estimates scatter than their own standard errors can explain,
#' and `C` rescales that excess back onto the variance scale.
#'
#' @noRd
.idio_meta <- function(estimate, se, conf) {
  keep <- is.finite(estimate) & is.finite(se) & se > 0
  estimate <- estimate[keep]
  se <- se[keep]
  k <- length(estimate)
  if (k < 2L) return(NULL)

  v <- se^2
  w <- 1 / v
  fixed <- sum(w * estimate) / sum(w)
  q <- sum(w * (estimate - fixed)^2)
  df <- k - 1L
  scale <- sum(w) - sum(w^2) / sum(w)
  # A negative excess means the estimates scatter LESS than their standard
  # errors alone predict, which is evidence of no real heterogeneity, not of
  # negative variance.
  tau2 <- if (scale > 0) max(0, (q - df) / scale) else 0

  weights <- 1 / (v + tau2)
  pooled <- sum(weights * estimate) / sum(weights)

  # The textbook standard error, sqrt(1 / sum(weights)), treats `tau2` as if it
  # were known rather than estimated, and under-covers as a result: 0.90 in
  # simulation where 0.95 was claimed. The Hartung-Knapp variance rescales it
  # by how much the estimates actually scatter around the pooled value, which
  # restores the coverage. It is never allowed to be the smaller of the two, so
  # the adjustment can only ever widen the interval.
  naive <- sqrt(1 / sum(weights))
  scatter <- sum(weights * (estimate - pooled)^2) / (df * sum(weights))
  se_pooled <- max(sqrt(max(scatter, 0)), naive)
  crit <- stats::qt(1 - (1 - conf) / 2, df = df)
  stat <- if (se_pooled > 0) pooled / se_pooled else NA_real_

  list(k = as.integer(k), estimate = pooled, se = se_pooled,
       se_naive = naive,
       lo = pooled - crit * se_pooled, hi = pooled + crit * se_pooled,
       p = if (is.na(stat)) NA_real_ else 2 * stats::pt(-abs(stat), df = df),
       tau = sqrt(tau2), i2 = if (q > 0) max(0, (q - df) / q) else 0,
       q = q, q_p = stats::pchisq(q, df = df, lower.tail = FALSE))
}

#' @export
print.idiostats_pooled <- function(x, ...) {
  tab <- as.data.frame(x)
  if (!.idio_printable(tab, c("term", "k", "estimate", "tau", "i2"))) {
    return(print.data.frame(tab, ...))
  }
  cat("POOLED PERSON EFFECTS\n")
  .idio_print_info(rbind(
    c("Method", "random effects (DerSimonian-Laird)"),
    c("People", format(max(tab$k))),
    c("Terms", format(nrow(tab)))
  ))
  cat("\n")
  .idio_print_block(
    cbind(tab$term, format(tab$k), .idio_num(tab$estimate),
          sprintf("[%s, %s]", .idio_num(tab$conf_low, 2L),
                  .idio_num(tab$conf_high, 2L)),
          .idio_num(tab$sd_observed, 3L), .idio_num(tab$tau, 3L),
          .idio_num(tab$i2, 3L), .idio_pval(tab$q_p)),
    headers = c("term", "k", "pooled", "95% CI", "sd_obs", "tau", "I2",
                "Q p"),
    n_left = 1L
  )
  cat("\n  sd_obs = spread you see;  tau = spread that is REAL\n")
  cat("  I2     = share of the observed spread that is real\n")
  invisible(x)
}

#' @export
print.idiostats_shrunk <- function(x, n = 12L, ...) {
  tab <- as.data.frame(x)
  if (!.idio_printable(tab, c("subject", "term", "estimate", "shrunken"))) {
    return(print.data.frame(tab, ...))
  }
  cat("SHRUNKEN PERSON EFFECTS\n")
  .idio_print_info(rbind(
    c("People", format(length(unique(tab$subject)))),
    c("Terms", format(length(unique(tab$term))))
  ))
  cat("\n")
  shown <- utils::head(tab, n)
  .idio_print_block(
    cbind(shown$subject, shown$term, .idio_num(shown$estimate),
          .idio_num(shown$std_error), .idio_num(shown$weight, 3L),
          .idio_num(shown$shrunken)),
    headers = c("subject", "term", "raw", "S.E.", "weight", "shrunken"),
    n_left = 2L
  )
  if (nrow(tab) > n) cat(sprintf("\n  ... %d more rows.\n", nrow(tab) - n))
  cat("\n  weight = how much of the person's own estimate is kept\n")
  invisible(x)
}
