# ---- Multilevel Vector Autoregression (mlVAR) ----

#' Build a Multilevel Vector Autoregression (mlVAR) network
#'
#' @description Estimates three networks from ESM/EMA panel data, matching
#'   `mlVAR::mlVAR()` with `estimator = "lmer"`, `temporal = "fixed"`,
#'   `contemporaneous = "fixed"` at machine precision: (1) a directed
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
#' Validated to machine precision (max_diff < 1e-10) against
#' `mlVAR::mlVAR()` on 25 real ESM datasets from `openesm` and 20 simulated
#' configurations (seeds 201-220). See `tmp/mlvar_equivalence_real20.R` and
#' `tmp/mlvar_equivalence_20seeds.R`.
#'
#' @param data A `data.frame` containing the panel data.
#' @param vars Character vector of variable column names to model.
#' @param id Character string naming the person-ID column.
#' @param day Character string naming the day/session column, or `NULL`.
#'   When provided, lag pairs are only formed within the same day.
#' @param beep Character string naming the measurement-occasion column, or
#'   `NULL`. When `NULL`, row position within each (id, day) is used.
#' @param lags Integer. Lag order; only `1` is supported (mlVAR's `lags`).
#' @param estimator Character. Only `"lmer"` / `"default"` are implemented;
#'   `"lm"` / `"Mplus"` raise an error (use `mlVAR::mlVAR()`).
#' @param temporal,contemporaneous Character. Only `"fixed"` is implemented
#'   (idiographic is a clean-room of mlVAR's fixed-effects path). The random-effects
#'   modes (`"correlated"`, `"orthogonal"`, `"unique"`) raise an error pointing
#'   to `mlVAR::mlVAR()`.
#' @param AR Logical. If `TRUE`, estimate only autoregressive (own-lag) temporal
#'   effects, giving a diagonal temporal matrix (matches `mlVAR(AR = TRUE)`).
#'   Default `FALSE`.
#' @param scale Logical. If `TRUE`, each variable is grand-mean centered and
#'   divided by its pooled SD before augmentation (mlVAR's `scale`). Default
#'   `FALSE`. (The deprecated `standardize` is an alias.)
#' @param scaleWithin Logical. If `TRUE`, additionally scale within person
#'   (mlVAR's `scaleWithin`). Default `FALSE`.
#' @param nCores Integer. Accepted for API parity; estimation is single-threaded
#'   (a message is emitted if `nCores > 1`).
#' @param verbose Logical. Emit progress messages. Default `FALSE`.
#' @param lag Deprecated alias for `lags`.
#' @param standardize Deprecated alias for `scale`.
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
#' fit <- build_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
#' print(fit)
#' summary(fit)
#' }
#'
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations (counts taken from `data`).
#' @param subject Optional vector naming the exact subject(s) to analyse.
#' @seealso [build_gimme()], [graphical_var()], [as_netobject()]
#' @export
build_mlvar <- function(data, vars, id,
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
                        subject = NULL) {
  data <- .ido_keep(data, id, min_obs, subject)

  estimator       <- match.arg(estimator)
  temporal        <- match.arg(temporal)
  contemporaneous <- match.arg(contemporaneous)

  # idiographic implements mlVAR's fixed-effects path only (estimator = "lmer",
  # temporal/contemporaneous = "fixed"); the random-effects modes are a
  # different multilevel estimator and are out of scope.
  if (!estimator %in% c("lmer", "default")) {
    stop("build_mlvar() implements the 'lmer' estimator only; for '", estimator,
         "' use mlVAR::mlVAR().", call. = FALSE)
  }
  if (!temporal %in% c("fixed", "default")) {
    stop("build_mlvar() implements temporal = \"fixed\" only; for '", temporal,
         "' (random temporal effects) use mlVAR::mlVAR().", call. = FALSE)
  }
  if (!contemporaneous %in% c("fixed", "default")) {
    stop("build_mlvar() implements contemporaneous = \"fixed\" only; for '",
         contemporaneous, "' use mlVAR::mlVAR().", call. = FALSE)
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

  # ---- Input validation ----
  stopifnot(
    is.data.frame(data),
    is.character(vars), length(vars) >= 2L,
    is.character(id), length(id) == 1L,
    is.numeric(lags), length(lags) == 1L
  )
  .ido_check_flag(AR, "AR")
  .ido_check_flag(scale, "scale")
  .ido_check_flag(scaleWithin, "scaleWithin")
  .ido_check_flag(verbose, "verbose")
  stopifnot(is.numeric(nCores), length(nCores) == 1L, nCores >= 1L)
  if (!(length(lags) == 1L && lags == 1L)) {
    stop("build_mlvar() supports lags = 1 only.", call. = FALSE)
  }

  required <- c(vars, id)
  if (!is.null(day))  required <- c(required, day)
  if (!is.null(beep)) required <- c(required, beep)
  missing_cols <- setdiff(required, names(data))
  if (length(missing_cols) > 0L) {
    stop("Columns not found in data: ",
         paste(missing_cols, collapse = ", "), call. = FALSE)
  }

  if (!requireNamespace("lme4", quietly = TRUE)) {
    stop("Package 'lme4' is required for build_mlvar().", call. = FALSE)
  }
  if (nCores > 1L) {
    message("build_mlvar() is single-threaded; ignoring nCores = ", nCores, ".")
  }

  lag <- 1L

  if (verbose) message("Preparing and augmenting panel ...")
  prepared <- .mlvar_prepare_data(data, vars, id, day, beep, scale)
  aug      <- .mlvar_augment_data(prepared, vars, id, day, beep, lag, scaleWithin)
  if (verbose) message("Fitting ", length(vars), " lmer models ...")
  Res      <- .mlvar_estimate_lmer(aug$data, aug$predModel, vars, id, AR = AR)

  # Wrap each of the three matrices as a full cograph_network netobject via
  # the package-wide `.ido_wrap()` constructor. Nestimate never calls
  # cograph — plotting is handled by cograph's existing splot.netobject /
  # splot.cograph_network dispatch, which fires automatically because each
  # constituent here is a standard netobject.
  temporal_net        <- .ido_wrap(Res$temporal$B,
                                         method   = "mlvar_temporal",
                                         directed = TRUE)
  contemporaneous_net <- .ido_wrap(Res$contemporaneous,
                                         method   = "mlvar_contemporaneous",
                                         directed = FALSE)
  between_net         <- .ido_wrap(Res$between,
                                         method   = "mlvar_between",
                                         directed = FALSE)

  nets <- list(
    temporal        = temporal_net,
    contemporaneous = contemporaneous_net,
    between         = between_net
  )

  # Model-level metadata lives in attributes so the list stays a pure
  # netobject_group (each element is a netobject). Use coefs(fit) to
  # retrieve the tidy coefs data.frame.
  attr(nets, "coefs")       <- Res$temporal$coefs
  attr(nets, "n_obs")       <- nrow(aug$data)
  attr(nets, "n_subjects")  <- length(unique(aug$data[[id]]))
  attr(nets, "lag")         <- lag
  attr(nets, "standardize") <- scale
  attr(nets, "scale")       <- scale
  attr(nets, "scaleWithin") <- scaleWithin
  attr(nets, "AR")          <- AR
  attr(nets, "group_col")   <- "network_type"

  class(nets) <- c("net_mlvar", "cograph_group", "netobject_group")
  nets
}

#' Tidy coefficients from a fitted mlvar model
#'
#' Generic accessor for the tidy coefficient table stored on a
#' [build_mlvar()] result. Returns a `data.frame` with one row per
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
#' @inherit build_mlvar examples
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
.mlvar_prepare_data <- function(data, vars, id, day, beep, scale) {
  df <- as.data.frame(data)

  md_cols <- c(id,
               if (!is.null(day))  day,
               if (!is.null(beep)) beep)
  df <- df[stats::complete.cases(df[, md_cols, drop = FALSE]), , drop = FALSE]

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
#' against `mlVAR`. The within-group lag/center/mean arithmetic then uses base
#' `ave()` for the same reason.
#' @noRd
.mlvar_augment_data <- function(data, vars, id, day, beep, lag,
                                scaleWithin = FALSE) {
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

  predModel <- list()

  # Within-person centering of the lagged predictors. With scaleWithin the
  # centering also divides by the within-person SD (mlVAR's aveCenter(scale=TRUE)).
  center_fun <- if (isTRUE(scaleWithin)) {
    function(x) (x - mean(x, na.rm = TRUE)) / stats::sd(x, na.rm = TRUE)
  } else {
    function(x) x - mean(x, na.rm = TRUE)
  }

  # Within (lagged, person-centered) predictors
  for (v in vars) {
    p_id <- paste0("L", lag, "_", v)
    augData[[p_id]] <- stats::ave(
      augData[[v]], augData[[id_col]], augData[[day_col]],
      FUN = function(x) .mlvar_aveLag(x, lag)
    )
    augData[[p_id]] <- stats::ave(
      augData[[p_id]], augData[[id_col]], FUN = center_fun
    )
    predModel[[length(predModel) + 1L]] <- list(
      dep = vars, pred = v, id = p_id, type = "within"
    )
  }

  # Between (person-mean) predictors
  for (v in vars) {
    p_id <- paste0("PM_", v)
    augData[[p_id]] <- stats::ave(
      augData[[v]], augData[[id_col]],
      FUN = function(x) mean(x, na.rm = TRUE)
    )
    predModel[[length(predModel) + 1L]] <- list(
      dep = vars, pred = v, id = p_id, type = "between"
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

  involved <- unique(c(vars, vapply(predModel, `[[`, character(1), "id")))
  augData <- stats::na.omit(
    augData[, c(involved, id_col, day_col, beep_col), drop = FALSE]
  )
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
.mlvar_estimate_lmer <- function(augData, predModel, vars, id, AR = FALSE) {
  d <- length(vars)
  n_obs <- nrow(augData)

  B             <- matrix(0, d, d, dimnames = list(vars, vars))
  Gamma         <- matrix(0, d, d, dimnames = list(vars, vars))
  mu_SD         <- stats::setNames(numeric(d), vars)
  sigma_vec     <- stats::setNames(numeric(d), vars)
  residuals_mat <- matrix(NA_real_, n_obs, d, dimnames = list(NULL, vars))

  within_ids <- vapply(Filter(function(m) m$type == "within",  predModel),
                       `[[`, character(1), "id")
  between_ids <- vapply(Filter(function(m) m$type == "between", predModel),
                        `[[`, character(1), "id")
  var_to_within  <- stats::setNames(within_ids,  vars)
  var_to_between <- stats::setNames(between_ids, vars)

  z975 <- stats::qnorm(0.975)

  # Tidy coefs: one row per (outcome, predictor) pair — fills d * d rows.
  # Faster and cleaner than growing a list of per-outcome data.frames and
  # `do.call(rbind, ...)` at the end.
  n_coef_rows <- d * d
  coefs_tidy <- data.frame(
    outcome     = rep(vars, each = d),
    predictor   = rep(vars, times = d),
    beta        = numeric(n_coef_rows),
    se          = numeric(n_coef_rows),
    t           = numeric(n_coef_rows),
    p           = numeric(n_coef_rows),
    ci_lower    = numeric(n_coef_rows),
    ci_upper    = numeric(n_coef_rows),
    significant = logical(n_coef_rows),
    stringsAsFactors = FALSE
  )

  for (k in seq_len(d)) {
    outcome <- vars[k]
    # AR = TRUE: each outcome regresses on its OWN lag only (mlVAR AR = TRUE
    # gives a diagonal temporal matrix); otherwise on all lagged predictors.
    # Own PM excluded — matches mlVAR's `getModel` filter on `dep == outcome`.
    within_preds <- if (isTRUE(AR)) var_to_within[outcome] else within_ids
    fixed_preds  <- c(within_preds, var_to_between[-k])

    # Random intercept only — matches mlVAR temporal="fixed".
    fm_str <- paste0(outcome, " ~ ",
                     paste(fixed_preds, collapse = " + "),
                     " + (1 | ", id, ")")
    fit <- suppressMessages(suppressWarnings(
      lme4::lmer(stats::as.formula(fm_str), data = augData, REML = FALSE)
    ))

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
    within_keys  <- var_to_within[vars]       # all d, for the row vectors
    between_keys <- var_to_between[vars[-k]]
    dropped <- setdiff(c(within_preds, between_keys), names(fe))  # vs fitted set
    if (length(dropped) > 0L) {
      warning(sprintf(
        "Model for '%s' dropped predictor(s) %s (rank-deficient design); ",
        outcome, paste(dropped, collapse = ", ")),
        "filling the affected coefficients with NA.", call. = FALSE)
    }
    B_row <- .mlvar_vec(fe, within_keys)
    # AR = TRUE only fits the own lag, so the off-diagonal temporal effects are
    # exactly 0 (not NA).
    if (isTRUE(AR)) B_row[is.na(B_row)] <- 0
    B[k, ]        <- B_row
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

    rows <- ((k - 1L) * d + 1L):(k * d)
    coefs_tidy$beta[rows]        <- beta_k
    coefs_tidy$se[rows]          <- se_k
    coefs_tidy$t[rows]           <- t_k
    coefs_tidy$p[rows]           <- p_k
    coefs_tidy$ci_lower[rows]    <- beta_k - z975 * se_k
    coefs_tidy$ci_upper[rows]    <- beta_k + z975 * se_k
    # A path that was not estimated (AR off-diagonals, dropped predictors) has
    # p = NA; report it as not significant rather than leaving `significant` NA.
    coefs_tidy$significant[rows] <- !is.na(p_k) & p_k < 0.05
  }

  contemporaneous <- .mlvar_contemporaneous_fixed(residuals_mat, sigma_vec, vars)
  between         <- .mlvar_compute_between_from_gamma(Gamma, mu_SD, vars)

  list(temporal = list(B = B, coefs = coefs_tidy, residuals = residuals_mat),
       contemporaneous = contemporaneous,
       between = between)
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
#' @param x A `net_mlvar` object returned by [build_mlvar()].
#' @param digits Number of digits used for printed network matrices.
#' @param ... Unused; present for S3 consistency.
#' @return Invisibly returns `x`.
#' @inherit build_mlvar examples
#' @export
print.net_mlvar <- function(x, digits = 2, ...) {
  coef_df <- attr(x, "coefs")
  d <- nrow(x$temporal$weights)
  n_sig <- sum(coef_df$significant, na.rm = TRUE)
  n_tot <- nrow(coef_df)

  cat(sprintf("mlVAR result: %d subjects, %d observations, %d variables (lag %d)\n",
              attr(x, "n_subjects"),
              attr(x, "n_obs"),
              d,
              attr(x, "lag")))
  cat(sprintf("  Temporal edges significant at p<0.05: %d / %d\n", n_sig, n_tot))
  .ido_print_networks(x, digits = digits)
  cat("\n  plot(x) | plot(x, layer = \"temporal\") | plot(x, layer = \"between\")",
      "\n  edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)\n")
  invisible(x)
}

#' Summary method for net_mlvar
#'
#' @param object A `net_mlvar` object returned by [build_mlvar()].
#' @param ... Unused; present for S3 consistency.
#' @return A tidy `data.frame` of per-network metrics (one row per network:
#'   `temporal`, `contemporaneous`, `between`). Use `coefs(object)` for the
#'   fixed-effect coefficient table, `edges(object)` for the edge list, and
#'   `nodes(object)` for node strengths.
#' @inherit build_mlvar examples
#' @export
summary.net_mlvar <- function(object, ...) {
  .tidy_over_group(as_netobject(object), .net_metrics)
}
