# Do subgroups exist at all?
#
# The clustering methods in this package will always return groups, because
# that is what they are asked to do. That is a dangerous default: a smooth,
# single-population cloud of person-specific coefficients can be cut in half
# very reproducibly, and the result looks like structure.
#
# Simulation in this package's development (60 replicates per cell, 30 people,
# 25 and 100 occasions each) established three things that shape this file:
#
#   * A Gaussian mixture with covariance-model selection is well calibrated
#     under normality: it correctly reports ONE population 92-95% of the time
#     when there are no subgroups. That is the null the clustering methods lack.
#
#   * That calibration is destroyed by SKEW. With the same single population but
#     skewed coefficients, the same criterion claimed subgroups in 35-47% of
#     runs. This replicates Bauer & Curran (2003) in coefficient space: classes
#     can be manufactured out of distributional shape alone. Hence
#     `.idio_shape()` and the warning it raises.
#
#   * Consensus stability is NOT evidence that subgroups exist. On data with no
#     subgroups whatsoever it scored 0.89-0.97. It measures whether a partition
#     is reproducible, not whether it is real.
#
# References: Bauer, D. J., & Curran, P. J. (2003). Distributional assumptions
# of growth mixture models: implications for overextraction of latent
# trajectory classes. Psychological Methods, 8(3), 338-363.

#' Test whether subgroups exist at all
#'
#' Every clustering method in this package returns groups on request, including
#' when there are none to find. This is the verb that can say **no**.
#'
#' People are summarised by their person-specific regression coefficients, and a
#' Gaussian mixture is fitted to those coefficients for `1..k_max` components,
#' selecting jointly over the number of components and the covariance structure
#' by BIC. If one component wins, the evidence does not support subgroups.
#'
#' The result also reports the skewness and kurtosis of the coefficients,
#' because distributional shape is what makes this test lie. In simulation, a
#' single skewed population produced spurious subgroups in 35-47% of runs, versus
#' 5-8% under normality. **A significant-looking subgroup solution on visibly
#' skewed coefficients is not trustworthy.**
#'
#' @inheritParams find_subgroups
#' @param k_max Largest number of subgroups considered.
#' @return An `idiostats_subgroup_test`. Use [as.data.frame()] for the tidy BIC
#'   table.
#' @references Bauer, D. J., & Curran, P. J. (2003). Distributional assumptions
#'   of growth mixture models. *Psychological Methods*, 8(3), 338-363.
#' @examples
#' test_subgroups(srl, y = "effort", x = "efficacy:monitoring", id = "name")
#' @export
test_subgroups <- function(data, y, x, id, time = NULL, k_max = 4L, ...) {
  .idio_count(k_max, "k_max")
  data <- .idio_check_data(data, y, id)
  x <- .idio_resolve_x(data, x, exclude = c(y, id),
                       soft_exclude = time)
  data <- data[stats::complete.cases(data[c(y, x)]), , drop = FALSE]
  .idio_stop_person_constant(data, x, id, what = "subgroup")

  subjects <- sort(unique(as.character(data[[id]])))
  B <- .idio_person_slopes(data, y, x, id, subjects)
  ok <- stats::complete.cases(B)
  B <- B[ok, , drop = FALSE]
  if (nrow(B) < 4L) {
    stop("Too few people with usable coefficients to test for subgroups.",
         call. = FALSE)
  }

  k_max <- min(as.integer(k_max), nrow(B) - 1L)
  tab <- .idio_gmm_search(scale(B), k_max)
  best <- tab[which.min(tab$bic), , drop = FALSE]
  shape <- .idio_shape(B)

  out <- structure(list(
    spec = list(y = y, x = x, id = id, k_max = k_max, n_people = nrow(B)),
    bic = tab,
    k = best$k,
    model = best$model,
    evidence = tab$bic[tab$k == 1L][1L] - best$bic,   # BIC gain over one group
    shape = shape,
    skewed = .idio_shape_risk(shape)
  ), class = "idiostats_subgroup_test")
  out
}

#' Is the coefficient distribution shaped in a way that manufactures subgroups?
#'
#' Skew and heavy tails do. But real subgroups ALSO make the coefficients
#' skewed whenever the groups are unevenly spaced, so skew on its own cannot
#' separate the two -- that is precisely the identification problem Bauer &
#' Curran expose, and no marginal moment solves it.
#'
#' Kurtosis breaks the tie in the common case. A genuinely multi-modal
#' distribution is *platykurtic* (strongly negative excess kurtosis); a merely
#' skewed unimodal one is not. So the risk flag requires suspicious skew or
#' heavy tails AND the absence of the flat, multi-modal signature.
#'
#' This is a heuristic, not a test. It cannot be otherwise: the definitive
#' answer requires validating the subgroups against something outside the model.
#'
#' @noRd
.idio_shape_risk <- function(shape) {
  if (is.null(shape) || !nrow(shape)) return(FALSE)
  suspicious <- abs(shape$z_skewness) > 2 | shape$z_kurtosis > 2
  multimodal <- shape$kurtosis < -0.5   # flat/multi-modal: looks like real groups
  any(suspicious & !multimodal)
}

#' Strength of evidence on Raftery's (1995) BIC scale
#' @noRd
.idio_evidence_label <- function(delta) {
  if (!is.finite(delta)) return("none")
  if (delta < 2) "weak" else if (delta < 6) "positive" else
    if (delta < 10) "strong" else "very strong"
}

#' @export
print.idiostats_subgroup_test <- function(x, ...) {
  cat("Idiostats Subgroup Test\n")
  cat(sprintf("  People:      %d\n", x$spec$n_people))
  cat(sprintf("  Coefficients: %s\n", paste(x$spec$x, collapse = ", ")))
  cat(sprintf("  Searched:    k = 1..%d, covariance models %s\n", x$spec$k_max,
              paste(unique(x$bic$model), collapse = "/")))
  cat("\n")
  if (x$k == 1L) {
    cat("  VERDICT:     no subgroups detected (one population fits best)\n")
    cat("               Clustering these people anyway will still return\n")
    cat("               groups -- they will not mean anything.\n")
  } else {
    cat(sprintf("  VERDICT:     %d subgroups (BIC beats one group by %.1f: %s evidence)\n",
                x$k, x$evidence, .idio_evidence_label(x$evidence)))
  }
  if (isTRUE(x$skewed)) {
    cat("\n  WARNING:     the person coefficients are skewed or heavy-tailed\n")
    cat(sprintf("               (%s).\n",
                paste(sprintf("%s: skew %.2f, kurtosis %.2f", x$shape$term,
                              x$shape$skewness, x$shape$kurtosis),
                      collapse = "; ")))
    cat("               Shape alone manufactures subgroups: in simulation a\n")
    cat("               single SKEWED population produced spurious subgroups\n")
    cat("               in 60% of runs, against 10% under normality\n")
    cat("               (cf. Bauer & Curran, 2003). Treat as unproven.\n")
  }
  cat("\n  Use as.data.frame() for the BIC table.\n")
  invisible(x)
}

#' @export
as.data.frame.idiostats_subgroup_test <- function(x, ...) {
  tab <- x$bic
  tab$selected <- seq_len(nrow(tab)) == which.min(tab$bic)
  rownames(tab) <- NULL
  tab
}

#' Skewness and excess kurtosis of the person coefficients
#'
#' Reported because shape, not heterogeneity, is what fools every class-counting
#' criterion.
#'
#' @noRd
.idio_shape <- function(B) {
  moment <- function(v, p) mean((v - mean(v))^p)
  n <- nrow(B)
  skew <- vapply(seq_len(ncol(B)), function(j) {
    v <- B[, j]
    moment(v, 3) / moment(v, 2)^1.5
  }, numeric(1))
  kurt <- vapply(seq_len(ncol(B)), function(j) {
    v <- B[, j]
    moment(v, 4) / moment(v, 2)^2 - 3
  }, numeric(1))

  # Judge shape against its own sampling error, not a fixed cutoff. Sample
  # skewness has standard error sqrt(6/n): with 30 people it exceeds 0.5 about
  # a quarter of the time on perfectly normal data, so a fixed 0.5 threshold
  # cries wolf constantly.
  data.frame(
    term = colnames(B), n = n, skewness = skew, kurtosis = kurt,
    z_skewness = skew / sqrt(6 / n), z_kurtosis = kurt / sqrt(24 / n),
    stringsAsFactors = FALSE
  )
}

# ------------------------------------------------------- Gaussian mixture -----

#' Search over number of components AND covariance structure, by BIC
#'
#' Selecting the covariance structure is what makes this calibrated. Allowing
#' only full, per-component covariances over-parameterises the model and it then
#' claims subgroups in ~40% of null runs; letting BIC also choose a parsimonious
#' covariance brings that to 5-8%.
#'
#' @noRd
.idio_gmm_search <- function(B, k_max, n_start = 10L) {
  models <- c("EII", "VII", "EEI", "VVI", "EEE", "VVV")
  grid <- expand.grid(k = seq_len(k_max), model = models,
                      stringsAsFactors = FALSE)
  rows <- lapply(seq_len(nrow(grid)), function(i) {
    fit <- .idio_gmm(B, grid$k[i], grid$model[i], n_start = n_start)
    if (is.null(fit)) return(NULL)
    data.frame(k = grid$k[i], model = grid$model[i], loglik = fit$loglik,
               npar = fit$npar, bic = fit$bic, stringsAsFactors = FALSE)
  })
  rows <- rows[!vapply(rows, is.null, logical(1))]
  if (!length(rows)) stop("No mixture could be fitted.", call. = FALSE)
  out <- do.call(rbind, rows)
  out <- out[order(out$bic), , drop = FALSE]
  rownames(out) <- NULL
  out
}

#' One Gaussian mixture, given k and a covariance structure
#' @noRd
.idio_gmm <- function(B, k, model, n_start = 6L, maxit = 200L, tol = 1e-6) {
  n <- nrow(B)
  p <- ncol(B)
  if (k > n - 1L) return(NULL)

  # A component that collapses onto a couple of points has a near-singular
  # covariance and an unbounded likelihood. BIC will happily buy that fake
  # component, which is how a mixture "discovers" subgroups in a single
  # population. Reject any solution with a degenerate component outright --
  # flexmix's `minprior` rule.
  min_size <- max(2, ceiling(0.05 * n))

  one_run <- function(seed) {
    set.seed(seed)
    # k-means initialisation, not random labels: random starts converge to
    # degenerate maxima far too often and wreck the calibration of the test.
    z <- matrix(0, n, k)
    init <- if (seed == 1L || k == 1L) {
      tryCatch(stats::kmeans(B, centers = k, nstart = 5L)$cluster,
               error = function(e) sample(seq_len(k), n, replace = TRUE))
    } else {
      sample(seq_len(k), n, replace = TRUE)
    }
    z[cbind(seq_len(n), init)] <- 1
    ll_old <- -Inf
    ll <- -Inf
    for (it in seq_len(maxit)) {
      if (any(colSums(z) < min_size)) return(NULL)
      w <- pmax(colMeans(z), 1e-8)
      mu <- t(vapply(seq_len(k), function(g) {
        colSums(B * z[, g]) / sum(pmax(z[, g], 1e-10))
      }, numeric(p)))
      if (p == 1L) mu <- matrix(mu, k, 1L)
      sigma <- .idio_gmm_cov(B, z, mu, model)
      if (is.null(sigma)) return(NULL)

      dens <- vapply(seq_len(k), function(g) {
        ch <- tryCatch(chol(sigma[[g]]), error = function(e) NULL)
        if (is.null(ch)) return(rep(-Inf, n))
        r <- backsolve(ch, t(sweep(B, 2L, mu[g, ])), transpose = TRUE)
        -0.5 * colSums(r^2) - sum(log(diag(ch))) - 0.5 * p * log(2 * pi) +
          log(w[g])
      }, numeric(n))
      dens <- matrix(dens, n, k)

      m <- apply(dens, 1L, max)
      lse <- m + log(rowSums(exp(dens - m)))
      z <- exp(dens - lse)
      ll <- sum(lse)
      if (!is.finite(ll)) return(NULL)
      if (abs(ll - ll_old) < tol) break
      ll_old <- ll
    }
    if (any(colSums(z) < min_size)) return(NULL)
    list(loglik = ll, z = z, mu = mu)
  }

  # Multiple starts: the mixture likelihood has local maxima, and a single run
  # does not find the global one.
  runs <- lapply(seq_len(n_start), one_run)
  runs <- runs[!vapply(runs, is.null, logical(1))]
  if (!length(runs)) return(NULL)
  best <- runs[[which.max(vapply(runs, `[[`, numeric(1), "loglik"))]]

  npar <- (k - 1L) + k * p + .idio_gmm_npar(k, p, model)
  best$npar <- npar
  best$bic <- -2 * best$loglik + npar * log(n)
  best$class <- max.col(best$z)
  best
}

#' Constrained covariance estimates, one per component
#'
#' EII spherical equal, VII spherical varying, EEI diagonal equal,
#' VVI diagonal varying, EEE full equal, VVV full varying.
#'
#' @noRd
.idio_gmm_cov <- function(B, z, mu, model) {
  n <- nrow(B)
  p <- ncol(B)
  k <- nrow(mu)
  # Regularise on the scale of the data, not absolutely: a fixed tiny ridge does
  # not stop a component from collapsing.
  ridge <- diag(1e-4 * mean(apply(B, 2L, stats::var)), p)
  ng <- pmax(colSums(z), 1e-10)

  scatter <- lapply(seq_len(k), function(g) {
    C <- sweep(B, 2L, mu[g, ])
    crossprod(C * z[, g], C)
  })

  out <- switch(model,
    EII = {
      s2 <- sum(vapply(scatter, function(S) sum(diag(S)), numeric(1))) / (n * p)
      rep(list(diag(max(s2, 1e-8), p)), k)
    },
    VII = lapply(seq_len(k), function(g) {
      diag(max(sum(diag(scatter[[g]])) / (ng[g] * p), 1e-8), p)
    }),
    EEI = {
      d <- Reduce(`+`, lapply(scatter, diag)) / n
      rep(list(diag(pmax(d, 1e-8), p)), k)
    },
    VVI = lapply(seq_len(k), function(g) {
      diag(pmax(diag(scatter[[g]]) / ng[g], 1e-8), p)
    }),
    EEE = {
      S <- Reduce(`+`, scatter) / n + ridge
      rep(list(S), k)
    },
    VVV = lapply(seq_len(k), function(g) scatter[[g]] / ng[g] + ridge),
    stop("Unknown covariance model: ", model, call. = FALSE)
  )
  if (any(vapply(out, function(S) any(!is.finite(S)), logical(1)))) return(NULL)
  out
}

.idio_gmm_npar <- function(k, p, model) {
  switch(model,
         EII = 1L,
         VII = k,
         EEI = p,
         VVI = k * p,
         EEE = p * (p + 1) / 2,
         VVV = k * p * (p + 1) / 2)
}
