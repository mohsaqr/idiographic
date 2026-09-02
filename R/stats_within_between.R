# Within-person and between-person decomposition.
#
# The package's thesis is that a within-person effect and a between-person
# effect are different quantities. Person-centering keeps the within half and
# throws the between half away. These verbs keep both, put them in one model,
# and test whether they actually differ.
#
# Column names follow the `<var>_within` / `<var>_between` convention used by
# datawizard::demean(), so the output drops straight into an existing lme4
# formula.

# ------------------------------------------------------- variance components ----

#' Split repeated-measures variance into within- and between-person parts
#'
#' The first question to ask of any repeated-measures variable: is the variation
#' mostly *between* people (some people simply score higher) or *within* people
#' (everyone moves around a lot over time)? The answer decides whether
#' person-specific modelling can pay off at all.
#'
#' Called on a **data frame**, the default estimator is the one-way
#' random-effects ANOVA, which handles unbalanced panels through the usual `n0`
#' correction rather than assuming equal numbers of occasions per person:
#'
#' \deqn{\sigma^2_{between} = (MS_{between} - MS_{within}) / n_0,
#'       \qquad \sigma^2_{within} = MS_{within}}
#'
#' `method = "reml"` fits `v ~ 1 + (1 | id)` with `lme4` instead. The two agree
#' closely on balanced data; REML is preferable when the panel is badly
#' unbalanced.
#'
#' `icc` is the share of variance that lies between people. A high `icc` means
#' people differ mostly in *level*, and a pooled model that ignores the person
#' will be badly confounded. A low `icc` means most of the action is
#' within-person, which is what idiographic modelling is for.
#'
#' `reliability` is a different question -- how precisely each person's *mean*
#' is measured, given how many occasions they contributed. A variable can have a
#' low `icc` (little between-person variance) and still have high `reliability`
#' (that little variance is measured well).
#'
#' Called on a [fit_within_between()] result fitted with `estimator = "reml"` or
#' `"ml"`, it returns the **model's** variance components instead: one row per
#' grouping level plus the residual, which is what a null multilevel model is
#' usually run to obtain.
#'
#' @param x A data frame of repeated measures, or a [fit_within_between()]
#'   result.
#' @param vars Columns to decompose (any [fit_lm()] selector). Defaults to every
#'   numeric column other than `id`.
#' @param id Person/unit ID column.
#' @param method `"anova"` (base R, the default) or `"reml"` (needs `lme4`).
#' @param ... Ignored.
#' @return A `data.frame` with class `idiographic_variance`. For a data frame:
#'   one row per variable, with `variable`, `n`, `people`, `var_within`,
#'   `var_between`, `var_total`, `icc`, `reliability`. For a fitted model: one
#'   row per grouping level, with `level`, `variance`, `sd`, `icc`.
#' @examples
#' variance_components(srl, vars = "efficacy:organizing", id = "name")
#' @export
variance_components <- function(x, ...) UseMethod("variance_components")

#' @rdname variance_components
#' @export
variance_components.data.frame <- function(x, vars = NULL, id,
                                           method = c("anova", "reml"), ...) {
  method <- match.arg(method)
  data <- as.data.frame(x)
  if (!(is.character(id) && length(id) == 1L && id %in% names(data))) {
    stop("`id` must be one ID column name in `data`.", call. = FALSE)
  }
  vars <- if (is.null(vars)) {
    numeric_cols <- names(data)[vapply(data, is.numeric, logical(1))]
    setdiff(numeric_cols, id)
  } else {
    # `.idio_resolve_x()` already refuses non-numeric columns.
    .idio_resolve_x(data, vars, exclude = id)
  }
  if (!length(vars)) stop("No columns to decompose.", call. = FALSE)

  key <- as.character(data[[id]])
  rows <- lapply(vars, function(v) {
    if (method == "anova") {
      .idio_variance_one(data[[v]], key, v)
    } else {
      .idio_variance_reml(data[[v]], key, v)
    }
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  structure(out, class = c("idiographic_variance", "idiostats_variance",
                           "data.frame"), id = id,
            method = method)
}

#' @rdname variance_components
#' @export
variance_components.idiostats_wb <- function(x, ...) {
  if (is.null(x$variances) || !nrow(x$variances)) {
    stop("Model variance components need `estimator = \"reml\"` or ",
         "\"ml\"; an OLS fit has no random effects. Call ",
         "variance_components() on the data instead.", call. = FALSE)
  }
  structure(x$variances,
            class = c("idiographic_variance", "idiostats_variance",
                      "data.frame"),
            id = x$spec$id, method = x$spec$estimator)
}

#' One-way random-effects variance components for a single variable
#'
#' `n0` is the unbalanced-design correction: with equal group sizes it is just
#' that size, so the balanced case falls out of the same formula.
#'
#' @noRd
.idio_variance_one <- function(v, key, name) {
  ok <- !is.na(v) & !is.na(key)
  v <- as.numeric(v[ok])
  key <- key[ok]
  groups <- split(v, key)
  groups <- groups[lengths(groups) > 0L]
  n <- length(v)
  k <- length(groups)

  if (k < 2L || n <= k) return(.idio_variance_na(name, n, k))

  ni <- lengths(groups)
  group_means <- vapply(groups, mean, numeric(1))
  grand <- mean(v)

  ss_between <- sum(ni * (group_means - grand)^2)
  ss_within <- sum(vapply(groups, function(z) sum((z - mean(z))^2), numeric(1)))
  ms_between <- ss_between / (k - 1L)
  ms_within <- ss_within / (n - k)
  n0 <- (n - sum(ni^2) / n) / (k - 1L)
  if (!is.finite(n0) || n0 <= 0) return(.idio_variance_na(name, n, k))

  # A negative variance estimate is a real possibility in this ANOVA; it means
  # "no detectable between-person variance", so it is reported as zero.
  .idio_variance_row(name, n, k, ms_within, max(0, (ms_between - ms_within) / n0),
                     if (ms_between > 0) {
                       max(0, min(1, (ms_between - ms_within) / ms_between))
                     } else {
                       NA_real_
                     })
}

#' REML variance components for a single variable, via lme4
#' @noRd
.idio_variance_reml <- function(v, key, name) {
  .idio_require("lme4", "reml")
  ok <- !is.na(v) & !is.na(key)
  v <- as.numeric(v[ok])
  key <- key[ok]
  n <- length(v)
  k <- length(unique(key))
  if (k < 2L || n <= k) return(.idio_variance_na(name, n, k))

  d <- data.frame(.idio_v = v, .idio_g = factor(key))
  # A convergence or singularity warning is worth surfacing, but it is not a
  # reason to throw the fit away: silently returning the ANOVA estimate while
  # still labelling the result "reml" would report one estimator under another
  # one's name. Only a genuine error falls back, and it says so.
  fit <- withCallingHandlers(
    tryCatch(lme4::lmer(.idio_v ~ 1 + (1 | .idio_g), data = d, REML = TRUE),
             error = function(e) NULL),
    warning = function(w) {
      warning("lme4 while fitting `", name, "`: ", conditionMessage(w),
              call. = FALSE)
      invokeRestart("muffleWarning")
    }
  )
  if (is.null(fit)) {
    warning("REML could not fit `", name, "`; reporting the ANOVA ",
            "decomposition for it instead.", call. = FALSE)
    return(.idio_variance_one(v, key, name))
  }

  vc <- as.data.frame(lme4::VarCorr(fit))
  between <- vc$vcov[vc$grp == ".idio_g"][1L]
  within <- vc$vcov[vc$grp == "Residual"][1L]
  # Reliability of a person mean, at the average number of occasions.
  n_bar <- n / k
  reliability <- if (between + within / n_bar > 0) {
    between / (between + within / n_bar)
  } else {
    NA_real_
  }
  .idio_variance_row(name, n, k, within, between, reliability)
}

.idio_variance_row <- function(name, n, k, within, between, reliability) {
  total <- within + between
  data.frame(
    variable = name, n = as.integer(n), people = as.integer(k),
    var_within = within, var_between = between, var_total = total,
    icc = if (isTRUE(total > 0)) between / total else NA_real_,
    reliability = reliability, stringsAsFactors = FALSE
  )
}

.idio_variance_na <- function(name, n, k) {
  data.frame(variable = name, n = as.integer(n), people = as.integer(k),
             var_within = NA_real_, var_between = NA_real_,
             var_total = NA_real_, icc = NA_real_, reliability = NA_real_,
             stringsAsFactors = FALSE)
}

#' @export
print.idiostats_variance <- function(x, ...) {
  tab <- as.data.frame(x)
  cat("VARIANCE COMPONENTS\n")
  .idio_print_info(rbind(
    c("Grouping", attr(x, "id") %||% "-"),
    c("Method", attr(x, "method") %||% "anova")
  ))
  cat("\n")
  if (!nrow(tab)) {
    cat("  Nothing to report.\n")
    return(invisible(x))
  }
  if ("variable" %in% names(tab)) {
    .idio_print_block(
      cbind(tab$variable, .idio_num(tab$var_within),
            .idio_num(tab$var_between), .idio_num(tab$icc, 3L),
            .idio_num(tab$reliability, 3L)),
      headers = c("", "Within", "Between", "ICC", "Reliability")
    )
    cat("\n  ICC         share of variance lying BETWEEN groups\n")
    cat("  Reliability precision of each group's own mean\n")
  } else {
    .idio_print_block(
      cbind(tab$level, .idio_num(tab$variance), .idio_num(tab$sd),
            .idio_num(tab$icc, 3L)),
      headers = c("Group", "Variance", "Std. Dev.", "ICC")
    )
  }
  invisible(x)
}

# ------------------------------------------------------------- decomposition ----

#' Person means of each column, as a named lookup per variable
#' @noRd
.idio_person_means <- function(vals, key) {
  lapply(vals, function(v) {
    tapply(as.numeric(v), key, function(z) mean(z, na.rm = TRUE))
  })
}

#' Within and between matrices, given person means to apply
#'
#' Applying *supplied* means (rather than recomputing them) is what lets a
#' model built on training rows score held-out rows without looking at them,
#' exactly as `.idio_scale()` does for standardization.
#'
#' @noRd
.idio_decompose_cols <- function(vals, key, means) {
  nm <- names(vals)
  between <- matrix(
    unlist(lapply(nm, function(v) unname(means[[v]][key]))),
    nrow = length(key), dimnames = list(NULL, nm)
  )
  list(within = as.matrix(vals) - between, between = between)
}

# --------------------------------------------------------- within-between fit ----

#' Fit a within-between (hybrid) model
#'
#' Puts the within-person and the between-person component of a predictor into
#' **one** model, so the two effects can be compared directly and the gap
#' between them tested. Person-centering alone cannot do this: it estimates the
#' within effect and discards the between effect entirely.
#'
#' Each predictor `x` is split into a person mean (the between component) and
#' the deviation from it (the within component).
#'
#' @section Model parameterizations:
#' \describe{
#'   \item{`within_between`}{Both components as separate terms (the default).
#'     The contextual effect is their difference, tested as a contrast.}
#'   \item{`within`}{The within component only -- the fixed-effects estimator.
#'     The only parameterization that also works at individual scope.}
#'   \item{`between`}{The between component only.}
#'   \item{`contextual`}{The raw predictor plus the person mean. Algebraically
#'     equivalent to `within_between`, but the coefficient on the person mean
#'     *is* the contextual effect directly, rather than a contrast of two.}
#' }
#'
#' @section Estimators:
#' `"ols"` (the default, base R) fits by least squares with **cluster-robust**
#' standard errors; rows within a person are not independent, and treating them
#' as independent gives roughly 77% coverage where 95% is claimed. Pass
#' `cluster` to cluster on something other than -- or in addition to -- the
#' person; with two clustering variables the Cameron-Gelbach-Miller two-way
#' estimator is used, which is what a design with people crossed by courses
#' needs.
#'
#' `"reml"` and `"ml"` fit a mixed model with `lme4` instead, adding a random
#' intercept for `id` and for anything named in `random`. This is what makes a
#' cross-classified design -- `(1 | person) + (1 | course)` -- expressible, and
#' it makes the model's variance components available through
#' [variance_components()]. The fixed-effect estimates agree closely with the
#' OLS ones; what differs is the standard errors and the variance decomposition.
#'
#' Person means are computed on the **training** rows and applied to the
#' held-out rows, so the reported metrics stay honest.
#'
#' @inheritParams fit_lm
#' @param model Parameterization: `"within_between"`, `"within"`, `"between"`,
#'   or `"contextual"`. See Details.
#' @param estimator `"ols"` (cluster-robust least squares), or `"reml"` / `"ml"`
#'   for a mixed model via `lme4`.
#' @param scope `"pooled"`, `"subgroup"`, or `"all"`. A between-person term is
#'   constant inside a person, so individual scope is available only for
#'   `model = "within"`.
#' @param random Extra grouping columns to give random intercepts, e.g.
#'   `random = "course"` for a cross-classified design. Mixed estimators only.
#' @param cluster Column(s) to cluster standard errors on, defaulting to `id`.
#'   Up to two, for two-way clustering. OLS only.
#' @param conf_level Confidence level for the reported intervals.
#' @return An `idiographic_wb` object, which is also an `idiographic_fit`. `coefs()`
#'   gains `component` and `variable` columns; [contextual()] returns the
#'   within/between comparison.
#' @examples
#' fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
#'                           id = "name", time = "day")
#' coefs(fit)
#' contextual(fit)
#'
#' # The contextual parameterization reports the same gap as one coefficient.
#' fit_within_between(srl, y = "effort", x = "efficacy", id = "name",
#'                    model = "contextual")
#' @export
fit_within_between <- function(data, y, x, id, time = NULL,
                               model = c("within_between", "within", "between",
                                         "contextual"),
                               estimator = c("ols", "reml", "ml"),
                               scope = "pooled", subgroup = NULL,
                               random = NULL, cluster = NULL,
                               conf_level = 0.95, test_prop = 0.2,
                               min_train = 10L, min_test = 1L) {
  model <- match.arg(model)
  estimator <- match.arg(estimator)
  if (!(is.numeric(conf_level) && length(conf_level) == 1L &&
        conf_level > 0 && conf_level < 1)) {
    stop("`conf_level` must be a number between 0 and 1.", call. = FALSE)
  }
  scopes <- .idio_scope(scope)
  if ("individual" %in% scopes && model != "within") {
    stop("A between-person term is constant inside a person, so `model = \"",
         model, "\"` cannot be estimated at individual scope. Use ",
         "`model = \"within\"`, or `scope = \"pooled\"` / \"subgroup\".",
         call. = FALSE)
  }
  random <- .idio_wb_group_cols(random, "random", data)
  cluster <- .idio_wb_group_cols(cluster, "cluster", data)
  if (length(random) && estimator == "ols") {
    stop("`random` needs a mixed estimator. Use `estimator = \"reml\"` or ",
         "\"ml\", or cluster on it instead with `cluster`.", call. = FALSE)
  }
  if (length(cluster) && estimator != "ols") {
    stop("`cluster` applies to `estimator = \"ols\"`. A mixed estimator ",
         "models the grouping with `random` instead.", call. = FALSE)
  }
  if (length(cluster) > 2L) {
    stop("`cluster` takes at most two columns (two-way clustering).",
         call. = FALSE)
  }

  # A person-constant predictor is refused elsewhere because a person-specific
  # model cannot estimate it. Here it is legitimate: it is purely between.
  prep <- .idio_prepare(data, y, x, id, time = time, scope = scope,
                        subgroup = subgroup, test_prop = test_prop,
                        min_train = min_train, min_test = min_test,
                        task = "regression", exclude = c(random, cluster),
                        allow_person_constant = TRUE)

  done <- lapply(prep$units, function(unit) {
    res <- tryCatch(.idio_wb_unit(prep, unit, y, prep$x, id, model, estimator,
                                  random, cluster, conf_level),
                    error = function(e) e)
    if (inherits(res, "error")) return(.idio_tag_error(res, unit, model,
                                                       estimator))
    res$key <- .idio_unit_key(unit, model)
    res
  })

  out <- .idio_assemble(done, prep$failures, "regression", NULL, spec = NULL)
  ok <- !vapply(done, inherits, logical(1), "error")
  ctx <- do.call(rbind, lapply(done[ok], `[[`, "contextual"))
  rownames(ctx) <- NULL
  variances <- do.call(rbind, lapply(done[ok], `[[`, "variances"))
  rownames(variances) <- NULL

  out$contextual <- ctx %||% .idio_empty_contextual()
  out$variances <- variances
  out$spec <- .idio_spec("within_between", model, estimator, y, prep$x, id,
                         prep$scopes, "regression", time, prep$groups)
  out$spec$conf_level <- conf_level
  out$spec$random <- random
  out$spec$cluster <- if (length(cluster)) cluster else id
  class(out) <- c("idiographic_wb", "idiostats_wb",
                  "idiographic_fit", "idiostats_fit")
  out
}

#' Validate a set of grouping column names
#' @noRd
.idio_wb_group_cols <- function(cols, arg, data) {
  if (is.null(cols)) return(character(0))
  if (!is.character(cols)) {
    stop("`", arg, "` must be column name(s) in `data`.", call. = FALSE)
  }
  missing <- setdiff(cols, names(data))
  if (length(missing)) {
    stop("`", arg, "` column(s) not found in `data`: ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  }
  unique(cols)
}

#' Fit one within-between unit
#' @noRd
.idio_wb_unit <- function(prep, unit, y, x, id, model, estimator, random,
                          cluster, conf_level) {
  train <- .idio_unit_rows(prep$data, unit, c("train", "valid"))
  test <- .idio_unit_rows(prep$data, unit, "test")
  if (!nrow(test)) stop("No held-out rows for this unit.", call. = FALSE)
  key_train <- as.character(train[[id]])
  if (model != "within" && length(unique(key_train)) < 2L) {
    stop("A between-person term needs at least two people; with one person ",
         "there is no between-person variation.", call. = FALSE)
  }

  means <- .idio_person_means(train[x], key_train)
  build <- .idio_wb_design(train[x], key_train, means, x, model)
  full <- build$matrix

  # A predictor with no variation in a component contributes an all-zero
  # column; keeping it would make the design singular, so it is dropped and
  # reported as NA rather than silently absorbed.
  spread <- apply(full, 2L, stats::sd, na.rm = TRUE)
  keep <- is.finite(spread) & spread > 0
  if (!any(keep)) {
    stop("No predictor varies once split into within and between parts.",
         call. = FALSE)
  }
  # Collinear columns are the same problem one step further on: a generalized
  # inverse would still return numbers, but it splits a shared effect between
  # aliased columns arbitrarily -- rescaling a duplicate predictor changes the
  # reported coefficients without changing the fit. Drop the aliased ones and
  # report them as NA instead of attaching statistics to an arbitrary split.
  keep[keep] <- .idio_identifiable(cbind(1, full[, keep, drop = FALSE]))[-1L]
  if (!any(keep)) {
    stop("No predictor is identifiable once split into within and between ",
         "parts.", call. = FALSE)
  }
  design <- cbind(1, full[, keep, drop = FALSE])
  colnames(design) <- c("(Intercept)", build$terms[keep])

  # Cluster identifiers have to be complete too. `split()` silently drops NA
  # groups, so a row with a missing cluster would still enter X'X and the
  # residuals while contributing nothing to the sandwich meat -- leaving the
  # coefficient and its variance computed on different samples.
  cluster_cols <- if (length(cluster)) cluster else id
  cluster_ok <- Reduce(`&`, lapply(cluster_cols, function(v) !is.na(train[[v]])))
  complete <- stats::complete.cases(design) & !is.na(train[[y]]) & cluster_ok
  if (sum(complete) <= ncol(design)) {
    stop("Too few complete training rows for a within-between model.",
         call. = FALSE)
  }
  design <- design[complete, , drop = FALSE]
  y_train <- as.numeric(train[[y]])[complete]
  train_rows <- train[complete, , drop = FALSE]

  est <- if (estimator == "ols") {
    clusters <- lapply(if (length(cluster)) cluster else id,
                       function(v) as.character(train_rows[[v]]))
    .idio_wb_ols(y_train, design, clusters, conf_level)
  } else {
    .idio_wb_mixed(y_train, design, train_rows, id, random,
                   reml = estimator == "reml", conf_level)
  }

  # Held-out rows are decomposed with the TRAINING person means.
  key_test <- as.character(test[[id]])
  test_build <- .idio_wb_design(test[x], key_test, means, x, model)
  test_design <- cbind(1, test_build$matrix[, keep, drop = FALSE])
  colnames(test_design) <- colnames(design)
  test_ok <- stats::complete.cases(test_design) & !is.na(test[[y]])
  if (!any(test_ok)) {
    stop("No held-out row could be scored: every person in the test rows is ",
         "missing a training person mean.", call. = FALSE)
  }
  test <- test[test_ok, , drop = FALSE]
  fitted <- .idio_wb_predict(est, test_design[test_ok, , drop = FALSE], test,
                             id, random)

  pred <- .idio_prediction_rows(fitted, test, y, id, unit, model, estimator,
                                "regression", NULL)
  coefs <- .idio_wb_coef_rows(est, unit, model, estimator, build, keep,
                              conf_level)
  ctx <- .idio_contextual_rows(est, design, conf_level, unit, model, estimator,
                               x, build, keep)
  variances <- if (!is.null(est$variances) && nrow(est$variances)) {
    cbind(scope = unit$scope, model = model, estimator = estimator,
          subject = unit$subject, subgroup = unit$subgroup, est$variances,
          stringsAsFactors = FALSE)
  } else {
    NULL
  }

  list(fit = est$fit %||% list(coefficients = est$beta, means = means),
       pred = pred, coefs = coefs, contextual = ctx, variances = variances)
}

#' Build the design columns for a parameterization
#'
#' `contextual` uses the raw predictor beside the person mean: the coefficient
#' on the mean is then the contextual effect itself, not a contrast of two.
#'
#' @noRd
.idio_wb_design <- function(vals, key, means, x, model) {
  parts <- .idio_decompose_cols(vals, key, means)
  switch(model,
    within_between = list(
      matrix = cbind(parts$within, parts$between),
      terms = c(paste0(x, "_within"), paste0(x, "_between")),
      components = rep(c("within", "between"), each = length(x)),
      variables = rep(x, 2L)
    ),
    within = list(matrix = parts$within, terms = paste0(x, "_within"),
                  components = rep("within", length(x)), variables = x),
    between = list(matrix = parts$between, terms = paste0(x, "_between"),
                   components = rep("between", length(x)), variables = x),
    contextual = list(
      matrix = cbind(as.matrix(vals), parts$between),
      terms = c(x, paste0(x, "_between")),
      components = rep(c("within", "contextual"), each = length(x)),
      variables = rep(x, 2L)
    )
  )
}

#' Which columns of a design are actually identified
#'
#' A generalized inverse will happily return coefficients for an aliased
#' design, but the split between collinear columns is arbitrary: for `y = 3 +
#' 2x`, the design `(1, x, x)` gives `(3, 1, 1)` while `(1, x, 2x)` gives
#' `(3, .4, .8)`. Both fit exactly and both encode the same slope, yet the
#' reported per-term numbers differ only because a duplicate was rescaled.
#' The QR pivot says which columns carry independent information; the rest are
#' reported as `NA`.
#'
#' @noRd
.idio_identifiable <- function(X) {
  X <- as.matrix(X)
  decomposition <- qr(X)
  keep <- rep(FALSE, ncol(X))
  keep[sort(decomposition$pivot[seq_len(decomposition$rank)])] <- TRUE
  keep
}

#' Least squares with one- or two-way cluster-robust variance
#'
#' Two clustering variables use the Cameron-Gelbach-Miller estimator,
#' `V1 + V2 - V12`, which is what a design with people crossed by another
#' grouping (courses, sites, waves) needs -- clustering on the person alone
#' would understate the uncertainty.
#'
#' @noRd
.idio_wb_ols <- function(y, X, clusters, conf) {
  X <- as.matrix(X)
  n <- nrow(X)
  xtx <- crossprod(X)
  bread <- tryCatch(solve(xtx), error = function(e) MASS_ginv(xtx))
  beta <- as.numeric(bread %*% crossprod(X, y))
  resid <- y - as.numeric(X %*% beta)

  # `.idio_sandwich()` falls back to the row-level HC1 form when a grouping has
  # only one level, because a one-cluster clustered meat is identically zero.
  if (length(clusters) == 1L) {
    one <- .idio_sandwich(X, resid, clusters[[1L]], bread)
    V <- one$V
    n_cl <- one$n_clusters
    df <- one$df
  } else {
    a <- .idio_sandwich(X, resid, clusters[[1L]], bread)
    b <- .idio_sandwich(X, resid, clusters[[2L]], bread)
    both <- .idio_sandwich(X, resid,
                           paste(clusters[[1L]], clusters[[2L]], sep = "\r"),
                           bread)
    V <- a$V + b$V - both$V
    n_cl <- min(a$n_clusters, b$n_clusters)
    df <- min(a$df, b$df)
  }
  names(beta) <- colnames(X)
  list(beta = beta, V = V, df = df, n = n, n_clusters = n_cl,
       variances = NULL, fit = NULL)
}

#' Mixed model via lme4, with random intercepts for id and anything in `random`
#' @noRd
.idio_wb_mixed <- function(y, X, rows, id, random, reml, conf) {
  .idio_require("lme4", if (reml) "reml" else "ml")
  X <- as.matrix(X)
  predictors <- setdiff(colnames(X), "(Intercept)")
  safe <- make.names(predictors, unique = TRUE)

  d <- as.data.frame(X[, predictors, drop = FALSE])
  names(d) <- safe
  d$.idio_y <- y
  groups <- c(id, random)
  safe_groups <- make.names(paste0("g_", groups), unique = TRUE)
  for (i in seq_along(groups)) d[[safe_groups[i]]] <- factor(rows[[groups[i]]])

  rhs <- paste(c(if (length(safe)) safe else "1",
                 sprintf("(1 | %s)", safe_groups)), collapse = " + ")
  form <- stats::as.formula(paste(".idio_y ~", rhs))
  # Convergence and singularity warnings are the ones a reader most needs, so
  # they are passed on rather than muffled.
  fit <- withCallingHandlers(
    lme4::lmer(form, data = d, REML = reml),
    warning = function(w) {
      warning("lme4: ", conditionMessage(w), call. = FALSE)
      invokeRestart("muffleWarning")
    }
  )

  # lme4 DROPS rank-deficient fixed effects, so `fixef()` can come back shorter
  # than the design. Renaming positionally would then slide every later
  # coefficient onto the previous variable's name -- with `x_within` and
  # `x_between` adjacent, that silently reports a between effect as a within
  # one. Ask for the dropped terms back and align by name instead.
  wanted <- c("(Intercept)", safe)
  full <- lme4::fixef(fit, add.dropped = TRUE)
  beta <- stats::setNames(unname(full[wanted]), c("(Intercept)", predictors))

  fitted_V <- as.matrix(stats::vcov(fit))
  V <- matrix(NA_real_, length(beta), length(beta),
              dimnames = list(names(beta), names(beta)))
  present <- match(rownames(fitted_V), wanted)
  V[present, present] <- fitted_V

  vc <- as.data.frame(lme4::VarCorr(fit))
  vc <- vc[is.na(vc$var2), , drop = FALSE]
  level <- ifelse(vc$grp == "Residual", "Residual",
                  groups[match(vc$grp, safe_groups)])
  total <- sum(vc$vcov)
  variances <- data.frame(
    level = level, variance = vc$vcov, sd = sqrt(vc$vcov),
    icc = if (total > 0) vc$vcov / total else NA_real_,
    stringsAsFactors = FALSE
  )

  n_cl <- length(unique(rows[[id]]))
  list(beta = beta, V = V, df = max(n_cl - 1L, 1L), n = nrow(X),
       n_clusters = n_cl, variances = variances,
       fit = fit, safe = stats::setNames(safe, predictors),
       safe_groups = stats::setNames(safe_groups, groups))
}

#' Predict held-out rows, using random effects when the model has them
#' @noRd
.idio_wb_predict <- function(est, test_design, test, id, random) {
  if (is.null(est$fit)) {
    return(as.numeric(test_design %*% est$beta))
  }
  predictors <- setdiff(colnames(test_design), "(Intercept)")
  d <- as.data.frame(test_design[, predictors, drop = FALSE])
  names(d) <- unname(est$safe[predictors])
  groups <- c(id, random)
  for (g in groups) d[[est$safe_groups[[g]]]] <- factor(test[[g]])
  as.numeric(stats::predict(est$fit, newdata = d, allow.new.levels = TRUE))
}

#' Turn an estimate object into confidence intervals and p-values
#' @noRd
.idio_wb_stats <- function(est, conf) {
  se <- sqrt(pmax(diag(est$V), 0))
  crit <- stats::qt(1 - (1 - conf) / 2, df = est$df)
  stat <- ifelse(se > 0, est$beta / se, NA_real_)
  list(estimate = est$beta, se = se, lo = est$beta - crit * se,
       hi = est$beta + crit * se, stat = stat,
       p = 2 * stats::pt(-abs(stat), df = est$df))
}

#' Tidy coefficient rows, tagged with which component each term is
#' @noRd
.idio_wb_coef_rows <- function(est, unit, model, estimator, build, keep, conf) {
  s <- .idio_wb_stats(est, conf)
  terms <- build$terms
  slot <- rep(NA_integer_, length(terms))
  slot[keep] <- seq_len(sum(keep)) + 1L
  pick <- function(v) c(v[1L], ifelse(is.na(slot), NA_real_, v[slot]))

  estimate <- pick(s$estimate)
  std_error <- pick(s$se)
  data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = unit$subject, subgroup = unit$subgroup,
    term = c("(Intercept)", terms),
    component = c(".none", build$components),
    variable = c(".none", build$variables),
    estimate = estimate, std_error = std_error,
    statistic = pick(s$stat), p_value = pick(s$p),
    conf_low = pick(s$lo), conf_high = pick(s$hi),
    stringsAsFactors = FALSE
  )
}

#' The contextual effect: between minus within, with the model's own variance
#'
#' Under `model = "contextual"` the coefficient on the person mean already IS
#' this quantity, so it is read off rather than contrasted.
#'
#' @noRd
.idio_contextual_rows <- function(est, design, conf, unit, model, estimator, x,
                                  build, keep) {
  terms <- build$terms
  slot <- rep(NA_integer_, length(terms))
  slot[keep] <- seq_len(sum(keep)) + 1L
  s <- .idio_wb_stats(est, conf)
  crit <- stats::qt(1 - (1 - conf) / 2, df = est$df)
  at <- function(i) if (is.na(i)) NA_real_ else unname(s$estimate[i])
  n_x <- length(x)

  rows <- lapply(seq_len(n_x), function(j) {
    if (model %in% c("within", "between")) {
      # Only one component is in the model, so there is nothing to compare.
      comp <- if (model == "within") "within" else "between"
      value <- at(slot[j])
      return(.idio_contextual_row(
        unit, model, estimator, x[j],
        if (comp == "within") value else NA_real_,
        if (comp == "between") value else NA_real_,
        NA_real_, NA_real_, NA_real_, NA_real_, NA_real_, NA_real_))
    }

    first <- slot[j]
    second <- slot[j + n_x]
    if (is.na(first) || is.na(second)) {
      # Whichever component survived is still a real, estimable effect.
      return(.idio_contextual_row(unit, model, estimator, x[j], at(first),
                                  at(second), NA_real_, NA_real_, NA_real_,
                                  NA_real_, NA_real_, NA_real_))
    }

    if (model == "contextual") {
      within <- at(first)
      gap <- at(second)
      se <- unname(s$se[second])
      between <- within + gap
    } else {
      within <- at(first)
      between <- at(second)
      contrast <- rep(0, length(s$estimate))
      contrast[first] <- -1
      contrast[second] <- 1
      gap <- sum(contrast * s$estimate)
      se <- sqrt(max(as.numeric(t(contrast) %*% est$V %*% contrast), 0))
    }
    stat <- if (is.finite(se) && se > 0) gap / se else NA_real_
    .idio_contextual_row(
      unit, model, estimator, x[j], within, between, gap, se,
      gap - crit * se, gap + crit * se, stat,
      if (is.na(stat)) NA_real_ else 2 * stats::pt(-abs(stat), df = est$df))
  })
  do.call(rbind, rows)
}

.idio_contextual_row <- function(unit, model, estimator, variable, within,
                                 between, est, se, lo, hi, stat, p) {
  data.frame(
    scope = unit$scope, model = model, estimator = estimator,
    subject = unit$subject, subgroup = unit$subgroup,
    variable = variable, within = within, between = between,
    contextual = est, std_error = se, conf_low = lo, conf_high = hi,
    statistic = stat, p_value = p, stringsAsFactors = FALSE
  )
}

.idio_empty_contextual <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), subgroup = character(),
             variable = character(), within = numeric(), between = numeric(),
             contextual = numeric(), std_error = numeric(),
             conf_low = numeric(), conf_high = numeric(),
             statistic = numeric(), p_value = numeric(),
             stringsAsFactors = FALSE)
}

#' Compare the within-person and between-person effect of each predictor
#'
#' The point of a within-between model. `within` is the effect of a person
#' moving away from their own average; `between` is the effect of one person
#' averaging higher than another. `contextual` is `between - within`, with a
#' person-clustered test: if its interval excludes zero, the two processes are
#' genuinely different and pooling them into one coefficient is a modelling
#' error.
#'
#' `model = "within"` and `model = "between"` fit only one component, so their
#' contextual effect is `NA` -- there is nothing to compare it against.
#'
#' @param x A [fit_within_between()] result.
#' @param variable,scope,subject,subgroup Optional filters.
#' @param sort_by Optional column to sort by.
#' @param decreasing Sort order when `sort_by` is supplied.
#' @param n Optional number of rows.
#' @param ... Ignored.
#' @return A data frame with one row per predictor per unit.
#' @examples
#' fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
#'                           id = "name", time = "day")
#' contextual(fit)
#' @export
contextual <- function(x, variable = NULL, scope = NULL, subject = NULL,
                       subgroup = NULL, sort_by = NULL, decreasing = FALSE,
                       n = NULL, ...) UseMethod("contextual")

#' @export
contextual.idiostats_wb <- function(x, variable = NULL, scope = NULL,
                                    subject = NULL, subgroup = NULL,
                                    sort_by = NULL, decreasing = FALSE,
                                    n = NULL, ...) {
  tab <- x$contextual
  if (!is.null(variable)) {
    tab <- tab[tab$variable %in% variable, , drop = FALSE]
  }
  out <- .idio_filter_table(tab, scope = scope, subject = subject,
                            subgroup = subgroup, sort_by = sort_by,
                            decreasing = decreasing, n = n)
  structure(out, class = c("idiographic_contextual", "idiostats_contextual",
                           "data.frame"))
}

#' @export
print.idiostats_contextual <- function(x, ...) {
  tab <- as.data.frame(x)
  if (!nrow(tab)) {
    cat("No contextual effects.\n")
    return(invisible(x))
  }
  # The five spine columns are part of the tidy contract, but when they carry
  # the same value in every row they are noise on screen. Show them once,
  # underneath, rather than repeating them across every row.
  spine <- c("scope", "model", "estimator", "subject", "subgroup")
  constant <- spine[vapply(spine, function(v) {
    length(unique(tab[[v]])) == 1L
  }, logical(1))]

  varying <- setdiff(spine, constant)
  labelled <- !identical(rownames(tab), as.character(seq_len(nrow(tab))))
  left <- cbind(if (labelled) rownames(tab),
                if (length(varying)) as.matrix(tab[varying]),
                tab$variable)
  left_headers <- c(if (labelled) "", varying, "variable")

  # A single-component model leaves whole columns unestimable; printing four
  # columns of dashes is noise, so they are dropped from the display only.
  candidates <- list(
    list("within", tab$within, .idio_num(tab$within)),
    list("between", tab$between, .idio_num(tab$between)),
    list("contextual", tab$contextual, .idio_num(tab$contextual)),
    list("S.E.", tab$std_error, .idio_num(tab$std_error)),
    list("95% CI", tab$conf_low,
         sprintf("[%s, %s]", .idio_num(tab$conf_low, 3L),
                 .idio_num(tab$conf_high, 3L))),
    list("p", tab$p_value, .idio_pval(tab$p_value))
  )
  keep <- vapply(candidates, function(z) any(is.finite(z[[2L]])), logical(1))
  candidates <- candidates[keep]

  .idio_print_block(
    cbind(left, do.call(cbind, lapply(candidates, `[[`, 3L))),
    headers = c(left_headers, vapply(candidates, `[[`, character(1), 1L)),
    n_left = ncol(left)
  )
  if (length(constant)) {
    cat("\n", paste(sprintf("%s = %s", constant,
                            vapply(constant, function(v) {
                              as.character(tab[[v]][1L])
                            }, character(1))), collapse = ",  "), "\n", sep = "")
  }
  invisible(x)
}

# ------------------------------------------------------------- printing ----
# A within-between model has two sets of coefficients that mean different
# things, so a single flat coefficient dump is the wrong shape for it. The
# printed form separates them into blocks, the way the model is actually read.

#' Format numbers for a printed block, with a dash for what is not estimable
#' @noRd
.idio_num <- function(v, digits = 4L) {
  ifelse(is.na(v), "-", formatC(v, format = "f", digits = digits))
}

.idio_pval <- function(p) {
  ifelse(is.na(p), "-", format.pval(p, digits = 3L, eps = 1e-4))
}

#' Print an aligned block
#'
#' The first `n_left` columns are label columns and are left-aligned; the rest
#' are numbers and are right-aligned on the decimal-formatted string.
#'
#' @noRd
.idio_print_block <- function(cells, headers, n_left = 1L, indent = "  ") {
  body <- as.matrix(cells)
  widths <- vapply(seq_len(ncol(body)), function(j) {
    max(nchar(c(headers[j], body[, j])), na.rm = TRUE)
  }, integer(1))
  row <- function(vals) {
    formatted <- vapply(seq_along(vals), function(j) {
      formatC(vals[j], width = if (j <= n_left) -widths[j] else widths[j])
    }, character(1))
    paste0(indent, paste(formatted, collapse = "   "))
  }
  cat(row(headers), "\n", sep = "")
  cat(strrep("-", nchar(row(headers))), "\n", sep = "")
  for (i in seq_len(nrow(body))) cat(row(body[i, ]), "\n", sep = "")
  invisible(NULL)
}

#' Print a two-column key/value block
#' @noRd
.idio_print_info <- function(pairs, indent = "  ") {
  width <- max(nchar(pairs[, 1L]))
  for (i in seq_len(nrow(pairs))) {
    cat(indent, formatC(pairs[i, 1L], width = -width), "   ", pairs[i, 2L],
        "\n", sep = "")
  }
  invisible(NULL)
}

#' @export
print.idiostats_wb <- function(x, ...) {
  spec <- x$spec
  scopes <- unique(x$contextual$scope)
  primary <- if ("pooled" %in% scopes) "pooled" else scopes[1L]
  cf <- x$coefs[x$coefs$scope == primary, , drop = FALSE]
  ctx <- x$contextual[x$contextual$scope == primary, , drop = FALSE]
  people <- length(unique(x$predictions$subject))

  cat("MODEL INFO\n")
  .idio_print_info(rbind(
    c("Outcome", spec$y),
    c("Predictors", paste(spec$x, collapse = ", ")),
    c("Person ID", sprintf("%s (%d people)", spec$id, people)),
    c("Specification", gsub("_", "-", spec$model)),
    c("Estimator", if (spec$estimator == "ols") {
      sprintf("OLS, cluster-robust on %s",
              paste(spec$cluster, collapse = " + "))
    } else {
      sprintf("%s mixed model, %s", toupper(spec$estimator),
              paste(sprintf("(1 | %s)", c(spec$id, spec$random)),
                    collapse = " + "))
    }),
    c("Scope", paste(spec$scope, collapse = " + "))
  ))

  met <- x$metrics[x$metrics$scope == primary &
                     x$metrics$subject == ".overall", , drop = FALSE]
  if (nrow(met)) {
    cat("\nMODEL FIT (held out)\n")
    .idio_print_info(rbind(
      c("Rows", format(met$n[1L], big.mark = ",")),
      c("RMSE", .idio_num(met$rmse[1L])),
      c("R-squared", .idio_num(met$r_squared[1L]))
    ))
  }

  if (primary == "individual") {
    cat(sprintf("\n%d individual models. Use contextual() or coefs() for the\n",
                length(unique(ctx$subject))))
    cat("per-person estimates, or plot_components() to see them.\n")
    return(invisible(x))
  }

  block <- function(title, component) {
    rows <- cf[cf$component == component & is.finite(cf$estimate), ,
               drop = FALSE]
    if (!nrow(rows)) return(invisible(NULL))
    cat("\n", title, "\n", sep = "")
    .idio_print_block(
      cbind(rows$variable, .idio_num(rows$estimate),
            .idio_num(rows$std_error), .idio_num(rows$statistic, 2L),
            .idio_pval(rows$p_value)),
      headers = c("", "Est.", "S.E.", "t val.", "p")
    )
  }
  block("WITHIN EFFECTS", "within")
  block("BETWEEN EFFECTS", "between")

  gap <- ctx[is.finite(ctx$contextual), , drop = FALSE]
  if (nrow(gap)) {
    cat("\nCONTEXTUAL EFFECTS (between - within)\n")
    .idio_print_block(
      cbind(gap$variable, .idio_num(gap$contextual),
            .idio_num(gap$std_error),
            sprintf("[%s, %s]", .idio_num(gap$conf_low, 3L),
                    .idio_num(gap$conf_high, 3L)),
            .idio_pval(gap$p_value)),
      headers = c("", "Est.", "S.E.", "95% CI", "p")
    )
    cat("  An interval excluding zero means the two processes differ.\n")
  }

  if (!is.null(x$variances) && nrow(x$variances)) {
    v <- x$variances[x$variances$scope == primary, , drop = FALSE]
    cat("\nRANDOM EFFECTS\n")
    .idio_print_block(
      cbind(v$level, .idio_num(v$variance), .idio_num(v$sd),
            .idio_num(v$icc, 3L)),
      headers = c("Group", "Variance", "Std. Dev.", "ICC")
    )
  }

  if (nrow(x$failures)) {
    cat(sprintf("\n%d unit(s) failed; see $failures.\n", nrow(x$failures)))
  }
  invisible(x)
}

# -------------------------------------------------------------------- plots ----

#' Plot the within/between split of variance
#'
#' One bar per variable, split into the share of variance lying within people
#' and between people. Variables at the top are the ones where people differ in
#' level; variables at the bottom are the ones that move within a person.
#'
#' @param x A [variance_components()] result.
#' @param sort_by Sort bars by this column; `NULL` keeps input order.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' v <- variance_components(srl, vars = "efficacy:organizing", id = "name")
#' plot_variance(v)
#' @export
plot_variance <- function(x, sort_by = "icc", ...) {
  if (!inherits(x, "idiostats_variance")) {
    stop("plot_variance() needs a variance_components() result.", call. = FALSE)
  }
  tab <- as.data.frame(x)
  label <- if ("variable" %in% names(tab)) "variable" else "level"
  tab <- tab[is.finite(tab$icc), , drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("No variance components available")
    return(invisible(tab))
  }
  if (!is.null(sort_by) && sort_by %in% names(tab)) {
    tab <- tab[order(tab[[sort_by]]), , drop = FALSE]
  }

  shares <- rbind(between = tab$icc, within = 1 - tab$icc)
  op <- .idio_plot_begin(mar = c(4.2, 8, 1, 1))
  on.exit(par(op), add = TRUE)
  at <- barplot(shares, horiz = TRUE, names.arg = tab[[label]], las = 1,
                col = c(.idio_colours[["blue"]], .idio_colours[["pale_blue"]]),
                border = NA, xlim = c(0, 1), xlab = "Share of observed variance",
                axes = FALSE, ...)
  graphics::axis(1, at = seq(0, 1, by = 0.25),
                 labels = paste0(seq(0, 100, by = 25), "%"))
  graphics::text(pmax(tab$icc / 2, 0.04), at,
                 labels = paste0(round(100 * tab$icc), "%"),
                 col = "white", cex = 0.76, font = 2)
  graphics::legend("topright", legend = c("Between people", "Within people"),
         fill = c(.idio_colours[["blue"]], .idio_colours[["pale_blue"]]),
         border = NA, bty = "n", inset = c(0, -0.1), xpd = TRUE, horiz = TRUE,
         text.col = .idio_colours[["ink"]])
  invisible(tab)
}

#' Plot within-person against between-person effects
#'
#' One row per predictor, with the within and between coefficients and their
#' confidence intervals. A predictor whose two intervals do not overlap is one
#' where pooling the two processes into a single coefficient would mislead.
#'
#' @param x A [fit_within_between()] result.
#' @param scope,subject,subgroup Optional filters.
#' @param ... Passed to base plotting functions.
#' @return Invisibly, the plotted table.
#' @examples
#' fit <- fit_within_between(srl, y = "effort", x = c("efficacy", "planning"),
#'                           id = "name", time = "day")
#' plot_components(fit)
#' @export
plot_components <- function(x, scope = "pooled", subject = NULL,
                            subgroup = NULL, ...) {
  if (!inherits(x, "idiostats_wb")) {
    stop("plot_components() needs a fit_within_between() result.",
         call. = FALSE)
  }
  tab <- coefs(x, scope = scope, subject = subject, subgroup = subgroup)
  tab <- tab[tab$component %in% c("within", "between", "contextual") &
               is.finite(tab$estimate), , drop = FALSE]
  if (!nrow(tab)) {
    .idio_plot_empty("No within/between coefficients available")
    return(invisible(tab))
  }

  shown <- intersect(c("within", "between", "contextual"),
                     unique(tab$component))
  colours <- c(within = "#E69F00", between = "#0072B2",
               contextual = "#009E73")
  vars <- unique(tab$variable)
  at <- seq_along(vars)
  offsets <- seq_along(shown)
  offsets <- (offsets - mean(offsets)) * 0.22

  xlim <- range(c(tab$conf_low, tab$conf_high, 0), na.rm = TRUE)
  op <- .idio_plot_begin(mar = c(4.2, 8, 1, 1))
  on.exit(par(op), add = TRUE)
  plot(NA, xlim = xlim, ylim = c(0.5, length(vars) + 0.5), yaxt = "n",
       xlab = "Coefficient estimate (95% CI)", ylab = "", ...)
  .idio_plot_grid(x = TRUE, y = FALSE)
  abline(v = 0, col = .idio_colours[["muted"]], lty = 2)
  axis(2, at = at, labels = vars, las = 1, tick = FALSE,
       col.axis = .idio_colours[["ink"]])

  for (i in seq_along(shown)) {
    rows <- tab[tab$component == shown[i], , drop = FALSE]
    rows <- rows[match(vars, rows$variable), , drop = FALSE]
    yy <- at + offsets[i]
    graphics::segments(rows$conf_low, yy, rows$conf_high, yy,
                       col = colours[[shown[i]]], lwd = 2)
    graphics::segments(rows$conf_low, yy - 0.035,
                       rows$conf_low, yy + 0.035,
                       col = colours[[shown[i]]])
    graphics::segments(rows$conf_high, yy - 0.035,
                       rows$conf_high, yy + 0.035,
                       col = colours[[shown[i]]])
    graphics::points(rows$estimate, yy, pch = 21,
                     bg = colours[[shown[i]]], col = "white", cex = 1.2)
  }
  legend("topright", legend = tools::toTitleCase(shown), pch = 21,
         pt.bg = unname(colours[shown]), col = "white", bty = "n",
         inset = c(0, -0.1), xpd = TRUE, horiz = TRUE,
         text.col = .idio_colours[["ink"]])
  invisible(tab)
}
