# ---- Group Iterative Multiple Model Estimation (GIMME) ----

#' GIMME: Group Iterative Multiple Model Estimation
#'
#' @description
#' Estimates person-specific directed networks from intensive longitudinal data
#' using the unified Structural Equation Modeling (uSEM) framework. Implements
#' a data-driven search that identifies:
#' \enumerate{
#'   \item \strong{Group-level paths}: Directed edges present for a majority
#'     (default 75\%) of individuals.
#'   \item \strong{Individual-level paths}: Additional edges specific to each
#'     person, found after group paths are established.
#' }
#'
#' Uses \code{lavaan} for SEM estimation and modification indices.
#' Accepts a single data frame with an ID column (not CSV directories).
#'
#' @param data A \code{data.frame} in long format with columns for person ID,
#'   time-varying variables, and optionally a time/beep column.
#' @param vars Character vector of variable names to model.
#' @param id Character string naming the person-ID column.
#' @param time Character string naming the time/order column, or \code{NULL}.
#'   When provided, data is sorted by \code{id} then \code{time} before lagging.
#' @param day Character string naming the day/session column, or \code{NULL}.
#'   When supplied, lag-1 pairs are formed only within the same \code{(id, day)}
#'   block, so a lag never crosses the overnight gap.
#' @param beep Character string naming the measurement-occasion column, or
#'   \code{NULL}. Used (with \code{day}) to order observations when \code{time}
#'   is not given.
#' @param min_obs Integer or \code{NULL}. Keep only subjects with at least this
#'   many observations (counts taken from \code{data}).
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @param ar Logical. If \code{TRUE} (default), autoregressive paths
#'   (each variable predicting itself at lag 1) are included as fixed paths.
#' @param standardize Logical. If \code{TRUE} (default \code{FALSE}),
#'   variables are standardized per person before estimation. Note: the
#'   returned coefficient network (\code{$coefs}, \code{$psi},
#'   \code{$temporal_avg}, \code{$contemporaneous_avg}, \code{$group_paths})
#'   is unaffected because idiographic extracts the standardized lavaan
#'   solution (\code{lavInspect(fit, "std")}), which is invariant to input
#'   scaling. Only the scale-dependent \code{$fit} statistics (chisq, aic,
#'   bic) change.
#' @param groupcutoff Numeric between 0 and 1. Proportion of individuals for
#'   whom a path must be significant to be added at group level.
#'   Default \code{0.75}.
#' @param subcutoff Numeric. Subgroup cutoff (default 0.75, matching
#'   \code{gimme}); only relevant to subgrouping, which is not implemented.
#' @param paths Character vector of lavaan-syntax paths to force into the model
#'   (e.g., \code{"V2~V1lag"}). Default \code{NULL}.
#' @param exogenous Character vector of variable names to treat as exogenous.
#'   Default \code{NULL}.
#' @param hybrid Logical. If \code{TRUE}, also searches residual covariances.
#'   Default \code{FALSE}.
#' @param VAR Logical. If \code{TRUE}, fit a standard VAR: only lagged directed
#'   paths are searched and contemporaneous relations are estimated as residual
#'   covariances (no directed contemporaneous paths). Matches
#'   \code{gimme(VAR = TRUE)}. Default \code{FALSE}.
#' @param rmsea_cutoff Numeric. RMSEA threshold for excellent fit (default 0.05).
#' @param srmr_cutoff Numeric. SRMR threshold for excellent fit (default 0.05).
#' @param nnfi_cutoff Numeric. NNFI/TLI threshold for excellent fit (default 0.95).
#' @param cfi_cutoff Numeric. CFI threshold for excellent fit (default 0.95).
#' @param n_excellent Integer. Number of fit indices that must be excellent to
#'   stop individual search. Default \code{2}.
#' @param seed Integer or \code{NULL}. Random seed for reproducibility.
#' @param group_correct Group-level multiple-comparison correction. Use
#'   \code{"Bonferroni Group"} (the default) to divide \code{alpha} by the
#'   number of people, \code{"Bonferroni Paths"} to divide it by the number of
#'   eligible paths, \code{"fdr"} for Benjamini-Hochberg correction, or a
#'   single number in \code{(0, 1)} to set the group alpha directly. The legacy
#'   misspelling \code{"Bonferoni Group"} is accepted with a deprecation
#'   warning.
#' @param indiv_correct Individual-level multiple-comparison correction. Use
#'   \code{"Bonferroni"} (the default) or \code{"fdr"}.
#' @param alpha Base significance level for group and individual searches.
#'   Default \code{0.05}.
#' @param stop_crit Individual-search stopping rule. \code{"standard"} stops
#'   when fit is adequate or no significant path remains; \code{"model fit"}
#'   (the default) keeps adding the largest-MI path, regardless of significance,
#'   until fit is adequate; and \code{"significance"} keeps adding significant
#'   paths even after fit is adequate.
#' @param subgroup Logical. Subgrouping (S-GIMME) is not implemented; \code{TRUE}
#'   raises an error pointing to \code{gimme::gimme()}. Default \code{FALSE}.
#' @param outcome,conv_vars,mult_vars,lv_model,lasso_model_crit,ms_allow,ordered,dir_prop_cutoff
#'   Accepted for \code{gimme::gimme()} API parity but not implemented (latent
#'   variable / fMRI-convolution / multiplied-term / LASSO / ordinal /
#'   multiple-solutions / directionality features). A non-default value raises an
#'   error pointing to \code{gimme::gimme()}.
#' @param out,sep,header,plot Accepted for \code{gimme::gimme()} API parity.
#'   idiographic reads a \code{data.frame} (not a CSV directory), so non-default
#'   \code{out}, \code{sep}, and \code{header} values emit a warning and have no
#'   effect. It returns an object you plot with [plot_gimme()];
#'   \code{plot = TRUE} emits a message.
#' @param sub_feature,sub_method,sub_sim_thresh,confirm_subgroup,conv_length,conv_interval,mean_center_mult,diagnos,ms_tol,lv_estimator,lv_scores,lv_miiv_scaling,lv_final_estimator
#'   Accepted for \code{gimme::gimme()} API parity. These configure the
#'   unsupported subgrouping / convolution / multiplied-term / multiple-solutions
#'   / latent-variable features and are inert here (their parent feature is
#'   guarded above).
#'
#' @return An S3 object of class \code{"net_gimme"} containing:
#' \describe{
#'   \item{\code{temporal}}{p x p matrix of group-level temporal (lagged)
#'     path counts -- entry \code{[i,j]} = number of individuals with path j(t-1)->i(t).}
#'   \item{\code{contemporaneous}}{p x p matrix of group-level contemporaneous
#'     path counts -- entry \code{[i,j]} = number of individuals with path j(t)->i(t).}
#'   \item{\code{coefs}}{List of per-person q x (q + p) coefficient matrices
#'     (q non-exogenous rows; columns = \code{[lagged, contemporaneous]}).}
#'   \item{\code{psi}}{List of per-person \code{q x (q + p)} standardized
#'     residual covariance matrices, with non-exogenous current variables in
#'     rows and
#'     \code{c(lag_names, varnames)} in columns, matching `gimme::gimme()`'s
#'     returned `psi` contract.}
#'   \item{\code{fit}}{Data frame of per-person fit indices (chisq, df, pvalue,
#'     rmsea, srmr, nnfi, cfi, bic, aic, logl, status).}
#'   \item{\code{path_counts}}{p x 2p matrix: how many individuals have each path.}
#'   \item{\code{paths}}{List of per-person character vectors of lavaan path syntax.}
#'   \item{\code{group_paths}}{Character vector of group-level paths found.}
#'   \item{\code{individual_paths}}{List of per-person character vectors of
#'     individual-level paths (beyond group).}
#'   \item{\code{syntax}}{List of per-person full lavaan syntax strings.}
#'   \item{\code{labels}}{Character vector of variable names.}
#'   \item{\code{n_subjects}}{Integer. Number of individuals.}
#'   \item{\code{n_obs}}{Integer vector. Time points per individual.}
#'   \item{\code{config}}{List of configuration parameters.}
#' }
#'
#' @examplesIf requireNamespace("lavaan", quietly = TRUE)
#' \donttest{
#' # Create simple panel data (3 subjects, 4 variables, 50 time points).
#' set.seed(42)
#' n_sub <- 3; n_t <- 50; vars <- paste0("V", 1:4)
#' rows <- lapply(seq_len(n_sub), function(i) {
#'   d <- as.data.frame(matrix(rnorm(n_t * 4), ncol = 4))
#'   names(d) <- vars; d$id <- i; d
#' })
#' panel <- do.call(rbind, rows)
#' res <- fit_gimme(panel, vars = vars, id = "id")
#' print(res)
#' }
#'
#' @seealso \code{\link{fit_mlvar}}, \code{\link{fit_graphical_var}},
#'   \code{\link{as_netobject}}
#'
#' @export
fit_gimme <- function(data,
                        vars,
                        id,
                        time = NULL,
                        day = NULL,
                        beep = NULL,
                        min_obs = NULL,
                        subject = NULL,
                        ar = TRUE,
                        standardize = FALSE,
                        groupcutoff = 0.75,
                        subcutoff = 0.75,
                        paths = NULL,
                        exogenous = NULL,
                        hybrid = FALSE,
                        VAR = FALSE,
                        rmsea_cutoff = 0.05,
                        srmr_cutoff = 0.05,
                        nnfi_cutoff = 0.95,
                        cfi_cutoff = 0.95,
                        n_excellent = 2L,
                        seed = NULL,
                        group_correct = "Bonferroni Group",
                        indiv_correct = "Bonferroni",
                        alpha = 0.05,
                        stop_crit = "model fit",
                        subgroup = FALSE,
                        outcome = NULL,
                        conv_vars = NULL,
                        mult_vars = NULL,
                        lv_model = NULL,
                        lasso_model_crit = NULL,
                        ms_allow = FALSE,
                        ordered = NULL,
                        dir_prop_cutoff = 0,
                        # ---- accepted for gimme::gimme() API parity ----
                        # I/O arguments: idiographic takes a data.frame and returns
                        # an object (plot with plot_gimme()), so these are no-ops.
                        out = NULL,
                        sep = NULL,
                        header = NULL,
                        plot = FALSE,
                        # Sub-arguments of unsupported features (subgrouping,
                        # convolution, multiplied terms, latent variables,
                        # multiple solutions); inert unless their parent feature
                        # is enabled, which is itself guarded above.
                        sub_feature = "lag & contemp",
                        sub_method = "Walktrap",
                        sub_sim_thresh = "lowest",
                        confirm_subgroup = NULL,
                        conv_length = 16,
                        conv_interval = 1,
                        mean_center_mult = FALSE,
                        diagnos = FALSE,
                        ms_tol = 1e-5,
                        lv_estimator = "miiv",
                        lv_scores = "regression",
                        lv_miiv_scaling = "first.indicator",
                        lv_final_estimator = "miiv") {

  .ido_check_flag(plot, "plot")
  if (isTRUE(plot)) {
    message("fit_gimme() returns an object; plot it with plot_gimme(fit). ",
            "Ignoring plot = TRUE.")
  }

  if (!requireNamespace("lavaan", quietly = TRUE)) {
    stop("fit_gimme() requires the optional package 'lavaan'. The rest of ", # nocov
         "idiographic remains available offline; install 'lavaan' only when ", # nocov
         "you need GIMME estimation.", call. = FALSE) # nocov
  }

  if (!is.null(seed)) {
    if (!(is.numeric(seed) && length(seed) == 1L && is.finite(seed) &&
          seed == floor(seed))) {
      stop("`seed` must be NULL or one finite whole number.", call. = FALSE)
    }
    set.seed(seed)
  }

  # --- Input validation ---
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame in long format.", call. = FALSE)
  }
  if (!(is.character(vars) && length(vars) >= 2L && !anyNA(vars) &&
        !anyDuplicated(vars) && all(nzchar(vars)))) {
    stop("`vars` must contain at least two unique, non-empty column names.",
         call. = FALSE)
  }
  if (!(is.character(id) && length(id) == 1L && !is.na(id) && nzchar(id) &&
        id %in% names(data))) {
    stop("`id` must name one column in `data`.", call. = FALSE)
  }
  if (!all(vars %in% names(data))) {
    missing_v <- setdiff(vars, names(data))
    stop("Variables not found in data: ", paste(missing_v, collapse = ", "),
         call. = FALSE)
  }
  .ido_check_numeric_vars(data, vars, check_variance = FALSE)
  if (!(is.numeric(groupcutoff) && length(groupcutoff) == 1L &&
        is.finite(groupcutoff) && groupcutoff > 0 && groupcutoff <= 1)) {
    stop("`groupcutoff` must be one finite number in (0, 1].", call. = FALSE)
  }
  .ido_check_col(time, "time", data)
  .ido_check_col(day,  "day",  data)
  .ido_check_col(beep, "beep", data)
  .ido_check_flag(ar, "ar")
  .ido_check_flag(standardize, "standardize")
  .ido_check_flag(hybrid, "hybrid")
  .ido_check_flag(VAR, "VAR")
  .ido_check_flag(subgroup, "subgroup")
  .ido_check_flag(ms_allow, "ms_allow")
  .ido_check_flag(mean_center_mult, "mean_center_mult")
  .ido_check_flag(diagnos, "diagnos")
  if (!is.null(header)) .ido_check_flag(header, "header")
  if ((hybrid || VAR) && !ar) {
    stop("`ar` must be TRUE when `hybrid` or `VAR` is TRUE.", call. = FALSE)
  }
  if (!(is.numeric(n_excellent) && length(n_excellent) == 1L &&
        is.finite(n_excellent) && n_excellent == floor(n_excellent) &&
        n_excellent >= 1L && n_excellent <= 4L)) {
    stop("`n_excellent` must be one whole number between 1 and 4.",
         call. = FALSE)
  }
  if (!is.numeric(alpha) || length(alpha) != 1L || !is.finite(alpha) ||
      alpha <= 0 || alpha >= 1) {
    stop("`alpha` must be a single finite number between 0 and 1.",
         call. = FALSE)
  }
  fit_cutoffs <- c(rmsea_cutoff, srmr_cutoff, nnfi_cutoff, cfi_cutoff)
  if (!is.numeric(fit_cutoffs) || length(fit_cutoffs) != 4L ||
      any(!is.finite(fit_cutoffs)) || any(fit_cutoffs < 0 | fit_cutoffs > 1)) {
    stop("Fit-index cutoffs must be finite numbers between 0 and 1.",
         call. = FALSE)
  }
  stop_crit <- match.arg(stop_crit,
                         c("standard", "model fit", "significance"))
  indiv_correct <- match.arg(indiv_correct, c("Bonferroni", "fdr"))
  group_correct <- .gimme_normalize_group_correct(group_correct)
  if (!is.null(paths) &&
      !(is.character(paths) && !anyNA(paths) && all(nzchar(trimws(paths))))) {
    stop("`paths` must be NULL or non-empty lavaan syntax strings.",
         call. = FALSE)
  }

  # idiographic implements the standard (and hybrid / VAR) GIMME search. The other
  # gimme::gimme() modes are different algorithms; accept the arguments for API
  # parity but error clearly rather than silently ignore them.
  if (isTRUE(subgroup)) {
    stop("fit_gimme() does not implement subgrouping (S-GIMME); ",
         "use gimme::gimme(subgroup = TRUE).", call. = FALSE)
  }
  unsupported <- c(
    outcome          = !is.null(outcome),
    conv_vars        = !is.null(conv_vars),
    mult_vars        = !is.null(mult_vars),
    lv_model         = !is.null(lv_model),
    lasso_model_crit = !is.null(lasso_model_crit),
    ms_allow         = isTRUE(ms_allow),
    ordered          = !is.null(ordered),
    dir_prop_cutoff  = !isTRUE(dir_prop_cutoff == 0)   # 0L and 0.0 both default
  )
  if (any(unsupported)) {
    stop("fit_gimme() does not support: ",
         paste(names(unsupported)[unsupported], collapse = ", "),
         ". These gimme features (latent-variable / fMRI-convolution / ",
         "multiplied terms / LASSO / ordinal / multiple-solutions / ",
         "directionality) require gimme::gimme().", call. = FALSE)
  }
  # Sub-options of the unsupported features (and gimme's standalone `diagnos`)
  # are accepted for API parity but inert. Warn rather than silently ignore them
  # so a caller who sets one expecting an effect is told it had none.
  chg <- function(v, d) if (is.null(d)) !is.null(v) else !isTRUE(all(v == d))
  inert <- c(
    subcutoff          = chg(subcutoff, 0.75),
    sub_feature        = chg(sub_feature, "lag & contemp"),
    sub_method         = chg(sub_method, "Walktrap"),
    sub_sim_thresh     = chg(sub_sim_thresh, "lowest"),
    confirm_subgroup   = chg(confirm_subgroup, NULL),
    conv_length        = chg(conv_length, 16),
    conv_interval      = chg(conv_interval, 1),
    mean_center_mult   = chg(mean_center_mult, FALSE),
    diagnos            = chg(diagnos, FALSE),
    ms_tol             = chg(ms_tol, 1e-5),
    lv_estimator       = chg(lv_estimator, "miiv"),
    lv_scores          = chg(lv_scores, "regression"),
    lv_miiv_scaling    = chg(lv_miiv_scaling, "first.indicator"),
    lv_final_estimator = chg(lv_final_estimator, "miiv")
  )
  if (any(inert)) {
    warning("fit_gimme() ignores these gimme sub-options (the parent feature ",
            "is not implemented): ", paste(names(inert)[inert], collapse = ", "),
            ". Use gimme::gimme() for them.", call. = FALSE)
  }
  ignored_io <- c(out = !is.null(out), sep = !is.null(sep),
                  header = !is.null(header))
  if (any(ignored_io)) {
    warning("fit_gimme() does not use these file-I/O arguments with long-form ",
            "data: ", paste(names(ignored_io)[ignored_io], collapse = ", "),
            ". Supply a data frame and use the returned object directly.",
            call. = FALSE)
  }
  if (!is.null(exogenous)) {
    if (!is.character(exogenous) || anyNA(exogenous) ||
        any(!nzchar(exogenous)) || anyDuplicated(exogenous)) {
      stop("`exogenous` must contain unique, non-empty variable names.",
           call. = FALSE)
    }
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

  # Keep only well-sampled subjects (counts taken from the data frame).
  data <- .ido_keep(data, id, min_obs, subject)

  # Build a within-person time index from day/beep when one is not supplied,
  # so fit_gimme takes the same id/day/beep interface as the other estimators.
  if (is.null(time) && (!is.null(day) || !is.null(beep))) {
    data <- data[do.call(order, data[c(id, day, beep)]), , drop = FALSE]
    data$.time <- stats::ave(seq_len(nrow(data)), data[[id]], FUN = seq_along)
    time <- ".time"
  }

  # --- Prepare per-person data ---
  # `day` is passed through so lag pairs are formed *within* (id, day) blocks
  # and never cross the overnight gap -- matching fit_graphical_var()/fit_mlvar().
  ts_list <- .gimme_prepare_data(data, vars, id, time, standardize, exogenous,
                                 day = day)
  n_subj <- length(ts_list)
  varnames <- vars

  if (n_subj < 2L) {
    stop("fit_gimme() requires at least 2 individuals.", call. = FALSE)
  }

  # --- Build lavaan syntax components ---
  # Upstream GIMME does not construct lagged copies of current variables that
  # are explicitly exogenous. They remain contemporaneous predictors only.
  lag_names <- paste0(setdiff(varnames, exogenous), "lag")
  endo_names <- varnames
  exog_names <- lag_names

  syntax_info <- .gimme_build_syntax(varnames, lag_names, endo_names,
                                      exog_names, ar, paths, exogenous,
                                      hybrid, VAR = VAR)

  base_syntax <- syntax_info$base_syntax
  candidate_paths <- syntax_info$candidate_paths
  candidate_corr <- syntax_info$candidate_corr
  fixed_paths <- syntax_info$fixed_paths

  # VAR = TRUE: no directed contemporaneous paths (candidate_paths is lagged
  # only), and contemporaneous relations are searched as residual covariances --
  # the same covariance mechanism hybrid uses. So both hybrid and VAR add the
  # candidate residual covariances to the eligible set.
  if (hybrid || VAR) {
    elig_paths <- c(candidate_paths, candidate_corr)
  } else {
    elig_paths <- candidate_paths
  }

  # --- Group-level search ---
  group_tests <- .gimme_group_thresholds(
    group_correct = group_correct,
    alpha = alpha,
    n_subj = n_subj,
    n_paths = length(elig_paths)
  )
  grp_cutoff <- group_tests$chisq
  grp_z_cutoff <- group_tests$z

  group_paths <- character(0)
  group_search_converged <- FALSE

  while (!group_search_converged) {
    current_syntax <- c(base_syntax, group_paths)

    # Fit model per person, collect modification indices
    mi_list <- lapply(ts_list, function(d) {
      .gimme_fit_and_mi(current_syntax, d, elig_paths)
    })

    # Select best path
    add_path <- .gimme_select_path(
      mi_list, elig_paths, groupcutoff, n_subj, grp_cutoff, hybrid,
      correction = group_tests$correction, alpha = group_tests$alpha
    )

    if (is.na(add_path)) {
      group_search_converged <- TRUE
    } else {
      group_paths <- c(group_paths, add_path)
    }
  }

  # --- Group-level pruning ---
  if (length(group_paths) > 0) {
    group_paths <- .gimme_prune_paths(base_syntax, group_paths, ts_list,
                                       n_subj, groupcutoff, grp_z_cutoff)
  }

  # --- Individual-level search ---
  # Entry and pruning thresholds follow the requested Bonferroni/FDR mode.
  individual_tests <- .gimme_individual_thresholds(
    indiv_correct = indiv_correct,
    alpha = alpha,
    n_paths = length(elig_paths)
  )
  ind_cutoff <- individual_tests$chisq
  ind_z_cutoff <- individual_tests$z

  fit_indices <- c("rmsea_cutoff" = rmsea_cutoff, "srmr_cutoff" = srmr_cutoff,
                   "nnfi_cutoff" = nnfi_cutoff, "cfi_cutoff" = cfi_cutoff)

  ind_results <- lapply(seq_len(n_subj), function(k) {
    .gimme_individual_search(
      base_syntax = base_syntax,
      group_paths = group_paths,
      data_k = ts_list[[k]],
      elig_paths = elig_paths,
      ind_cutoff = ind_cutoff,
      ind_z_cutoff = ind_z_cutoff,
      fit_indices = fit_indices,
      n_excellent = n_excellent,
      stop_crit = stop_crit,
      indiv_correct = indiv_correct,
      alpha = alpha,
      hybrid = hybrid,
      endo_names = endo_names,
      lag_names = lag_names
    )
  })
  names(ind_results) <- names(ts_list)

  # --- Extract results ---
  result <- .gimme_extract_results(ind_results, varnames, lag_names,
                                    group_paths, base_syntax, fixed_paths,
                                    n_subj, ts_list, hybrid, VAR = VAR)

  result$labels <- varnames
  result$n_subjects <- n_subj
  result$n_obs <- vapply(ts_list, nrow, integer(1))
  result$config <- list(
    ar = ar, standardize = standardize, groupcutoff = groupcutoff,
    hybrid = hybrid, rmsea_cutoff = rmsea_cutoff, srmr_cutoff = srmr_cutoff,
    nnfi_cutoff = nnfi_cutoff, cfi_cutoff = cfi_cutoff,
    n_excellent = n_excellent, exogenous = exogenous,
    fixed_paths = fixed_paths, seed = seed, VAR = VAR,
    group_correct = group_correct, indiv_correct = indiv_correct,
    alpha = alpha, stop_crit = stop_crit,
    group_chisq_cutoff = grp_cutoff, group_z_cutoff = grp_z_cutoff,
    individual_chisq_cutoff = ind_cutoff,
    individual_z_cutoff = ind_z_cutoff
  )

  .gimme_cograph_network(result)
}


# ============================================================================
# Data preparation
# ============================================================================

#' Prepare per-person time series with lagged columns
#'
#' When `day` is supplied, a current row is paired with its lag only if the
#' previous row belongs to the same (id, day) block; the first row of each day
#' has no within-day predecessor and is dropped. This keeps lag-1 pairs from
#' crossing the overnight gap, matching `fit_graphical_var()`/`fit_mlvar()`. With
#' `day = NULL` every consecutive within-person pair is used (legacy behaviour).
#' @noRd
.gimme_prepare_data <- function(data, vars, id, time, standardize, exogenous,
                                day = NULL) {
  ids <- unique(data[[id]])

  ts_list <- lapply(ids, function(pid) {
    d <- data[data[[id]] == pid, , drop = FALSE]

    # Sort by time if provided (when day was supplied without time, fit_gimme
    # already created a within-day-monotone .time index used here).
    if (!is.null(time)) {
      d <- d[order(d[[time]]), , drop = FALSE]
    }

    # Extract variables
    mat <- d[, vars, drop = FALSE]

    # Standardize per person if requested
    if (standardize) {
      mat <- as.data.frame(lapply(mat, function(x) {
        s <- stats::sd(x, na.rm = TRUE)
        if (is.na(s) || s == 0) return(x) # nocov
        (x - mean(x, na.rm = TRUE)) / s
      }))
    }

    n <- nrow(mat)
    if (n < 3L) return(NULL)

    # Pair current row i with lag row i-1. With day blocks, keep a pair only
    # when rows i and i-1 share the same day (no cross-day lags).
    cur_mat <- mat[-1L, , drop = FALSE]            # rows 2..n
    lag_vars <- setdiff(vars, exogenous)
    lag_mat <- mat[-n, lag_vars, drop = FALSE]     # rows 1..n-1
    colnames(lag_mat) <- paste0(colnames(lag_mat), "lag")

    if (!is.null(day)) {
      dayv <- d[[day]]
      # pair j kept iff rows j and j+1 share a non-missing day. `& !is.na`
      # guards against NA days producing NA logical indices (which would inject
      # all-NA rows instead of dropping the pair).
      same <- !is.na(dayv[-1L]) & !is.na(dayv[-n]) & dayv[-1L] == dayv[-n]
      cur_mat <- cur_mat[same, , drop = FALSE]
      lag_mat <- lag_mat[same, , drop = FALSE]
    }

    # Need at least two within-(id, day) lag pairs to fit a person's model.
    if (nrow(cur_mat) < 2L) return(NULL)

    # Combine: current + lagged
    result <- cbind(cur_mat, lag_mat)
    rownames(result) <- NULL
    result
  })

  names(ts_list) <- as.character(ids)
  # Remove NULLs (subjects with too few observations)
  ts_list <- ts_list[!vapply(ts_list, is.null, logical(1))]

  if (length(ts_list) == 0) {
    stop("No subjects have enough within-day lag pairs (minimum 2).",
         call. = FALSE)
  }

  ts_list
}


# ============================================================================
# Syntax building
# ============================================================================

#' Build base lavaan syntax and candidate path lists
#' @noRd
.gimme_build_syntax <- function(varnames, lag_names, endo_names, exog_names,
                                 ar, paths, exogenous, hybrid, VAR = FALSE) {
  # Split current variables into effective-endogenous vs exogenous, mirroring
  # gimme::setupBaseSyntax. A variable named in `exogenous` is treated as a
  # predictor only: it is dropped from the endogenous variance/intercept set
  # and from the regression-outcome (LHS) set, joins the exogenous
  # covariance/mean block, gets nonsense paths so endogenous variables cannot
  # predict it, and gets no AR self-path. `exogenous = NULL` is a no-op
  # (endo_eff == endo_names, exog_cur empty), so output is unchanged.
  exog_cur  <- intersect(endo_names, exogenous)
  endo_eff  <- setdiff(endo_names, exog_cur)
  # Exogenous block = lagged predictors plus any exogenous current variables.
  exog_block <- c(exog_names, exog_cur)

  # Endogenous variances and intercepts (effective-endogenous only)
  var_endo <- paste0(endo_eff, "~~", endo_eff)
  int_endo <- paste0(endo_eff, "~1")

  # Exogenous covariances and intercepts (lagged + exogenous current)
  exog_pairs <- outer(exog_block, exog_block,
                      function(x, y) paste0(x, "~~", y))
  cov_exog <- exog_pairs[lower.tri(exog_pairs, diag = TRUE)]
  int_exog <- paste0(exog_block, "~1")

  # Nonsense paths: exogenous (lagged + exogenous current) cannot be
  # predicted by effective-endogenous variables.
  nons_reg <- c(t(outer(exog_block, endo_eff, function(x, y) {
    paste0(x, "~0*", y)
  })))

  # Fixed paths (AR if requested + user-specified). Exogenous current
  # variables get no AR self-path (they are not endogenous outcomes).
  fixed_paths <- paths
  if (ar) {
    ar_vars  <- setdiff(varnames, exog_cur)
    ar_paths <- paste0(ar_vars, "~", ar_vars, "lag")
    fixed_paths <- c(fixed_paths, ar_paths)
  }

  # All possible directed paths: endo_eff ~ (endo_eff + exog_cur + lagged).
  # Outcomes (LHS) are effective-endogenous only; predictors (RHS) include
  # exogenous current variables and all lagged variables. With VAR = TRUE the
  # contemporaneous predictors (endo_eff) are excluded, so only lagged directed
  # paths are searched (contemporaneous relations become residual covariances).
  rhs_vars <- if (isTRUE(VAR)) exog_block else c(endo_eff, exog_block)
  all_poss <- c(t(outer(endo_eff, rhs_vars, function(x, y) {
    paste0(x, "~", y)
  })))
  # Remove self-regression (endo_i ~ endo_i) -- these are variances
  self_reg <- paste0(endo_eff, "~", endo_eff)
  all_poss <- setdiff(all_poss, self_reg)

  # All possible residual covariances (effective-endogenous only)
  corr_pairs <- outer(endo_eff, endo_eff, function(x, y) paste0(x, "~~", y))
  all_corr <- c(corr_pairs[lower.tri(corr_pairs)],
                corr_pairs[upper.tri(corr_pairs)])

  # Candidate paths = all possible minus fixed and nonsense
  candidate_paths <- setdiff(all_poss, c(fixed_paths, nons_reg))
  candidate_corr <- all_corr

  base_syntax <- c(var_endo, int_endo, cov_exog, int_exog, nons_reg,
                   fixed_paths)

  list(
    base_syntax = base_syntax,
    candidate_paths = candidate_paths,
    candidate_corr = candidate_corr,
    fixed_paths = fixed_paths
  )
}


# ============================================================================
# Lavaan fitting helpers
# ============================================================================

#' Fit lavaan model and extract modification indices for eligible paths
#' @noRd
.gimme_fit_and_mi <- function(syntax, data_k, elig_paths) {
  fit <- .gimme_fit_lavaan(syntax, data_k)

  if (is.null(fit)) return(NA) # nocov start
  if (!lavaan::lavInspect(fit, "converged")) return(NA)
  if (any(is.na(lavaan::lavInspect(fit, what = "list")$se))) return(NA) # nocov end

  mi <- tryCatch({
    mis <- lavaan::modindices(fit, standardized = FALSE, sort. = FALSE)
    mis$param <- paste0(mis$lhs, mis$op, mis$rhs)
    mis[mis$param %in% elig_paths, , drop = FALSE]
  }, error = function(e) NA)

  mi
}


#' Fit lavaan model and extract z-values for specified paths
#' @noRd
.gimme_fit_and_z <- function(syntax, data_k, elig_paths) {
  fit <- .gimme_fit_lavaan(syntax, data_k)

  if (is.null(fit)) return(NA) # nocov start
  if (!lavaan::lavInspect(fit, "converged")) return(NA) # nocov end

  # Use standardizedSolution for z-values (matches gimme's return.zs)
  ss <- tryCatch(lavaan::standardizedSolution(fit), error = function(e) NULL)
  if (is.null(ss)) return(NA) # nocov

  ss$param <- paste0(ss$lhs, ss$op, ss$rhs)
  ss[ss$param %in% elig_paths, , drop = FALSE]
}


#' Fit final lavaan model and extract all results
#' @noRd
.gimme_fit_final <- function(syntax, data_k, varnames, lag_names) {
  fit <- .gimme_fit_lavaan(syntax, data_k)
  p <- length(varnames)
  all_names <- c(lag_names, varnames)
  # gimme excludes declared exogenous variables from the endogenous rows of
  # path_est_mats/psi, while retaining them as current-variable columns. Since
  # only non-exogenous variables receive lag columns, lag_names identifies the
  # exact row set without needing another public-facing argument here.
  endo_names <- sub("lag$", "", lag_names)

  if (is.null(fit)) { # nocov start
    return(list(
      coefs = matrix(0, length(endo_names), length(all_names),
                     dimnames = list(endo_names, all_names)),
      psi = matrix(0, length(endo_names), length(all_names),
                   dimnames = list(endo_names, all_names)),
      fit_indices = data.frame(
        chisq = NA, df = NA, pvalue = NA, rmsea = NA, srmr = NA,
        nnfi = NA, cfi = NA, bic = NA, aic = NA, logl = NA
      ),
      status = "failed to converge"
    )) # nocov end
  }

  converged <- lavaan::lavInspect(fit, "converged")

  # Extract standardized coefficient matrix (betas) -- matches gimme's output
  std_est <- tryCatch(lavaan::lavInspect(fit, "std"), error = function(e) NULL)

  coef_mat <- matrix(0, length(endo_names), length(all_names),
                     dimnames = list(endo_names, all_names))
  # gimme returns the current-variable rows of lavaan's standardized psi block
  # against all lagged/current columns (p x 2p), not the full 2p x 2p matrix.
  psi_mat <- matrix(0, length(endo_names), length(all_names),
                    dimnames = list(endo_names, all_names))

  if (!is.null(std_est)) {
    beta <- std_est$beta
    avail_rows <- intersect(endo_names, rownames(beta))
    avail_cols <- intersect(all_names, colnames(beta))
    coef_mat[avail_rows, avail_cols] <- round(
      beta[avail_rows, avail_cols, drop = FALSE], digits = 4
    )

    psi <- std_est$psi
    avail_psi_r <- intersect(endo_names, rownames(psi))
    avail_psi_c <- intersect(all_names, colnames(psi))
    psi_mat[avail_psi_r, avail_psi_c] <- round(
      psi[avail_psi_r, avail_psi_c, drop = FALSE], digits = 4
    )
  }

  # Extract fit indices
  fi <- tryCatch(
    lavaan::fitMeasures(fit, c("chisq", "df", "pvalue", "rmsea", "srmr",
                                "nnfi", "cfi", "bic", "aic", "logl")),
    error = function(e) rep(NA, 10)
  )
  fi_df <- as.data.frame(as.list(fi))

  # Status
  status <- if (converged) "converged normally" else "failed to converge"

  list(
    coefs = coef_mat,
    psi = psi_mat,
    fit_indices = fi_df,
    status = status
  )
}


# ============================================================================
# Group search
# ============================================================================

#' Normalize and validate the group correction mode
#' @noRd
.gimme_normalize_group_correct <- function(group_correct) {
  if (is.numeric(group_correct)) {
    if (length(group_correct) != 1L || !is.finite(group_correct) ||
        group_correct <= 0 || group_correct >= 1) {
      stop("Numeric `group_correct` must be a single finite number between 0 and 1.",
           call. = FALSE)
    }
    return(as.numeric(group_correct))
  }

  if (!is.character(group_correct) || length(group_correct) != 1L ||
      is.na(group_correct)) {
    stop("`group_correct` must be \"Bonferroni Group\", ",
         "\"Bonferroni Paths\", \"fdr\", or a number between 0 and 1.",
         call. = FALSE)
  }

  if (identical(group_correct, "Bonferoni Group")) {
    warning("`group_correct = \"Bonferoni Group\"` is deprecated; use the ",
            "correct spelling, \"Bonferroni Group\".", call. = FALSE)
    group_correct <- "Bonferroni Group"
  }

  valid <- c("Bonferroni Group", "Bonferroni Paths", "fdr")
  if (!group_correct %in% valid) {
    stop("`group_correct` must be \"Bonferroni Group\", ",
         "\"Bonferroni Paths\", \"fdr\", or a number between 0 and 1.",
         call. = FALSE)
  }
  group_correct
}


#' Compute group-level entry and pruning thresholds
#' @noRd
.gimme_group_thresholds <- function(group_correct, alpha, n_subj, n_paths) {
  n_paths <- max(1L, as.integer(n_paths))

  if (is.numeric(group_correct)) {
    test_alpha <- group_correct
    correction <- "fixed"
  } else if (identical(group_correct, "Bonferroni Group")) {
    test_alpha <- alpha / n_subj
    correction <- "Bonferroni"
  } else if (identical(group_correct, "Bonferroni Paths")) {
    test_alpha <- alpha / n_paths
    correction <- "Bonferroni"
  } else { # fdr: BH is applied during MI entry; raw alpha is used for pruning.
    test_alpha <- alpha
    correction <- "fdr"
  }

  list(
    chisq = stats::qchisq(1 - test_alpha, df = 1),
    z = abs(stats::qnorm(test_alpha / 2)),
    alpha = alpha,
    test_alpha = test_alpha,
    correction = correction
  )
}


#' Compute individual-level entry and pruning thresholds
#' @noRd
.gimme_individual_thresholds <- function(indiv_correct, alpha, n_paths) {
  n_paths <- max(1L, as.integer(n_paths))
  test_alpha <- if (identical(indiv_correct, "Bonferroni")) {
    alpha / n_paths
  } else {
    alpha
  }

  # gimme 10.0 uses a one-sided normal tail (then absolute value) for
  # individual pruning in both modes.
  list(
    chisq = stats::qchisq(1 - test_alpha, df = 1),
    z = abs(stats::qnorm(test_alpha)),
    alpha = alpha,
    test_alpha = test_alpha,
    correction = indiv_correct
  )
}


#' Flag significant modification indices under a correction rule
#' @noRd
.gimme_significant_mi <- function(mi, chisq_cutoff, correction, alpha) {
  sig <- rep(FALSE, length(mi))
  usable <- is.finite(mi)
  if (!any(usable)) return(sig)

  if (identical(correction, "fdr")) {
    p <- 1 - stats::pchisq(mi[usable], df = 1)
    adjusted <- stats::p.adjust(p, method = "BH")
    sig[usable] <- adjusted <= alpha
  } else {
    sig[usable] <- mi[usable] >= chisq_cutoff
  }
  sig
}

#' Select best candidate path from modification indices across subjects
#' @noRd
.gimme_select_path <- function(mi_list, elig_paths, prop_cutoff, n_subj,
                                chisq_cutoff, hybrid,
                                correction = "Bonferroni", alpha = 0.05) {
  # Remove NAs (non-converged subjects)
  mi_valid <- mi_list[!vapply(mi_list, function(x) is.atomic(x) && length(x) == 1L && is.na(x), logical(1))]
  n_converge <- length(mi_valid)

  if (n_converge <= (n_subj / 2)) return(NA_character_)
  if (n_converge == 0) return(NA_character_) # nocov

  # Combine all modification indices
  mi_all <- do.call(rbind, mi_valid)
  if (is.null(mi_all) || nrow(mi_all) == 0) return(NA_character_) # nocov

  mi_all$param <- paste0(mi_all$lhs, mi_all$op, mi_all$rhs)
  mi_all <- mi_all[mi_all$param %in% elig_paths, , drop = FALSE]
  if (nrow(mi_all) == 0) return(NA_character_) # nocov

  # Count significant MIs per path
  mi_all$sig <- as.integer(.gimme_significant_mi(
    mi_all$mi, chisq_cutoff = chisq_cutoff,
    correction = correction, alpha = alpha
  ))

  # Aggregate per path: total MI, number of subjects significant, mean MI.
  param_stats <- data.frame(
    param = unique(mi_all$param),
    stringsAsFactors = FALSE
  )
  param_stats$sum_mi <- vapply(param_stats$param, function(p) {
    sum(mi_all$mi[mi_all$param == p])
  }, numeric(1))
  param_stats$count_sig <- vapply(param_stats$param, function(p) {
    sum(mi_all$sig[mi_all$param == p])
  }, numeric(1))
  param_stats$mean_mi <- vapply(param_stats$param, function(p) {
    mean(mi_all$mi[mi_all$param == p])
  }, numeric(1))

  # Sort: most people significant first, then highest mean MI (matches gimme)
  param_stats <- param_stats[order(-param_stats$count_sig,
                                    -param_stats$mean_mi), , drop = FALSE]

  # Check if top path meets group cutoff
  if (param_stats$count_sig[1] > (prop_cutoff * n_converge)) {
    return(param_stats$param[1])
  }

  NA_character_
}


# ============================================================================
# Group pruning
# ============================================================================

#' Prune group paths by checking z-values across subjects
#' @noRd
.gimme_prune_paths <- function(base_syntax, group_paths, ts_list,
                                n_subj, prop_cutoff, z_cutoff) {
  pruning <- TRUE

  while (pruning) {
    current_syntax <- c(base_syntax, group_paths)

    # Get z-values per person
    z_list <- lapply(ts_list, function(d) {
      .gimme_fit_and_z(current_syntax, d, group_paths)
    })

    # Find weakest path
    drop_path <- .gimme_find_weakest(z_list, group_paths, prop_cutoff,
                                      n_subj, z_cutoff)

    if (is.na(drop_path)) {
      pruning <- FALSE
    } else {
      group_paths <- setdiff(group_paths, drop_path) # nocov
      if (length(group_paths) == 0) { # nocov start
        pruning <- FALSE # nocov end
      }
    }
  }

  group_paths
}


#' Find the weakest path that should be pruned
#' @noRd
.gimme_find_weakest <- function(z_list, elig_paths, prop_cutoff, n_subj,
                                 z_cutoff) {
  z_valid <- z_list[!vapply(z_list, function(x) is.atomic(x) && length(x) == 1L && is.na(x), logical(1))]
  n_converge <- length(z_valid)
  if (n_converge == 0) return(NA_character_)

  z_all <- do.call(rbind, z_valid)
  if (is.null(z_all) || nrow(z_all) == 0) return(NA_character_)

  z_all$param <- paste0(z_all$lhs, z_all$op, z_all$rhs)
  z_all <- z_all[z_all$param %in% elig_paths, , drop = FALSE]
  if (nrow(z_all) == 0) return(NA_character_)

  # Count non-significant z-values per path
  z_all$nonsig <- ifelse(abs(z_all$z) < z_cutoff, 1L, 0L)

  param_stats <- data.frame(
    param = unique(z_all$param),
    stringsAsFactors = FALSE
  )
  param_stats$count_nonsig <- vapply(param_stats$param, function(p) {
    sum(z_all$nonsig[z_all$param == p])
  }, numeric(1))
  param_stats$mean_abs_z <- vapply(param_stats$param, function(p) {
    mean(abs(z_all$z[z_all$param == p]))
  }, numeric(1))

  # Sort: most non-significant first, then lowest mean |z|
  param_stats <- param_stats[order(-param_stats$count_nonsig,
                                    param_stats$mean_abs_z), , drop = FALSE]

  # Prune if the weakest path is non-significant for > (1 - prop_cutoff) of subjects
  if (param_stats$count_nonsig[1] > ((1 - prop_cutoff) * n_converge)) {
    return(param_stats$param[1]) # nocov
  }

  NA_character_
}


# ============================================================================
# Individual search
# ============================================================================

#' Run individual-level path search for one person
#' @noRd
.gimme_individual_search <- function(base_syntax, group_paths, data_k,
                                      elig_paths, ind_cutoff, ind_z_cutoff,
                                      fit_indices, n_excellent, stop_crit,
                                      indiv_correct, alpha, hybrid, endo_names,
                                      lag_names) {
  ind_paths <- character(0)
  nonconv_path <- character(0)  # paths that caused instability
  dropped_param <- character(0) # paths dropped by z-pruning
  model_fit_pruned <- FALSE

  # --- Phase 1: Forward search ---
  ind_paths <- .gimme_ind_forward_search(
    base_syntax, group_paths, ind_paths, data_k, elig_paths,
    ind_cutoff, fit_indices, n_excellent,
    exclude = character(0), stop_crit = stop_crit,
    indiv_correct = indiv_correct, alpha = alpha
  )

  # --- Phase 2: Stability + prune + resume cycle ---
  # Mirrors gimme's search.paths.ind post-search loop
  outer_done <- FALSE

  while (!outer_done) {
    # 2a: Check stability -- pop unstable paths
    stable_result <- .gimme_stabilize(
      base_syntax, group_paths, ind_paths, data_k,
      endo_names, lag_names
    )
    ind_paths <- stable_result$ind_paths
    nonconv_path <- c(nonconv_path, stable_result$removed)
    converged <- stable_result$converged
    stable <- stable_result$stable

    # 2b: Z-prune individual paths (only on a converged, stable model)
    pruned_any <- FALSE
    allow_prune <- !identical(stop_crit, "model fit") || !model_fit_pruned
    if (converged && stable && length(ind_paths) > 0 && allow_prune) {
      prune_done <- FALSE
      while (!prune_done) {
        current_syntax <- c(base_syntax, group_paths, ind_paths)
        z_info <- .gimme_fit_and_z(current_syntax, data_k, ind_paths)

        if (!identical(z_info, NA) && is.data.frame(z_info) && nrow(z_info) > 0) {
          z_info$param <- paste0(z_info$lhs, z_info$op, z_info$rhs)
          # Find weakest non-significant path
          nonsig <- z_info[abs(z_info$z) < ind_z_cutoff, , drop = FALSE]
          if (nrow(nonsig) > 0) {
            weakest <- nonsig$param[which.min(abs(nonsig$z))]
            dropped_param <- c(dropped_param, weakest)
            ind_paths <- setdiff(ind_paths, weakest)
            pruned_any <- TRUE
          } else {
            prune_done <- TRUE
          }
        } else {
          prune_done <- TRUE # nocov
        }
      }
      if (identical(stop_crit, "model fit")) model_fit_pruned <- TRUE
    }

    # 2c: Resume the forward search whenever a path was removed (for instability
    # or non-significance) OR the model is still unstable / non-converged. This
    # mirrors gimme's pop-exclude-resume: a subject whose group+AR baseline is
    # itself unstable needs a DIFFERENT set of individual paths to stabilise it,
    # so we exclude the removed paths and keep searching instead of abandoning
    # the subject (the previous code broke here, leaving hard subjects with no
    # individual paths and a worse-fitting, unstable model).
    # Under "model fit", a path removed for weak significance can be added
    # again if it is needed for adequate fit. Avoid re-pruning on that resumed
    # pass to prevent an add/drop cycle, matching gimme 10.0's search rule.
    exclude <- if (identical(stop_crit, "model fit")) {
      unique(nonconv_path)
    } else {
      unique(c(dropped_param, nonconv_path))
    }
    if (length(stable_result$removed) > 0 || pruned_any ||
        !stable || !converged) {
      new_paths <- .gimme_ind_forward_search(
        base_syntax, group_paths, ind_paths, data_k,
        elig_paths, ind_cutoff, fit_indices, n_excellent,
        exclude = exclude, stop_crit = stop_crit,
        indiv_correct = indiv_correct, alpha = alpha
      )
      if (length(new_paths) > length(ind_paths)) {
        ind_paths <- new_paths
        next  # loop back to the stability check
      }
    }

    outer_done <- TRUE
  }

  list(
    group_paths = group_paths,
    ind_paths = ind_paths,
    full_syntax = c(base_syntax, group_paths, ind_paths)
  )
}


#' Forward search: add individual paths one at a time via MI
#' @noRd
.gimme_ind_forward_search <- function(base_syntax, group_paths, ind_paths,
                                       data_k, elig_paths, ind_cutoff,
                                       fit_indices, n_excellent, exclude,
                                       stop_crit, indiv_correct, alpha) {
  search <- TRUE

  while (search) {
    current_syntax <- c(base_syntax, group_paths, ind_paths)

    # Check if current fit is excellent enough
    fit <- .gimme_fit_lavaan(current_syntax, data_k)

    good_fit <- FALSE
    if (!is.null(fit) && lavaan::lavInspect(fit, "converged")) {
      fi <- tryCatch(
        lavaan::fitMeasures(fit, c("rmsea", "srmr", "nnfi", "cfi")),
        error = function(e) NULL
      )

      if (!is.null(fi)) {
        n_exc <- sum(c(
          !is.na(fi["rmsea"]) && fi["rmsea"] <= fit_indices["rmsea_cutoff"],
          !is.na(fi["srmr"]) && fi["srmr"] <= fit_indices["srmr_cutoff"],
          !is.na(fi["nnfi"]) && fi["nnfi"] >= fit_indices["nnfi_cutoff"],
          !is.na(fi["cfi"]) && fi["cfi"] >= fit_indices["cfi_cutoff"]
        ))

        good_fit <- n_exc >= n_excellent
      }
    }

    # Get modification indices
    mi <- .gimme_fit_and_mi(current_syntax, data_k, elig_paths)
    if (is.null(mi) || (is.atomic(mi) && length(mi) == 1L && is.na(mi)) || nrow(mi) == 0) { # nocov start
      search <- FALSE
      next # nocov end
    }

    mi$param <- paste0(mi$lhs, mi$op, mi$rhs)
    # Filter to paths not already in model and not excluded
    already_in <- c(group_paths, ind_paths, exclude)
    mi <- mi[!mi$param %in% already_in, , drop = FALSE]
    if (nrow(mi) == 0) { # nocov start
      search <- FALSE
      next # nocov end
    }

    add_path <- .gimme_choose_individual_path(
      mi = mi,
      good_fit = good_fit,
      ind_cutoff = ind_cutoff,
      stop_crit = stop_crit,
      indiv_correct = indiv_correct,
      alpha = alpha
    )
    if (is.na(add_path)) {
      search <- FALSE
      next
    }
    ind_paths <- c(ind_paths, add_path)
  }

  ind_paths
}


#' Choose the next individual path under the requested stopping rule
#' @noRd
.gimme_choose_individual_path <- function(mi, good_fit, ind_cutoff,
                                           stop_crit, indiv_correct, alpha) {
  if (is.null(mi) || !is.data.frame(mi) || nrow(mi) == 0L) {
    return(NA_character_)
  }

  # Both standard and model-fit searches stop once the requested fit is met.
  # A significance search deliberately continues beyond adequate fit.
  if (isTRUE(good_fit) && stop_crit %in% c("standard", "model fit")) {
    return(NA_character_)
  }

  ord <- order(-mi$mi, na.last = NA)
  if (length(ord) == 0L) return(NA_character_)
  mi <- mi[ord, , drop = FALSE]

  # Model-fit search ignores significance until fit is adequate.
  if (identical(stop_crit, "model fit")) return(mi$param[1L])

  sig <- .gimme_significant_mi(
    mi$mi,
    chisq_cutoff = ind_cutoff,
    correction = indiv_correct,
    alpha = alpha
  )
  if (!any(sig)) return(NA_character_)
  mi$param[which(sig)[1L]]
}


#' Test whether standardized beta eigenvalues indicate instability
#' @details Matches gimme's testWeights: checks if any eigenvalue of
#'   the contemporaneous or lagged standardized beta block has Re >= 1.
#' @noRd
.gimme_test_weights <- function(fit, endo_names, lag_names) {
  std_beta <- tryCatch(
    lavaan::lavInspect(fit, "std")$beta,
    error = function(e) NULL
  )
  if (is.null(std_beta)) return(TRUE)  # treat errors as unstable

  # Effective endogenous outcomes are the variables lavaan actually kept as beta
  # rows (exogenous current variables and dropped predictors are absent). Build
  # both blocks against this SAME name set so each is square: a non-square block
  # would make eigen() error. Lagged block is endo_eff x endo_eff_lag, the
  # contemporaneous block endo_eff x endo_eff.
  endo_eff <- intersect(endo_names, rownames(std_beta))
  if (length(endo_eff) == 0L) return(TRUE) # nocov

  lag_cols  <- paste0(endo_eff, "lag")
  have_lag  <- lag_cols  %in% colnames(std_beta)
  have_cont <- endo_eff  %in% colnames(std_beta)

  unstable <- FALSE
  if (all(have_lag)) {
    lag_block <- round(std_beta[endo_eff, lag_cols, drop = FALSE], digits = 4)
    unstable <- unstable ||
      any(Re(eigen(lag_block, only.values = TRUE)$values) >= 1)
  }
  if (all(have_cont)) {
    cont_block <- round(std_beta[endo_eff, endo_eff, drop = FALSE], digits = 4)
    unstable <- unstable ||
      any(Re(eigen(cont_block, only.values = TRUE)$values) >= 1)
  }

  unstable
}


#' Pop unstable individual paths until model is stable
#' @noRd
.gimme_stabilize <- function(base_syntax, group_paths, ind_paths, data_k,
                              endo_names, lag_names) {
  removed <- character(0)

  repeat {
    current_syntax <- c(base_syntax, group_paths, ind_paths)
    fit <- .gimme_fit_lavaan(current_syntax, data_k)

    if (is.null(fit)) { # nocov start
      return(list(ind_paths = ind_paths, removed = removed,
                  converged = FALSE, stable = FALSE))
    } # nocov end

    converged <- lavaan::lavInspect(fit, "converged")
    zero_se <- tryCatch(
      sum(lavaan::lavInspect(fit, "se")$beta, na.rm = TRUE) == 0,
      error = function(e) TRUE
    )
    unstable <- .gimme_test_weights(fit, endo_names, lag_names)

    if (converged && !zero_se && !unstable) {
      return(list(ind_paths = ind_paths, removed = removed,
                  converged = TRUE, stable = TRUE))
    }

    # Model is unstable/non-converged -- pop last individual path
    if (length(ind_paths) == 0) {
      return(list(ind_paths = ind_paths, removed = removed,
                  converged = converged, stable = !unstable))
    }

    removed <- c(removed, ind_paths[length(ind_paths)]) # nocov start
    ind_paths <- ind_paths[-length(ind_paths)] # nocov end
  }
}


#' Fit a lavaan model with standard gimme settings
#' @noRd
.gimme_fit_lavaan <- function(syntax, data_k) {
  tryCatch(
    lavaan::lavaan(
      model = paste(syntax, collapse = "\n"),
      data = data_k,
      model.type = "sem",
      missing = "fiml",
      estimator = "ml",
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


# ============================================================================
# Result extraction
# ============================================================================

#' Extract structured results from individual search outputs
#' @noRd
.gimme_extract_results <- function(ind_results, varnames, lag_names,
                                    group_paths, base_syntax, fixed_paths,
                                    n_subj, ts_list, hybrid, VAR = FALSE) {
  p <- length(varnames)
  all_names <- c(lag_names, varnames)
  subj_names <- names(ind_results)

  # Fit final models and extract per-person results
  coefs_list <- vector("list", n_subj)
  psi_list <- vector("list", n_subj)
  fit_list <- vector("list", n_subj)
  syntax_list <- vector("list", n_subj)
  ind_paths_list <- vector("list", n_subj)

  for (k in seq_len(n_subj)) {
    syntax_k <- ind_results[[k]]$full_syntax
    syntax_list[[k]] <- syntax_k
    ind_paths_list[[k]] <- ind_results[[k]]$ind_paths

    final <- .gimme_fit_final(syntax_k, ts_list[[k]], varnames, lag_names)

    coefs_list[[k]] <- final$coefs
    psi_list[[k]] <- final$psi
    fit_list[[k]] <- cbind(
      data.frame(file = subj_names[k], stringsAsFactors = FALSE),
      final$fit_indices,
      data.frame(status = final$status, stringsAsFactors = FALSE)
    )
  }
  names(coefs_list) <- subj_names
  names(psi_list) <- subj_names
  names(syntax_list) <- subj_names
  names(ind_paths_list) <- subj_names

  # Build fit data.frame
  fit_df <- do.call(rbind, fit_list)
  rownames(fit_df) <- NULL

  # Build path count matrices
  path_counts <- matrix(0L, p, length(all_names),
                        dimnames = list(varnames, all_names))
  for (k in seq_len(n_subj)) {
    mat <- coefs_list[[k]]
    # NA-safe: a non-converged person's matrix may hold NA; treat NA as "no path"
    # rather than poisoning the whole count column.
    path_counts[rownames(mat), colnames(mat)] <-
      path_counts[rownames(mat), colnames(mat), drop = FALSE] +
      (!is.na(mat) & mat != 0) * 1L
  }

  fixed_reg <- fixed_paths[grepl("~", fixed_paths, fixed = TRUE) &
                             !grepl("~~", fixed_paths, fixed = TRUE)]
  if (length(fixed_reg) > 0L) {
    fixed_lhs <- sub("\\s*~.*$", "", fixed_reg)
    fixed_rhs <- sub("^.*?~\\s*", "", fixed_reg)
    fixed_rhs <- sub("^[+-]?[0-9.]+\\*", "", fixed_rhs)
    fixed_ok <- fixed_lhs %in% rownames(path_counts) &
      fixed_rhs %in% colnames(path_counts)
    path_counts[cbind(fixed_lhs[fixed_ok], fixed_rhs[fixed_ok])] <- n_subj
  }

  # Separate temporal and contemporaneous count matrices
  lag_vars <- sub("lag$", "", lag_names)
  temporal_counts <- matrix(0L, p, p,
                            dimnames = list(varnames, varnames))
  temporal_counts[, lag_vars] <- path_counts[, lag_names, drop = FALSE]
  contemp_counts <- path_counts[, varnames, drop = FALSE]

  # Build group-level average coefficient matrices
  temporal_avg <- matrix(0, p, p, dimnames = list(varnames, varnames))
  endo_names <- rownames(coefs_list[[1L]])
  temporal_avg[endo_names, lag_vars] <-
    Reduce("+", lapply(coefs_list,
                       function(m) m[, lag_names, drop = FALSE])) / n_subj
  contemp_avg <- matrix(0, p, p, dimnames = list(varnames, varnames))
  contemp_avg[endo_names, varnames] <-
    Reduce("+", lapply(coefs_list,
                       function(m) m[, varnames, drop = FALSE])) / n_subj

  # Contemporaneous residual-covariance network. Under VAR (and hybrid) gimme
  # expresses contemporaneous relations as freely-estimated residual covariances
  # -- the current-variable block of psi -- NOT as directed lag-0 regressions, so
  # the directed `contemp_counts` above is all-zero there. Derive the undirected
  # covariance network (count of subjects with a non-zero off-diagonal, and the
  # group-average covariance) so the tidy accessors can surface it.
  psi_cur <- lapply(psi_list, function(P) {
    M <- matrix(0, p, p, dimnames = list(varnames, varnames))
    have_rows <- intersect(varnames, rownames(P))
    M[have_rows, varnames] <- P[have_rows, varnames, drop = FALSE]
    diag(M) <- 0
    M
  })
  contemp_cov <- Reduce("+", lapply(psi_cur,
                                    function(M) (!is.na(M) & M != 0) * 1L))
  contemp_cov_avg <- Reduce("+", lapply(psi_cur, function(M) {
    M[is.na(M)] <- 0
    M
  })) / n_subj
  contemp_is_cov <- isTRUE(hybrid) || isTRUE(VAR)

  list(
    temporal = temporal_counts,
    temporal_avg = temporal_avg,
    contemporaneous = contemp_counts,
    contemporaneous_avg = contemp_avg,
    contemp_cov = contemp_cov,
    contemp_cov_avg = contemp_cov_avg,
    contemp_is_cov = contemp_is_cov,
    coefs = coefs_list,
    psi = psi_list,
    fit = fit_df,
    path_counts = path_counts,
    paths = syntax_list,
    group_paths = group_paths,
    individual_paths = ind_paths_list,
    syntax = syntax_list
  )
}


# ============================================================================
# S3 Methods
# ============================================================================

#' Print Method for net_gimme
#'
#' @param x A \code{net_gimme} object.
#' @param digits Number of digits used for printed network matrices.
#' @param ... Additional arguments (ignored).
#'
#' @return The input object, invisibly.
#'
#' @examplesIf requireNamespace("lavaan", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' panel <- data.frame(
#'   id = rep(1:5, each = 20),
#'   t  = rep(seq_len(20), 5),
#'   A  = rnorm(100), B = rnorm(100), C = rnorm(100)
#' )
#' gm <- fit_gimme(panel, vars = c("A","B","C"), id = "id", time = "t")
#' print(gm)
#' }
#'
#' @export
print.net_gimme <- function(x, digits = 2, ...) {
  cat("GIMME Network Analysis\n")
  cat(strrep("-", 30), "\n")
  cat("Subjects:  ", x$n_subjects, "\n")
  cat("Variables: ", length(x$labels), " (",
      paste(x$labels, collapse = ", "), ")\n")
  cat("AR paths:  ", ifelse(x$config$ar, "yes", "no"), "\n")
  cat("Hybrid:    ", ifelse(x$config$hybrid, "yes", "no"), "\n\n")

  cat("Group-level paths found:", length(x$group_paths), "\n")
  if (length(x$group_paths) > 0) {
    for (gp in x$group_paths) cat("  ", gp, "\n")
  }

  n_ind <- vapply(x$individual_paths, length, integer(1))
  cat("\nIndividual-level paths: ",
      sprintf("mean %.1f, range %d-%d\n", mean(n_ind), min(n_ind), max(n_ind)))

  cat("\nProportion of subjects with each path:\n")
  .ido_print_networks(x, digits = digits)

  cat("\n  plot(x)  (faithful gimme-style mixed network) | plot(x, layer = \"temporal\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}


#' Summary Method for net_gimme
#'
#' @param object A \code{net_gimme} object.
#' @param ... Additional arguments (ignored).
#'
#' @return A tidy `data.frame` of per-network metrics (one row per network:
#'   `temporal`, `contemporaneous`), with `n_edges`/`density`/etc. computed from
#'   the proportion-of-subjects networks. Per-subject fit indices are in
#'   `object$fit`; `coefs(object)` gives the per-person estimates,
#'   `edges(object)` the tidy edge list, and `nodes(object)` node strengths.
#'
#' @examplesIf requireNamespace("lavaan", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' panel <- data.frame(
#'   id = rep(1:5, each = 20),
#'   t  = rep(seq_len(20), 5),
#'   A  = rnorm(100), B = rnorm(100), C = rnorm(100)
#' )
#' gm <- fit_gimme(panel, vars = c("A","B","C"), id = "id", time = "t")
#' summary(gm)
#' }
#'
#' @export
summary.net_gimme <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
