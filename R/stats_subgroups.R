#' Discover subgroups of people
#'
#' Groups people who behave alike, so that a model can be fitted per subgroup
#' rather than pooling everyone or fitting everyone separately.
#'
#' Methods:
#' \describe{
#'   \item{`effect_clustering`}{Cluster people by their person-specific slopes.
#'     People whose predictors act the same way land together.}
#'   \item{`error_clustering`}{Cluster people by how a pooled model fails them
#'     (error size and direction). Finds who the pooled model does not serve.}
#'   \item{`repeated_split`}{Like `effect_clustering`, but slopes are recomputed
#'     on repeated resamples, so unstable people are exposed.}
#'   \item{`model_tree`}{Split people on person-level `moderators` (age,
#'     condition, baseline score) to reduce prediction error. The only method
#'     that says *why* people differ, in terms of variables you measured.}
#'   \item{`mixture_regression`}{A finite mixture of regressions fitted by EM,
#'     with the **person** as the mixing unit: every row a person contributes
#'     counts towards that person's likelihood under each component, so people
#'     are assigned whole. Unlike `effect_clustering` it does not need a
#'     separate regression per person, so it can place people with too few
#'     occasions to support one. `$mixture` holds the component regressions and
#'     the posterior probabilities, and `groups()` gains a `posterior` column --
#'     how sure the model is of each assignment, which is a stronger statement
#'     than how often a partition reproduces. Matches `flexmix::flexmix(y ~ x |
#'     id)` to the reported precision on log-likelihood, BIC and assignment.}
#'   \item{`random_partition`}{Random labels. A null baseline: compare its
#'     stability against a real method to see whether structure exists.}
#' }
#'
#' **These methods always return subgroups, including when there are none.**
#' Call [test_subgroups()] first, or use `k = "auto"`, which is allowed to answer
#' "one population".
#'
#' Stability is a consensus score: each person is repeatedly re-clustered on
#' resampled rows, and stability is how often they land with the same companions.
#' It measures whether a partition is **reproducible, not whether it is real**.
#' In simulation, data containing no subgroups at all scored 0.89-0.97 --
#' because slicing a single smooth cloud of coefficients in half is highly
#' repeatable. Do not read a high stability as evidence that the groups exist.
#'
#' With `k = "auto"` the number of subgroups is chosen by [test_subgroups()], a
#' Gaussian mixture on the person coefficients selected by BIC over both the
#' number of components and the covariance structure. It may return **one**, in
#' which case a warning is raised and the partition should not be trusted. See
#' `$selection` for the BIC table and `$shape` for the skewness diagnostic.
#'
#' `method = "mixture_regression"` defers to the same test rather than to its
#' own BIC, and the reason is worth knowing. On 30 simulated panels containing
#' **no** subgroups -- one population whose slopes merely varied continuously --
#' the mixture's BIC chose more than one component **30 times out of 30**, while
#' [test_subgroups()] answered "one population" 30 times out of 30 and still
#' recovered two real classes when they were present. A mixture of regressions
#' fits a continuum of slopes better with two components than with one, and its
#' BIC has no device to tell that apart from genuine classes. The mixture's own
#' BIC table is still reported in `$mixture_bic`, for comparison with a
#' `flexmix`-style workflow -- it simply does not get to choose.
#'
#' @param data Data frame.
#' @param y Outcome column name.
#' @param x Predictors (any [fit_lm()] selector).
#' @param id Person/unit ID column.
#' @param method Discovery method.
#' @param k Number of subgroups, or `"auto"` to choose it by stability.
#' @param reps Resamples used for the stability score.
#' @param moderators Person-level column(s) to split on. Required by
#'   `method = "model_tree"`, ignored otherwise. Must be constant within person.
#' @param time Optional ordering column.
#' @param k_max Largest `k` considered when `k = "auto"`.
#' @param ... Ignored.
#' @return An `idiostats_groups` object. Use [groups()] for the tidy table.
#' @examples
#' g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                     id = "name", k = 2, reps = 10)
#' groups(g)
#'
#' # Let the data choose how many subgroups there are.
#' auto <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                        id = "name", k = "auto", k_max = 4, reps = 10)
#' auto$selection
#' @export
find_subgroups <- function(data, y, x, id,
                           method = c("effect_clustering", "error_clustering",
                                      "repeated_split", "model_tree",
                                      "mixture_regression",
                                      "random_partition"),
                           k = 2L, reps = 50L, moderators = NULL, time = NULL,
                           k_max = 6L, ...) {
  method <- match.arg(method)
  .idio_count(reps, "reps")
  auto <- identical(k, "auto")
  if (!auto) .idio_count(k, "k")

  data <- .idio_check_data(data, y, id)
  x <- .idio_resolve_x(data, x, exclude = c(y, id, moderators),
                       soft_exclude = time)
  data <- data[stats::complete.cases(data[c(y, x)]), , drop = FALSE]
  .idio_stop_person_constant(data, x, id, what = "subgroup")

  if (method == "model_tree" && is.null(moderators)) {
    stop("`method = \"model_tree\"` needs `moderators`: person-level column(s) ",
         "in `data` to split people on.", call. = FALSE)
  }
  mods <- .idio_moderator_matrix(data, id, moderators)

  subjects <- sort(unique(as.character(data[[id]])))

  # Does any subgroup structure exist? Stability cannot answer this -- it scores
  # 0.89-0.97 on data with no subgroups at all -- so `k = "auto"` is decided by
  # a calibrated mixture BIC that is allowed to answer "one population".
  test <- NULL
  if (auto) {
    # Every method, including mixture_regression, defers to test_subgroups()
    # here. A mixture of regressions has its own BIC, and it is tempting to use
    # it -- but in simulation it chose k > 1 on 30 of 30 null panels whose
    # slopes merely varied continuously, while test_subgroups() answered "one
    # population" on 30 of 30 and still found two real classes when they
    # existed. The mixture BIC is reported (see `$mixture_bic`) but never gets
    # to decide.
    test <- test_subgroups(data, y, x, id, time = time, k_max = k_max)
    k_used <- test$k
    if (k_used == 1L) {
      warning("No subgroups detected: one population fits these people best. ",
              "Any partition returned below is not supported by the data.",
              call. = FALSE)
    }
  } else {
    k_used <- as.integer(k)
  }

  if (length(subjects) <= k_used) {
    stop("Need more people than subgroups: ", length(subjects), " people, k = ",
         k_used, ".", call. = FALSE)
  }

  run <- .idio_subgroup_run(data, y, x, id, subjects, method,
                            max(k_used, 1L), reps, mods)

  selection <- if (auto) as.data.frame(test) else NULL

  # Reported for comparison with a flexmix-style workflow, never used to choose
  # k -- see the note above.
  mixture_bic <- if (method == "mixture_regression" && auto) {
    tryCatch(.idio_mixreg_sweep(data, y, x, id, subjects, k_max)$table,
             error = function(e) NULL)
  } else {
    NULL
  }

  tab <- data.frame(
    subject = run$subjects,
    subgroup = paste0("g", run$labels),
    method = method,
    stability = run$stability,
    n_assignments = as.integer(reps),
    stringsAsFactors = FALSE
  )
  # A mixture reports how sure it is of each assignment directly, which is a
  # different and stronger statement than "this partition reproduces".
  if (!is.null(run$mixture)) {
    tab$posterior <- run$mixture$confidence[match(tab$subject,
                                                  run$mixture$subjects)]
  }
  rownames(tab) <- NULL

  # Shape drives spurious subgroups, so it is always reported -- not only when
  # the number of groups was chosen automatically.
  shape <- tryCatch(.idio_shape(run$features), error = function(e) NULL)

  structure(list(
    spec = list(method = method, k = as.integer(k_used),
                reps = as.integer(reps), auto = auto, y = y, x = x, id = id,
                time = time, moderators = moderators),
    groups = tab,
    selection = selection,
    test = test,
    shape = shape,
    features = run$features,
    mixture = run$mixture,
    mixture_bic = mixture_bic,
    failures = run$failures
  ), class = "idiostats_groups")
}

#' One (method, k) run: label people, then score how stably they stay together
#' @noRd
.idio_subgroup_run <- function(data, y, x, id, subjects, method, k, reps,
                               mods) {
  ref <- .idio_subject_labels(data, y, x, id, subjects, method, k, mods)

  co <- Reduce(`+`, lapply(seq_len(reps), function(i) {
    resampled <- .idio_resample_rows(data, id)
    l <- tryCatch(
      suppressWarnings(
        .idio_subject_labels(resampled, y, x, id, ref$subjects, method, k,
                             mods)$labels),
      error = function(e) NULL
    )
    if (is.null(l) || length(l) != length(ref$labels)) {
      return(matrix(0, length(ref$subjects), length(ref$subjects)))
    }
    outer(l, l, `==`) * 1
  }))

  ref$stability <- .idio_stability(co, ref$labels, reps)
  ref
}

#' Assign every person to a subgroup, by whichever method was asked for
#' @noRd
.idio_subject_labels <- function(data, y, x, id, subjects, method, k, mods) {
  if (method == "model_tree") {
    keep <- subjects[subjects %in% rownames(mods)]
    if (length(keep) < 2L) {
      stop("Too few people with usable moderators for \"model_tree\".",
           call. = FALSE)
    }
    labels <- .idio_model_tree(data, y, x, id, keep,
                              mods[keep, , drop = FALSE], k)
    return(list(labels = labels, subjects = keep,
                features = mods[keep, , drop = FALSE],
                failures = .idio_empty_failures()))
  }

  if (method == "mixture_regression") {
    mix <- .idio_mixreg(data, y, x, id, subjects, k)
    # Shape diagnostics still want person coefficients, and those exist only
    # for people the mixture did not need them for -- so they are collected
    # separately and are allowed to cover fewer people.
    f <- tryCatch(.idio_features(data, y, x, id, subjects, "effect_clustering"),
                  error = function(e) NULL)
    return(list(labels = mix$labels, subjects = mix$subjects,
                features = f$matrix, mixture = mix,
                failures = f$failures %||% .idio_empty_failures()))
  }

  f <- .idio_features(data, y, x, id, subjects, method)
  list(labels = .idio_kcluster(f$matrix, k, method), subjects = f$subjects,
       features = f$matrix, failures = f$failures)
}

#' Finite mixture of regressions, with the PERSON as the mixing unit
#'
#' A row-level mixture would assign each *occasion* to a component, which is
#' not what a subgroup of people is. Here every row belonging to one person
#' contributes to that person's likelihood under each component, so a person is
#' assigned as a whole -- which is also why this method can place people who
#' have too few occasions to support a regression of their own, unlike
#' `effect_clustering`.
#'
#' Fitted by EM: the E-step is a person-level posterior computed in logs, the
#' M-step is a weighted least squares per component. EM finds local optima, so
#' several starts are tried and the best likelihood wins; the first start is
#' k-means on the person coefficients, which is a far better guess than random.
#'
#' @noRd
.idio_mixreg <- function(data, y, x, id, subjects, k, starts = 5L,
                         maxit = 300L, tol = 1e-7) {
  ids <- as.character(data[[id]])
  keep <- ids %in% subjects
  data <- data[keep, , drop = FALSE]
  ids <- ids[keep]
  people <- sort(unique(ids))
  n_people <- length(people)
  if (n_people <= k) {
    stop("Need more people than components for \"mixture_regression\".",
         call. = FALSE)
  }

  X <- cbind(`(Intercept)` = 1, as.matrix(data[x]))
  yv <- as.numeric(data[[y]])
  rows_of <- split(seq_along(ids), factor(ids, levels = people))
  person_of <- match(ids, people)

  inits <- .idio_mixreg_inits(data, y, x, id, people, k, starts)
  runs <- lapply(inits, function(z0) {
    tryCatch(.idio_mixreg_em(X, yv, person_of, rows_of, z0, maxit, tol),
             error = function(e) NULL)
  })
  runs <- runs[!vapply(runs, is.null, logical(1))]
  if (!length(runs)) {
    stop("The mixture of regressions could not be fitted from any start.",
         call. = FALSE)
  }
  # A run that simply ran out of iterations is not a converged solution, and
  # picking purely on log-likelihood would let one supply the assignments
  # without ever saying so. Converged starts win; an unconverged fallback is
  # reported.
  settled <- runs[vapply(runs, `[[`, logical(1), "converged")]
  if (length(settled)) {
    runs <- settled
  } else {
    warning("The mixture of regressions hit `maxit` from every start; the ",
            "component memberships below are not a converged solution.",
            call. = FALSE)
  }
  best <- runs[[which.max(vapply(runs, `[[`, numeric(1), "loglik"))]]

  labels <- max.col(best$z, ties.method = "first")
  n_par <- k * (ncol(X) + 1L) + (k - 1L)
  list(labels = labels, subjects = people, posterior = best$z,
       loglik = best$loglik, converged = best$converged,
       iterations = best$iter, k = as.integer(k), n_par = as.integer(n_par),
       bic = -2 * best$loglik + n_par * log(nrow(X)),
       components = .idio_mixreg_components(best, colnames(X)),
       confidence = apply(best$z, 1L, max))
}

#' Starting responsibilities: k-means on person coefficients, then random
#' @noRd
.idio_mixreg_inits <- function(data, y, x, id, people, k, starts) {
  hard <- function(labels) {
    z <- matrix(0, length(people), k)
    z[cbind(seq_along(people), labels)] <- 1
    z
  }
  smart <- tryCatch({
    f <- .idio_features(data, y, x, id, people, "effect_clustering")
    labels <- .idio_kcluster(f$matrix, k, "effect_clustering")
    seeded <- rep(seq_len(k), length.out = length(people))
    seeded[match(f$subjects, people)] <- labels
    list(hard(seeded))
  }, error = function(e) list())

  random <- lapply(seq_len(max(0L, starts - length(smart))), function(i) {
    hard(sample(rep_len(seq_len(k), length(people))))
  })
  c(smart, random)
}

#' One EM run to convergence
#' @noRd
.idio_mixreg_em <- function(X, y, person_of, rows_of, z, maxit, tol) {
  n_people <- nrow(z)
  k <- ncol(z)
  p <- ncol(X)
  loglik <- -Inf
  iter <- 0L

  repeat {
    iter <- iter + 1L
    weights <- z[person_of, , drop = FALSE]
    proportions <- colMeans(z)
    if (any(proportions <= 0)) stop("A component emptied.", call. = FALSE)

    fits <- lapply(seq_len(k), function(j) {
      w <- weights[, j]
      total <- sum(w)
      if (total <= p) stop("A component holds too little weight.",
                           call. = FALSE)
      xw <- X * w
      beta <- tryCatch(solve(crossprod(xw, X), crossprod(xw, y)),
                       error = function(e) {
                         MASS_ginv(crossprod(xw, X)) %*% crossprod(xw, y)
                       })
      resid <- y - as.numeric(X %*% beta)
      list(beta = as.numeric(beta),
           sigma2 = max(sum(w * resid^2) / total, 1e-10))
    })

    # E-step: a person's log-likelihood is the sum over their own rows.
    person_ll <- vapply(fits, function(f) {
      d <- stats::dnorm(y - as.numeric(X %*% f$beta), sd = sqrt(f$sigma2),
                        log = TRUE)
      vapply(rows_of, function(i) sum(d[i]), numeric(1))
    }, numeric(n_people))
    person_ll <- matrix(person_ll, nrow = n_people)

    weighted <- sweep(person_ll, 2L, log(proportions), "+")
    biggest <- apply(weighted, 1L, max)
    shifted <- exp(weighted - biggest)
    totals <- rowSums(shifted)
    new_loglik <- sum(biggest + log(totals))
    z <- shifted / totals

    converged <- abs(new_loglik - loglik) < tol * (abs(new_loglik) + 1)
    loglik <- new_loglik
    if (converged || iter >= maxit) break
  }
  list(z = z, loglik = loglik, fits = fits, proportions = proportions,
       iter = iter, converged = converged)
}

#' Tidy the fitted component regressions
#' @noRd
.idio_mixreg_components <- function(best, terms) {
  k <- length(best$fits)
  do.call(rbind, lapply(seq_len(k), function(j) {
    data.frame(subgroup = paste0("g", j),
               share = best$proportions[j],
               sigma = sqrt(best$fits[[j]]$sigma2),
               term = terms,
               estimate = best$fits[[j]]$beta,
               stringsAsFactors = FALSE)
  }))
}

#' Choose k for a mixture of regressions by its own BIC
#'
#' The mixture has a likelihood, so it can be asked directly how many
#' components the data support -- and, unlike consensus stability, it is
#' allowed to answer one.
#'
#' @noRd
.idio_mixreg_sweep <- function(data, y, x, id, subjects, k_max) {
  ks <- seq_len(max(1L, min(k_max, length(subjects) - 1L)))
  rows <- lapply(ks, function(k) {
    fit <- tryCatch(.idio_mixreg(data, y, x, id, subjects, k),
                    error = function(e) NULL)
    if (is.null(fit)) {
      return(data.frame(k = k, loglik = NA_real_, n_par = NA_integer_,
                        bic = NA_real_, stringsAsFactors = FALSE))
    }
    data.frame(k = k, loglik = fit$loglik, n_par = fit$n_par, bic = fit$bic,
               stringsAsFactors = FALSE)
  })
  tab <- do.call(rbind, rows)
  usable <- tab[is.finite(tab$bic), , drop = FALSE]
  if (!nrow(usable)) {
    stop("The mixture of regressions could not be fitted at any k.",
         call. = FALSE)
  }
  best <- usable$k[which.min(usable$bic)]
  list(k = as.integer(best), table = tab)
}

#' Chance-adjusted stability: 0 for a random partition at any k, 1 for perfect
#' @noRd
.idio_adjust_stability <- function(stability, k) {
  chance <- 1 / k
  (stability - chance) / (1 - chance)
}

#' Person-level moderator matrix (one row per person)
#' @noRd
.idio_moderator_matrix <- function(data, id, moderators) {
  if (is.null(moderators)) return(NULL)
  if (!(is.character(moderators) && all(moderators %in% names(data)))) {
    stop("`moderators` must name column(s) in `data`.", call. = FALSE)
  }
  ids <- as.character(data[[id]])
  tab <- unique(data[c(id, moderators)])
  tab[[id]] <- as.character(tab[[id]])
  if (anyDuplicated(tab[[id]])) {
    stop("Moderator(s) must be constant within each person: ",
         paste(moderators, collapse = ", "), ".", call. = FALSE)
  }
  m <- data.matrix(tab[moderators])
  rownames(m) <- tab[[id]]
  m[stats::complete.cases(m), , drop = FALSE]
}

#' Grow a best-first tree that splits *people* on moderators
#'
#' At each step every (moderator, cut) is scored by the total squared error of
#' fitting the model separately inside the two child groups. The split that buys
#' the most error reduction is taken, until there are `k` leaves. This is the
#' one method that explains *why* people differ, in terms of variables you
#' measured, rather than only clustering how they differ.
#'
#' @noRd
.idio_model_tree <- function(data, y, x, id, subjects, mods, k) {
  ids <- as.character(data[[id]])
  form <- .idio_formula(y, x)

  sse <- function(members) {
    rows <- ids %in% members
    if (sum(rows) < length(x) + 2L) return(Inf)
    fit <- tryCatch(stats::lm(form, data = data[rows, , drop = FALSE]),
                    error = function(e) NULL)
    if (is.null(fit)) return(Inf)
    sum(stats::residuals(fit)^2)
  }

  # Best split of one node, or NULL when no split helps.
  best_split <- function(members) {
    parent <- sse(members)
    cand <- lapply(colnames(mods), function(v) {
      vals <- sort(unique(mods[members, v]))
      if (length(vals) < 2L) return(NULL)
      cuts <- (utils::head(vals, -1L) + utils::tail(vals, -1L)) / 2
      scored <- lapply(cuts, function(cut) {
        left <- members[mods[members, v] <= cut]
        right <- setdiff(members, left)
        if (!length(left) || !length(right)) return(NULL)
        list(variable = v, cut = cut, left = left, right = right,
             gain = parent - (sse(left) + sse(right)))
      })
      scored <- scored[!vapply(scored, is.null, logical(1))]
      if (!length(scored)) return(NULL)
      scored[[which.max(vapply(scored, `[[`, numeric(1), "gain"))]]
    })
    cand <- cand[!vapply(cand, is.null, logical(1))]
    if (!length(cand)) return(NULL)
    top <- cand[[which.max(vapply(cand, `[[`, numeric(1), "gain"))]]
    if (!is.finite(top$gain) || top$gain <= 0) return(NULL)
    top
  }

  leaves <- list(subjects)
  while (length(leaves) < k) {
    splits <- lapply(leaves, best_split)
    gains <- vapply(splits, function(s) if (is.null(s)) -Inf else s$gain,
                    numeric(1))
    if (!any(is.finite(gains) & gains > 0)) break
    i <- which.max(gains)
    leaves <- c(leaves[-i], list(splits[[i]]$left), list(splits[[i]]$right))
  }

  labels <- integer(length(subjects))
  names(labels) <- subjects
  invisible(lapply(seq_along(leaves), function(i) {
    labels[leaves[[i]]] <<- i
  }))
  unname(labels)
}

#' Person-level features that a subgroup method clusters on
#' @noRd
.idio_features <- function(data, y, x, id, subjects, method) {
  if (method == "random_partition") {
    m <- matrix(stats::runif(length(subjects)), ncol = 1L,
                dimnames = list(subjects, "random"))
    return(list(matrix = m, subjects = subjects,
                failures = .idio_empty_failures()))
  }

  if (method == "error_clustering") {
    form <- .idio_formula(y, x)
    pooled <- stats::lm(form, data = data)
    resid <- data[[y]] - as.numeric(stats::predict(pooled, data))
    ids <- as.character(data[[id]])
    grab <- function(f) vapply(subjects, function(s) {
      r <- resid[ids == s]
      if (!length(r)) return(NA_real_)
      f(r)
    }, numeric(1))
    m <- cbind(rmse = grab(function(r) sqrt(mean(r^2))),
               bias = grab(mean),
               mae = grab(function(r) mean(abs(r))))
    rownames(m) <- subjects
    return(.idio_drop_incomplete(m, subjects, method))
  }

  # effect_clustering and repeated_split both cluster person-specific slopes.
  m <- .idio_person_slopes(data, y, x, id, subjects)
  .idio_drop_incomplete(m, subjects, method)
}

#' Person-specific slopes (intercept dropped: we cluster dynamics, not level)
#' @noRd
.idio_person_slopes <- function(data, y, x, id, subjects) {
  form <- .idio_formula(y, x)
  ids <- as.character(data[[id]])
  rows <- lapply(subjects, function(s) {
    sub <- data[ids == s, , drop = FALSE]
    co <- tryCatch(stats::coef(stats::lm(form, data = sub)),
                   error = function(e) NULL)
    if (is.null(co)) return(stats::setNames(rep(NA_real_, length(x)), x))
    co[x]
  })
  m <- do.call(rbind, rows)
  rownames(m) <- subjects
  colnames(m) <- x
  m
}

.idio_drop_incomplete <- function(m, subjects, method) {
  ok <- stats::complete.cases(m)
  failures <- if (any(!ok)) {
    do.call(rbind, lapply(subjects[!ok], .idio_split_failure,
                          message = "Could not compute subgroup features."))
  } else {
    .idio_empty_failures()
  }
  if (sum(ok) < 2L) {
    stop("Too few people with usable features for method \"", method, "\".",
         call. = FALSE)
  }
  list(matrix = m[ok, , drop = FALSE], subjects = subjects[ok],
       failures = failures)
}

.idio_kcluster <- function(m, k, method) {
  z <- scale(m)
  z[!is.finite(z)] <- 0
  k <- min(k, nrow(z) - 1L)
  stats::kmeans(z, centers = k, nstart = 10L, iter.max = 50L)$cluster
}

.idio_resample_rows <- function(data, id) {
  ids <- as.character(data[[id]])
  idx <- unlist(lapply(split(seq_len(nrow(data)), ids), function(i) {
    sample(i, length(i), replace = TRUE)
  }), use.names = FALSE)
  data[idx, , drop = FALSE]
}

#' Consensus stability: how often a person keeps the same companions
#' @noRd
.idio_stability <- function(co, labels, reps) {
  vapply(seq_along(labels), function(i) {
    peers <- which(labels == labels[i])
    peers <- peers[peers != i]
    if (!length(peers)) return(NA_real_)
    mean(co[i, peers]) / reps
  }, numeric(1))
}

#' @export
print.idiostats_groups <- function(x, ...) {
  tab <- x$groups
  cat("Idiostats Subgroups\n")
  cat(sprintf("  Method:      %s\n", x$spec$method))
  if (!is.null(x$spec$moderators)) {
    cat(sprintf("  Moderators:  %s\n",
                paste(x$spec$moderators, collapse = ", ")))
  }
  cat(sprintf("  Subgroups:   %d%s\n", length(unique(tab$subgroup)),
              if (isTRUE(x$spec$auto)) " (chosen automatically)" else ""))
  cat(sprintf("  People:      %d\n", nrow(tab)))
  sizes <- table(tab$subgroup)
  cat(sprintf("  Sizes:       %s\n",
              paste(names(sizes), as.integer(sizes), sep = "=",
                    collapse = ", ")))
  # Stability is reproducibility, NOT existence. On data with no subgroups at
  # all it scores 0.89-0.97, because cutting a single smooth cloud in half is
  # highly repeatable. Say so, rather than let the number reassure anyone.
  cat(sprintf("  Stability:   %.2f (how reproducible the partition is --\n",
              mean(tab$stability, na.rm = TRUE)))
  cat("               NOT evidence that the subgroups are real)\n")

  if (!is.null(x$test)) {
    if (x$test$k == 1L) {
      cat("\n  VERDICT:     no subgroups detected -- one population fits best.\n")
      cat("               The groups above are not supported by the data.\n")
    } else {
      cat(sprintf("\n  VERDICT:     %d subgroups (mixture BIC beats one group by %.1f: %s evidence)\n",
                  x$test$k, x$test$evidence,
                  .idio_evidence_label(x$test$evidence)))
    }
  } else {
    cat("\n  Existence:   not tested. Use test_subgroups() to ask whether any\n")
    cat("               subgroups exist before trusting this partition.\n")
  }

  if (.idio_shape_risk(x$shape)) {
    cat("\n  WARNING:     the person coefficients are skewed or heavy-tailed.\n")
    cat("               Shape alone manufactures subgroups: in simulation a\n")
    cat("               single SKEWED population yielded spurious subgroups in\n")
    cat("               60% of runs, against 10% under normality\n")
    cat("               (cf. Bauer & Curran, 2003). Treat this as unproven.\n")
  }
  cat("\n  Use groups(), test_subgroups(), fit_subgroups()\n")
  invisible(x)
}

#' Tidy subgroup assignments
#'
#' @param x An [find_subgroups()] result, or a fit built with subgroups.
#' @param subgroup,subject Optional filters.
#' @param sort_by Optional column to sort by.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A data frame of subgroup assignments.
#' @examples
#' g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                     id = "name", k = 2, reps = 10)
#' groups(g, sort_by = "stability", decreasing = TRUE, n = 5)
#' @export
groups <- function(x, subgroup = NULL, subject = NULL, sort_by = NULL,
                   decreasing = FALSE, n = NULL, ...) UseMethod("groups")

#' @export
groups.idiostats_groups <- function(x, subgroup = NULL, subject = NULL,
                                    sort_by = NULL, decreasing = FALSE,
                                    n = NULL, ...) {
  .idio_filter_table(x$groups, subject = subject, subgroup = subgroup,
                     sort_by = sort_by, decreasing = decreasing, n = n)
}

#' @export
groups.idiostats_fit <- function(x, subgroup = NULL, subject = NULL,
                                 sort_by = NULL, decreasing = FALSE, n = NULL,
                                 ...) {
  g <- x$spec$groups
  if (is.null(g) || !length(g)) {
    return(data.frame(subject = character(), subgroup = character(),
                      stringsAsFactors = FALSE))
  }
  tab <- data.frame(subject = names(g), subgroup = as.character(g),
                    stringsAsFactors = FALSE)
  .idio_filter_table(tab, subject = subject, subgroup = subgroup,
                     sort_by = sort_by, decreasing = decreasing, n = n)
}

#' Fit subgroup-specific models
#'
#' Fits pooled, subgroup and person-specific models together so all three levels
#' can be compared in one table.
#'
#' @inheritParams fit_lm
#' @param subgroup Subgroup mapping: an [find_subgroups()] result, a grouping
#'   column in `data`, or a named vector of labels per person.
#' @param method Which family to fit: `"lm"`, `"glm"`, or `"ml"`.
#' @param scope Defaults to `"all"` (pooled + subgroup + individual).
#' @param ... Passed to the underlying fitter, e.g. `model` or `family`.
#' @return An `idiostats_fit`.
#' @examples
#' g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                     id = "name", k = 2, reps = 10)
#' fit <- fit_subgroups(srl, y = "effort", x = "efficacy:monitoring",
#'                      id = "name", subgroup = g, time = "day")
#' metrics(fit, overall = TRUE)
#' @export
fit_subgroups <- function(data, y, x, id, subgroup, method = c("lm", "glm",
                                                               "ml"),
                          scope = "all", ...) {
  method <- match.arg(method)
  fitter <- switch(method, lm = fit_lm, glm = fit_glm, ml = fit_ml)
  fitter(data = data, y = y, x = x, id = id, scope = scope,
         subgroup = subgroup, ...)
}
