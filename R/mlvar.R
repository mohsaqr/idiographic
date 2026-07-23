# ---- Multilevel Vector Autoregression (mlVAR) ----

#' Build a Multilevel Vector Autoregression (mlVAR) network
#'
#' @description Estimates three networks from ESM/EMA panel data, matching
#'   validated `mlVAR::mlVAR()` configurations at machine precision: (1) a directed
#'   temporal network of fixed-effect lagged regression coefficients, (2)
#'   an undirected contemporaneous network of partial correlations among
#'   residuals, and (3) an undirected between-subjects network of partial
#'   correlations derived from the person-mean fixed effects.
#'
#' @details The algorithm follows mlVAR's lmer pipeline exactly:
#' \enumerate{
#'   \item Drop rows with NA in id/day/beep and optionally grand-mean
#'         standardize each variable.
#'   \item Expand the per-(id, day) beep grid and right-join original
#'         values, producing the augmented panel (`augData`).
#'   \item Add within-person lagged predictors (`L1_*`) and person-mean
#'         predictors (`PM_*`).
#'   \item For each outcome variable fit
#'         `lmer(y ~ within + between-except-own-PM + (1 | id))` with
#'         `REML = FALSE`. Collect the fixed-effect temporal matrix `B`,
#'         between-effect matrix `Gamma`, random-intercept SDs (`mu_SD`),
#'         and lmer residual SDs.
#'   \item Contemporaneous network:
#'         `cor2pcor(D %*% cov2cor(cor(resid)) %*% D)`.
#'   \item Between-subjects network:
#'         `cor2pcor(pseudoinverse(forcePositive(D (I - Gamma))))`.
#' }
#'
#' The committed oracle matrix validates fixed temporal/contemporaneous `lmer`
#' fits at lags 1 and 1+2, preprocessing controls (`scale`, `scaleWithin`,
#' `compareToLags`, `trueMeans`, and position detrending), and lag-1
#' `estimator = "lm"`, `temporal = "unique"` fits across every supported
#' contemporaneous structure. Other configurations carry a narrower
#' declaration available through [equivalence()].
#'
#' @param data A `data.frame` containing the panel data.
#' @param vars Character vector of variable column names to model.
#' @param id Character string naming the person-ID column.
#' @param day Character string naming the day/session column, or `NULL`.
#'   When provided, lag pairs are only formed within the same day.
#' @param beep Character string naming the measurement-occasion column, or
#'   `NULL`. When `NULL`, row position within each (id, day) is used.
#' @param lags One or more unique positive integer lag orders (mlVAR's `lags`).
#' @param estimator Character. Frequentist estimator: `"lmer"` (multilevel)
#'   or `"lm"` (separate person-specific models, requiring
#'   `temporal = "unique"`). The legacy value `"Mplus"` selects
#'   `engine = "mplus"`.
#' @param temporal,contemporaneous Character random-effect structure. The native
#'   frequentist engine supports fixed, correlated, orthogonal, and unique
#'   person-specific effects. The Bayesian engine maps correlated/orthogonal/
#'   unique temporal effects to its full random-slope model.
#' @param AR Logical. If `TRUE`, estimate only autoregressive (own-lag) temporal
#'   effects, giving a diagonal temporal matrix (matches `mlVAR(AR = TRUE)`).
#'   For the native frequentist/reference path this requires `estimator =
#'   "lmer"`. Default `FALSE`.
#' @param scale Logical. If `TRUE`, each variable is grand-mean centred and
#'   divided by its pooled SD before augmentation (mlVAR's `scale`). Default
#'   `FALSE`. (The deprecated `standardize` is an alias.)
#' @param scaleWithin Logical. If `TRUE`, additionally scale within person
#'   (mlVAR's `scaleWithin`). Default `FALSE`.
#' @param nCores Positive integer number of outcome models to fit in parallel.
#'   Uses forked workers on Unix-like systems and a PSOCK cluster on Windows.
#' @param verbose Logical. Emit progress messages. Default `FALSE`.
#' @param lag Deprecated alias for `lags`.
#' @param standardize Deprecated alias for `scale`.
#' @param engine Estimation engine: `"frequentist"` (native lme4/base R),
#'   `"bayes"` (the native DSEM sampler), `"mplus"` (licensed Mplus through
#'   [fit_mlvar_mplus()]), or `"reference"` (direct `mlVAR::mlVAR()` followed by
#'   conversion to idiographic's tidy result contract).
#' @param standardize_mode Easy standardization vocabulary: `"none"`,
#'   `"global"`, `"within"`, or `"both"`. When supplied it sets `scale` and
#'   `scaleWithin`; the logical legacy arguments remain supported.
#' @param missing Missing-data policy: `"omit"`, `"fail"`, or `"model"`.
#'   `"fail"` checks model variables and ID/day/beep ordering keys. Within-model
#'   imputation is available with the Bayesian random-slope engine.
#' @param compare_to_lags Optional positive lag vector used only to align the
#'   analysis rows when comparing models with different lag orders. It must
#'   include every fitted value in `lags`; for example, use `c(1, 2)` while
#'   fitting lag 1 for a comparison with a lag-2 model.
#' @param true_means Optional data frame containing `id` and all `vars`, used as
#'   known person means instead of sample means.
#' @param detrend `"none"` or `"position"`. Position detrending standardizes
#'   each measurement position across subjects before model standardization.
#' @param na_rm Logical legacy spelling for whether incomplete model rows are
#'   omitted. `FALSE` is equivalent to `missing = "fail"`.
#' @param orthogonal Deprecated upstream compatibility flag. When supplied it
#'   sets `temporal = "orthogonal"` (`TRUE`) or `"correlated"` (`FALSE`).
#' @param ... Engine-specific controls. For example `n_iter`, `n_chains`, and
#'   `residual` for the Bayesian engine, or Mplus controls for the Mplus engine.
#'
#' @section Observation keys:
#' When `beep` is supplied, every complete `(id, day, beep)` key (or `(id,
#' beep)` when `day = NULL`) must be unique. Duplicate keys often indicate that
#' a study-period/session column was lost during data conversion. Because
#' upstream join behaviour is row-order dependent in that case, `fit_mlvar()`
#' errors and asks you to resolve or explicitly deduplicate the source data.
#'
#' @return A dual-class `c("net_mlvar", "netobject_group")` object — a
#'   named list of three full netobjects, one per network, plus
#'   model-level metadata stored as attributes. Each element is a
#'   standard `c("netobject", "cograph_network")` weight-matrix wrapper
#'   (no raw `$data`), so `print()`, `summary()`, [coefs()], and
#'   `cograph::splot(fit$temporal)` work directly. The three constituents
#'   are matrix-wrapped and carry no underlying panel data, so any
#'   data-resampling workflow (bootstrap, reliability, stability) must start
#'   from the original panel rather than from these wrappers.
#'   Structure:
#'   \describe{
#'     \item{`fit$temporal`}{Directed netobject for the `d x d` matrix of
#'       fixed-effect lagged coefficients. `$weights[i, j]` is the effect
#'       of variable j at t-lag on variable i at t. `method =
#'       "mlvar_temporal"`, `directed = TRUE`.}
#'     \item{`fit$contemporaneous`}{Undirected netobject for the `d x d`
#'       partial-correlation network of within-person lmer residuals.
#'       `method = "mlvar_contemporaneous"`, `directed = FALSE`.}
#'     \item{`fit$between`}{Undirected netobject for the `d x d`
#'       partial-correlation network of person means, derived from
#'       `D (I - Gamma)`. `method = "mlvar_between"`, `directed = FALSE`.
#'       \strong{Convention:} when a random-intercept SD is 0 the between
#'       network is not estimable; idiographic returns an all-zero matrix (with a
#'       warning) as a plotting-oriented convention, whereas `mlVAR` returns
#'       an all-`NA` matrix. The contemporaneous network follows the same
#'       zero-on-degeneracy convention. This is a deliberate departure from
#'       strict reference equivalence in the singular case.}
#'     \item{`attr(fit, "coefs")` / [coefs()]}{Tidy `data.frame` with one
#'       row per `(outcome, predictor)` pair and columns `outcome`,
#'       `predictor`, `beta`, `se`, `t`, `p`, `ci_lower`, `ci_upper`,
#'       `significant`. Filter, sort, or plot with base R or the tidyverse.
#'       Retrieve with `coefs(fit)`.}
#'     \item{`attr(fit, "n_obs")`}{Number of rows in the augmented panel
#'       after na.omit.}
#'     \item{`attr(fit, "n_subjects")`}{Number of unique subjects remaining.}
#'     \item{`attr(fit, "lag")`}{Lag order used.}
#'     \item{`attr(fit, "standardize")`}{Logical; whether pre-augmentation
#'       standardization was applied.}
#'   }
#'
#' @examplesIf requireNamespace("lme4", quietly = TRUE)
#' \donttest{
#' set.seed(1)
#' n_id <- 8; n_t <- 30; vars <- c("A", "B", "C")
#' rows <- lapply(seq_len(n_id), function(i) {
#'   m <- as.data.frame(matrix(rnorm(n_t * 3), ncol = 3))
#'   names(m) <- vars
#'   m$id <- i; m$day <- 1L; m$beep <- seq_len(n_t)
#'   m
#' })
#' d <- do.call(rbind, rows)
#' fit <- fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
#' print(fit)
#' summary(fit)
#' }
#'
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations (counts taken from `data`).
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @seealso [fit_gimme()], [fit_graphical_var()], [as_netobject()]
#' @export
fit_mlvar <- function(data, vars, id,
                        day = NULL, beep = NULL,
                        lags = 1L,
                        estimator = c("lmer", "default", "lm", "Mplus"),
                        temporal = c("fixed", "correlated", "orthogonal",
                                     "unique", "default"),
                        contemporaneous = c("fixed", "correlated", "orthogonal",
                                            "unique", "default"),
                        AR = FALSE,
                        scale = FALSE,
                        scaleWithin = FALSE,
                        nCores = 1L,
                        verbose = FALSE,
                        lag = NULL,
                        standardize = NULL,
                        min_obs = NULL,
                        subject = NULL,
                        engine = c("frequentist", "bayes", "mplus", "reference"),
                        standardize_mode = NULL,
                        missing = c("omit", "fail", "model"),
                        compare_to_lags = NULL,
                        true_means = NULL,
                        detrend = c("none", "position"),
                        na_rm = TRUE,
                        orthogonal = NULL,
                        ...) {
  estimator       <- match.arg(estimator)
  temporal        <- match.arg(temporal)
  contemporaneous <- match.arg(contemporaneous)
  engine           <- match.arg(engine)
  missing          <- match.arg(missing)
  detrend          <- match.arg(detrend)

  if (identical(estimator, "Mplus")) engine <- "mplus"
  if (identical(estimator, "default")) estimator <- "lmer"
  if (identical(temporal, "default")) temporal <- "fixed"
  if (identical(contemporaneous, "default")) contemporaneous <- "fixed"
  if (!is.null(orthogonal)) {
    .ido_check_flag(orthogonal, "orthogonal")
    temporal <- if (isTRUE(orthogonal)) "orthogonal" else "correlated"
    warning("`orthogonal` is deprecated; setting `temporal = \"",
            temporal, "\"`.", call. = FALSE)
  }

  # `lag` (idiographic) and `standardize` (idiographic) are deprecated aliases of the
  # mlVAR-API names `lags` / `scale`. If the caller sets BOTH the canonical name
  # and the deprecated alias to conflicting values, honour the canonical name
  # and warn rather than silently letting the alias win.
  if (!is.null(lag)) {
    if (!missing(lags) && !identical(lags, lag)) {
      warning("Both `lags` and the deprecated `lag` were set and disagree; ",
              "using lags = ", lags, " and ignoring lag = ", lag, ".",
              call. = FALSE)
    } else {
      lags <- lag
    }
  }
  if (!is.null(standardize)) {
    if (!missing(scale) && !identical(scale, standardize)) {
      warning("Both `scale` and the deprecated `standardize` were set and ",
              "disagree; using scale = ", scale, " and ignoring standardize = ",
              standardize, ".", call. = FALSE)
    } else {
      scale <- standardize
    }
  }

  if (!is.null(standardize_mode)) {
    mode <- match.arg(standardize_mode, c("none", "global", "within", "both"))
    scale <- mode %in% c("global", "both")
    scaleWithin <- mode %in% c("within", "both")
  }
  .ido_check_flag(na_rm, "na_rm")
  if (!isTRUE(na_rm)) missing <- "fail"
  na_rm <- !identical(missing, "fail")

  # Shared validation happens before engine dispatch so every backend reports
  # the same clear contract errors instead of leaking backend-specific
  # subscript/stopifnot failures or silently ignoring front-door controls.
  if (!is.data.frame(data)) {
    stop("`data` must be a data frame.", call. = FALSE)
  }
  if (!(is.character(vars) && length(vars) >= 2L && !anyNA(vars) &&
        !anyDuplicated(vars) && all(nzchar(vars)))) {
    stop("`vars` must contain at least two unique, non-empty column names.",
         call. = FALSE)
  }
  if (!(is.character(id) && length(id) == 1L && !is.na(id) && nzchar(id))) {
    stop("`id` must be one non-empty column name.", call. = FALSE)
  }
  required <- c(vars, id, day, beep)
  required <- required[!vapply(required, is.null, logical(1))]
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols)) {
    stop("Columns not found in data: ", paste(missing_cols, collapse = ", "),
         call. = FALSE)
  }
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  .ido_check_numeric_vars(data, vars, check_variance = FALSE)
  .ido_check_flag(AR, "AR")
  .ido_check_flag(scale, "scale")
  .ido_check_flag(scaleWithin, "scaleWithin")
  .ido_check_flag(verbose, "verbose")
  if (!(is.numeric(nCores) && length(nCores) == 1L && is.finite(nCores) &&
        nCores == floor(nCores) && nCores >= 1L)) {
    stop("`nCores` must be one positive integer.", call. = FALSE)
  }
  nCores <- as.integer(nCores)
  if (!(is.numeric(lags) && length(lags) >= 1L && all(is.finite(lags)) &&
        all(lags >= 1L) && all(lags == floor(lags)) && !anyDuplicated(lags))) {
    stop("`lags` must contain unique positive whole numbers.", call. = FALSE)
  }
  lags <- sort(as.integer(lags))
  if (!is.null(compare_to_lags)) {
    if (!is.numeric(compare_to_lags) || !length(compare_to_lags) ||
        any(!is.finite(compare_to_lags)) || any(compare_to_lags < 1L) ||
        any(compare_to_lags != floor(compare_to_lags))) {
      stop("`compare_to_lags` must be NULL or positive whole-number lags.",
           call. = FALSE)
    }
    compare_to_lags <- sort(unique(as.integer(compare_to_lags)))
    if (!all(lags %in% compare_to_lags)) {
      stop("`compare_to_lags` must include every fitted value in `lags`; ",
           "for example, use `compare_to_lags = c(1, 2)` when fitting lag 1 ",
           "on rows aligned to a lag-2 model.", call. = FALSE)
    }
  }
  if (engine %in% c("frequentist", "reference")) {
    if (identical(estimator, "lm") && !identical(temporal, "unique")) {
      stop("`estimator = \"lm\"` requires `temporal = \"unique\"`, matching mlVAR.",
           call. = FALSE)
    }
    if (identical(temporal, "unique") && !identical(estimator, "lm")) {
      stop("`temporal = \"unique\"` requires `estimator = \"lm\"`, matching mlVAR.",
           call. = FALSE)
    }
    if (isTRUE(AR) && !identical(estimator, "lmer")) {
      stop("`AR = TRUE` requires `estimator = \"lmer\"`, matching mlVAR.",
           call. = FALSE)
    }
  }
  data <- .ido_keep(data, id, min_obs, subject)
  if (identical(missing, "fail") &&
      anyNA(data[, required, drop = FALSE])) {
    stop("Missing model or ordering values found with `missing = \"fail\"`.",
         call. = FALSE)
  }
  key_cols <- c(id, day, beep)
  key_cols <- key_cols[!vapply(key_cols, is.null, logical(1))]
  if (!is.null(beep) && length(key_cols) >= 2L) {
    complete_key <- stats::complete.cases(data[, key_cols, drop = FALSE])
    duplicate_key <- duplicated(data[complete_key, key_cols, drop = FALSE])
    if (any(duplicate_key)) {
      stop(
        "Duplicate observation keys found: ", sum(duplicate_key),
        " row(s) repeat `", paste(key_cols, collapse = "`, `"),
        "`. Resolve the period/session structure or deduplicate explicitly ",
        "before fitting; duplicate keys do not have deterministic mlVAR ",
        "semantics.",
        call. = FALSE
      )
    }
  }

  engine_args <- list(...)
  if (engine == "bayes") {
    unsupported <- c(
      AR = isTRUE(AR),
      nCores = nCores != 1L,
      compare_to_lags = !is.null(compare_to_lags),
      true_means = !is.null(true_means),
      detrend = !identical(detrend, "none"),
      estimator = !identical(estimator, "lmer")
    )
    if (any(unsupported)) {
      stop("The Bayesian engine does not accept front-door control(s): ",
           paste(names(unsupported)[unsupported], collapse = ", "),
           ". Use its explicit MCMC controls in `...`.", call. = FALSE)
    }
    if (!identical(lags, 1L)) {
      stop("The Bayesian engine currently supports `lags = 1` only.",
           call. = FALSE)
    }
    bayes_temporal <- if (temporal == "fixed") "fixed" else "random"
    if (contemporaneous != "fixed") {
      stop("The native Bayesian engine currently supports ",
           "`contemporaneous = \"fixed\"`; use `residual = \"random\"` for ",
           "person-specific innovation covariances.", call. = FALSE)
    }
    if (identical(missing, "model")) {
      if (bayes_temporal != "random") {
        stop("`missing = \"model\"` requires random temporal effects for the ",
             "Bayesian engine.", call. = FALSE)
      }
      engine_args$impute <- TRUE
    }
    args <- c(list(data = data, vars = vars, id = id, day = day, beep = beep,
                   lags = lags, temporal = bayes_temporal,
                   contemporaneous = "fixed", scale = scale,
                   scaleWithin = scaleWithin, min_obs = NULL, subject = NULL,
                   verbose = verbose), engine_args)
    return(do.call(fit_mlvar_bayes, args))
  }

  if (engine == "mplus") {
    unsupported <- c(
      AR = isTRUE(AR),
      compare_to_lags = !is.null(compare_to_lags),
      true_means = !is.null(true_means),
      detrend = !identical(detrend, "none")
    )
    if (any(unsupported)) {
      stop("The Mplus engine does not accept front-door control(s): ",
           paste(names(unsupported)[unsupported], collapse = ", "), ".",
           call. = FALSE)
    }
    if (!identical(lags, 1L)) {
      stop("The Mplus engine currently supports `lags = 1` only.",
           call. = FALSE)
    }
    if (temporal == "unique" || contemporaneous == "unique") {
      stop("The Mplus engine does not support `unique` temporal or ",
           "contemporaneous effects.", call. = FALSE)
    }
    if (!estimator %in% c("lmer", "Mplus")) {
      stop("The Mplus engine does not use `estimator = \"", estimator,
           "\"`.", call. = FALSE)
    }
    if (missing == "model") {
      stop("`missing = \"model\"` is implicit in Mplus; do not request it ",
           "through the frequentist front end.", call. = FALSE)
    }
    args <- c(list(data = data, vars = vars, id = id, day = day, beep = beep,
                   lags = lags, temporal = temporal,
                   contemporaneous = contemporaneous, nCores = nCores,
                   scale = scale, scaleWithin = scaleWithin,
                   min_obs = NULL, subject = NULL, verbose = verbose),
              engine_args)
    return(do.call(fit_mlvar_mplus, args))
  }

  if (engine == "reference") {
    if (identical(missing, "model")) {
      stop("`missing = \"model\"` is available only for `engine = \"bayes\"`.",
           call. = FALSE)
    }
    return(.mlvar_reference_engine(
      data = data, vars = vars, id = id, day = day, beep = beep, lags = lags,
      estimator = estimator, temporal = temporal,
      contemporaneous = contemporaneous, nCores = nCores, verbose = verbose,
      scale = scale, scaleWithin = scaleWithin, AR = AR,
      compare_to_lags = compare_to_lags, true_means = true_means,
      na_rm = na_rm, detrend = detrend, extra = engine_args
    ))
  }

  if (identical(missing, "model")) {
    stop("`missing = \"model\"` is available only for `engine = \"bayes\"`.",
         call. = FALSE)
  }
  if (length(engine_args)) {
    stop("Unused frequentist engine argument(s) in `...`: ",
         paste(names(engine_args) %||% rep("<unnamed>", length(engine_args)),
               collapse = ", "),
         ". Use explicit `fit_mlvar()` arguments or select an engine that ",
         "accepts these controls.", call. = FALSE)
  }
  if (verbose) message("Preparing and augmenting panel ...")
  prepared <- .mlvar_prepare_data(data, vars, id, day, beep, scale,
                                  full_detrend = identical(detrend, "position"))
  aug <- .mlvar_augment_data(
    prepared, vars, id, day, beep, lag = lags, scaleWithin = scaleWithin,
    compare_to_lags = compare_to_lags, true_means = true_means,
    # Structural lag rows are necessarily incomplete and are always removed;
    # `missing = "fail"` has already checked the user's observed values above.
    missing = "omit"
  )
  if (verbose) message("Fitting ", length(vars), " ", estimator, " models ...")
  Res <- if (identical(estimator, "lm") || identical(temporal, "unique")) {
    .mlvar_estimate_unique(aug$data, aug$predModel, vars, id, AR = AR,
                           contemporaneous = contemporaneous)
  } else {
    if (!requireNamespace("lme4", quietly = TRUE)) {
      stop(
        "This fit_mlvar() configuration requires the optional package 'lme4'. ",
        "Install it to use estimator = 'lmer', or use estimator = 'lm' for ",
        "the dependency-free native engine.",
        call. = FALSE
      )
    }
    .mlvar_estimate_lmer(
      aug$data, aug$predModel, vars, id, AR = AR, temporal = temporal,
      contemporaneous = contemporaneous, nCores = as.integer(nCores)
    )
  }

  # Wrap each of the three matrices as a full cograph_network netobject via
  # the package-wide `.ido_wrap()` constructor. Plotting is handled by
  # cograph's existing splot.netobject /
  # splot.cograph_network dispatch, which fires automatically because each
  # constituent here is a standard netobject.
  B_layers <- Res$temporal$B
  if (is.matrix(B_layers)) B_layers <- stats::setNames(list(B_layers),
                                                       paste0("lag", lags[1L]))
  temporal_nets <- lapply(seq_along(B_layers), function(k) {
    .ido_wrap(B_layers[[k]],
              method = if (length(B_layers) == 1L) "mlvar_temporal" else
                paste0("mlvar_temporal_", names(B_layers)[k]),
              directed = TRUE)
  })
  names(temporal_nets) <- if (length(B_layers) == 1L) "temporal" else
    paste0("temporal_", names(B_layers))
  contemporaneous_net <- .ido_wrap(Res$contemporaneous,
                                         method   = "mlvar_contemporaneous",
                                         directed = FALSE)
  between_net         <- .ido_wrap(Res$between,
                                         method   = "mlvar_between",
                                         directed = FALSE)

  nets <- c(temporal_nets, list(contemporaneous = contemporaneous_net,
                               between = between_net))

  # Model-level metadata lives in attributes so the list stays a pure
  # netobject_group (each element is a netobject). Use coefs(fit) to
  # retrieve the tidy coefs data.frame.
  attr(nets, "coefs")       <- Res$temporal$coefs
  attr(nets, "n_obs")       <- nrow(aug$data)
  attr(nets, "n_subjects")  <- length(unique(aug$data[[id]]))
  attr(nets, "lag")         <- lags
  attr(nets, "temporal_matrices") <- B_layers
  attr(nets, "temporal_subjects") <- Res$temporal$subjects %||% NULL
  attr(nets, "contemporaneous_subjects") <-
    Res$contemporaneous_subjects %||% NULL
  attr(nets, "standardize") <- scale
  attr(nets, "scale")       <- scale
  attr(nets, "scaleWithin") <- scaleWithin
  attr(nets, "AR")          <- AR
  attr(nets, "config") <- list(
    engine = "frequentist", estimator = estimator, temporal = temporal,
    contemporaneous = contemporaneous, lags = lags,
    compare_to_lags = compare_to_lags, standardize_mode = standardize_mode,
    true_means_supplied = !is.null(true_means),
    scale = scale, scaleWithin = scaleWithin, missing = missing,
    detrend = detrend, nCores = nCores
  )
  attr(nets, "group_col")   <- "network_type"

  class(nets) <- c("net_mlvar", "cograph_group", "netobject_group")
  nets
}

#' Run the current mlVAR implementation behind idiographic's tidy contract
#'
#' This backend is intentionally explicit (`engine = "reference"`): it is used
#' for reference-oracle work and for upstream-only modes while their native
#' equivalents are being validated. It never changes the default native path.
#' @noRd
.mlvar_reference_engine <- function(data, vars, id, day, beep, lags,
                                    estimator, temporal, contemporaneous,
                                    nCores, verbose, scale, scaleWithin, AR,
                                    compare_to_lags, true_means, na_rm, detrend,
                                    extra = list()) {
  if (!requireNamespace("mlVAR", quietly = TRUE)) {
    stop("Package 'mlVAR' is required for `engine = \"reference\"`.",
         call. = FALSE)
  }
  args <- list(
    data = data, vars = vars, idvar = id, lags = lags,
    estimator = estimator, temporal = temporal,
    contemporaneous = contemporaneous, nCores = nCores, verbose = verbose,
    scale = scale, scaleWithin = scaleWithin, AR = AR, na.rm = na_rm,
    full_detrend = identical(detrend, "position")
  )
  if (!is.null(day)) args$dayvar <- day
  if (!is.null(beep)) args$beepvar <- beep
  if (!is.null(compare_to_lags)) args$compareToLags <- compare_to_lags
  if (!is.null(true_means)) args$trueMeans <- true_means
  dup <- intersect(names(args), names(extra))
  if (length(dup)) {
    stop("Engine argument(s) supplied twice: ", paste(dup, collapse = ", "),
         call. = FALSE)
  }
  fit <- do.call(mlVAR::mlVAR, c(args, extra))
  .mlvar_reference_to_idiographic(fit, vars, lags, config = list(
    engine = "reference", estimator = estimator, temporal = temporal,
    contemporaneous = contemporaneous, scale = scale,
    scaleWithin = scaleWithin, AR = AR, id = id, day = day, beep = beep,
    compare_to_lags = compare_to_lags, detrend = detrend
  ))
}

#' Convert an mlVAR result to idiographic network layers
#' @noRd
.mlvar_reference_to_idiographic <- function(fit, vars, lags = 1L,
                                            config = list()) {
  if (!inherits(fit, "mlVAR")) {
    stop("Expected an object of class 'mlVAR'.", call. = FALSE)
  }
  p <- length(vars)
  pull_mean <- function(x, fallback = NULL) {
    if (!is.null(x) && !is.null(x$mean)) return(x$mean)
    if (!is.null(fallback)) return(fallback)
    matrix(0, p, p, dimnames = list(vars, vars))
  }
  beta <- pull_mean(fit$results$Beta)
  if (is.null(dim(beta))) beta <- matrix(beta, p, p)
  beta_layers <- if (length(dim(beta)) == 3L) {
    lapply(seq_len(dim(beta)[3L]), function(k) beta[, , k, drop = TRUE])
  } else {
    list(as.matrix(beta))
  }
  used_lags <- as.integer(lags)[seq_along(beta_layers)]
  beta_layers <- lapply(beta_layers, function(x) {
    x <- as.matrix(x); dimnames(x) <- list(vars, vars); x
  })
  names(beta_layers) <- paste0("lag", used_lags)

  theta <- as.matrix(pull_mean(fit$results$Theta$pcor))
  omega <- as.matrix(pull_mean(fit$results$Omega_mu$pcor))
  dimnames(theta) <- dimnames(omega) <- list(vars, vars)
  diag(theta) <- diag(omega) <- 0

  networks <- list()
  if (length(beta_layers) == 1L) {
    networks$temporal <- .ido_wrap(beta_layers[[1L]], "mlvar_temporal", TRUE)
  } else {
    for (k in seq_along(beta_layers)) {
      networks[[paste0("temporal_lag", used_lags[k])]] <-
        .ido_wrap(beta_layers[[k]], paste0("mlvar_temporal_lag", used_lags[k]),
                  TRUE)
    }
  }
  networks$contemporaneous <- .ido_wrap(theta, "mlvar_contemporaneous", FALSE)
  networks$between <- .ido_wrap(omega, "mlvar_between", FALSE)

  B <- fit$results$Beta
  rows <- do.call(rbind, lapply(seq_along(beta_layers), function(k) {
    grid <- expand.grid(outcome = vars, predictor = vars,
                        stringsAsFactors = FALSE)
    idx <- cbind(match(grid$outcome, vars), match(grid$predictor, vars))
    pull_cell <- function(slot) {
      a <- B[[slot]]
      if (is.null(a)) return(rep(NA_real_, nrow(grid)))
      if (length(dim(a)) == 3L) a <- a[, , k, drop = TRUE]
      as.numeric(a[idx])
    }
    data.frame(
      lag = used_lags[k], outcome = grid$outcome, predictor = grid$predictor,
      beta = as.numeric(beta_layers[[k]][idx]),
      se = pull_cell("SD"), t = NA_real_, p = pull_cell("P"),
      ci_lower = pull_cell("lower"), ci_upper = pull_cell("upper"),
      significant = {
        lo <- pull_cell("lower"); hi <- pull_cell("upper")
        !is.na(lo) & !is.na(hi) & (lo > 0 | hi < 0)
      }, stringsAsFactors = FALSE
    )
  }))
  if (length(beta_layers) == 1L) rows$lag <- NULL

  attr(networks, "coefs") <- rows
  attr(networks, "n_obs") <- fit$output$summaries$Observations %||%
    if (!is.null(fit$data)) nrow(fit$data) else NA_integer_
  attr(networks, "n_subjects") <- if (!is.null(fit$data) &&
                                        config$id %in% names(fit$data)) {
    length(unique(fit$data[[config$id]]))
  } else NA_integer_
  attr(networks, "lag") <- as.integer(lags)
  attr(networks, "temporal_matrices") <- beta_layers
  attr(networks, "standardize") <- config$scale
  attr(networks, "scale") <- config$scale
  attr(networks, "scaleWithin") <- config$scaleWithin
  attr(networks, "AR") <- config$AR
  attr(networks, "reference") <- fit
  attr(networks, "config") <- config
  attr(networks, "group_col") <- "network_type"
  class(networks) <- c("net_mlvar_reference", "net_mlvar", "cograph_group",
                       "netobject_group")
  networks
}

#' Tidy coefficients from a fitted mlvar model
#'
#' Generic accessor for the tidy coefficient table stored on a
#' [fit_mlvar()] result. Returns a `data.frame` with one row per
#' `(outcome, predictor)` pair and columns `outcome`, `predictor`,
#' `beta`, `se`, `t`, `p`, `ci_lower`, `ci_upper`, `significant`.
#'
#' Only the within-person (temporal) coefficients are tabulated —
#' these are the lagged fixed effects that populate `fit$temporal`.
#' The between-subjects effects that go into `fit$between` are handled
#' via the `D (I - Gamma)` transformation and are not exposed as a
#' separate tidy table.
#'
#' @param x A fitted model object — currently only `net_mlvar` is supported.
#' @param ... Unused.
#' @return A tidy `data.frame` of coefficient estimates.
#' @inherit fit_mlvar examples
#' @export
coefs <- function(x, ...) {
  UseMethod("coefs")
}

#' @rdname coefs
#' @export
coefs.net_mlvar <- function(x, ...) {
  attr(x, "coefs")
}

#' @rdname coefs
#' @export
coefs.default <- function(x, ...) {
  stop("No coefs() method for object of class '",
       class(x)[1], "'", call. = FALSE)
}

# ---- Internal helpers --------------------------------------------------

#' Safely pull named entries from a vector, NA for any missing name
#' @noRd
.mlvar_vec <- function(named, keys) {
  out <- rep(NA_real_, length(keys))
  hit <- match(keys, names(named))
  ok  <- !is.na(hit)
  out[ok] <- as.numeric(named[hit[ok]])
  out
}

#' Safely pull a column for named rows of a matrix, NA for any missing row
#'
#' `lme4` can drop a fixed effect in rank-deficient / collinear designs, leaving
#' its name out of `summary(fit)$coefficients`. Direct `mat[keys, col]` indexing
#' would then raise "subscript out of bounds"; this returns NA for the absent
#' rows so the coefficient table degrades gracefully.
#' @noRd
.mlvar_row <- function(mat, keys, col) {
  out <- rep(NA_real_, length(keys))
  hit <- match(keys, rownames(mat))
  ok  <- !is.na(hit)
  out[ok] <- as.numeric(mat[hit[ok], col])
  out
}

#' Drop rows with NA metadata and optionally grand-mean standardize
#' @noRd
.mlvar_prepare_data <- function(data, vars, id, day, beep, scale,
                                full_detrend = FALSE) {
  df <- as.data.frame(data)

  md_cols <- c(id,
               if (!is.null(day))  day,
               if (!is.null(beep)) beep)
  df <- df[stats::complete.cases(df[, md_cols, drop = FALSE]), , drop = FALSE]

  if (isTRUE(full_detrend)) {
    order_cols <- c(id, if (!is.null(day)) day, if (!is.null(beep)) beep)
    ord <- do.call(order, df[order_cols])
    inverse <- order(ord)
    ordered <- df[ord, , drop = FALSE]
    position <- stats::ave(seq_len(nrow(ordered)), ordered[[id]], FUN = seq_along)
    counts <- table(ordered[[id]])
    if (length(unique(as.integer(counts))) != 1L) {
      stop("`detrend = \"position\"` requires a balanced panel (the same ",
           "number of ordered observations per subject).", call. = FALSE)
    }
    for (v in vars) {
      ordered[[v]] <- stats::ave(ordered[[v]], position, FUN = function(x) {
        s <- stats::sd(x, na.rm = TRUE)
        if (!is.finite(s) || s == 0) x - mean(x, na.rm = TRUE) else
          (x - mean(x, na.rm = TRUE)) / s
      })
    }
    df <- ordered[inverse, , drop = FALSE]
  }

  if (isTRUE(scale)) {
    for (v in vars) {
      x <- as.numeric(df[[v]])
      sd_val <- stats::sd(x, na.rm = TRUE)
      if (is.na(sd_val) || sd_val == 0) {
        df[[v]] <- 0
      } else {
        df[[v]] <- (x - mean(x, na.rm = TRUE)) / sd_val
      }
    }
  }
  df
}

#' Beep-grid augmentation + within/between predictor construction
#'
#' Base-R implementation: build the full per-(id, day) consecutive-beep grid,
#' place the observed rows onto it with a `match()`-based join (NA elsewhere),
#' and order the augmented panel by (id, day, beep). The join copies each column
#' by position (`df[[v]][match]`), so integer inputs keep integer type and NA
#' fills stay `NA_integer_` -- important because base R's `mean()` uses two-pass
#' summation for doubles but a plain sum/n for integers, and that ~1e-14
#' difference otherwise amplifies through lmer into ~1e-10 coefficient diffs
#' against `mlVAR`. The within-group lag/centre/mean arithmetic then uses base
#' `ave()` for the same reason.
#' @noRd
.mlvar_augment_data <- function(data, vars, id, day, beep, lag,
                                scaleWithin = FALSE,
                                compare_to_lags = NULL,
                                true_means = NULL,
                                missing = c("omit", "fail")) {
  missing <- match.arg(missing)
  id_col   <- id
  day_col  <- if (is.null(day))  ".day"  else day
  beep_col <- if (is.null(beep)) ".beep" else beep

  df <- as.data.frame(data)
  if (is.null(day)) df[[day_col]] <- 1L
  if (is.null(beep)) {
    df[[beep_col]] <- stats::ave(seq_len(nrow(df)), df[[id_col]], df[[day_col]],
                                 FUN = seq_along)
  }

  idv <- df[[id_col]]; dayv <- df[[day_col]]; beepv <- df[[beep_col]]

  # Per-(id, day) beep range; the augmented grid is first:last (consecutive
  # integers), matching mlVAR's global seq() restricted to each block's range.
  gkey <- paste(idv, dayv, sep = "\r")
  first <- tapply(beepv, gkey, min, na.rm = TRUE)
  last  <- tapply(beepv, gkey, max, na.rm = TRUE)
  ud <- unique(data.frame(id = idv, day = dayv, stringsAsFactors = FALSE))
  udk <- paste(ud$id, ud$day, sep = "\r")
  grid <- do.call(rbind, lapply(seq_len(nrow(ud)), function(k) {
    b <- seq.int(first[[udk[k]]], last[[udk[k]]])
    data.frame(a = ud$id[k], b = ud$day[k], c = b, stringsAsFactors = FALSE)
  }))
  names(grid) <- c(id_col, day_col, beep_col)
  grid <- grid[order(grid[[id_col]], grid[[day_col]], grid[[beep_col]]), ,
               drop = FALSE]

  # Place observed values onto the grid by (id, day, beep), preserving types.
  m <- match(paste(grid[[id_col]], grid[[day_col]], grid[[beep_col]], sep = "\r"),
             paste(idv, dayv, beepv, sep = "\r"))
  augData <- grid
  for (col in setdiff(names(df), c(id_col, day_col, beep_col))) {
    augData[[col]] <- df[[col]][m]
  }
  rownames(augData) <- NULL

  true_match <- NULL
  if (!is.null(true_means)) {
    if (!is.data.frame(true_means) || !all(c(id, vars) %in% names(true_means))) {
      stop("`true_means` must be a data frame containing `id` and every ",
           "model variable.", call. = FALSE)
    }
    if (anyDuplicated(true_means[[id]])) {
      stop("`true_means` must have exactly one row per subject.", call. = FALSE)
    }
    if (any(!vapply(true_means[vars], is.numeric, logical(1)))) {
      stop("Every model-variable column in `true_means` must be numeric.",
           call. = FALSE)
    }
    true_match <- match(as.character(augData[[id_col]]),
                        as.character(true_means[[id]]))
    if (anyNA(true_match)) {
      stop("`true_means` is missing one or more fitted subjects.", call. = FALSE)
    }
  }

  predModel <- list()

  # Within-person centering of the lagged predictors. With scaleWithin the
  # centering also divides by the within-person SD (mlVAR's aveCenter(scale=TRUE)).
  center_fun <- if (isTRUE(scaleWithin)) {
    function(x) (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)
  } else {
    function(x) x - mean(x, na.rm = TRUE)
  }

  # Within (lagged, person-centered) predictors. Extra compare-to lags are
  # constructed and included in complete-row filtering, but are not fitted.
  fit_lags <- sort(unique(as.integer(lag)))
  all_lags <- sort(unique(c(fit_lags, as.integer(compare_to_lags))))
  compare_ids <- character()
  for (lag_i in all_lags) {
    for (v in vars) {
      p_id <- paste0("L", lag_i, "_", v)
      augData[[p_id]] <- stats::ave(
        augData[[v]], augData[[id_col]], augData[[day_col]],
        FUN = function(x) .mlvar_aveLag(x, lag_i)
      )
      if (is.null(true_means)) {
        augData[[p_id]] <- stats::ave(
          augData[[p_id]], augData[[id_col]], FUN = center_fun
        )
      } else {
        # mlVAR's trueMeans branch subtracts the supplied person mean rather
        # than the observed lag mean. If within scaling is requested it then
        # applies aveScaleNoCenter, preserving the centered series' own mean.
        augData[[p_id]] <- augData[[p_id]] - true_means[[v]][true_match]
        if (isTRUE(scaleWithin)) {
          augData[[p_id]] <- stats::ave(
            augData[[p_id]], augData[[id_col]], FUN = function(x) {
              m <- mean(x, na.rm = TRUE)
              (x - m) / stats::sd(x, na.rm = TRUE) + m
            }
          )
        }
      }
      if (lag_i %in% fit_lags) {
        predModel[[length(predModel) + 1L]] <- list(
          dep = vars, pred = v, id = p_id, type = "within", lag = lag_i
        )
      } else {
        compare_ids <- c(compare_ids, p_id)
      }
    }
  }

  # Between (person-mean) predictors
  for (v in vars) {
    p_id <- paste0("PM_", v)
    if (is.null(true_means)) {
      augData[[p_id]] <- stats::ave(
        augData[[v]], augData[[id_col]],
        FUN = function(x) mean(x, na.rm = TRUE)
      )
    } else {
      augData[[p_id]] <- true_means[[v]][true_match]
    }
    predModel[[length(predModel) + 1L]] <- list(
      dep = vars, pred = v, id = p_id, type = "between", lag = NA_integer_
    )
  }

  # With scaleWithin, the outcome variables are within-person scaled around the
  # person mean (mlVAR's aveScaleNoCenter: center, /SD, then re-add the mean).
  if (isTRUE(scaleWithin)) {
    for (v in vars) {
      augData[[v]] <- stats::ave(
        augData[[v]], augData[[id_col]],
        FUN = function(x) {
          m <- mean(x, na.rm = TRUE)
          (x - m) / stats::sd(x, na.rm = TRUE) + m
        }
      )
    }
  }

  involved <- unique(c(vars, vapply(predModel, `[[`, character(1), "id"),
                       compare_ids))
  augData <- augData[, c(involved, id_col, day_col, beep_col), drop = FALSE]
  incomplete <- !stats::complete.cases(augData[, involved, drop = FALSE])
  if (any(incomplete) && identical(missing, "fail")) {
    stop(sum(incomplete), " incomplete model row(s) found with ",
         "`missing = \"fail\"`.", call. = FALSE)
  }
  if (any(incomplete)) augData <- augData[!incomplete, , drop = FALSE]
  rownames(augData) <- NULL

  list(data = augData, predModel = predModel)
}

#' Fit d outcome-specific lmer models and assemble the three networks
#'
#' Matches `mlVAR:::lmer_mlVAR` with `temporal = "fixed"`,
#' `contemporaneous = "fixed"`. For each outcome k fits
#' `outcome_k ~ L1_v1 + ... + L1_vd + PM_v_{-k} + (1 | id)` with
#' `REML = FALSE`, then assembles Beta, Gamma, mu_SD, residuals.
#' @noRd
.mlvar_estimate_lmer <- function(augData, predModel, vars, id, AR = FALSE,
                                 temporal = c("fixed", "correlated",
                                              "orthogonal"),
                                 contemporaneous = c("fixed", "correlated",
                                                     "orthogonal", "unique"),
                                 nCores = 1L) {
  temporal <- match.arg(temporal)
  contemporaneous <- match.arg(contemporaneous)
  d <- length(vars)
  n_obs <- nrow(augData)

  within_model <- Filter(function(m) m$type == "within", predModel)
  between_model <- Filter(function(m) m$type == "between", predModel)
  lags <- sort(unique(vapply(within_model, `[[`, integer(1), "lag")))
  B_layers <- stats::setNames(lapply(lags, function(z) {
    matrix(0, d, d, dimnames = list(vars, vars))
  }), paste0("lag", lags))
  Gamma         <- matrix(0, d, d, dimnames = list(vars, vars))
  mu_SD         <- stats::setNames(numeric(d), vars)
  sigma_vec     <- stats::setNames(numeric(d), vars)
  residuals_mat <- matrix(NA_real_, n_obs, d, dimnames = list(NULL, vars))

  within_ids <- vapply(within_model, `[[`, character(1), "id")
  within_vars <- vapply(within_model, `[[`, character(1), "pred")
  within_lags <- vapply(within_model, `[[`, integer(1), "lag")
  between_ids <- vapply(between_model, `[[`, character(1), "id")
  between_vars <- vapply(between_model, `[[`, character(1), "pred")
  var_to_between <- stats::setNames(between_ids, vars)

  z975 <- stats::qnorm(0.975)

  # Tidy coefs: one row per (outcome, predictor) pair — fills d * d rows.
  # Faster and cleaner than growing a list of per-outcome data.frames and
  # `do.call(rbind, ...)` at the end.
  n_coef_rows <- d * d * length(lags)
  coefs_tidy <- data.frame(
    lag         = rep(lags, each = d * d),
    outcome     = rep(rep(vars, each = d), times = length(lags)),
    predictor   = rep(vars, times = d * length(lags)),
    beta        = numeric(n_coef_rows),
    se          = numeric(n_coef_rows),
    t           = numeric(n_coef_rows),
    p           = numeric(n_coef_rows),
    ci_lower    = numeric(n_coef_rows),
    ci_upper    = numeric(n_coef_rows),
    significant = logical(n_coef_rows),
    stringsAsFactors = FALSE
  )

  fitted_models <- vector("list", d)
  names(fitted_models) <- vars

  specs <- lapply(seq_len(d), function(k) {
    outcome <- vars[k]
    within_preds <- if (isTRUE(AR)) {
      within_ids[within_vars == outcome]
    } else within_ids
    fixed_preds <- c(within_preds, var_to_between[-k])
    random_term <- if (temporal == "fixed") {
      paste0("(1 | ", id, ")")
    } else {
      paste0("(", paste(within_preds, collapse = " + "), " ",
             if (temporal == "orthogonal") "||" else "|", " ", id, ")")
    }
    list(
      outcome = outcome,
      within_preds = within_preds,
      between_keys = var_to_between[vars[-k]],
      formula = stats::as.formula(paste0(
        outcome, " ~ ", paste(fixed_preds, collapse = " + "), " + ",
        random_term
      ))
    )
  })
  fit_one <- function(k) {
    suppressMessages(suppressWarnings(
      lme4::lmer(specs[[k]]$formula, data = augData, REML = FALSE)
    ))
  }
  if (nCores > 1L && d > 1L) {
    workers <- min(as.integer(nCores), d)
    if (.Platform$OS.type == "windows") {
      cl <- parallel::makePSOCKcluster(workers)
      on.exit(parallel::stopCluster(cl), add = TRUE)
      parallel::clusterEvalQ(cl, library(lme4))
      fitted_models <- parallel::parLapply(cl, seq_len(d), fit_one)
    } else {
      fitted_models <- parallel::mclapply(seq_len(d), fit_one,
                                          mc.cores = workers,
                                          mc.preschedule = TRUE)
    }
    names(fitted_models) <- vars
  } else {
    fitted_models <- lapply(seq_len(d), fit_one)
    names(fitted_models) <- vars
  }

  for (k in seq_len(d)) {
    outcome <- specs[[k]]$outcome
    # AR = TRUE: each outcome regresses on its OWN lag only (mlVAR AR = TRUE
    # gives a diagonal temporal matrix); otherwise on all lagged predictors.
    # Own PM excluded — matches mlVAR's `getModel` filter on `dep == outcome`.
    within_preds <- specs[[k]]$within_preds
    fit <- fitted_models[[k]]

    # Convergence diagnostics — warn but don't stop (matches mlVAR behaviour)
    if (lme4::isSingular(fit)) {
      warning(sprintf(
        "Model for '%s': singular fit (random-effects variance near zero).",
        outcome
      ), call. = FALSE)
    }
    conv_msgs <- fit@optinfo$conv$lme4$messages
    if (length(conv_msgs) > 0L) {
      warning(sprintf(
        "Model for '%s': %s", outcome, paste(conv_msgs, collapse = "; ")
      ), call. = FALSE)
    }

    fe <- lme4::fixef(fit)
    # Defensive name matching: a rank-deficient lmer fit can silently drop a
    # predictor, so pull by name and warn rather than mis-align or error.
    within_keys <- within_ids
    between_keys <- specs[[k]]$between_keys
    dropped <- setdiff(c(within_preds, between_keys), names(fe))  # vs fitted set
    if (length(dropped) > 0L) {
      warning(sprintf(
        "Model for '%s' dropped predictor(s) %s (rank-deficient design); ",
        outcome, paste(dropped, collapse = ", ")),
        "filling the affected coefficients with NA.", call. = FALSE)
    }
    B_row <- .mlvar_vec(fe, within_keys)
    if (isTRUE(AR)) B_row[within_vars != outcome] <- 0
    for (ell in seq_along(lags)) {
      take <- within_lags == lags[ell]
      B_layers[[ell]][k, ] <- B_row[take]
    }
    Gamma[k, -k]  <- .mlvar_vec(fe, between_keys)

    vc <- lme4::VarCorr(fit)
    ri_var <- as.numeric(vc[[id]][1, 1])
    mu_SD[k] <- if (!is.na(ri_var) && ri_var > 0) sqrt(ri_var) else 0

    sigma_vec[k] <- stats::sigma(fit)

    # Align residuals to augData row order (lmer drops any NA rows)
    res <- stats::residuals(fit)
    row_names <- rownames(augData)
    if (!is.null(row_names) && !is.null(names(res))) {
      residuals_mat[, k] <- res[match(row_names, names(res))]
    } else {
      residuals_mat[, k] <- res
    }

    sfe    <- summary(fit)$coefficients
    beta_k <- B_row                               # AR off-diagonals already 0
    se_k   <- .mlvar_row(sfe, within_keys, "Std. Error")
    t_k    <- .mlvar_row(sfe, within_keys, "t value")
    p_k    <- 2 * (1 - stats::pnorm(abs(t_k)))

    for (ell in seq_along(lags)) {
      take <- which(within_lags == lags[ell])
      rows <- (ell - 1L) * d * d + ((k - 1L) * d + seq_len(d))
      coefs_tidy$beta[rows]        <- beta_k[take]
      coefs_tidy$se[rows]          <- se_k[take]
      coefs_tidy$t[rows]           <- t_k[take]
      coefs_tidy$p[rows]           <- p_k[take]
      coefs_tidy$ci_lower[rows]    <- beta_k[take] - z975 * se_k[take]
      coefs_tidy$ci_upper[rows]    <- beta_k[take] + z975 * se_k[take]
      coefs_tidy$significant[rows] <- !is.na(p_k[take]) & p_k[take] < 0.05
    }
  }

  subject_temporal <- NULL
  if (temporal != "fixed") {
    subject_ids <- rownames(lme4::ranef(fitted_models[[1L]])[[id]])
    subject_temporal <- stats::setNames(vector("list", length(subject_ids)),
                                        subject_ids)
    ran <- lapply(fitted_models, function(fit) lme4::ranef(fit)[[id]])
    for (s in seq_along(subject_ids)) {
      layers <- lapply(seq_along(lags), function(ell) {
        mat <- B_layers[[ell]]
        take <- within_lags == lags[ell]
        keys <- within_ids[take]
        for (k in seq_len(d)) {
          vals <- .mlvar_vec(unlist(ran[[k]][s, , drop = TRUE]), keys)
          vals[is.na(vals)] <- 0
          mat[k, ] <- mat[k, ] + vals
        }
        mat
      })
      names(layers) <- names(B_layers)
      subject_temporal[[s]] <- if (length(layers) == 1L) layers[[1L]] else layers
    }
  }

  theta <- .mlvar_estimate_contemporaneous(
    residuals_mat, augData[[id]], vars, sigma_vec, contemporaneous, id
  )
  between         <- .mlvar_compute_between_from_gamma(Gamma, mu_SD, vars)

  if (length(lags) == 1L) {
    B_out <- B_layers[[1L]]
    coefs_tidy$lag <- NULL
  } else B_out <- B_layers
  list(temporal = list(B = B_out, coefs = coefs_tidy,
                       residuals = residuals_mat, subjects = subject_temporal),
       contemporaneous = theta$group,
       contemporaneous_subjects = theta$subjects,
       between = between,
       models = fitted_models)
}

#' Separate person-specific least-squares mlVAR models
#' @noRd
.mlvar_estimate_unique <- function(augData, predModel, vars, id, AR = FALSE,
                                   contemporaneous = c("fixed", "unique",
                                                       "correlated",
                                                       "orthogonal")) {
  contemporaneous <- match.arg(contemporaneous)
  within_model <- Filter(function(m) m$type == "within", predModel)
  within_ids <- vapply(within_model, `[[`, character(1), "id")
  within_vars <- vapply(within_model, `[[`, character(1), "pred")
  within_lags <- vapply(within_model, `[[`, integer(1), "lag")
  lags <- sort(unique(within_lags))
  d <- length(vars)
  ids <- unique(augData[[id]])
  subject_layers <- stats::setNames(vector("list", length(ids)),
                                    as.character(ids))
  subject_intercepts <- matrix(NA_real_, length(ids), d,
                               dimnames = list(as.character(ids), vars))
  residuals_mat <- matrix(NA_real_, nrow(augData), d,
                          dimnames = list(NULL, vars))
  subject_betas <- array(NA_real_, c(length(ids), d, d, length(lags)),
                         dimnames = list(as.character(ids), vars, vars,
                                         paste0("lag", lags)))

  for (s in seq_along(ids)) {
    rows <- which(augData[[id]] == ids[s])
    dat <- augData[rows, , drop = FALSE]
    layers <- stats::setNames(lapply(lags, function(z) {
      matrix(0, d, d, dimnames = list(vars, vars))
    }), paste0("lag", lags))
    for (k in seq_len(d)) {
      keep <- if (isTRUE(AR)) within_vars == vars[k] else rep(TRUE, length(within_ids))
      form <- stats::reformulate(within_ids[keep], response = vars[k])
      fit <- stats::lm(form, data = dat)
      cf <- stats::coef(fit)
      subject_intercepts[s, k] <- unname(cf["(Intercept)"])
      residuals_mat[rows, k] <- stats::residuals(fit)
      for (ell in seq_along(lags)) {
        take <- within_lags == lags[ell]
        vals <- .mlvar_vec(cf, within_ids[take])
        if (isTRUE(AR)) vals[within_vars[take] != vars[k]] <- 0
        layers[[ell]][k, ] <- vals
        subject_betas[s, k, , ell] <- vals
      }
    }
    subject_layers[[s]] <- if (length(layers) == 1L) layers[[1L]] else layers
  }

  B_layers <- lapply(seq_along(lags), function(ell) {
    apply(subject_betas[, , , ell, drop = FALSE], c(2, 3), mean, na.rm = TRUE)
  })
  names(B_layers) <- paste0("lag", lags)
  B_layers <- lapply(B_layers, function(x) {
    dimnames(x) <- list(vars, vars); x
  })

  rows <- vector("list", length(lags))
  z975 <- stats::qnorm(.975)
  for (ell in seq_along(lags)) {
    grid <- expand.grid(outcome = vars, predictor = vars,
                        stringsAsFactors = FALSE)
    idx <- cbind(match(grid$outcome, vars), match(grid$predictor, vars))
    se <- apply(subject_betas[, , , ell, drop = FALSE], c(2, 3),
                stats::sd, na.rm = TRUE) / sqrt(length(ids))
    beta <- B_layers[[ell]]
    tval <- beta / se
    pval <- 2 * (1 - stats::pnorm(abs(tval)))
    rows[[ell]] <- data.frame(
      lag = lags[ell], outcome = grid$outcome, predictor = grid$predictor,
      beta = beta[idx], se = se[idx], t = tval[idx], p = pval[idx],
      ci_lower = beta[idx] - z975 * se[idx],
      ci_upper = beta[idx] + z975 * se[idx],
      significant = !is.na(pval[idx]) & pval[idx] < .05,
      stringsAsFactors = FALSE
    )
  }
  coefs_tidy <- do.call(rbind, rows)
  rownames(coefs_tidy) <- NULL
  if (length(lags) == 1L) coefs_tidy$lag <- NULL

  mean_cov <- stats::cov(subject_intercepts, use = "pairwise.complete.obs")
  between <- if (anyNA(mean_cov)) {
    warning("Between-subjects network is not estimable; returning zeros.",
            call. = FALSE)
    matrix(0, d, d, dimnames = list(vars, vars))
  } else {
    ans <- .ido_cor2pcor(.mlvar_force_positive(mean_cov))
    diag(ans) <- 0; dimnames(ans) <- list(vars, vars); ans
  }
  sigma_vec <- apply(residuals_mat, 2L, stats::sd, na.rm = TRUE)
  theta <- .mlvar_estimate_contemporaneous(
    residuals_mat, augData[[id]], vars, sigma_vec, contemporaneous, id
  )
  list(temporal = list(B = if (length(lags) == 1L) B_layers[[1L]] else B_layers,
                       coefs = coefs_tidy, residuals = residuals_mat,
                       subjects = subject_layers),
       contemporaneous = theta$group,
       contemporaneous_subjects = theta$subjects,
       between = between)
}

#' Group and person-specific contemporaneous networks
#' @noRd
.mlvar_estimate_contemporaneous <- function(residuals_mat, subject, vars,
                                             sigma_vec, structure, id_name) {
  if (structure == "fixed") {
    return(list(group = .mlvar_contemporaneous_fixed(residuals_mat, sigma_vec,
                                                     vars), subjects = NULL))
  }
  ids <- unique(subject)
  if (structure == "unique") {
    covs <- lapply(ids, function(z) {
      x <- residuals_mat[subject == z, , drop = FALSE]
      stats::cov(x, use = "pairwise.complete.obs")
    })
    valid <- vapply(covs, function(x) is.matrix(x) && !anyNA(x), logical(1))
    group_cov <- if (any(valid)) Reduce(`+`, covs[valid]) / sum(valid) else
      matrix(NA_real_, length(vars), length(vars))
    group <- if (anyNA(group_cov)) {
      matrix(0, length(vars), length(vars), dimnames = list(vars, vars))
    } else {
      ans <- .ido_cor2pcor(.mlvar_force_positive(group_cov))
      diag(ans) <- 0; dimnames(ans) <- list(vars, vars); ans
    }
    subjects <- stats::setNames(lapply(covs, function(x) {
      if (anyNA(x)) return(matrix(NA_real_, length(vars), length(vars),
                                  dimnames = list(vars, vars)))
      ans <- .ido_cor2pcor(.mlvar_force_positive(x)); diag(ans) <- 0
      dimnames(ans) <- list(vars, vars); ans
    }), as.character(ids))
    return(list(group = group, subjects = subjects))
  }

  resid_df <- as.data.frame(residuals_mat)
  resid_df[[id_name]] <- subject
  d <- length(vars)
  gamma <- matrix(0, d, d, dimnames = list(vars, vars))
  fits <- vector("list", d)
  for (k in seq_len(d)) {
    others <- vars[-k]
    random <- paste0("(0 + ", paste(others, collapse = " + "), " ",
                     if (structure == "orthogonal") "||" else "|", " ",
                     id_name, ")")
    form <- stats::as.formula(paste(vars[k], "~ 0 +",
                                    paste(others, collapse = " + "), "+",
                                    random))
    fits[[k]] <- suppressMessages(suppressWarnings(
      lme4::lmer(form, data = resid_df, REML = FALSE)
    ))
    gamma[k, -k] <- .mlvar_vec(lme4::fixef(fits[[k]]), others)
  }
  D <- diag(1 / vapply(fits, function(x) stats::sigma(x)^2, numeric(1)))
  precision <- .mlvar_force_positive(D %*% (diag(d) - gamma))
  group <- .ido_cor2pcor(.ido_pseudoinverse(precision))
  diag(group) <- 0; dimnames(group) <- list(vars, vars)
  ran <- lapply(fits, function(x) lme4::ranef(x)[[id_name]])
  subject_ids <- rownames(ran[[1L]])
  subjects <- stats::setNames(lapply(seq_along(subject_ids), function(s) {
    gs <- gamma
    for (k in seq_len(d)) {
      vals <- .mlvar_vec(unlist(ran[[k]][s, , drop = TRUE]), vars[-k])
      vals[is.na(vals)] <- 0
      gs[k, -k] <- gs[k, -k] + vals
    }
    prec <- .mlvar_force_positive(D %*% (diag(d) - gs))
    ans <- .ido_cor2pcor(.ido_pseudoinverse(prec)); diag(ans) <- 0
    dimnames(ans) <- list(vars, vars); ans
  }), subject_ids)
  list(group = group, subjects = subjects)
}

#' Within-group lag (matches mlVAR:::aveLag)
#'
#' Uses a logical `NA` (not `NA_real_`) for the prepended entries so that
#' integer input columns retain integer type. Preserving the integer type
#' is critical because base R's `mean()` uses a two-pass summation
#' correction for numeric input but a simple sum/n for integer input — the
#' two paths drift by ~1.4e-14, which then amplifies through lmer into
#' ~1e-10 coefficient diffs against mlVAR's integer-typed pipeline.
#' @noRd
.mlvar_aveLag <- function(x, lag = 1L) {
  n <- length(x)
  if (lag >= n) return(rep(NA, n))
  c(rep(NA, lag), x[seq_len(n - lag)])
}

#' Force a symmetric matrix to be positive-definite — byte-for-byte replica
#' of `mlVAR:::forcePositive`.
#'
#' Note the scalar-recycling quirk in the upstream implementation. In
#' `x - (diag(n) * min_ev - 0.001)`, the `0.001` scalar is subtracted from
#' every element of the diagonal matrix — so the final operation adds
#' `|min_ev|` to the diagonal *and* `+0.001` to every off-diagonal element.
#' This looks unintentional upstream but has to be replicated exactly for
#' equivalence with `mlVAR::mlVAR()`.
#' @noRd
.mlvar_force_positive <- function(x) {
  x <- (x + t(x)) / 2
  ev <- eigen(x, symmetric = TRUE, only.values = TRUE)$values
  if (any(ev < 0)) {
    x - (diag(nrow(x)) * min(ev) - 0.001)
  } else {
    x
  }
}

#' Between-subjects partial correlation from Gamma + mu_SD
#'
#' Matches mlVAR's Omega_mu branch:
#'   `D = diag(1 / mu_SD^2)`
#'   `inv = forcePositive(D (I - Gamma))`
#'   `cov = .ido_pseudoinverse(inv)`
#'   `pcor = .ido_cor2pcor(cov)`
#' @noRd
.mlvar_compute_between_from_gamma <- function(Gamma, mu_SD, vars) {
  d <- length(vars)
  if (any(mu_SD == 0)) {
    warning("Between-subjects network not estimable: a random-intercept SD is ",
            "0 (no between-person variance). Returning a zero matrix by ",
            "convention (mlVAR returns NA here).", call. = FALSE)
    return(matrix(0, d, d, dimnames = list(vars, vars)))
  }

  D <- diag(1 / mu_SD^2)
  inv <- D %*% (diag(d) - Gamma)
  inv <- (inv + t(inv)) / 2
  inv <- .mlvar_force_positive(inv)

  mu_cov <- .ido_pseudoinverse(inv)
  pcor <- .ido_cor2pcor(mu_cov)
  diag(pcor) <- 0
  rownames(pcor) <- colnames(pcor) <- vars
  pcor
}

#' Contemporaneous partial correlation via mlVAR's "fixed" path
#'
#' Replicates `mlVAR:::lmer_mlVAR` Theta assembly for
#' `contemporaneous = "fixed"`: rescale the residual correlation by the
#' per-outcome lmer residual SDs and take `cor2pcor` directly. No
#' EBIC-GLASSO regularization. Note `cor2pcor` is scale-invariant, so the
#' `D %*% . %*% D` rescaling does not affect the pcor output — it is kept
#' only for parity with mlVAR's `cov`/`prec` slots.
#' @noRd
.mlvar_contemporaneous_fixed <- function(residuals_mat, sigma_vec, vars) {
  d <- length(vars)
  R <- stats::cor(residuals_mat, use = "pairwise.complete.obs")
  if (any(is.na(R))) {
    warning("Contemporaneous network not estimable: residual correlations ",
            "contain NA. Returning a zero matrix by convention.",
            call. = FALSE)
    return(matrix(0, d, d, dimnames = list(vars, vars)))
  }
  D <- diag(sigma_vec)
  Theta_cov <- D %*% stats::cov2cor(R) %*% D
  pcor <- .ido_cor2pcor(Theta_cov)
  diag(pcor) <- 0
  rownames(pcor) <- colnames(pcor) <- vars
  pcor
}


# ---- S3 methods --------------------------------------------------------

#' Print method for net_mlvar
#'
#' @param x A `net_mlvar` object returned by [fit_mlvar()].
#' @param digits Number of digits used for printed network matrices.
#' @param ... Unused; present for S3 consistency.
#' @return Invisibly returns `x`.
#' @inherit fit_mlvar examples
#' @export
print.net_mlvar <- function(x, digits = 2, ...) {
  coef_df <- attr(x, "coefs")
  temporal_name <- grep("^temporal($|_)", names(x), value = TRUE)[1L]
  d <- nrow(x[[temporal_name]]$weights)
  n_sig <- sum(coef_df$significant, na.rm = TRUE)
  n_tot <- nrow(coef_df)

  cat(sprintf("mlVAR result: %d subjects, %d observations, %d variables (lags %s)\n",
              attr(x, "n_subjects"),
              attr(x, "n_obs"),
              d,
              paste(attr(x, "lag"), collapse = ", ")))
  cat(sprintf("  Temporal edges significant at p<0.05: %d / %d\n", n_sig, n_tot))
  .ido_print_networks(x, digits = digits)
  cat("\n  plot(x) | plot(x, layer = \"temporal\") | plot(x, layer = \"between\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' Summary method for net_mlvar
#'
#' @param object A `net_mlvar` object returned by [fit_mlvar()].
#' @param ... Unused; present for S3 consistency.
#' @return A tidy `data.frame` of per-network metrics (one row per network:
#'   `temporal`, `contemporaneous`, `between`). Use `coefs(object)` for the
#'   fixed-effect coefficient table, `edges(object)` for the edge list, and
#'   `nodes(object)` for node strengths.
#' @inherit fit_mlvar examples
#' @export
summary.net_mlvar <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
