# ---- Unified Structural Equation Modeling (uSEM) ----

#' Build a user-specified unified SEM network
#'
#' @description
#' Fits person-specific unified Structural Equation Models (uSEM) for intensive
#' longitudinal data. A uSEM combines lagged directed effects, optional
#' contemporaneous directed effects, and optional residual covariances in one
#' SEM. Unlike [build_gimme()], this function does no automated path search:
#' the model is fixed by `temporal`, `contemporaneous`, `residual_cov`, and
#' `paths`. With `trim = TRUE`, idiographic uses an independent clean-room
#' modification-index entry and z-value pruning layer over the declared
#' candidate set.
#'
#' @param data A `data.frame` in long format.
#' @param vars Character vector of time-varying variables.
#' @param id Character string naming the person-ID column.
#' @param time Character string naming the within-person ordering column, or
#'   `NULL`.
#' @param day Character string naming the day/session column, or `NULL`. When
#'   supplied, lag pairs are formed only within the same `(id, day)` block.
#' @param beep Character string naming the measurement-occasion column, or
#'   `NULL`. Used with `day` to order observations when `time` is not supplied.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations.
#' @param subject Optional vector naming the subject(s) to analyse.
#' @param temporal `"ar"` (own-lag only; default), `"all"` (all lagged
#'   predictors), `"none"`, or a character vector of lavaan regressions such as
#'   `"A ~ Blag"`.
#' @param contemporaneous `"none"` (default), `"all"` (all directed lag-0
#'   predictors except self-regressions), or lavaan regressions such as
#'   `"B ~ A"`.
#' @param residual_cov Logical. Estimate residual covariances among current
#'   endogenous variables? Default `TRUE`.
#' @param trim Logical. If `TRUE`, treat `temporal`, `contemporaneous`, and
#'   `residual_cov` as an eligible search space: start from the structural
#'   baseline, add paths by modification index until fit criteria are met, then
#'   prune weak paths. This is an idiographic clean-room search layer, not a clone of
#'   any external package. Default `FALSE` fits the exact fixed syntax.
#' @param trim_alpha Significance level used for modification-index entry and
#'   z-value pruning when `trim = TRUE`. Default `0.05`.
#' @param trim_fit_criteria Number of fit criteria that must pass before
#'   forward search stops. Default `3`.
#' @param cfi_cutoff,tli_cutoff,rmsea_cutoff,srmr_cutoff Fit thresholds used by
#'   trimmed uSEM.
#' @param paths Extra lavaan syntax lines to include unchanged.
#' @param exogenous Optional subset of `vars` to treat as exogenous current
#'   variables. They can predict endogenous variables but are not outcomes.
#' @param standardize Logical. Standardize variables per person before fitting.
#' @param estimator Lavaan estimator. Default `"ml"`.
#' @param seed Optional random seed.
#'
#' @return A `net_usem` object with average `$temporal`,
#'   `$contemporaneous`, and `$residual_cov` matrices, per-subject matrices in
#'   `$subjects`, a tidy coefficient table from [coefs()], fit indices, syntax,
#'   labels, and configuration metadata.
#' @examplesIf requireNamespace("lavaan", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' d <- data.frame(
#'   id = rep(1:4, each = 30),
#'   t = rep(seq_len(30), 4),
#'   A = rnorm(120), B = rnorm(120), C = rnorm(120)
#' )
#' fit <- build_usem(d, vars = c("A", "B", "C"), id = "id", time = "t")
#' edges(fit)
#' }
#' @seealso [build_gimme()], [graphical_var()], [build_mlvar()]
#' @export
build_usem <- function(data, vars, id,
                       time = NULL, day = NULL, beep = NULL,
                       min_obs = NULL, subject = NULL,
                       temporal = c("ar", "all", "none"),
                       contemporaneous = c("none", "all"),
                       residual_cov = TRUE,
                       trim = FALSE,
                       trim_alpha = 0.05,
                       trim_fit_criteria = 3L,
                       cfi_cutoff = 0.95,
                       tli_cutoff = 0.95,
                       rmsea_cutoff = 0.08,
                       srmr_cutoff = 0.08,
                       paths = NULL,
                       exogenous = NULL,
                       standardize = FALSE,
                       estimator = "ml",
                       seed = NULL) {
  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("Package 'lavaan' is required for build_usem(). ",
         "Install it with install.packages('lavaan').", call. = FALSE)
  }
  if (!is.null(seed)) set.seed(seed)

  stopifnot(is.data.frame(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.character(id), length(id) == 1L, id %in% names(data))
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(time, "time", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  .ido_check_flag(residual_cov, "residual_cov")
  .ido_check_flag(trim, "trim")
  .ido_check_flag(standardize, "standardize")
  stopifnot(is.numeric(trim_alpha), length(trim_alpha) == 1L,
            is.finite(trim_alpha), trim_alpha > 0, trim_alpha < 1)
  stopifnot(is.numeric(trim_fit_criteria), length(trim_fit_criteria) == 1L,
            is.finite(trim_fit_criteria), trim_fit_criteria >= 1L,
            trim_fit_criteria <= 4L)
  stopifnot(is.numeric(cfi_cutoff), length(cfi_cutoff) == 1L,
            is.numeric(tli_cutoff), length(tli_cutoff) == 1L,
            is.numeric(rmsea_cutoff), length(rmsea_cutoff) == 1L,
            is.numeric(srmr_cutoff), length(srmr_cutoff) == 1L)
  stopifnot(is.character(estimator), length(estimator) == 1L)
  if (!is.null(paths)) stopifnot(is.character(paths))
  if (!is.null(exogenous)) {
    stopifnot(is.character(exogenous))
    bad_exog <- setdiff(exogenous, vars)
    if (length(bad_exog) > 0L) {
      stop("`exogenous` names must be among `vars`: ",
           paste(bad_exog, collapse = ", "), call. = FALSE)
    }
    if (length(setdiff(vars, exogenous)) < 1L) {
      stop("`exogenous` cannot include every variable -- ",
           "at least one endogenous variable is required.", call. = FALSE)
    }
  }

  data <- .ido_keep(data, id, min_obs, subject)
  if (is.null(time) && (!is.null(day) || !is.null(beep))) {
    data <- data[do.call(order, data[c(id, day, beep)]), , drop = FALSE]
    data$.time <- stats::ave(seq_len(nrow(data)), data[[id]], FUN = seq_along)
    time <- ".time"
  }

  ts_list <- .gimme_prepare_data(data, vars, id, time, standardize, exogenous,
                                 day = day)
  if (length(ts_list) < 1L) {
    stop("No subjects have enough lag pairs for uSEM.", call. = FALSE)
  }

  lag_names <- paste0(vars, "lag")
  spec <- .usem_syntax_spec(vars, lag_names, temporal, contemporaneous,
                            residual_cov, paths, exogenous)
  if (isTRUE(trim)) {
    fit_cutoffs <- c(cfi = cfi_cutoff, tli = tli_cutoff,
                     rmsea = rmsea_cutoff, srmr = srmr_cutoff)
    syntax_list <- lapply(ts_list, function(d) {
      .usem_trim_syntax(
        data_k = d,
        base_syntax = spec$base_syntax,
        candidate_paths = spec$candidate_paths,
        estimator = estimator,
        alpha = trim_alpha,
        fit_criteria = as.integer(trim_fit_criteria),
        fit_cutoffs = fit_cutoffs
      )
    })
  } else {
    syntax <- .usem_build_syntax(
      vars = vars,
      lag_names = lag_names,
      temporal = temporal,
      contemporaneous = contemporaneous,
      residual_cov = residual_cov,
      paths = paths,
      exogenous = exogenous
    )
    syntax_list <- stats::setNames(rep(list(syntax), length(ts_list)),
                                   names(ts_list))
  }

  fits <- lapply(seq_along(ts_list), function(i) {
    .usem_fit_final(syntax_list[[i]], ts_list[[i]], vars, lag_names, estimator)
  })
  names(fits) <- names(ts_list)
  ok <- vapply(fits, `[[`, logical(1), "converged")
  if (!any(ok)) {
    stop("No subject-level uSEM models converged.", call. = FALSE)
  }
  if (any(!ok)) {
    warning(sum(!ok), " subject-level uSEM model(s) did not converge: ",
            paste(names(ts_list)[!ok], collapse = ", "), call. = FALSE)
  }

  subjects <- lapply(fits, function(x) {
    list(temporal = x$temporal,
         contemporaneous = x$contemporaneous,
         residual_cov = x$residual_cov)
  })
  names(subjects) <- names(ts_list)

  mean_mat <- function(name) {
    mats <- lapply(fits[ok], `[[`, name)
    out <- Reduce("+", mats) / length(mats)
    dimnames(out) <- dimnames(mats[[1L]])
    out
  }
  fit_df <- do.call(rbind, lapply(seq_along(fits), function(i) {
    cbind(data.frame(subject = names(ts_list)[i], stringsAsFactors = FALSE),
          fits[[i]]$fit,
          data.frame(status = fits[[i]]$status, stringsAsFactors = FALSE))
  }))
  rownames(fit_df) <- NULL

  out <- list(
    temporal = mean_mat("temporal"),
    contemporaneous = mean_mat("contemporaneous"),
    residual_cov = mean_mat("residual_cov"),
    subjects = subjects,
    coefs = do.call(rbind, lapply(seq_along(fits), function(i) {
      .usem_tidy_coefs(names(ts_list)[i], fits[[i]])
    })),
    fit = fit_df,
    syntax = if (isTRUE(trim)) syntax_list else syntax_list[[1L]],
    labels = vars,
    n_subjects = length(ts_list),
    n_converged = sum(ok),
    n_obs = vapply(ts_list, nrow, integer(1)),
    config = list(
      temporal = temporal,
      contemporaneous = contemporaneous,
      residual_cov = residual_cov,
      trim = trim,
      trim_alpha = trim_alpha,
      trim_fit_criteria = trim_fit_criteria,
      fit_cutoffs = c(cfi = cfi_cutoff, tli = tli_cutoff,
                      rmsea = rmsea_cutoff, srmr = srmr_cutoff),
      paths = paths,
      exogenous = exogenous,
      standardize = standardize,
      estimator = estimator
    )
  )
  rownames(out$coefs) <- NULL
  .ido_group_result(
    "net_usem",
    list(
      temporal = .ido_wrap(t(out$temporal), "relative", TRUE),
      contemporaneous = .ido_wrap(t(out$contemporaneous), "relative", TRUE),
      residual_cov = .ido_wrap(out$residual_cov, "co_occurrence", FALSE)
    ),
    out
  )
}

#' @noRd
.usem_mode_or_paths <- function(x, modes, arg) {
  if (is.character(x) && length(x) == 1L && x %in% modes) return(x)
  if (is.character(x) && length(x) > 1L && all(x %in% modes)) return(x[1L])
  if (is.character(x) && length(x) >= 1L && any(grepl("~", x, fixed = TRUE))) {
    return(x)
  }
  stop("`", arg, "` must be one of ", paste(sQuote(modes), collapse = ", "),
       " or a character vector of lavaan paths.", call. = FALSE)
}

#' @noRd
.usem_build_syntax <- function(vars, lag_names, temporal, contemporaneous,
                               residual_cov, paths, exogenous) {
  spec <- .usem_syntax_spec(vars, lag_names, temporal, contemporaneous,
                            residual_cov, paths, exogenous)
  unique(c(spec$base_syntax, spec$candidate_paths))
}

#' @noRd
.usem_syntax_spec <- function(vars, lag_names, temporal, contemporaneous,
                              residual_cov, paths, exogenous) {
  temporal <- .usem_mode_or_paths(temporal, c("ar", "all", "none"), "temporal")
  contemporaneous <- .usem_mode_or_paths(
    contemporaneous, c("none", "all"), "contemporaneous"
  )
  exog_cur <- intersect(vars, exogenous)
  endo_eff <- setdiff(vars, exog_cur)
  exog_block <- c(lag_names, exog_cur)

  var_endo <- paste0(endo_eff, "~~", endo_eff)
  int_endo <- paste0(endo_eff, "~1")
  exog_pairs <- outer(exog_block, exog_block,
                      function(x, y) paste0(x, "~~", y))
  cov_exog <- exog_pairs[lower.tri(exog_pairs, diag = TRUE)]
  int_exog <- paste0(exog_block, "~1")
  nons_reg <- c(t(outer(exog_block, endo_eff, function(x, y) {
    paste0(x, "~0*", y)
  })))

  temporal_paths <- .usem_temporal_paths(temporal, endo_eff, vars, lag_names,
                                         exog_cur)
  contemp_paths <- .usem_contemp_paths(contemporaneous, endo_eff, exog_cur)
  resid_paths <- if (isTRUE(residual_cov) && length(endo_eff) > 1L) {
    pairs <- outer(endo_eff, endo_eff, function(x, y) paste0(x, "~~", y))
    pairs[lower.tri(pairs)]
  } else {
    character(0)
  }

  list(
    base_syntax = unique(c(var_endo, int_endo, cov_exog, int_exog, nons_reg,
                           paths)),
    candidate_paths = unique(c(temporal_paths, contemp_paths, resid_paths))
  )
}

#' @noRd
.usem_temporal_paths <- function(temporal, endo_eff, vars, lag_names,
                                 exog_cur) {
  if (identical(temporal, "none")) return(character(0))
  if (identical(temporal, "ar")) {
    ar_vars <- setdiff(vars, exog_cur)
    return(paste0(ar_vars, "~", ar_vars, "lag"))
  }
  if (identical(temporal, "all")) {
    return(c(t(outer(endo_eff, lag_names, function(x, y) paste0(x, "~", y)))))
  }
  .usem_validate_regressions(temporal, lhs = endo_eff, rhs = lag_names,
                             arg = "temporal")
  temporal
}

#' @noRd
.usem_contemp_paths <- function(contemporaneous, endo_eff, exog_cur) {
  if (identical(contemporaneous, "none")) return(character(0))
  rhs_vars <- c(endo_eff, exog_cur)
  if (identical(contemporaneous, "all")) {
    out <- c(t(outer(endo_eff, rhs_vars, function(x, y) paste0(x, "~", y))))
    return(setdiff(out, paste0(endo_eff, "~", endo_eff)))
  }
  .usem_validate_regressions(contemporaneous, lhs = endo_eff, rhs = rhs_vars,
                             arg = "contemporaneous")
  contemporaneous
}

#' @noRd
.usem_validate_regressions <- function(paths, lhs, rhs, arg) {
  clean <- gsub("\\s+", "", paths)
  bad_op <- grepl("~~", clean, fixed = TRUE) | !grepl("~", clean, fixed = TRUE)
  parts <- strsplit(clean, "~", fixed = TRUE)
  bad_shape <- lengths(parts) != 2L
  left <- vapply(parts, `[`, character(1), 1L)
  right <- vapply(parts, `[`, character(1), 2L)
  right <- sub("^[+-]?[0-9.]+\\*", "", right)
  bad <- bad_op | bad_shape | !left %in% lhs | !right %in% rhs
  if (any(bad)) {
    stop("Invalid `", arg, "` path(s): ",
         paste(paths[bad], collapse = ", "), call. = FALSE)
  }
  invisible(NULL)
}

#' @noRd
.usem_trim_syntax <- function(data_k, base_syntax, candidate_paths, estimator,
                              alpha, fit_criteria, fit_cutoffs) {
  current <- unique(base_syntax)
  eligible <- setdiff(.usem_canon_paths(candidate_paths),
                      .usem_canon_paths(current))
  path_lookup <- stats::setNames(candidate_paths,
                                 .usem_canon_paths(candidate_paths))
  mi_cutoff <- stats::qchisq(1 - alpha, df = 1)

  for (step in seq_along(eligible)) {
    fit <- .usem_fit_lavaan(current, data_k, estimator)
    if (!is.null(fit) && isTRUE(lavaan::lavInspect(fit, "converged")) &&
        .usem_fit_passes(fit, fit_cutoffs) >= fit_criteria) {
      break
    }
    add <- .usem_best_mi_path(fit, eligible, mi_cutoff)
    if (is.na(add)) break
    current <- unique(c(current, path_lookup[[add]]))
    eligible <- setdiff(eligible, add)
  }

  current <- .usem_prune_syntax(current, base_syntax, data_k, estimator,
                                alpha, fit_criteria, fit_cutoffs)
  unique(current)
}

#' @noRd
.usem_best_mi_path <- function(fit, eligible, cutoff) {
  if (is.null(fit) || !isTRUE(lavaan::lavInspect(fit, "converged"))) {
    return(NA_character_)
  }
  mi <- tryCatch(lavaan::modindices(fit, standardized = FALSE, sort. = FALSE),
                 error = function(e) NULL)
  if (is.null(mi) || nrow(mi) == 0L) return(NA_character_)
  mi$param <- .usem_canon_paths(paste0(mi$lhs, mi$op, mi$rhs))
  mi <- mi[mi$param %in% eligible & mi$mi >= cutoff, , drop = FALSE]
  if (nrow(mi) == 0L) return(NA_character_)
  mi$param[which.max(mi$mi)]
}

#' @noRd
.usem_prune_syntax <- function(current, base_syntax, data_k, estimator, alpha,
                               fit_criteria, fit_cutoffs) {
  fixed <- .usem_canon_paths(base_syntax)
  z_cutoff <- abs(stats::qnorm(alpha / 2))
  repeat {
    fit <- .usem_fit_lavaan(current, data_k, estimator)
    if (is.null(fit) || !isTRUE(lavaan::lavInspect(fit, "converged"))) break
    ss <- tryCatch(lavaan::standardizedSolution(fit), error = function(e) NULL)
    if (is.null(ss) || nrow(ss) == 0L || !"z" %in% names(ss)) break
    ss$param <- .usem_canon_paths(paste0(ss$lhs, ss$op, ss$rhs))
    dynamic <- setdiff(.usem_canon_paths(current), fixed)
    cand <- ss[ss$param %in% dynamic & !is.na(ss$z) & abs(ss$z) < z_cutoff,
               , drop = FALSE]
    if (nrow(cand) == 0L) break
    drop_param <- cand$param[which.min(abs(cand$z))]
    trial <- current[.usem_canon_paths(current) != drop_param]
    trial_fit <- .usem_fit_lavaan(trial, data_k, estimator)
    if (!is.null(trial_fit) &&
        isTRUE(lavaan::lavInspect(trial_fit, "converged")) &&
        .usem_fit_passes(trial_fit, fit_cutoffs) >= fit_criteria) {
      current <- trial
    } else {
      break
    }
  }
  current
}

#' @noRd
.usem_fit_passes <- function(fit, cutoffs) {
  fm <- tryCatch(
    suppressWarnings(lavaan::fitMeasures(fit, c("cfi", "tli", "rmsea", "srmr"))),
    error = function(e) rep(NA_real_, 4L)
  )
  sum(c(!is.na(fm["cfi"]) && fm["cfi"] >= cutoffs["cfi"],
        !is.na(fm["tli"]) && fm["tli"] >= cutoffs["tli"],
        !is.na(fm["rmsea"]) && fm["rmsea"] <= cutoffs["rmsea"],
        !is.na(fm["srmr"]) && fm["srmr"] <= cutoffs["srmr"]))
}

#' @noRd
.usem_canon_paths <- function(paths) {
  clean <- gsub("\\s+", "", paths)
  sym <- grepl("~~", clean, fixed = TRUE)
  clean[sym] <- vapply(strsplit(clean[sym], "~~", fixed = TRUE), function(x) {
    paste(sort(x), collapse = "~~")
  }, character(1))
  clean
}

#' @noRd
.usem_fit_lavaan <- function(syntax, data_k, estimator) {
  tryCatch(
    lavaan::lavaan(
      model = paste(syntax, collapse = "\n"),
      data = data_k,
      model.type = "sem",
      missing = "fiml",
      estimator = estimator,
      int.ov.free = FALSE,
      int.lv.free = TRUE,
      auto.fix.first = TRUE,
      auto.var = TRUE,
      auto.cov.lv.x = TRUE,
      auto.th = TRUE,
      auto.delta = TRUE,
      auto.cov.y = FALSE,
      auto.fix.single = TRUE,
      warn = FALSE
    ),
    error = function(e) NULL
  )
}

#' @noRd
.usem_fit_final <- function(syntax, data_k, varnames, lag_names, estimator) {
  fit <- .usem_fit_lavaan(syntax, data_k, estimator)
  p <- length(varnames)
  all_names <- c(lag_names, varnames)
  empty_coef <- matrix(NA_real_, p, 2L * p,
                       dimnames = list(varnames, all_names))
  empty_psi <- matrix(NA_real_, 2L * p, 2L * p,
                      dimnames = list(all_names, all_names))
  if (is.null(fit)) {
    return(.usem_final_object(empty_coef, empty_psi, FALSE,
                              "failed to converge"))
  }

  converged <- isTRUE(lavaan::lavInspect(fit, "converged"))
  std_est <- tryCatch(lavaan::lavInspect(fit, "std"), error = function(e) NULL)
  coef_mat <- matrix(0, p, 2L * p, dimnames = list(varnames, all_names))
  psi_mat <- matrix(0, 2L * p, 2L * p, dimnames = list(all_names, all_names))
  if (!is.null(std_est)) {
    beta <- std_est$beta
    avail_rows <- intersect(varnames, rownames(beta))
    avail_cols <- intersect(all_names, colnames(beta))
    coef_mat[avail_rows, avail_cols] <- beta[avail_rows, avail_cols,
                                             drop = FALSE]
    psi <- std_est$psi
    avail_psi_r <- intersect(all_names, rownames(psi))
    avail_psi_c <- intersect(all_names, colnames(psi))
    psi_mat[avail_psi_r, avail_psi_c] <- psi[avail_psi_r, avail_psi_c,
                                             drop = FALSE]
  }
  .usem_final_object(coef_mat, psi_mat, converged,
                     if (converged) "converged normally"
                     else "failed to converge",
                     fit = fit)
}

#' @noRd
.usem_final_object <- function(coef_mat, psi_mat, converged, status,
                               fit = NULL) {
  varnames <- rownames(coef_mat)
  lag_names <- paste0(varnames, "lag")
  temporal <- coef_mat[, lag_names, drop = FALSE]
  colnames(temporal) <- varnames
  contemporaneous <- coef_mat[, varnames, drop = FALSE]
  diag(contemporaneous) <- 0
  residual_cov <- psi_mat[varnames, varnames, drop = FALSE]
  diag(residual_cov) <- 0

  measures <- c("chisq", "df", "pvalue", "rmsea", "srmr", "nnfi", "cfi",
                "bic", "aic", "logl")
  fi <- if (is.null(fit)) {
    stats::setNames(rep(NA_real_, length(measures)), measures)
  } else {
    tryCatch(suppressWarnings(lavaan::fitMeasures(fit, measures)),
             error = function(e) stats::setNames(rep(NA_real_, length(measures)),
                                                 measures))
  }
  list(
    temporal = temporal,
    contemporaneous = contemporaneous,
    residual_cov = residual_cov,
    coef_mat = coef_mat,
    psi = psi_mat,
    fit = as.data.frame(as.list(fi)),
    converged = converged,
    status = status
  )
}

#' @noRd
.usem_tidy_coefs <- function(subject, fit) {
  mat_long <- function(m, network, directed) {
    if (directed) {
      idx <- which(matrix(TRUE, nrow(m), ncol(m)), arr.ind = TRUE)
    } else {
      idx <- which(upper.tri(m), arr.ind = TRUE)
    }
    data.frame(
      subject = subject,
      network = network,
      from = colnames(m)[idx[, 2L]],
      to = rownames(m)[idx[, 1L]],
      weight = m[idx],
      stringsAsFactors = FALSE
    )
  }
  rbind(
    mat_long(fit$temporal, "temporal", TRUE),
    mat_long(fit$contemporaneous, "contemporaneous", TRUE),
    mat_long(fit$residual_cov, "residual_cov", FALSE)
  )
}

#' @export
as_netobject.net_usem <- function(x, ...) {
  .ido_network_group(x)
}

#' @rdname edges
#' @export
edges.net_usem <- function(x, sort_by = "weight", include_self = FALSE, ...) {
  edges(as_netobject(x), sort_by = sort_by, include_self = include_self)
}

#' @rdname coefs
#' @export
coefs.net_usem <- function(x, ...) {
  x$coefs
}

#' @rdname nodes
#' @export
nodes.net_usem <- function(x, ...) {
  nodes(as_netobject(x), ...)
}

#' @export
as.data.frame.net_usem <- function(x, row.names = NULL, optional = FALSE, ...) {
  edges(x, ...)
}

#' Summary method for uSEM fits
#'
#' @param object A `net_usem` object.
#' @param ... Ignored.
#' @return A tidy per-network metrics `data.frame`.
#' @export
summary.net_usem <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}

#' Print method for uSEM fits
#'
#' @param x A `net_usem` object.
#' @param digits Number of digits used for printed network matrices.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.net_usem <- function(x, digits = 2, ...) {
  cat("uSEM Result\n")
  cat(sprintf("  Subjects:      %d (%d converged)\n",
              x$n_subjects, x$n_converged))
  cat(sprintf("  Variables:     %d (%s)\n",
              length(x$labels), paste(x$labels, collapse = ", ")))
  cat(sprintf("  Observations:  median %g (range %d-%d)\n",
              stats::median(x$n_obs), min(x$n_obs), max(x$n_obs)))
  .ido_print_networks(x, digits = digits)
  cat("\n  plot(x) | plot(x, layer = \"temporal\") |",
      "plot(x, layer = \"contemporaneous\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}
