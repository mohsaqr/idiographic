# ---- Native Bayesian multilevel VAR matching Mplus DSEM ----------------------
#
# Clean-room Gibbs sampler that statistically reproduces Mplus DSEM
# (Dynamic Structural Equation Modeling) two-level VAR(1) output --- the same
# thing mlVAR::mlVAR(estimator = "Mplus") produces --- WITHOUT requiring Mplus.
#
# Model (Mplus "temporal = fixed, contemporaneous = fixed"), verified against
# the generated Mplus .out (TECH1 priors + MODEL RESULTS):
#
#   Latent decomposition:  y_it = mu_i + w_it       (mu_i = latent person mean)
#   Within VAR(1):         w_it = B w_{i,t-1} + e_it,  e_it ~ N(0, Sigma_W)
#   Between:               mu_i ~ N(alpha, Sigma_B)
#
# The lagged predictor is centred on the LATENT person mean mu_i (sampled), not
# the observed mean -- this is Mplus's latent mean centring that removes
# Nickell/Ludtke bias. Defaults matched to Mplus BAYES exactly:
#   * B, alpha        ~ N(0, infinity)           (flat / improper)
#   * Sigma_W, Sigma_B ~ IW(0, -(p+1))           (Mplus prints IW(0,-3) for p=2)
# Point estimate reported = posterior MEDIAN (Mplus default), with posterior SD
# and equal-tailed 95% credible interval. The committed fixture metadata records
# the Mplus configuration used for each oracle comparison.

#' Build a Bayesian multilevel VAR network (Mplus DSEM-targeted)
#'
#' @description Native, pure-R Bayesian estimator for a two-level VAR(1) that
#'   statistically reproduces Mplus DSEM output (the estimator behind
#'   `mlVAR::mlVAR(estimator = "Mplus")`) without needing Mplus installed. A
#'   conjugate Gibbs sampler estimates a fixed temporal matrix, a within-person
#'   residual (contemporaneous) network, and a between-person network, using
#'   latent mean centring and Mplus's default priors. Point estimates are
#'   posterior medians with posterior SDs and 95% credible intervals.
#'
#' @details The sampler alternates five conjugate full-conditional draws per
#'   iteration: the latent person means `mu_i` (Gaussian), the fixed temporal
#'   matrix `B` (matrix-normal), the within residual covariance `Sigma_W`
#'   (inverse-Wishart), the grand mean `alpha` (Gaussian), and the between
#'   covariance `Sigma_B` (inverse-Wishart). The lagged predictor is recentred
#'   on the current `mu_i` draw every iteration (latent mean centring). Data
#'   are globally standardized first (matching `mlVAR`'s `scale = TRUE`); the
#'   first observation of each block is used only as a lag (condition-on-first).
#'
#'   Validated to statistical (Monte-Carlo-error) equivalence against real
#'   Mplus 9 DSEM output on standardized synthetic panels: posterior medians of
#'   `B`, `Sigma_W`, `Sigma_B` agree with Mplus to well within a posterior SD.
#'
#' @param data A `data.frame` containing the panel data.
#' @param vars Character vector of variable column names to model (length >= 2).
#' @param id Character string naming the person-ID column.
#' @param day Character string naming the day/session column, or `NULL`.
#' @param beep Character string naming the measurement-occasion column, or
#'   `NULL`. When `NULL`, row position within each (id, day) block is used.
#' @param lags Integer lag order; only `1` is supported (matches Mplus DSEM
#'   defaults here).
#' @param temporal Character. `"fixed"` (default) fits fixed temporal effects
#'   with random intercepts (Mplus DSEM `temporal = "fixed"`). `"random"` fits
#'   the full DSEM with person-specific temporal matrices `B_i` and a full
#'   random-effect covariance over `(mu_i, vec(B_i))`; the temporal network then
#'   reports the posterior mean transition matrix and `attr(fit, "slope_sd")`
#'   holds the per-coefficient random-slope SDs. `"random"` needs more subjects
#'   estimable random-effect covariance: at least `2 * (p + p^2) + 1` subjects.
#' @param contemporaneous Character. Only `"fixed"` is implemented.
#' @param residual Character. `"fixed"` (default) uses one shared population
#'   within-person residual covariance. `"random"` (only with
#'   `temporal = "random"`) gives each subject their own residual covariance
#'   `Sigma_W_i` via a conjugate hierarchical inverse-Wishart
#'   (`Sigma_W_i ~ IW(Lambda, p + 2)`, `Lambda ~ Wishart`), matching DSEM
#'   person-specific innovation variances; the reported contemporaneous network
#'   is then the population-average residual covariance.
#' @param scale Logical. Global grand-mean/SD standardization of each variable
#'   before fitting (Mplus/`mlVAR` `scale = TRUE`). Default `TRUE`.
#' @param scaleWithin Logical. Additionally within-person scale each variable.
#'   Default `FALSE`.
#' @param tinterval Numeric or `NULL`. When supplied, `beep` is treated as a
#'   continuous time variable and binned onto a regular grid of this width
#'   (Mplus `TINTERVAL`); the integer bin becomes the occasion index for
#'   gap-aware lagging, and multiple observations in one (id, day, bin) slot are
#'   collapsed to the first. Lagging is gap-aware in all cases: lag-1 pairs are
#'   only formed between consecutive occasions, so missing occasions never
#'   create spurious lag pairs. Default `NULL`.
#' @param impute Logical. If `TRUE` (only with `temporal = "random"`), missing
#'   observations are imputed **within the model** each MCMC iteration (data
#'   augmentation), rather than dropped: each person's series is expanded to a
#'   full occasion grid and every latent cell is drawn from its Gaussian full
#'   conditional (as an outcome at `t` and a predictor at `t+1`), using a
#'   vectorised even/odd (checkerboard) block sweep. This matches how Mplus /
#'   Stan / JAGS handle missing data and removes the listwise-deletion bias under
#'   heavy missingness, at extra computational cost. Default `FALSE`.
#' @param n_iter Integer. Total MCMC iterations per chain. Default `4000`.
#' @param n_burnin Integer. Burn-in iterations discarded per chain. Default
#'   `n_iter / 2` (Mplus's first-half burn-in convention).
#' @param n_chains Integer. Number of independent chains. Default `2`.
#' @param thin Integer. Keep every `thin`-th post-burn-in draw. Default `1`.
#' @param seed Integer or `NULL`. Base RNG seed (chain `c` uses `seed + c`).
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations before fitting.
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @param verbose Logical. Emit progress messages. Default `FALSE`.
#'
#' @return A `net_mlvar_bayes` object (also inheriting `net_mlvar`), a named
#'   list of three netobjects (`temporal`, `contemporaneous`, `between`) with
#'   posterior-summary attributes. `coefs()` returns a tidy table with
#'   `estimate` (posterior median), `posterior_sd`, `ci_lower`, `ci_upper`,
#'   `p` (one-tailed), and `significant` (95% CI excludes 0). Posterior draws
#'   and the max Gelman-Rubin PSR are kept in attributes.
#'
#' @examples
#' \donttest{
#' set.seed(1)
#' n_id <- 10; n_t <- 40; vars <- c("A", "B")
#' rows <- lapply(seq_len(n_id), function(i) {
#'   y <- matrix(0, n_t, 2)
#'   for (t in 2:n_t) y[t, ] <- c(0.3, 0.15) * y[t - 1, ] + rnorm(2)
#'   data.frame(id = i, beep = seq_len(n_t), A = y[, 1], B = y[, 2])
#' })
#' d <- do.call(rbind, rows)
#' fit <- fit_mlvar_bayes(d, vars = vars, id = "id", beep = "beep",
#'                          n_iter = 2000, seed = 1)
#' print(fit)
#' coefs(fit)
#' }
#' @seealso [fit_mlvar()] (frequentist lmer path), [fit_mlvar_mplus()]
#'   (true-Mplus wrapper).
#' @export
fit_mlvar_bayes <- function(data, vars, id,
                              day = NULL, beep = NULL,
                              lags = 1L,
                              temporal = c("fixed", "default", "random"),
                              contemporaneous = c("fixed", "default"),
                              residual = c("fixed", "random"),
                              scale = TRUE,
                              scaleWithin = FALSE,
                              tinterval = NULL,
                              impute = FALSE,
                              n_iter = 4000L,
                              n_burnin = NULL,
                              n_chains = 2L,
                              thin = 1L,
                              seed = NULL,
                              min_obs = NULL,
                              subject = NULL,
                              verbose = FALSE) {
  temporal <- match.arg(temporal)
  contemporaneous <- match.arg(contemporaneous)
  residual <- match.arg(residual)
  random <- identical(temporal, "random")
  if (identical(residual, "random") && !random) {
    stop("residual = \"random\" requires temporal = \"random\".", call. = FALSE)
  }
  .ido_check_flag(impute, "impute")
  if (isTRUE(impute) && !random) {
    stop("impute = TRUE currently requires temporal = \"random\" (the full DSEM).",
         call. = FALSE)
  }
  if (!contemporaneous %in% c("fixed", "default")) {
    stop("fit_mlvar_bayes() implements contemporaneous = \"fixed\" only.",
         call. = FALSE)
  }
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.character(id), length(id) == 1L)
  stopifnot(is.numeric(lags), length(lags) == 1L, lags == 1L)
  stopifnot(is.numeric(n_iter), n_iter >= 100L,
            is.numeric(n_chains), n_chains >= 1L,
            is.numeric(thin), thin >= 1L)
  .ido_check_flag(scale, "scale")
  .ido_check_flag(scaleWithin, "scaleWithin")
  .ido_check_flag(verbose, "verbose")
  if (is.null(n_burnin)) n_burnin <- as.integer(floor(n_iter / 2))
  stopifnot(is.numeric(n_burnin), n_burnin >= 0L, n_burnin < n_iter)

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  data <- .ido_keep(data, id, min_obs, subject)
  .ido_check_numeric_vars(data, vars)

  if (!is.null(tinterval)) {
    stopifnot(is.numeric(tinterval), length(tinterval) == 1L, tinterval > 0)
  }
  prep <- if (isTRUE(impute)) {
    .mlvb_prepare_grid(data, vars, id, day, beep, scale, scaleWithin, tinterval)
  } else {
    .mlvb_prepare(data, vars, id, day, beep, scale, scaleWithin, tinterval)
  }
  p <- length(vars)
  if (verbose) message("Running ", n_chains, " chain(s) x ", n_iter,
                       " iterations (p = ", p, ", N = ", length(prep$persons),
                       ") ...")

  chains <- lapply(seq_len(n_chains), function(c_i) {
    if (verbose) message("  chain ", c_i, " ...")
    s <- if (is.null(seed)) NULL else seed + c_i
    if (isTRUE(impute)) {
      .mlvb_gibbs_random_impute(prep$persons, p, n_iter, n_burnin, thin, seed = s,
                                residual = residual)
    } else if (random) {
      .mlvb_gibbs_random(prep$persons, p, n_iter, n_burnin, thin, seed = s,
                         residual = residual)
    } else {
      .mlvb_gibbs(prep$persons, p, n_iter, n_burnin, thin, seed = s)
    }
  })

  post <- .mlvb_pool(chains)
  psr  <- .mlvb_psr(chains)
  summ <- .mlvb_summaries(post, vars, psr)
  # Random-slope draws also carry the per-coefficient random-effect SD (sqrt of
  # the slope block variances of Sigma_RE) --- reported but not a network.
  slope_sd <- if (random) {
    sv <- do.call(rbind, lapply(chains, `[[`, "slopeVar"))   # (sum m) x p^2
    matrix(sqrt(apply(sv, 2, stats::median)), p, p,
           dimnames = list(vars, vars))       # [outcome, predictor]
  } else NULL

  temporal_net <- .ido_wrap(summ$B_med, method = "mlvar_bayes_temporal",
                            directed = TRUE)
  contemp_net  <- .ido_wrap(summ$contemp_pcor,
                            method = "mlvar_bayes_contemporaneous",
                            directed = FALSE)
  between_net  <- .ido_wrap(summ$between_pcor, method = "mlvar_bayes_between",
                            directed = FALSE)

  nets <- list(temporal = temporal_net,
               contemporaneous = contemp_net,
               between = between_net)
  attr(nets, "coefs")       <- summ$coefs
  attr(nets, "matrices")    <- list(B = summ$B_med, Sigma_W = summ$SW_med,
                                     Sigma_B = summ$SB_med, alpha = summ$alpha_med)
  attr(nets, "temporal_type") <- if (random) "random" else "fixed"
  attr(nets, "residual_type") <- residual
  attr(nets, "imputed")     <- isTRUE(impute)
  attr(nets, "slope_sd")    <- slope_sd
  attr(nets, "posterior")   <- post
  attr(nets, "psr")         <- psr
  attr(nets, "max_psr")     <- if (any(is.finite(psr))) max(psr[is.finite(psr)]) else NA_real_
  attr(nets, "n_obs")       <- prep$n_obs
  attr(nets, "n_subjects")  <- length(prep$persons)
  attr(nets, "lag")         <- 1L
  attr(nets, "standardize") <- scale
  attr(nets, "scale")       <- scale
  attr(nets, "scaleWithin") <- scaleWithin
  attr(nets, "config")      <- list(
    engine = "bayes", estimator = "native", temporal = temporal,
    contemporaneous = contemporaneous, residual = residual, lags = 1L,
    scale = scale, scaleWithin = scaleWithin, impute = isTRUE(impute)
  )
  attr(nets, "mcmc")        <- list(n_iter = n_iter, n_burnin = n_burnin,
                                    n_chains = n_chains, thin = thin,
                                    n_draws = dim(post$B)[3])
  attr(nets, "group_col")   <- "network_type"
  class(nets) <- c("net_mlvar_bayes", "net_mlvar", "cograph_group",
                   "netobject_group")
  nets
}

# ---- Data preparation --------------------------------------------------------

#' Global (and optional within) standardization + per-person current/lag arrays.
#'
#' Mirrors mlVAR's Mplus front end: each variable is globally z-scored
#' (`scale = TRUE`, sample SD), optionally within-person scaled, ordered by
#' (id, day, beep), and split into per-block lag-1 pairs (condition-on-first).
#'
#' Lagging is **gap-aware**: a lag pair is only formed between rows at
#' *consecutive* measurement occasions (occasion index differing by exactly 1)
#' within the same (id, day) block, so missing occasions do not create spurious
#' lag-1 pairs across a gap (matching Mplus's `&1` operator and the frequentist
#' `fit_mlvar()` beep-grid augmentation). With `tinterval`, a continuous time
#' column is first binned onto a regular grid of that width (Mplus `TINTERVAL`),
#' the resulting integer bin becomes the occasion index, and rows falling in the
#' same (id, day, bin) are collapsed to the first observation.
#' @noRd
.mlvb_prepare <- function(data, vars, id, day, beep, scale, scaleWithin,
                          tinterval = NULL) {
  df <- as.data.frame(data)
  md <- c(id, if (!is.null(day)) day, if (!is.null(beep)) beep)
  df <- df[stats::complete.cases(df[, md, drop = FALSE]), , drop = FALSE]

  if (isTRUE(scale)) {
    for (v in vars) {
      x <- as.numeric(df[[v]]); s <- stats::sd(x, na.rm = TRUE)
      df[[v]] <- if (is.na(s) || s == 0) 0 else (x - mean(x, na.rm = TRUE)) / s
    }
  }
  if (isTRUE(scaleWithin)) {
    for (v in vars) {
      df[[v]] <- stats::ave(df[[v]], df[[id]], FUN = function(z) {
        s <- stats::sd(z, na.rm = TRUE)
        if (is.na(s) || s == 0) z - mean(z, na.rm = TRUE) else
          (z - mean(z, na.rm = TRUE)) / s
      })
    }
  }

  idv  <- df[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(df)) else df[[day]]

  # Integer occasion index used for gap-aware lagging.
  if (!is.null(tinterval)) {
    if (is.null(beep)) {
      stop("`tinterval` requires a `beep`/time column to bin.", call. = FALSE)
    }
    t0  <- min(df[[beep]], na.rm = TRUE)
    occ <- as.integer(round((df[[beep]] - t0) / tinterval))
  } else if (!is.null(beep)) {
    occ <- df[[beep]]                                   # assumed occasion codes
  } else {
    occ <- stats::ave(seq_len(nrow(df)), idv, dayv, FUN = seq_along)
  }

  ord <- order(idv, dayv, occ)
  df <- df[ord, , drop = FALSE]; idv <- idv[ord]; dayv <- dayv[ord]; occ <- occ[ord]

  # TINTERVAL: collapse multiple observations sharing a (id, day, bin) slot.
  if (!is.null(tinterval)) {
    uk <- !duplicated(paste(idv, dayv, occ, sep = "\r"))
    df <- df[uk, , drop = FALSE]; idv <- idv[uk]; dayv <- dayv[uk]; occ <- occ[uk]
  }

  Y <- as.matrix(df[, vars, drop = FALSE])
  blk <- paste(idv, dayv, sep = "\r")

  persons <- lapply(unique(idv), function(i) {
    sel <- idv == i
    Yi <- Y[sel, , drop = FALSE]; bi <- blk[sel]; oi <- occ[sel]
    n <- length(bi)
    # row t has a lag iff row t-1 is the same block AND the immediately
    # preceding occasion (occ diff == 1), i.e. no gap.
    same <- if (n >= 2L) {
      c(FALSE, bi[-1L] == bi[-n] & (oi[-1L] - oi[-n]) == 1L)
    } else rep(FALSE, n)
    idx  <- which(same)
    keep <- idx[stats::complete.cases(Yi[idx, , drop = FALSE]) &
                stats::complete.cases(Yi[idx - 1L, , drop = FALSE])]
    list(cur = Yi[keep, , drop = FALSE],
         lag = Yi[keep - 1L, , drop = FALSE])
  })
  persons <- Filter(function(pp) nrow(pp$cur) >= 1L, persons)
  if (length(persons) < 2L) {
    stop("Need at least 2 subjects with usable lag pairs for a two-level model.",
         call. = FALSE)
  }
  list(persons = persons,
       n_obs = sum(vapply(persons, function(pp) nrow(pp$cur), integer(1))))
}

# ---- Sampling primitives (pure R, no external MCMC deps) ---------------------

#' Draw W ~ Wishart(df, Scale) via the Bartlett decomposition. `df` may be
#' non-integer; requires `df > p - 1`.
#' @noRd
.mlvb_rwishart <- function(df, Scale) {
  p <- nrow(Scale)
  L <- t(chol(Scale))
  A <- matrix(0, p, p)
  diag(A) <- sqrt(stats::rchisq(p, df = df - seq_len(p) + 1))
  if (p > 1L) A[lower.tri(A)] <- stats::rnorm(p * (p - 1) / 2)
  LA <- L %*% A
  tcrossprod(LA)
}

#' Draw Sigma ~ Inverse-Wishart(S, nu) with density
#' proportional to |Sigma|^{-(nu+p+1)/2} exp(-1/2 tr(S Sigma^{-1})).
#' Uses Sigma^{-1} ~ Wishart(nu, S^{-1}).
#' @noRd
.mlvb_riwish <- function(nu, S) {
  K <- .mlvb_rwishart(nu, .mlvb_solve(S))
  .mlvb_solve(K)
}

#' Robust symmetric-matrix inverse: plain solve, then a tiny ridge, then a
#' symmetric eigen pseudo-inverse — so a numerically singular matrix never
#' throws (it degrades to a regularised inverse instead).
#' @noRd
.mlvb_solve <- function(M) {
  out <- tryCatch(solve(M), error = function(e) NULL)
  if (is.null(out)) {
    out <- tryCatch(solve(M + diag(1e-8, nrow(M))), error = function(e) NULL)
  }
  if (is.null(out)) {
    S <- (M + t(M)) / 2
    ev <- eigen(S, symmetric = TRUE)
    d <- ev$values; d[abs(d) < 1e-10] <- 1e-10
    out <- ev$vectors %*% (t(ev$vectors) / d)
  }
  (out + t(out)) / 2
}

#' Draw a single multivariate normal via Cholesky, with an eigen fallback for a
#' numerically near-singular / non-positive-definite covariance.
#' @noRd
.mlvb_rmvn <- function(mean, Sigma) {
  n <- length(mean)
  L <- tryCatch(t(chol(Sigma)), error = function(e) {
    S <- (Sigma + t(Sigma)) / 2
    ev <- eigen(S, symmetric = TRUE)
    ev$values[ev$values < 0] <- 0
    ev$vectors %*% diag(sqrt(ev$values), n)
  })
  as.numeric(mean + L %*% stats::rnorm(n))
}

# ---- One Gibbs chain ---------------------------------------------------------

#' Conjugate Gibbs sampler for the fixed/fixed two-level VAR(1).
#' Returns kept draws for B (p x p x m), Sigma_W, Sigma_B, alpha (m x p).
#' @noRd
.mlvb_gibbs <- function(persons, p, n_iter, n_burnin, thin, seed = NULL) {
  if (!is.null(seed)) set.seed(seed)
  N <- length(persons)
  Ti <- vapply(persons, function(pp) nrow(pp$cur), integer(1))
  # The p x p between-subjects covariance has an improper-prior posterior
  # IW(., N - p - 1); a proper, full-rank draw needs N - p - 1 >= p, i.e.
  # N >= 2p + 1 (otherwise the Bartlett chi-square d.f. reach 0 and produce NaN).
  if (N < 2L * p + 1L) {
    stop("Bayesian mlVAR (temporal = \"fixed\") needs at least ", 2L * p + 1L,
         " subjects for p = ", p, " to estimate the between-subjects covariance; ",
         "with fewer subjects use fit_var_bayes() for a single-level VAR.",
         call. = FALSE)
  }

  B <- matrix(0, p, p); SigmaW <- diag(p); SigmaB <- diag(p)
  alpha <- rep(0, p); mu <- matrix(0, N, p)

  keep_it <- seq(n_burnin + 1L, n_iter, by = thin)
  m <- length(keep_it)
  out <- list(B = array(0, c(p, p, m)), SW = array(0, c(p, p, m)),
              SB = array(0, c(p, p, m)), alpha = matrix(0, m, p))
  ki <- 0L

  for (it in seq_len(n_iter)) {
    ## (1) latent person means mu_i | B, Sigma_W, alpha, Sigma_B
    SWinv <- .mlvb_solve(SigmaW); SBinv <- .mlvb_solve(SigmaB)
    A <- diag(p) - B
    AtSWinv <- crossprod(A, SWinv)             # A' Sigma_W^{-1}
    AtSWinvA <- AtSWinv %*% A
    base_rhs <- SBinv %*% alpha
    for (i in seq_len(N)) {
      cur <- persons[[i]]$cur; lg <- persons[[i]]$lag
      r <- cur - lg %*% t(B)                   # r_it = y_it - B y_{i,t-1}
      prec <- SBinv + Ti[i] * AtSWinvA
      Vi <- .mlvb_solve(prec)
      mi <- Vi %*% (base_rhs + AtSWinv %*% colSums(r))
      mu[i, ] <- .mlvb_rmvn(mi, Vi)
    }

    ## within deviations w = y - mu_i
    Wcur <- do.call(rbind, lapply(seq_len(N), function(i)
      persons[[i]]$cur - rep(mu[i, ], each = Ti[i])))
    Wlag <- do.call(rbind, lapply(seq_len(N), function(i)
      persons[[i]]$lag - rep(mu[i, ], each = Ti[i])))
    n <- nrow(Wcur)

    ## (2) B | Sigma_W, w  --- matrix-normal (flat prior)
    XtXinv <- .mlvb_solve(crossprod(Wlag))
    Bt_hat <- XtXinv %*% crossprod(Wlag, Wcur)          # p x p = B'
    Z <- matrix(stats::rnorm(p * p), p, p)
    Bt <- Bt_hat + t(chol(XtXinv)) %*% Z %*% chol(SigmaW)
    B <- t(Bt)

    ## (3) Sigma_W | B, w  --- IW(E'E, n - p - 1)
    E <- Wcur - Wlag %*% Bt
    SigmaW <- .mlvb_riwish(n - p - 1, crossprod(E))

    ## (4) alpha | mu, Sigma_B  --- N(mean(mu), Sigma_B / N)
    alpha <- .mlvb_rmvn(colMeans(mu), SigmaB / N)

    ## (5) Sigma_B | mu, alpha --- IW(SS, N - p - 1)
    dev <- sweep(mu, 2, alpha)
    SigmaB <- .mlvb_riwish(N - p - 1, crossprod(dev))

    if (it %in% keep_it) {
      ki <- ki + 1L
      out$B[, , ki] <- B; out$SW[, , ki] <- SigmaW
      out$SB[, , ki] <- SigmaB; out$alpha[ki, ] <- alpha
    }
  }
  out
}

# ---- Random-slopes (full DSEM) sampler --------------------------------------

#' Gaussian conditional of block `idxA` given block `idxB = xB` under N(gamma, S).
#' @noRd
.mlvb_cond_normal <- function(gamma, S, idxA, idxB, xB) {
  SAA <- S[idxA, idxA, drop = FALSE]; SAB <- S[idxA, idxB, drop = FALSE]
  SBB <- S[idxB, idxB, drop = FALSE]
  SBBi <- .mlvb_solve(SBB)
  m <- gamma[idxA] + SAB %*% SBBi %*% (xB - gamma[idxB])
  V <- SAA - SAB %*% SBBi %*% t(SAB)
  list(mean = as.numeric(m), cov = (V + t(V)) / 2)
}

#' Conjugate block Gibbs for the full DSEM: person-specific temporal matrices
#' B_i with random effects theta_i = (mu_i, vec(B_i)) ~ N(gamma, Sigma_RE),
#' within residual Sigma_W. Priors: gamma flat N(0, inf); Sigma_RE, Sigma_W
#' ~ IW(0, -(dim+1)). Latent mean centring via the sampled mu_i. Validated at
#' p = 1 against Mplus DSEM random-AR; dimension-general for p >= 1.
#'
#' The (mu_i, B_i) block is updated by two conditionally-linear Gaussian steps
#' (mu_i | B_i, then vec(B_i) | mu_i via a Kronecker-form multivariate
#' regression), each using the Gaussian conditional of the random-effect prior.
#' Returns the same slot names as the fixed sampler (B = gamma's slope block,
#' SB = intercept block of Sigma_RE) so downstream pooling/summaries are shared,
#' plus `slopeVar` (kept slope-block variances, rows = draws, cols = p^2).
#' @noRd
.mlvb_gibbs_random <- function(persons, p, n_iter, n_burnin, thin, seed = NULL,
                               residual = "fixed") {
  if (!is.null(seed)) set.seed(seed)
  N <- length(persons)
  Ti <- vapply(persons, function(pp) nrow(pp$cur), integer(1))
  K <- p + p * p
  idx_mu <- seq_len(p); idx_B <- p + seq_len(p * p)
  # The K x K random-effect covariance has an improper-prior posterior
  # IW(., N - (K + 1)); a proper, full-rank draw needs N - (K + 1) >= K, i.e.
  # N >= 2K + 1 (otherwise the Bartlett chi-square d.f. reach 0).
  if (N < 2L * K + 1L) {
    stop("Random-slope DSEM needs at least ", 2L * K + 1L, " subjects for p = ",
         p, " (the ", K, "-dim random-effect covariance is otherwise not ",
         "estimable). Use temporal = \"fixed\".", call. = FALSE)
  }
  rand_resid <- identical(residual, "random")

  B_i <- replicate(N, matrix(0, p, p), simplify = FALSE)
  mu <- matrix(0, N, p)
  gamma <- numeric(K); Sre <- diag(0.1, K)
  SigmaW <- diag(p)                                    # shared (residual="fixed")
  # Person-specific innovation covariances via a conjugate hierarchical IW:
  #   Sigma_W_i ~ IW(Lambda, nu0);  Lambda ~ Wishart(V0, m0).
  SigmaW_i <- replicate(N, diag(p), simplify = FALSE)
  Lambda <- diag(p); nu0 <- p + 2L; V0inv <- diag(p); m0 <- p + 1L

  keep_it <- seq(n_burnin + 1L, n_iter, by = thin); m <- length(keep_it)
  out <- list(B = array(0, c(p, p, m)), SW = array(0, c(p, p, m)),
              SB = array(0, c(p, p, m)), alpha = matrix(0, m, p),
              slopeVar = matrix(0, m, p * p))
  ki <- 0L
  for (it in seq_len(n_iter)) {
    SWinv <- .mlvb_solve(SigmaW)
    SWinv_i <- if (rand_resid) lapply(SigmaW_i, .mlvb_solve) else NULL
    theta <- matrix(0, N, K)
    for (i in seq_len(N)) {
      cur <- persons[[i]]$cur; lg <- persons[[i]]$lag; T <- Ti[i]
      Bi <- B_i[[i]]
      SWi <- if (rand_resid) SWinv_i[[i]] else SWinv    # person-specific precision
      ## mu_i | B_i
      A <- diag(p) - Bi
      r <- cur - lg %*% t(Bi)                      # T x p
      cn <- .mlvb_cond_normal(gamma, Sre, idx_mu, idx_B, as.vector(Bi))
      V0i <- .mlvb_solve(cn$cov)
      prec <- T * crossprod(A, SWi) %*% A + V0i
      rhs  <- crossprod(A, SWi) %*% colSums(r) + V0i %*% cn$mean
      Vi <- .mlvb_solve(prec)
      mu[i, ] <- .mlvb_rmvn(as.numeric(Vi %*% rhs), Vi)
      ## vec(B_i) | mu_i   (Kronecker-form multivariate regression)
      Xl <- lg - rep(mu[i, ], each = T); Wc <- cur - rep(mu[i, ], each = T)
      cnB <- .mlvb_cond_normal(gamma, Sre, idx_B, idx_mu, mu[i, ])
      Vb0 <- .mlvb_solve(cnB$cov)
      prec_b <- kronecker(crossprod(Xl), SWi) + Vb0
      rhs_b  <- as.vector(SWi %*% crossprod(Wc, Xl)) + Vb0 %*% cnB$mean
      Vb <- .mlvb_solve(prec_b)
      vecB <- .mlvb_rmvn(as.numeric(Vb %*% rhs_b), Vb)
      Bi <- matrix(vecB, p, p)
      B_i[[i]] <- Bi
      theta[i, ] <- c(mu[i, ], as.vector(Bi))
    }
    ## gamma | theta, Sre  (flat prior)
    gamma <- .mlvb_rmvn(colMeans(theta), Sre / N)
    ## Sigma_RE | theta, gamma
    dev <- sweep(theta, 2, gamma)
    Sre <- .mlvb_riwish(N - (K + 1L), crossprod(dev))
    ## Residual covariance
    per_E <- function(i) {
      T <- Ti[i]
      (persons[[i]]$cur - rep(mu[i, ], each = T)) -
        (persons[[i]]$lag - rep(mu[i, ], each = T)) %*% t(B_i[[i]])
    }
    if (rand_resid) {
      # Sigma_W_i | E_i, Lambda ~ IW(Lambda + E_i'E_i, nu0 + T_i)
      SigmaW_i <- lapply(seq_len(N), function(i)
        .mlvb_riwish(nu0 + Ti[i], Lambda + crossprod(per_E(i))))
      # Lambda | {Sigma_W_i} ~ Wishart(m0 + N*nu0, (V0inv + sum Sigma_i^{-1})^{-1})
      sum_inv <- Reduce(`+`, lapply(SigmaW_i, .mlvb_solve))
      Lambda <- .mlvb_rwishart(m0 + N * nu0, .mlvb_solve(V0inv + sum_inv))
      SigmaW_pop <- Reduce(`+`, SigmaW_i) / N          # population-average
    } else {
      E <- do.call(rbind, lapply(seq_len(N), per_E))
      SigmaW <- .mlvb_riwish(nrow(E) - p - 1, crossprod(E))
      SigmaW_pop <- SigmaW
    }

    if (it %in% keep_it) {
      ki <- ki + 1L
      out$B[, , ki] <- matrix(gamma[idx_B], p, p)     # mean transition matrix
      out$SW[, , ki] <- SigmaW_pop
      out$SB[, , ki] <- Sre[idx_mu, idx_mu, drop = FALSE]
      out$alpha[ki, ] <- gamma[idx_mu]
      out$slopeVar[ki, ] <- diag(Sre[idx_B, idx_B, drop = FALSE])
    }
  }
  out
}

# ---- Missing-data imputation (data augmentation) ----------------------------

#' Build per-person full occasion grids (with an NA mask) for imputation.
#'
#' Same scaling / occasion logic as `.mlvb_prepare`, but instead of dropping
#' incomplete rows each (id, day) block is expanded to a full grid over its
#' observed occasion range; absent occasions and NA cells become latent values
#' to be imputed. Each person carries a list of blocks `list(Y, M)` where `Y` is
#' the (imputation-initialised) grid and `M` the observed mask.
#' @noRd
.mlvb_prepare_grid <- function(data, vars, id, day, beep, scale, scaleWithin,
                               tinterval = NULL, grid_cap = 5000L) {
  df <- as.data.frame(data)
  md <- c(id, if (!is.null(day)) day, if (!is.null(beep)) beep)
  df <- df[stats::complete.cases(df[, md, drop = FALSE]), , drop = FALSE]
  if (isTRUE(scale)) for (v in vars) {
    x <- as.numeric(df[[v]]); s <- stats::sd(x, na.rm = TRUE)
    df[[v]] <- if (is.na(s) || s == 0) 0 else (x - mean(x, na.rm = TRUE)) / s
  }
  if (isTRUE(scaleWithin)) for (v in vars) {
    df[[v]] <- stats::ave(df[[v]], df[[id]], FUN = function(z) {
      s <- stats::sd(z, na.rm = TRUE)
      if (is.na(s) || s == 0) z - mean(z, na.rm = TRUE) else
        (z - mean(z, na.rm = TRUE)) / s
    })
  }
  idv  <- df[[id]]
  dayv <- if (is.null(day)) rep(1L, nrow(df)) else df[[day]]
  if (!is.null(tinterval)) {
    if (is.null(beep)) stop("`tinterval` requires a `beep`/time column.", call. = FALSE)
    t0 <- min(df[[beep]], na.rm = TRUE)
    occ <- as.integer(round((df[[beep]] - t0) / tinterval))
  } else if (!is.null(beep)) {
    occ <- as.integer(round(df[[beep]] - min(df[[beep]], na.rm = TRUE)))
  } else {
    occ <- stats::ave(seq_len(nrow(df)), idv, dayv, FUN = seq_along) - 1L
  }
  ord <- order(idv, dayv, occ)
  df <- df[ord, , drop = FALSE]; idv <- idv[ord]; dayv <- dayv[ord]; occ <- occ[ord]
  uk <- !duplicated(paste(idv, dayv, occ, sep = "\r"))
  df <- df[uk, , drop = FALSE]; idv <- idv[uk]; dayv <- dayv[uk]; occ <- occ[uk]
  Y <- as.matrix(df[, vars, drop = FALSE]); p <- length(vars)

  n_obs <- 0L
  persons <- lapply(unique(idv), function(pid) {
    seli <- idv == pid; dd <- dayv[seli]; oo <- occ[seli]; Yi <- Y[seli, , drop = FALSE]
    blocks <- lapply(unique(dd), function(dv) {
      selb <- dd == dv; ob <- oo[selb]; Yb <- Yi[selb, , drop = FALSE]
      rng <- range(ob); grid <- rng[1]:rng[2]; Tg <- length(grid)
      if (Tg > grid_cap) {
        stop("Imputation grid too large (", Tg, " occasions for one block; cap ",
             grid_cap, "). Check the time/beep scale or set `tinterval`.",
             call. = FALSE)
      }
      G <- matrix(NA_real_, Tg, p); G[match(ob, grid), ] <- Yb
      M <- !is.na(G)
      # initialise latent cells with the block column mean (else 0)
      for (d in seq_len(p)) {
        mv <- mean(G[, d], na.rm = TRUE); if (is.na(mv)) mv <- 0
        G[!M[, d], d] <- mv
      }
      n_obs <<- n_obs + (Tg - 1L)
      list(Y = G, M = M)
    })
    blocks
  })
  list(persons = persons, n_obs = n_obs)
}

#' Impute one block's latent cells from their Gaussian full conditionals.
#'
#' Each `y_t` enters the likelihood as an outcome (given `y_{t-1}`) and as a
#' predictor (for `y_{t+1}`); both are Gaussian, so the full conditional is
#' Gaussian. Missing components are drawn given the observed components
#' (partitioned multivariate normal). `t = 1` uses a diffuse initial prior.
#' Lower-triangular (or eigen) square root L with L L' = Sigma; never throws.
#' @noRd
.mlvb_chol <- function(Sigma) {
  n <- nrow(Sigma)
  tryCatch(t(chol(Sigma)), error = function(e) {
    S <- (Sigma + t(Sigma)) / 2
    ev <- eigen(S, symmetric = TRUE)
    ev$values[ev$values < 0] <- 0
    ev$vectors %*% diag(sqrt(ev$values), n)
  })
}

#' Precompute the constant checkerboard imputation plan for one block's mask.
#'
#' The missingness mask never changes across MCMC iterations, so the split of
#' occasions into odd/even halves, into interior/first/last positions, and into
#' missingness-pattern groups (with their observed/missing index sets) is
#' computed once here and reused every iteration. Returns a list of two halves
#' (odd, even); each holds `interior`/`first`/`last` position entries, each a
#' list of pattern groups `list(ts, sub, o, u)`.
#' @noRd
.mlvb_impute_plan <- function(M) {
  Tn <- nrow(M); seqT <- seq_len(Tn)
  pos_groups <- function(ts) {
    if (!length(ts)) return(NULL)
    ts <- ts[rowSums(!M[ts, , drop = FALSE]) > 0L]      # only occasions with a gap
    if (!length(ts)) return(NULL)
    patt <- apply(M[ts, , drop = FALSE], 1L, paste, collapse = "")
    groups <- lapply(unique(patt), function(pg) {
      j <- which(patt == pg); obs <- M[ts[j][1L], ]
      list(ts = ts[j], sub = j, o = which(obs), u = which(!obs))
    })
    list(ts = ts, groups = groups)
  }
  lapply(c(1L, 0L), function(par) {
    ts <- seqT[seqT %% 2L == par]
    list(interior = pos_groups(ts[ts != 1L & ts != Tn]),
         first = if (1L %in% ts) pos_groups(1L) else NULL,
         last  = if (Tn %in% ts) pos_groups(Tn) else NULL)
  })
}

#' Impute a block's latent cells with a **checkerboard (even/odd) block Gibbs**.
#'
#' Given B_i, mu_i, Sigma_W_i the latent series is a Gaussian Markov chain, so
#' every even-indexed occasion is conditionally independent of the others given
#' the odd occasions (and vice versa). Updating all odd, then all even occasions
#' is a single valid Gibbs sweep, but each half is sampled in one vectorised pass
#' (grouped by position and missingness pattern via the precomputed `plan`)
#' instead of a per-occasion loop. Same target posterior as the scalar sweep;
#' only the scan order (hence the exact draws, not the posterior) differs.
#' @noRd
.mlvb_impute_block <- function(Y, plan, mu, Bi, Siginv, priorP, p) {
  Tn <- nrow(Y)
  ci    <- as.numeric((diag(p) - Bi) %*% mu)
  c_out <- as.numeric(Siginv %*% ci)              # outcome-term constant (t >= 2)
  BtS   <- crossprod(Bi, Siginv)                  # B' Sigma^{-1}
  c_pred <- as.numeric(-BtS %*% ci)               # predictor-term constant (t <= T-1)
  pr_mu <- as.numeric(priorP %*% mu)              # initial-condition prior (t = 1)

  if (Tn == 1L) {
    fg <- plan[[1L]]$first
    if (!is.null(fg)) {
      Vp <- .mlvb_solve(priorP)
      Y <- .mlvb_sample_groups(Y, fg, matrix(mu, p, 1L), Vp)
    }
    return(Y)
  }
  Ppred <- BtS %*% Bi                             # B' Sigma^{-1} B
  SigB  <- Siginv %*% Bi                           # Sigma^{-1} B
  V_int   <- .mlvb_solve(Siginv + Ppred)          # interior occasions
  V_first <- .mlvb_solve(priorP + Ppred)          # t = 1
  V_last  <- .mlvb_solve(Siginv)                  # t = Tn
  c0 <- c_out + c_pred

  for (half in plan) {                             # odd occasions, then even
    ip <- half$interior
    if (!is.null(ip)) {
      ts <- ip$ts
      Mm <- V_int %*% (c0 + SigB %*% t(Y[ts - 1L, , drop = FALSE]) +
                       BtS %*% t(Y[ts + 1L, , drop = FALSE]))
      Y <- .mlvb_sample_groups(Y, ip, Mm, V_int)
    }
    if (!is.null(half$first)) {
      m1 <- as.numeric(V_first %*% (pr_mu + c_pred + BtS %*% Y[2L, ]))
      Y <- .mlvb_sample_groups(Y, half$first, matrix(m1, p, 1L), V_first)
    }
    if (!is.null(half$last)) {
      mT <- as.numeric(V_last %*% (c_out + SigB %*% Y[Tn - 1L, ]))
      Y <- .mlvb_sample_groups(Y, half$last, matrix(mT, p, 1L), V_last)
    }
  }
  Y
}

#' Sample the missing cells of a precomputed position entry `pg` (occasions
#' sharing covariance `V`) from unconditional means `Mm` (p x nrow(pg$ts)),
#' vectorised within each precomputed missingness-pattern group.
#' @noRd
.mlvb_sample_groups <- function(Y, pg, Mm, V) {
  for (g in pg$groups) {
    o <- g$o; u <- g$u; tt <- g$ts; j <- g$sub
    Mu <- Mm[u, j, drop = FALSE]
    if (length(o) == 0L) {
      L <- .mlvb_chol(V[u, u, drop = FALSE])
      draw <- Mu + L %*% matrix(stats::rnorm(length(u) * length(j)), length(u))
    } else {
      Vuo <- V[u, o, drop = FALSE]
      Wuo <- Vuo %*% .mlvb_solve(V[o, o, drop = FALSE])
      Vc  <- V[u, u, drop = FALSE] - Wuo %*% t(Vuo)
      resid <- t(Y[tt, o, drop = FALSE]) - Mm[o, j, drop = FALSE]
      L <- .mlvb_chol((Vc + t(Vc)) / 2)
      draw <- (Mu + Wuo %*% resid) +
        L %*% matrix(stats::rnorm(length(u) * length(j)), length(u))
    }
    Y[tt, u] <- t(draw)
  }
  Y
}

#' Random-slope DSEM Gibbs with within-model imputation (data augmentation).
#'
#' Superset of `.mlvb_gibbs_random`: each iteration first imputes the latent
#' cells of every person's occasion grid, then runs the standard conjugate
#' updates on the completed data. Supports `residual = "fixed"|"random"`.
#' @noRd
.mlvb_gibbs_random_impute <- function(persons, p, n_iter, n_burnin, thin,
                                      seed = NULL, residual = "fixed") {
  if (!is.null(seed)) set.seed(seed)
  N <- length(persons)
  K <- p + p * p; idx_mu <- seq_len(p); idx_B <- p + seq_len(p * p)
  if (N < 2L * K + 1L) {
    stop("Random-slope DSEM needs at least ", 2L * K + 1L, " subjects for p = ",
         p, " (the ", K, "-dim random-effect covariance is otherwise not ",
         "estimable).", call. = FALSE)
  }
  rand_resid <- identical(residual, "random")
  Yimp  <- lapply(persons, function(bl) lapply(bl, `[[`, "Y"))
  # Precompute the constant checkerboard plan per block (mask never changes).
  Plans <- lapply(persons, function(bl) lapply(bl, function(b) .mlvb_impute_plan(b$M)))

  B_i <- replicate(N, matrix(0, p, p), simplify = FALSE)
  mu <- matrix(0, N, p); gamma <- numeric(K); Sre <- diag(0.1, K)
  SigmaW <- diag(p); SigmaW_i <- replicate(N, diag(p), simplify = FALSE)
  Lambda <- diag(p); nu0 <- p + 2L; V0inv <- diag(p); m0 <- p + 1L
  priorP <- diag(1 / 100, p)

  keep_it <- seq(n_burnin + 1L, n_iter, by = thin); m <- length(keep_it)
  out <- list(B = array(0, c(p, p, m)), SW = array(0, c(p, p, m)),
              SB = array(0, c(p, p, m)), alpha = matrix(0, m, p),
              slopeVar = matrix(0, m, p * p))
  ki <- 0L
  for (it in seq_len(n_iter)) {
    SWinv <- .mlvb_solve(SigmaW)
    SWinv_i <- if (rand_resid) lapply(SigmaW_i, .mlvb_solve) else NULL
    theta <- matrix(0, N, K)
    cur_l <- vector("list", N); lag_l <- vector("list", N)
    for (i in seq_len(N)) {
      SWi <- if (rand_resid) SWinv_i[[i]] else SWinv
      Bi <- B_i[[i]]
      # 1. impute this person's blocks
      Yimp[[i]] <- lapply(seq_along(Yimp[[i]]), function(b)
        .mlvb_impute_block(Yimp[[i]][[b]], Plans[[i]][[b]], mu[i, ], Bi, SWi, priorP, p))
      # 2. completed cur/lag across blocks
      cur <- do.call(rbind, lapply(Yimp[[i]], function(Y) Y[-1L, , drop = FALSE]))
      lg  <- do.call(rbind, lapply(Yimp[[i]], function(Y) Y[-nrow(Y), , drop = FALSE]))
      cur_l[[i]] <- cur; lag_l[[i]] <- lg; T <- nrow(cur)
      # 3. mu_i | B_i
      A <- diag(p) - Bi; r <- cur - lg %*% t(Bi)
      cn <- .mlvb_cond_normal(gamma, Sre, idx_mu, idx_B, as.vector(Bi))
      V0i <- .mlvb_solve(cn$cov)
      prec <- T * crossprod(A, SWi) %*% A + V0i
      rhs  <- crossprod(A, SWi) %*% colSums(r) + V0i %*% cn$mean
      Vi <- .mlvb_solve(prec); mu[i, ] <- .mlvb_rmvn(as.numeric(Vi %*% rhs), Vi)
      # 4. vec(B_i) | mu_i
      Xl <- lg - rep(mu[i, ], each = T); Wc <- cur - rep(mu[i, ], each = T)
      cnB <- .mlvb_cond_normal(gamma, Sre, idx_B, idx_mu, mu[i, ])
      Vb0 <- .mlvb_solve(cnB$cov)
      prec_b <- kronecker(crossprod(Xl), SWi) + Vb0
      rhs_b  <- as.vector(SWi %*% crossprod(Wc, Xl)) + Vb0 %*% cnB$mean
      Vb <- .mlvb_solve(prec_b)
      Bi <- matrix(.mlvb_rmvn(as.numeric(Vb %*% rhs_b), Vb), p, p)
      B_i[[i]] <- Bi; theta[i, ] <- c(mu[i, ], as.vector(Bi))
    }
    gamma <- .mlvb_rmvn(colMeans(theta), Sre / N)
    Sre <- .mlvb_riwish(N - (K + 1L), crossprod(sweep(theta, 2, gamma)))
    per_E <- function(i) {
      T <- nrow(cur_l[[i]])
      (cur_l[[i]] - rep(mu[i, ], each = T)) -
        (lag_l[[i]] - rep(mu[i, ], each = T)) %*% t(B_i[[i]])
    }
    if (rand_resid) {
      SigmaW_i <- lapply(seq_len(N), function(i)
        .mlvb_riwish(nu0 + nrow(cur_l[[i]]), Lambda + crossprod(per_E(i))))
      Lambda <- .mlvb_rwishart(m0 + N * nu0,
                               .mlvb_solve(V0inv + Reduce(`+`, lapply(SigmaW_i, .mlvb_solve))))
      SigmaW_pop <- Reduce(`+`, SigmaW_i) / N
    } else {
      E <- do.call(rbind, lapply(seq_len(N), per_E))
      SigmaW <- .mlvb_riwish(nrow(E) - p - 1, crossprod(E)); SigmaW_pop <- SigmaW
    }
    if (it %in% keep_it) {
      ki <- ki + 1L
      out$B[, , ki] <- matrix(gamma[idx_B], p, p); out$SW[, , ki] <- SigmaW_pop
      out$SB[, , ki] <- Sre[idx_mu, idx_mu, drop = FALSE]; out$alpha[ki, ] <- gamma[idx_mu]
      out$slopeVar[ki, ] <- diag(Sre[idx_B, idx_B, drop = FALSE])
    }
  }
  out
}

# ---- Pool chains + summarize -------------------------------------------------

#' @noRd
.mlvb_pool <- function(chains) {
  cat3 <- function(slot) {
    arrs <- lapply(chains, `[[`, slot)
    d <- dim(arrs[[1]])
    array(unlist(arrs), c(d[1], d[2], sum(vapply(arrs, function(a) dim(a)[3],
                                                 integer(1)))))
  }
  list(B = cat3("B"), SW = cat3("SW"), SB = cat3("SB"),
       alpha = do.call(rbind, lapply(chains, `[[`, "alpha")))
}

#' Max Gelman-Rubin PSR across all scalar parameters (B, Sigma_W, Sigma_B).
#' @noRd
.mlvb_psr <- function(chains) {
  scal <- function(ch) cbind(
    matrix(aperm(ch$B,  c(3, 1, 2)), nrow = dim(ch$B)[3]),
    matrix(aperm(ch$SW, c(3, 1, 2)), nrow = dim(ch$SW)[3]),
    matrix(aperm(ch$SB, c(3, 1, 2)), nrow = dim(ch$SB)[3]))
  mats <- lapply(chains, scal)
  M <- length(mats); if (M < 2L) return(NA_real_)
  nkeep <- nrow(mats[[1]])
  means <- vapply(mats, colMeans, numeric(ncol(mats[[1]])))
  vars  <- vapply(mats, function(x) apply(x, 2, stats::var),
                  numeric(ncol(mats[[1]])))
  Bv <- nkeep * apply(means, 1, stats::var)
  Wv <- rowMeans(vars)
  varhat <- ((nkeep - 1) / nkeep) * Wv + Bv / nkeep
  psr <- sqrt(varhat / Wv)
  psr[is.finite(psr)]
}

#' Posterior medians / SDs / CIs / one-tailed p, networks, and tidy coefs.
#' @noRd
.mlvb_summaries <- function(post, vars, psr) {
  p <- length(vars)
  med <- function(a) apply(a, c(1, 2), stats::median)
  B_med  <- med(post$B);  SW_med <- med(post$SW); SB_med <- med(post$SB)
  dimnames(B_med) <- dimnames(SW_med) <- dimnames(SB_med) <- list(vars, vars)
  alpha_med <- apply(post$alpha, 2, stats::median)

  # networks: partial correlations of the (median) covariance matrices, as mlVAR
  contemp_pcor <- .mlvb_pcor(SW_med); between_pcor <- .mlvb_pcor(SB_med)
  dimnames(contemp_pcor) <- dimnames(between_pcor) <- list(vars, vars)

  # tidy temporal coefs (one row per outcome x predictor)
  q <- function(a, pr) apply(a, c(1, 2), stats::quantile, probs = pr,
                             names = FALSE)
  Blo <- q(post$B, 0.025); Bhi <- q(post$B, 0.975)
  Bsd <- apply(post$B, c(1, 2), stats::sd)
  ptail <- apply(post$B, c(1, 2), function(x) {
    pg <- mean(x > 0); min(pg, 1 - pg)
  })
  idx <- expand.grid(row = seq_len(p), col = seq_len(p))
  coefs <- data.frame(
    outcome      = vars[idx$row],
    predictor    = vars[idx$col],
    estimate     = B_med[cbind(idx$row, idx$col)],
    posterior_sd = Bsd[cbind(idx$row, idx$col)],
    ci_lower     = Blo[cbind(idx$row, idx$col)],
    ci_upper     = Bhi[cbind(idx$row, idx$col)],
    p            = ptail[cbind(idx$row, idx$col)],
    stringsAsFactors = FALSE
  )
  coefs$significant <- coefs$ci_lower > 0 | coefs$ci_upper < 0
  coefs <- coefs[order(idx$row, idx$col), ]
  rownames(coefs) <- NULL

  list(B_med = B_med, SW_med = SW_med, SB_med = SB_med, alpha_med = alpha_med,
       contemp_pcor = contemp_pcor, between_pcor = between_pcor, coefs = coefs)
}

#' Partial correlations from a covariance matrix (diag zeroed), matching mlVAR.
#' @noRd
.mlvb_pcor <- function(Sigma) {
  pc <- tryCatch(.ido_cor2pcor(Sigma),
                 error = function(e) matrix(0, nrow(Sigma), ncol(Sigma)))
  diag(pc) <- 0
  (pc + t(pc)) / 2
}

# ---- S3 methods --------------------------------------------------------------

#' @rdname coefs
#' @export
coefs.net_mlvar_bayes <- function(x, ...) attr(x, "coefs")

#' Print method for net_mlvar_bayes
#'
#' @param x A `net_mlvar_bayes` object from [fit_mlvar_bayes()].
#' @param digits Digits for printed network matrices.
#' @param ... Unused.
#' @return Invisibly returns `x`.
#' @export
print.net_mlvar_bayes <- function(x, digits = 2, ...) {
  cf <- attr(x, "coefs")
  d <- nrow(x$temporal$weights)
  mc <- attr(x, "mcmc")
  n_sig <- sum(cf$significant, na.rm = TRUE)
  ttype <- attr(x, "temporal_type") %||% "fixed"
  cat(sprintf(paste0("Bayesian mlVAR (Mplus DSEM-targeted, temporal = %s): ",
                     "%d subjects, %d observations, %d variables\n"),
              ttype, attr(x, "n_subjects"), attr(x, "n_obs"), d))
  cat(sprintf("  MCMC: %d chains x %d iter (%d burn-in), %d draws | max PSR = %.3f\n",
              mc$n_chains, mc$n_iter, mc$n_burnin, mc$n_draws, attr(x, "max_psr")))
  cat(sprintf("  Temporal 95%% CIs excluding 0: %d / %d\n", n_sig, nrow(cf)))
  if (identical(ttype, "random")) {
    ss <- attr(x, "slope_sd")
    cat(sprintf("  Random-slope SD range: %.3f - %.3f (person-specific temporal)\n",
                min(ss, na.rm = TRUE), max(ss, na.rm = TRUE)))
  }
  .ido_print_networks(x, digits = digits)
  cat("\n  coefs(x) posterior median/SD/CI | matrices(x) | edges(x) | summary(x)\n")
  invisible(x)
}
