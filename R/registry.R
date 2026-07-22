# ---- Estimator registry and unified front door --------------------------------

.idiographic_estimators <- new.env(parent = emptyenv())
.idiographic_estimators$entries <- list()
.idiographic_estimators$aliases <- character()
.idiographic_estimators$initialized <- FALSE

#' Registered idiographic estimators
#'
#' `idiographic` uses a small registry to give estimators and workflows one
#' stable dispatch interface. Package methods are registered lazily, so the
#' registry does not depend on source-file load order. Third-party methods can
#' register either a function or the name of a function available in the
#' package namespace or calling environment.
#'
#' @param kind Optional character vector selecting `"estimator"` and/or
#'   `"workflow"` registrations.
#'
#' @return `list_estimators()` returns one row per registration.
#' @examples
#' list_estimators()
#' list_estimators("workflow")
#' @export
list_estimators <- function(kind = NULL) {
  .ido_initialize_registry()
  entries <- .idiographic_estimators$entries
  if (!is.null(kind)) {
    if (!length(kind)) {
      entries <- list()
    } else {
      kind <- match.arg(kind, c("estimator", "workflow"), several.ok = TRUE)
      entries <- entries[vapply(entries, function(x) x$kind %in% kind,
                                logical(1))]
    }
  }

  if (!length(entries)) {
    return(data.frame(
      name = character(), kind = character(), function_name = character(),
      aliases = character(), result_class = character(), available = logical(),
      description = character(), stringsAsFactors = FALSE
    ))
  }

  rows <- lapply(entries, function(x) {
    data.frame(
      name = x$name,
      kind = x$kind,
      function_name = if (is.character(x$fit)) x$fit else "<function>",
      aliases = paste(x$aliases, collapse = ", "),
      result_class = paste(x$result_class, collapse = ", "),
      available = .ido_estimator_available(x),
      description = x$description,
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$kind, out$name), , drop = FALSE]
}

#' Inspect a registered estimator
#'
#' @param method A registered method name or alias. Names are case-insensitive;
#'   spaces, hyphens, and periods are normalized to underscores.
#'
#' @return `estimator_info()` returns the complete registration as a list.
#' @examples
#' estimator_info("var")
#' @export
estimator_info <- function(method) {
  .ido_estimator_spec(method)
}

#' Get a registered estimator function
#'
#' @inheritParams estimator_info
#'
#' @return `get_estimator()` returns the registered fitting function.
#' @examples
#' var_fitter <- get_estimator("var")
#' is.function(var_fitter)
#' @export
get_estimator <- function(method) {
  spec <- .ido_estimator_spec(method)
  .ido_resolve_estimator_function(spec)
}

#' Register an idiographic estimator or workflow
#'
#' @param name Unique canonical method name.
#' @param fit A function, or a single character string naming a function.
#' @param aliases Optional alternative method names.
#' @param kind Either `"estimator"` or `"workflow"`.
#' @param description Short human-readable description.
#' @param result_class Optional result classes used to infer equivalence metadata
#'   for objects produced by direct calls to the estimator.
#' @param equivalence A named list describing the validation status, reference,
#'   scope, tolerance, and notes. Missing fields receive conservative defaults.
#' @param overwrite Logical. Replace an existing registration with the same
#'   canonical name. Aliases owned by another method are never overwritten.
#'
#' @return `register_estimator()` invisibly returns the new registration.
#' @examples
#' demo_fitter <- function(data, ...) structure(list(data = data),
#'                                              class = "demo_result")
#' register_estimator("demo", demo_fitter, result_class = "demo_result")
#' get_estimator("demo")
#' remove_estimator("demo")
#' @export
register_estimator <- function(name, fit, aliases = character(),
                               kind = c("estimator", "workflow"),
                               description = "",
                               result_class = character(),
                               equivalence = list(),
                               overwrite = FALSE) {
  .ido_initialize_registry()
  # A character reference found in the caller is captured as a closure, which
  # makes local/plugin-defined estimators reliable after the caller returns.
  if (is.character(fit) && length(fit) == 1L && !is.na(fit)) {
    candidate <- get0(fit, envir = parent.frame(), mode = "function",
                      inherits = TRUE)
    if (!is.null(candidate)) fit <- candidate
  }
  .ido_register_estimator(
    name = name, fit = fit, aliases = aliases, kind = kind,
    description = description, result_class = result_class,
    equivalence = equivalence, overwrite = overwrite
  )
}

#' Remove a registered estimator
#'
#' @inheritParams estimator_info
#' @param missing_ok Logical. If `TRUE`, silently do nothing when `method` is
#'   not registered.
#'
#' @return Invisibly returns the removed registration, or `NULL` when
#'   `missing_ok = TRUE` and no registration exists.
#' @examples
#' temp_fitter <- function(data, ...) data
#' register_estimator("temporary", temp_fitter)
#' remove_estimator("temporary")
#' remove_estimator("temporary", missing_ok = TRUE)
#' @export
remove_estimator <- function(method, missing_ok = FALSE) {
  .ido_initialize_registry()
  .ido_check_flag(missing_ok, "missing_ok")
  key <- .ido_normalize_method(method, "method")
  canonical <- .ido_registry_canonical(key)
  if (is.null(canonical)) {
    if (isTRUE(missing_ok)) return(invisible(NULL))
    stop("No estimator is registered as `", method, "`.", call. = FALSE)
  }

  old <- .idiographic_estimators$entries[[canonical]]
  .idiographic_estimators$entries[[canonical]] <- NULL
  owned <- .idiographic_estimators$aliases == canonical
  if (any(owned)) {
    .idiographic_estimators$aliases <-
      .idiographic_estimators$aliases[!owned]
  }
  invisible(old)
}

#' Fit an idiographic model through the unified interface
#'
#' `fit_idiographic()` dispatches every built-in estimator and workflow through
#' the same entry point. Arguments may be supplied directly or in `params`,
#' which makes a stored configuration directly replayable. Direct arguments
#' and `params` must both be named and cannot overlap; this turns otherwise
#' ambiguous duplicate arguments into an immediate, informative error.
#'
#' @param data A data frame or matrix passed to the selected method.
#' @param method A registered method name or alias.
#' @param ... Named arguments passed directly to the selected method.
#' @param params A named list of additional method arguments.
#'
#' @return The selected method's result, unchanged except for lightweight
#'   dispatch and equivalence metadata attributes.
#' @examples
#' set.seed(1)
#' d <- data.frame(A = rnorm(80), B = rnorm(80))
#' fit <- fit_idiographic(d, "var", vars = c("A", "B"), scale = FALSE)
#' fit2 <- fit_idiographic(d, "ols-var",
#'                         params = list(vars = c("A", "B"), scale = FALSE))
#' equivalence(fit)
#' @export
fit_idiographic <- function(data, method, ..., params = list()) {
  spec <- .ido_estimator_spec(method)
  dots <- list(...)
  .ido_check_dispatch_args(dots, "direct arguments (`...`)")
  .ido_check_dispatch_args(params, "`params`")

  reserved <- c("data", "method", "params")
  bad_reserved <- intersect(c(names(dots), names(params)), reserved)
  if (length(bad_reserved)) {
    stop("Do not supply reserved argument(s) in `...` or `params`: ",
         paste(unique(bad_reserved), collapse = ", "), ".", call. = FALSE)
  }
  overlap <- intersect(names(dots), names(params))
  if (length(overlap)) {
    stop("Argument(s) supplied both directly and in `params`: ",
         paste(overlap, collapse = ", "), ". Supply each argument once.",
         call. = FALSE)
  }

  fun <- .ido_resolve_estimator_function(spec)
  args <- c(list(data = data), dots, params)
  result <- do.call(fun, args)
  if (!is.null(result)) {
    attr(result, "idiographic_method") <- spec$name
    attr(result, "idiographic_dispatch") <- list(
      method = spec$name,
      requested_method = as.character(method),
      function_name = if (is.character(spec$fit)) spec$fit else "<function>",
      argument_names = names(args)[-1L],
      params = c(dots, params)
    )
    attr(result, "idiographic_equivalence") <-
      .ido_equivalence_object(spec$name,
                              .ido_refine_equivalence(spec, result),
                              source = "dispatch")
  }
  result
}

#' Report method-equivalence evidence
#'
#' Returns the equivalence declaration attached by [fit_idiographic()]. For a
#' result created by a direct `fit_*()` call, the registry can infer the method
#' from a unique registered result class. The declaration describes the scope
#' of committed validation; it is not a new statistical equivalence test.
#'
#' @param x A fitted object.
#'
#' @return An `idiographic_equivalence` list with `method`, `status`,
#'   `reference`, `scope`, `tolerance`, `notes`, and `source`.
#' @examples
#' set.seed(2)
#' d <- data.frame(A = rnorm(40), B = rnorm(40))
#' fit <- fit_var(d, vars = c("A", "B"), scale = FALSE)
#' equivalence(fit)
#' @export
equivalence <- function(x) {
  attached <- attr(x, "idiographic_equivalence", exact = TRUE)
  if (!is.null(attached)) return(attached)

  method <- attr(x, "idiographic_method", exact = TRUE)
  source <- "method_attribute"
  if (is.null(method)) {
    .ido_initialize_registry()
    classes <- class(x)
    positions <- vapply(.idiographic_estimators$entries, function(spec) {
      pos <- match(spec$result_class, classes, nomatch = NA_integer_)
      if (any(!is.na(pos))) min(pos, na.rm = TRUE) else Inf
    }, numeric(1))
    best <- min(positions)
    matched <- names(positions)[is.finite(positions) & positions == best]
    # Prefer a more specific leading class (for example net_mlvar_bayes over
    # its net_mlvar parent), but do not guess between registrations tied at the
    # same class position.
    if (is.finite(best) && length(matched) == 1L) {
      method <- unname(matched)
      source <- "result_class"
    }
  }

  if (!is.null(method)) {
    spec <- tryCatch(.ido_estimator_spec(method), error = function(e) NULL)
    if (!is.null(spec)) {
      return(.ido_equivalence_object(spec$name,
                                     .ido_refine_equivalence(spec, x),
                                     source = source))
    }
  }

  .ido_equivalence_object(
    method = NA_character_,
    declaration = list(
      status = "unknown", reference = NA_character_,
      scope = "No unique registered method could be inferred from this object.",
      tolerance = NA_real_, notes = character()
    ),
    source = "unknown"
  )
}

#' Package-wide equivalence and validation ledger
#'
#' Returns one tidy row for every registered estimator and workflow. Unlike
#' [equivalence()], which refines the declaration for one fitted object,
#' `equivalence_table()` exposes the package-wide evidence boundary before a
#' model is fitted. A `closed` evidence status means the declared scope has an
#' executable oracle, engine, recovery, or internal-consistency contract; it
#' does not turn native extensions into claims about an unrelated package.
#'
#' @param method Optional registered method name or alias. `NULL` returns all
#'   built-in and currently registered methods.
#'
#' @return A data frame with method, kind, declared status, evidence status,
#'   reference, numerical tolerance bounds, scope, and notes.
#' @examples
#' equivalence_table()
#' equivalence_table("gimme")
#' @export
equivalence_table <- function(method = NULL) {
  .ido_initialize_registry()
  entries <- .idiographic_estimators$entries
  if (!is.null(method)) {
    spec <- .ido_estimator_spec(method)
    entries <- entries[spec$name]
  }
  rows <- lapply(entries, function(spec) {
    declaration <- spec$equivalence
    evidence_status <- switch(
      declaration$status,
      not_assessed = "open",
      unknown = "open",
      delegated = "conditional",
      partial = "bounded",
      supported_extension = "bounded",
      "closed"
    )
    tolerance <- declaration$tolerance
    finite <- tolerance[is.finite(tolerance)]
    data.frame(
      method = spec$name,
      kind = spec$kind,
      status = declaration$status,
      evidence_status = evidence_status,
      reference = declaration$reference,
      tolerance_min = if (length(finite)) min(finite) else NA_real_,
      tolerance_max = if (length(finite)) max(finite) else NA_real_,
      scope = declaration$scope,
      notes = paste(declaration$notes, collapse = " "),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$kind, out$method), , drop = FALSE]
}

#' Argument-by-argument validation coverage
#'
#' Builds a tidy, executable ledger from the actual formals of every registered
#' entry point. Each argument is classified according to the strongest honest
#' evidence contract available for that method: direct oracle/engine equality,
#' frozen statistical fixtures, recovery/internal validation, delegated
#' forwarding, a supported extension, or an explicit rejection boundary.
#' Consequently a newly added formal cannot silently disappear from the audit:
#' package tests require every current formal to occur exactly once here.
#'
#' @inheritParams equivalence_table
#'
#' @return A data frame with one row per public method argument.
#' @examples
#' argument_coverage()
#' argument_coverage("mlvar")
#' @export
argument_coverage <- function(method = NULL) {
  .ido_initialize_registry()
  entries <- .idiographic_estimators$entries
  if (!is.null(method)) {
    spec <- .ido_estimator_spec(method)
    entries <- entries[spec$name]
  }
  rows <- lapply(entries, function(spec) {
    fun <- .ido_resolve_estimator_function(spec)
    arguments <- names(formals(fun))
    status <- vapply(arguments, .ido_argument_status, character(1), spec = spec)
    data.frame(
      method = spec$name,
      kind = spec$kind,
      argument = arguments,
      status = status,
      reference = spec$equivalence$reference,
      scope = vapply(seq_along(arguments), function(i) {
        .ido_argument_scope(spec, arguments[i], status[i])
      }, character(1)),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$kind, out$method, match(out$argument,
                                       unique(out$argument))), , drop = FALSE]
}

#' @noRd
.ido_known_argument_signatures <- c(
  compare = "data|vars|id|day|beep|keep_fits|estimators|estimator_args",
  forecast = paste(
    c("data", "vars", "id", "day", "beep", "scale", "center_within",
      "delete_missings", "...", "estimator", "step", "keep_fits",
      "block_size", "initial", "assess", "n_splits"), collapse = "|"),
  gimme = paste(
    c("data", "vars", "id", "day", "beep", "min_obs", "subject", "seed",
      "standardize", "time", "cfi_cutoff", "rmsea_cutoff", "srmr_cutoff",
      "paths", "exogenous", "ar", "groupcutoff", "subcutoff", "hybrid",
      "VAR", "nnfi_cutoff", "n_excellent", "group_correct", "indiv_correct",
      "alpha", "stop_crit", "subgroup", "outcome", "conv_vars", "mult_vars",
      "lv_model", "lasso_model_crit", "ms_allow", "ordered",
      "dir_prop_cutoff", "out", "sep", "header", "plot", "sub_feature",
      "sub_method", "sub_sim_thresh", "confirm_subgroup", "conv_length",
      "conv_interval", "mean_center_mult", "diagnos", "ms_tol",
      "lv_estimator", "lv_scores", "lv_miiv_scaling", "lv_final_estimator"),
    collapse = "|"),
  graphical_var = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale",
      "center_within", "delete_missings", "min_obs", "subject", "verbose",
      "n_lambda", "gamma", "lambda_min_ratio", "lambda_min_kappa",
      "lambda_min_beta", "penalize_diagonal", "lambda_beta", "lambda_kappa",
      "regularize_mat_beta", "regularize_mat_kappa", "maxit_in", "maxit_out",
      "likelihood", "ebic_tol", "mimic"), collapse = "|"),
  graphical_var_each = "data|vars|id|day|beep|min_obs|...",
  ml = paste(
    c("data", "id", "day", "beep", "...", "estimator", "standardize",
      "alpha", "outcome", "keep_fits", "predictors", "task", "model",
      "compare", "test_prop", "min_train", "min_test", "lambda", "k",
      "n_components", "max_iter", "tol"), collapse = "|"),
  mlvar = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale", "min_obs",
      "subject", "...", "verbose", "estimator", "temporal",
      "contemporaneous", "AR", "scaleWithin", "nCores", "lag",
      "standardize", "engine", "standardize_mode", "missing",
      "compare_to_lags", "true_means", "detrend", "na_rm", "orthogonal"),
    collapse = "|"),
  mlvar_bayes = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale", "min_obs",
      "subject", "n_iter", "n_burnin", "n_chains", "thin", "seed",
      "verbose", "temporal", "contemporaneous", "scaleWithin", "residual",
      "tinterval", "impute"), collapse = "|"),
  mlvar_mplus = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale", "min_obs",
      "subject", "...", "verbose", "temporal", "contemporaneous",
      "scaleWithin", "nCores", "MplusSave", "MplusName", "iterations",
      "chains", "signs", "workdir"), collapse = "|"),
  preprocess = paste(
    c("data", "vars", "id", "day", "beep", "scale", "center_within",
      "delete_missings", "min_obs", "subject", "detrend", "checks",
      "trend_alpha", "ar_threshold", "mean_shift_threshold",
      "sd_ratio_threshold", "unit_root_t_cutoff"), collapse = "|"),
  rolling_graphical_var = paste(
    c("data", "vars", "id", "day", "beep", "scale", "center_within",
      "delete_missings", "min_obs", "subject", "...", "window_size", "step",
      "keep_fits"), collapse = "|"),
  rolling_var = paste(
    c("data", "vars", "id", "day", "beep", "scale", "center_within",
      "delete_missings", "min_obs", "subject", "window_size", "step",
      "keep_fits"), collapse = "|"),
  stability = paste(
    c("data", "vars", "id", "day", "beep", "...", "seed", "estimator",
      "keep_fits", "n_resamples", "resample", "block_size", "threshold"),
    collapse = "|"),
  usem = paste(
    c("data", "vars", "id", "day", "beep", "min_obs", "subject", "seed",
      "estimator", "temporal", "contemporaneous", "standardize", "time",
      "residual_cov", "trim", "trim_alpha", "trim_fit_criteria",
      "cfi_cutoff", "tli_cutoff", "rmsea_cutoff", "srmr_cutoff", "paths",
      "exogenous"), collapse = "|"),
  var = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale",
      "center_within", "delete_missings", "min_obs", "subject"),
    collapse = "|"),
  var_bayes = paste(
    c("data", "vars", "id", "day", "beep", "lags", "scale",
      "center_within", "min_obs", "subject", "n_iter", "n_burnin",
      "n_chains", "thin", "seed", "verbose"), collapse = "|"),
  var_each = "data|vars|id|day|beep|min_obs|..."
)

#' @noRd
.ido_argument_status <- function(argument, spec) {
  method <- spec$name
  signature <- unname(.ido_known_argument_signatures[method])
  known <- if (length(signature) && !is.na(signature)) {
    strsplit(signature, "|", fixed = TRUE)[[1L]]
  } else {
    character()
  }
  if (!argument %in% known) return("unassessed")
  if (method == "graphical_var") {
    if (argument %in% c("lags", "n_lambda")) return("validated_or_extension")
    if (argument == "mimic") return("validated_or_rejected")
    if (argument %in% c("min_obs", "subject", "verbose"))
      return("validated_behavior")
    return("validated_oracle")
  }
  if (method == "graphical_var_each") {
    return(if (argument == "...") "validated_forwarding" else
      "validated_wrapper")
  }
  if (method == "mlvar") {
    if (argument %in% c("engine", "estimator", "temporal",
                        "contemporaneous", "lags")) return("mode_dependent")
    if (argument == "...") return("validated_or_rejected")
    if (argument %in% c("min_obs", "subject", "verbose", "missing"))
      return("validated_behavior")
    return("validated_oracle")
  }
  if (method == "mlvar_bayes") {
    if (argument %in% c("temporal", "residual", "impute", "tinterval"))
      return("fixture_or_recovery")
    return("validated_statistical")
  }
  if (method == "mlvar_mplus") {
    if (argument %in% c("min_obs", "subject", "workdir"))
      return("validated_behavior")
    return("delegated_contract")
  }
  if (method == "usem") {
    if (argument %in% c("trim", "trim_alpha", "trim_fit_criteria",
                        "cfi_cutoff", "tli_cutoff", "rmsea_cutoff",
                        "srmr_cutoff")) return("validated_extension")
    return("validated_engine")
  }
  if (method == "gimme") {
    rejected <- c("subgroup", "outcome", "conv_vars", "mult_vars",
                  "lv_model", "lasso_model_crit", "ms_allow", "ordered",
                  "dir_prop_cutoff")
    warned <- c("subcutoff", "out", "sep", "header", "plot",
                "sub_feature", "sub_method", "sub_sim_thresh",
                "confirm_subgroup", "conv_length", "conv_interval",
                "mean_center_mult", "diagnos", "ms_tol", "lv_estimator",
                "lv_scores", "lv_miiv_scaling", "lv_final_estimator")
    if (argument %in% rejected) return("explicit_rejection")
    if (argument %in% warned) return("explicit_warning_boundary")
    if (argument == "ar") return("oracle_or_upstream_failure")
    return("validated_oracle_matrix")
  }
  if (method == "var_bayes") return("validated_statistical")
  if (method %in% c("var", "var_each")) return("validated_engine")
  if (method %in% c("rolling_var", "rolling_graphical_var", "preprocess",
                    "stability", "compare", "forecast"))
    return("validated_internal")
  if (method == "ml") return("validated_native")
  "unassessed"
}

#' @noRd
.ido_argument_scope <- function(spec, argument, status) {
  boundary <- switch(
    status,
    explicit_rejection = "Non-default use errors explicitly; no silent support claim.",
    explicit_warning_boundary = "Non-default use warns explicitly because the parent feature or file workflow is outside idiographic's scope.",
    validated_or_extension = "Competitor-compatible values are oracle-tested; additional tidy values are labelled idiographic extensions.",
    validated_or_rejected = "Supported values are tested; unused or legacy values error explicitly.",
    mode_dependent = "The fitted object's equivalence declaration is refined from the selected engine and structure.",
    fixture_or_recovery = "Fixed/checkable slices use external fixtures; advanced native slices use planted recovery and are labelled accordingly.",
    delegated_contract = "Argument forwarding and output conversion are executable; estimation is delegated to the licensed backend.",
    oracle_or_upstream_failure = "The supported AR path is oracle-tested; upstream gimme 10.0 fails on the audited ar=FALSE fixture, which remains a local extension.",
    paste0("Evidence class: ", status, ".")
  )
  paste0("`", argument, "`: ", boundary, " ", spec$equivalence$scope)
}

#' @export
print.idiographic_equivalence <- function(x, ...) {
  method <- if (is.na(x$method)) "unknown" else x$method
  reference <- if (length(x$reference) && !is.na(x$reference)) {
    x$reference
  } else {
    "none"
  }
  cat("Idiographic equivalence declaration\n")
  cat("  Method:    ", method, "\n", sep = "")
  cat("  Status:    ", x$status, "\n", sep = "")
  cat("  Reference: ", reference, "\n", sep = "")
  cat("  Scope:     ", x$scope, "\n", sep = "")
  if (length(x$tolerance) && any(!is.na(x$tolerance))) {
    cat("  Tolerance: ", paste(x$tolerance, collapse = " to "), "\n", sep = "")
  }
  if (length(x$notes)) {
    cat("  Notes:     ", paste(x$notes, collapse = " "), "\n", sep = "")
  }
  invisible(x)
}

# ---- Internal registry machinery --------------------------------------------

.ido_normalize_method <- function(x, argument = "method") {
  if (!(is.character(x) && length(x) == 1L && !is.na(x) && nzchar(trimws(x)))) {
    stop("`", argument, "` must be one non-empty character string.",
         call. = FALSE)
  }
  key <- tolower(trimws(x))
  key <- gsub("[^a-z0-9]+", "_", key)
  key <- gsub("^_+|_+$", "", key)
  key <- gsub("_+", "_", key)
  if (!nzchar(key)) {
    stop("`", argument, "` does not contain a usable method name.",
         call. = FALSE)
  }
  key
}

.ido_check_dispatch_args <- function(x, label) {
  if (is.null(x) || !is.list(x)) {
    stop(label, " must be a list.", call. = FALSE)
  }
  if (!length(x)) return(invisible(TRUE))
  nms <- names(x)
  if (is.null(nms) || anyNA(nms) || any(!nzchar(nms))) {
    stop(label, " must be fully named.", call. = FALSE)
  }
  duplicated_names <- unique(nms[duplicated(nms)])
  if (length(duplicated_names)) {
    stop(label, " contains duplicate argument name(s): ",
         paste(duplicated_names, collapse = ", "), ".", call. = FALSE)
  }
  invisible(TRUE)
}

.ido_registry_canonical <- function(key) {
  if (key %in% names(.idiographic_estimators$entries)) return(key)
  if (key %in% names(.idiographic_estimators$aliases)) {
    return(unname(.idiographic_estimators$aliases[[key]]))
  }
  NULL
}

.ido_estimator_spec <- function(method) {
  .ido_initialize_registry()
  key <- .ido_normalize_method(method, "method")
  canonical <- .ido_registry_canonical(key)
  if (is.null(canonical)) {
    choices <- names(.idiographic_estimators$entries)
    stop("Unknown idiographic method `", method, "`. Registered methods: ",
         paste(sort(choices), collapse = ", "), ".", call. = FALSE)
  }
  .idiographic_estimators$entries[[canonical]]
}

.ido_estimator_available <- function(spec) {
  if (is.function(spec$fit)) return(TRUE)
  !is.null(get0(spec$fit,
               envir = environment(.ido_estimator_available),
               mode = "function", inherits = TRUE))
}

.ido_resolve_estimator_function <- function(spec) {
  fun <- if (is.function(spec$fit)) {
    spec$fit
  } else {
    get0(spec$fit,
         envir = environment(.ido_resolve_estimator_function),
         mode = "function", inherits = TRUE)
  }
  if (is.null(fun)) {
    stop("Registered method `", spec$name, "` refers to unavailable function `",
         spec$fit, "`.", call. = FALSE)
  }
  .ido_validate_estimator_function(fun, spec$name)
  fun
}

.ido_validate_estimator_function <- function(fun, name = "estimator") {
  nms <- names(formals(fun))
  if (!("data" %in% nms || "..." %in% nms)) {
    stop("Estimator `", name, "` must accept a `data` argument (or `...`).",
         call. = FALSE)
  }
  invisible(TRUE)
}

.ido_register_estimator <- function(name, fit, aliases = character(),
                                    kind = c("estimator", "workflow"),
                                    description = "",
                                    result_class = character(),
                                    equivalence = list(), overwrite = FALSE) {
  canonical <- .ido_normalize_method(name, "name")
  kind <- match.arg(kind)
  .ido_check_flag(overwrite, "overwrite")
  if (!(is.function(fit) ||
        (is.character(fit) && length(fit) == 1L && !is.na(fit) && nzchar(fit)))) {
    stop("`fit` must be a function or one non-empty function name.",
         call. = FALSE)
  }
  if (is.function(fit)) .ido_validate_estimator_function(fit, canonical)
  if (!is.character(aliases) || anyNA(aliases)) {
    stop("`aliases` must be a character vector without missing values.",
         call. = FALSE)
  }
  aliases <- unique(vapply(aliases, .ido_normalize_method, character(1),
                           argument = "aliases"))
  aliases <- setdiff(aliases, canonical)
  if (!(is.character(description) && length(description) == 1L &&
        !is.na(description))) {
    stop("`description` must be one character string.", call. = FALSE)
  }
  if (!is.character(result_class) || anyNA(result_class) ||
      any(!nzchar(result_class))) {
    stop("`result_class` must contain non-empty class names.", call. = FALSE)
  }
  if (!is.list(equivalence) || is.null(names(equivalence)) ||
      any(!nzchar(names(equivalence)))) {
    if (length(equivalence)) {
      stop("`equivalence` must be a named list.", call. = FALSE)
    }
  }
  if (length(equivalence)) {
    if (anyDuplicated(names(equivalence))) {
      stop("`equivalence` cannot contain duplicate fields.", call. = FALSE)
    }
    reserved_equivalence <- intersect(names(equivalence), c("method", "source"))
    if (length(reserved_equivalence)) {
      stop("`equivalence` cannot define reserved field(s): ",
           paste(reserved_equivalence, collapse = ", "), ".", call. = FALSE)
    }
  }

  existing <- .ido_registry_canonical(canonical)
  if (!is.null(existing) && !identical(existing, canonical)) {
    stop("Cannot register `", canonical, "`; it is an alias of `", existing,
         "`.", call. = FALSE)
  }
  if (!is.null(existing) && !isTRUE(overwrite)) {
    stop("Estimator `", canonical, "` is already registered. Use ",
         "`overwrite = TRUE` to replace it.", call. = FALSE)
  }

  claimed <- unique(c(canonical, aliases))
  conflicts <- vapply(claimed, function(alias) {
    owner <- .ido_registry_canonical(alias)
    !is.null(owner) && !identical(owner, canonical)
  }, logical(1))
  if (any(conflicts)) {
    conflict_names <- claimed[conflicts]
    owners <- vapply(conflict_names, function(alias) {
      .ido_registry_canonical(alias)
    }, character(1))
    detail <- paste0("`", conflict_names, "` (", owners, ")")
    stop("Alias conflict: ", paste(detail, collapse = ", "), ".",
         call. = FALSE)
  }

  if (!is.null(existing)) {
    old_aliases <- names(.idiographic_estimators$aliases)[
      .idiographic_estimators$aliases == canonical]
    if (length(old_aliases)) {
      .idiographic_estimators$aliases <-
        .idiographic_estimators$aliases[setdiff(
          names(.idiographic_estimators$aliases), old_aliases
        )]
    }
  }

  declaration <- utils::modifyList(list(
    status = "not_assessed",
    reference = NA_character_,
    scope = "No external equivalence scope has been declared.",
    tolerance = NA_real_,
    notes = character()
  ), equivalence)
  if (!(is.character(declaration$status) && length(declaration$status) == 1L &&
        !is.na(declaration$status) && nzchar(declaration$status))) {
    stop("`equivalence$status` must be one non-empty character string.",
         call. = FALSE)
  }
  if (!(is.character(declaration$reference) &&
        length(declaration$reference) == 1L)) {
    stop("`equivalence$reference` must be one character string or `NA`.",
         call. = FALSE)
  }
  if (!(is.character(declaration$scope) && length(declaration$scope) == 1L &&
        !is.na(declaration$scope) && nzchar(declaration$scope))) {
    stop("`equivalence$scope` must be one non-empty character string.",
         call. = FALSE)
  }
  if (!(is.numeric(declaration$tolerance) &&
        length(declaration$tolerance) >= 1L &&
        all(is.na(declaration$tolerance) |
            (is.finite(declaration$tolerance) & declaration$tolerance >= 0)))) {
    stop("`equivalence$tolerance` must contain non-negative numbers or `NA`.",
         call. = FALSE)
  }
  if (!is.character(declaration$notes) || anyNA(declaration$notes)) {
    stop("`equivalence$notes` must be a character vector without missing values.",
         call. = FALSE)
  }
  spec <- list(
    name = canonical,
    fit = fit,
    aliases = aliases,
    kind = kind,
    description = description,
    result_class = unique(result_class),
    equivalence = declaration
  )
  .idiographic_estimators$entries[[canonical]] <- spec
  if (length(aliases)) {
    values <- rep(canonical, length(aliases))
    names(values) <- aliases
    .idiographic_estimators$aliases <-
      c(.idiographic_estimators$aliases, values)
  }
  invisible(spec)
}

.ido_equivalence_object <- function(method, declaration, source) {
  structure(c(list(method = method), declaration, list(source = source)),
            class = "idiographic_equivalence")
}

#' Narrow a registry declaration when the fitted configuration lies outside
#' the externally validated slice. Supported extensions must never inherit a
#' blanket "validated" label merely because they share a result class.
#' @noRd
.ido_refine_equivalence <- function(spec, result) {
  declaration <- spec$equivalence
  if (identical(spec$name, "graphical_var")) {
    model <- attr(result, "model", exact = TRUE)
    lags <- model$lags %||% 1L
    unequal_grids <- length(model$n_lambda %||% 1L) == 2L &&
      !identical(unname((model$n_lambda)[["beta"]]),
                 unname((model$n_lambda)[["kappa"]]))
    if (!identical(as.integer(lags), 1L) || unequal_grids) {
      declaration$status <- "supported_extension"
      extension <- c(
        if (!identical(as.integer(lags), 1L))
          paste0("lags ", paste(lags, collapse = ", ")),
        if (unequal_grids) paste0(
          "separate beta/kappa grid sizes ", model$n_lambda[["beta"]],
          "/", model$n_lambda[["kappa"]]
        )
      )
      declaration$scope <- paste0(
        "Idiographic graphical VAR extension (", paste(extension, collapse = "; "),
        "); no direct graphicalVAR numerical claim for this configuration."
      )
      declaration$tolerance <- NA_real_
      declaration$notes <- c(declaration$notes,
                             "The upstream oracle matrix does not transfer to this extension fit.")
    }
  }
  if (identical(spec$name, "graphical_var_each")) {
    child_status <- vapply(result, function(fit) equivalence(fit)$status,
                           character(1))
    if (!length(child_status) || any(child_status != "validated")) {
      declaration$status <- "supported_extension"
      declaration$scope <- paste0(
        "Per-subject graphical VAR wrapper containing an empty or extension-",
        "only base fit; the lag-1 upstream subject-oracle claim does not ",
        "transfer to this object."
      )
      declaration$tolerance <- NA_real_
    }
  }
  if (identical(spec$name, "mlvar")) {
    config <- attr(result, "config", exact = TRUE) %||% list()
    if (identical(config$engine, "reference")) {
      declaration$status <- "delegated"
      declaration$scope <- paste0(
        "Direct mlVAR::mlVAR backend with conversion to idiographic's tidy ",
        "result contract (temporal=", config$temporal %||% "fixed",
        ", contemporaneous=", config$contemporaneous %||% "fixed",
        ", lags=", paste(config$lags %||% attr(result, "lag") %||% 1L,
                           collapse = ","), ")."
      )
      declaration$tolerance <- 0
      declaration$notes <- "Delegated output conversion, not an independent estimator comparison."
      return(declaration)
    }
    used_lags <- as.integer(config$lags %||% attr(result, "lag") %||% 1L)
    lmer_oracle <-
      identical(config$engine %||% "frequentist", "frequentist") &&
      identical(config$estimator %||% "lmer", "lmer") &&
      (
        (identical(used_lags, 1L) &&
         (config$temporal %||% "fixed") %in%
           c("fixed", "correlated", "orthogonal") &&
         (config$contemporaneous %||% "fixed") %in%
           c("fixed", "unique", "correlated", "orthogonal")) ||
        (identical(used_lags, c(1L, 2L)) &&
         identical(config$temporal %||% "fixed", "fixed") &&
         identical(config$contemporaneous %||% "fixed", "fixed"))
      )
    unique_oracle <-
      identical(config$engine %||% "frequentist", "frequentist") &&
      identical(config$estimator, "lm") &&
      identical(config$temporal, "unique") &&
      config$contemporaneous %in% c("fixed", "unique", "correlated", "orthogonal") &&
      identical(used_lags, 1L)
    in_scope <- lmer_oracle || unique_oracle
    if (in_scope) {
      declaration$status <- "validated"
      declaration$scope <- if (lmer_oracle) {
        paste0(
          "Direct mlVAR 0.7.3 oracle matrix for lmer temporal='",
          config$temporal %||% "fixed", "', contemporaneous='",
          config$contemporaneous %||% "fixed", "', lags ",
          paste(used_lags, collapse = ","),
          "; includes standardization, aligned compareToLags, trueMeans, and ",
          "position-detrending controls where applicable. The lag-1, ",
          "scale=FALSE slice is also validated on 20 real ESM panels."
        )
      } else {
        paste0(
          "Direct mlVAR 0.7.3 oracle matrix for estimator='lm', ",
          "temporal='unique', contemporaneous='", config$contemporaneous,
          "', lag 1."
        )
      }
      declaration$tolerance <- 1e-8
    }
    if (!in_scope) {
      declaration$status <- "supported_extension"
      declaration$scope <- paste0(
        "Supported mlVAR configuration outside the committed oracle matrix: ",
        "engine=", config$engine %||% "frequentist", ", estimator=",
        config$estimator %||% "lmer", ", temporal=",
        config$temporal %||% "fixed", ", contemporaneous=",
        config$contemporaneous %||% "fixed", ", lags=",
        paste(config$lags %||% attr(result, "lag") %||% 1L, collapse = ","), "."
      )
      declaration$tolerance <- NA_real_
      declaration$notes <- c(declaration$notes,
                             "Oracle evidence does not transfer beyond its declared matrix.")
    }
  }
  if (identical(spec$name, "mlvar_bayes")) {
    config <- attr(result, "config", exact = TRUE) %||% list()
    if (identical(config$residual, "random") || isTRUE(config$impute)) {
      features <- c(if (identical(config$residual, "random"))
                      "person-specific residual covariance",
                    if (isTRUE(config$impute)) "within-model imputation")
      declaration$status <- "validated_recovery"
      declaration$reference <- "simulation recovery and complete-data identity"
      declaration$scope <- paste0(
        "Native Bayesian DSEM extension: ", paste(features, collapse = " and "),
        "; validated by planted-parameter recovery, missing-cell recovery, ",
        "and sampler invariants rather than a direct Mplus fixture."
      )
      declaration$tolerance <- NA_real_
      declaration$notes <- paste0(
        "Do not interpret recovery validation as numerical Mplus equivalence."
      )
    }
  }
  if (identical(spec$name, "gimme")) {
    config <- result$config %||% list()
    p <- length(result$labels %||% character())
    group_control_tested <-
      (is.character(config$group_correct) &&
       config$group_correct %in%
         c("Bonferroni Group", "Bonferroni Paths", "fdr")) ||
      (is.numeric(config$group_correct) &&
       identical(as.numeric(config$group_correct), .01))
    fit_control_tested <-
      (identical(config$rmsea_cutoff, .05) &&
       identical(config$srmr_cutoff, .05) &&
       identical(config$nnfi_cutoff, .95) &&
       identical(config$cfi_cutoff, .95) &&
       identical(as.integer(config$n_excellent), 2L)) ||
      (identical(config$rmsea_cutoff, .1) &&
       identical(config$srmr_cutoff, .1) &&
       identical(config$nnfi_cutoff, .9) &&
       identical(config$cfi_cutoff, .9) &&
       identical(as.integer(config$n_excellent), 3L))
    bivariate_oracle <- p == 2L &&
      isTRUE(config$ar) &&
      group_control_tested &&
      config$indiv_correct %in% c("Bonferroni", "fdr") &&
      config$alpha %in% c(.05, .1) &&
      config$stop_crit %in% c("standard", "model fit", "significance") &&
      config$groupcutoff %in% c(.75, .5) &&
      fit_control_tested &&
      is.null(config$exogenous)
    multivariate_default <- p == 3L && isTRUE(config$ar) &&
      !isTRUE(config$hybrid) && !isTRUE(config$VAR) &&
      identical(config$group_correct, "Bonferroni Group") &&
      identical(config$indiv_correct, "Bonferroni") &&
      identical(config$alpha, .05) &&
      identical(config$stop_crit, "model fit") &&
      identical(config$groupcutoff, .75) && fit_control_tested &&
      (is.null(config$exogenous) || length(config$exogenous) == 1L)
    multivariate_interaction <- p == 3L && isTRUE(config$ar) &&
      isTRUE(config$hybrid) && !isTRUE(config$VAR) &&
      identical(config$group_correct, "fdr") &&
      identical(config$indiv_correct, "fdr") &&
      identical(config$alpha, .1) &&
      identical(config$stop_crit, "significance") &&
      identical(config$groupcutoff, .6) && fit_control_tested &&
      is.null(config$exogenous)
    oracle_scope <- bivariate_oracle || multivariate_default ||
      multivariate_interaction
    if (oracle_scope) {
      mode <- if (isTRUE(config$VAR)) "VAR" else if (isTRUE(config$hybrid))
        "hybrid" else "standard"
      declaration$status <- "validated"
      declaration$scope <- paste0(
        "Direct gimme 10.0 ", p, "-variable ", mode,
        "-mode oracle matrix: canonical syntax, selected paths/covariances, ",
        "counts, individual standardized coefficient and psi matrices, fit ",
        "statistics/status, correction modes, alpha, stopping criteria, ",
        "standardization, cutoffs, forced paths, uneven panel lengths, and ",
        "exogenous-variable dimensions where applicable."
      )
      declaration$tolerance <- c(0, 5e-5)
      declaration$notes <- c(
        "The gimme 10.0 argument-capture line is patched in-memory in the test ",
        "for R 4.6 compatibility; the statistical search code is unchanged.",
        "Path/search matrices are exact; 5e-5 is only the half-unit bound for ",
        "gimme's four-decimal fit-table representation. Evidence is scoped, ",
        "not blanket equivalence for unsupported ",
        "S-GIMME, latent-variable, convolution, or multiple-solution modes."
      )
    } else {
      declaration$status <- "supported_extension"
      declaration$scope <- paste0(
        "Supported native GIMME configuration outside the committed bivariate/",
        "multivariate standard/hybrid/VAR, exogenous, uneven-panel, and search-",
        "control oracle matrix."
      )
      declaration$tolerance <- NA_real_
    }
  }
  if (identical(spec$name, "usem")) {
    config <- (attr(result, "model", exact = TRUE) %||% list())$config %||%
      list()
    if (isTRUE(config$trim) ||
        !tolower(config$estimator %||% "ml") %in% c("ml", "mlr")) {
      declaration$status <- "supported_extension"
      declaration$scope <- if (isTRUE(config$trim)) {
        paste0(
          "Idiographic clean-room uSEM path search using lavaan fits; fixed-",
          "syntax engine equivalence does not establish search equivalence."
        )
      } else {
        paste0(
          "Fixed-syntax lavaan estimator='", config$estimator,
          "' outside the committed ML/MLR oracle matrix."
        )
      }
      declaration$tolerance <- NA_real_
    }
  }
  declaration
}

.ido_initialize_registry <- function() {
  if (isTRUE(.idiographic_estimators$initialized)) return(invisible(TRUE))
  previous_entries <- .idiographic_estimators$entries
  previous_aliases <- .idiographic_estimators$aliases
  initialized <- FALSE
  on.exit({
    if (!initialized) {
      .idiographic_estimators$entries <- previous_entries
      .idiographic_estimators$aliases <- previous_aliases
      .idiographic_estimators$initialized <- FALSE
    }
  }, add = TRUE)
  # Set before registration because the public and internal registration paths
  # may inspect the registry recursively.
  .idiographic_estimators$initialized <- TRUE

  add <- function(name, fit, aliases = character(), kind = "estimator",
                  description = "", result_class = character(),
                  equivalence = list()) {
    .ido_register_estimator(
      name, fit, aliases, kind, description, result_class, equivalence,
      overwrite = FALSE
    )
  }

  add("var", "fit_var", c("fit_var", "ols", "ols_var"),
      description = "Ordinary least-squares VAR(1)",
      result_class = "var_result",
      equivalence = list(
        status = "validated", reference = "stats::lm.fit",
        scope = "OLS coefficient engine and package-defined VAR(1) preprocessing.",
        tolerance = 1e-10,
        notes = "This is engine equivalence, not blanket equivalence to another VAR package."
      ))
  add("var_each", "fit_var_each", c("fit_var_each", "ols_var_each"),
      description = "One ordinary VAR per subject", result_class = "var_list",
      equivalence = list(
        status = "validated", reference = "idiographic::fit_var",
        scope = "Exact per-subject wrapper behavior.", tolerance = 0
      ))
  add("var_bayes", "fit_var_bayes",
      c("fit_var_bayes", "bayes_var", "bayesian_var"),
      description = "Native Bayesian VAR(1)", result_class = "var_bayes_result",
      equivalence = list(
        status = "partial", reference = "Mplus ESTIMATOR=BAYES",
        scope = paste0(
          "Three frozen bivariate Mplus fixtures, an OLS cross-check, and ",
          "executable burn-in/thinning/retained-draw contracts."
        ),
        tolerance = c(0.02, 0.03),
        notes = "Tolerance is statistical and parameter-dependent."
      ))
  add("graphical_var", "fit_graphical_var",
      c("fit_graphical_var", "gvar", "graphicalvar"),
      description = "Sparse graphical VAR with EBIC selection",
      result_class = "gvar_result",
      equivalence = list(
        status = "validated", reference = "graphicalVAR::graphicalVAR",
        scope = "Supported lag-1 settings, including tested beta/kappa options.",
        tolerance = 1e-6,
        notes = "The declared tolerance follows the expanded committed oracle matrix."
      ))
  add("graphical_var_each", "fit_graphical_var_each",
      c("fit_graphical_var_each", "gvar_each"),
      description = "One graphical VAR per subject", result_class = "gvar_list",
      equivalence = list(
        status = "validated", reference = "graphicalVAR::graphicalVAR",
        scope = paste0(
          "Every returned subject fit is compared directly with an upstream ",
          "lag-1 graphicalVAR fit on the same subject panel."
        ),
        tolerance = 1e-6
      ))
  add("mlvar", "fit_mlvar", c("fit_mlvar", "multilevel_var"),
      description = "Frequentist fixed-effects multilevel VAR",
      result_class = "net_mlvar",
      equivalence = list(
        status = "validated", reference = "mlVAR::mlVAR",
        scope = paste0(
          "Direct oracle matrix for every supported lag-1 lmer temporal and ",
          "contemporaneous structure, plus 20 real ESM fixed/fixed panels."
        ),
        tolerance = 1e-8,
        notes = paste0(
          "Real-panel evidence covers lag 1 with scale=FALSE; the synthetic ",
          "oracle matrix additionally covers validated multi-lag, preprocessing, ",
          "and unique-model slices."
        )
      ))
  add("mlvar_bayes", "fit_mlvar_bayes",
      c("fit_mlvar_bayes", "bayes_mlvar", "bayesian_mlvar", "dsem", "native_dsem"),
      description = "Native Bayesian multilevel VAR/DSEM",
      result_class = "net_mlvar_bayes",
      equivalence = list(
        status = "partial", reference = "Mplus DSEM",
        scope = paste0(
          "Five fixed bivariate fixtures, one univariate random-AR fixture, ",
          "multivariate recovery, missing-data recovery, and explicit MCMC ",
          "control contracts."
        ),
        tolerance = NA_real_,
        notes = "Full random-slope and missing-data feature equivalence is not established."
      ))
  add("mlvar_mplus", "fit_mlvar_mplus",
      c("fit_mlvar_mplus", "mplus", "mplus_dsem"),
      description = "Licensed Mplus-backed multilevel VAR",
      result_class = "net_mplus",
      equivalence = list(
        status = "delegated", reference = "mlVAR::mlVAR(estimator='Mplus')",
        scope = paste0(
          "Complete backend argument-forwarding and output-conversion contract; ",
          "the statistical estimator is the delegated licensed backend."
        ), tolerance = NA_real_,
        notes = paste0(
          "The committed suite tests the complete wrapper boundary with a ",
          "contract double. Running Mplus itself remains conditional on a ",
          "licensed executable."
        )
      ))
  add("usem", "fit_usem", c("fit_usem", "u_sem"),
      description = "Person-specific unified SEM", result_class = "net_usem",
      equivalence = list(
        status = "validated", reference = "lavaan::lavaan",
        scope = paste0(
          "Fixed-syntax estimates for raw/standardized panels and ML/MLR ",
          "engines; trimming remains a native search procedure."
        ),
        tolerance = 1e-8
      ))
  add("gimme", "fit_gimme", c("fit_gimme", "gimme_sem"),
      description = "Group and individual uSEM path search",
      result_class = "net_gimme",
      equivalence = list(
        status = "validated", reference = "gimme::gimme 10.0",
        scope = paste0(
          "Direct bivariate and three-variable standard/hybrid/VAR oracle ",
          "matrix covering search outputs, fit statistics, corrections, alpha, ",
          "stopping rules, standardization, fit/group cutoffs, forced paths, ",
          "exogenous variables, and uneven panels, plus recovery tests."
        ),
        tolerance = c(0, 5e-5),
        notes = paste0(
          "Unsupported S-GIMME, latent-variable, convolution, ordinal, LASSO, ",
          "and multiple-solution modes error explicitly instead of inheriting ",
          "this supported-surface claim. gimme 10.0 itself fails on the audited ",
          "ar=FALSE fixture, so that local mode remains a supported extension."
        )
      ))
  add("rolling_var", "fit_rolling_var", c("fit_rolling_var"),
      description = "Rolling-window ordinary VAR",
      result_class = "rolling_var_result",
      equivalence = list(
        status = "validated_internal", reference = "idiographic::fit_var",
        scope = paste0(
          "Every retained window is a registered VAR fit; direct-window ",
          "equality, boundaries, and planted-change recovery are tested."
        ), tolerance = 0
      ))
  add("rolling_graphical_var", "fit_rolling_graphical_var",
      c("fit_rolling_graphical_var", "rolling_gvar"),
      description = "Rolling-window graphical VAR",
      result_class = "rolling_gvar_result",
      equivalence = list(
        status = "validated_internal", reference = "idiographic::fit_graphical_var",
        scope = paste0(
          "Every retained window is a registered graphical VAR fit; direct-",
          "window equality, boundaries, and planted-change recovery are tested."
        ), tolerance = 0
      ))
  add("ml", "fit_ml",
      c("fit_ml", "idiographic_ml", "fit_idiographic_ml",
        "individualized_ml", "fit_individualized_ml"),
      description = "Idiographic supervised machine learning",
      result_class = "idioml_result",
      equivalence = list(
        status = "validated_native", reference = "base-R engines and closed forms",
        scope = paste0(
          "All regression/classification model families, selectors, prediction, ",
          "and tuning controls are exercised; linear and logistic engines are ",
          "cell-equal to lm.fit/glm.fit."
        ),
        tolerance = NA_real_
      ))

  add("preprocess", "preprocess", c("prepare", "preprocessing"),
      kind = "workflow", description = "Preprocessing and data-quality audit",
      result_class = "preprocess_result",
      equivalence = list(
        status = "validated_internal", reference = "shared lag-design engines",
        scope = paste0(
          "Exact shared GVAR lag-design equality plus deterministic diagnostic, ",
          "filtering, detrending, missingness, and threshold contracts."
        ), tolerance = 0
      ))
  add("stability", "estimate_stability",
      c("estimate_stability", "bootstrap_stability"), kind = "workflow",
      description = "Edge-stability resampling workflow",
      result_class = "stability_result",
      equivalence = list(
        status = "validated_internal", reference = "registered base estimators",
        scope = paste0(
          "Deterministic block/split-half resampling, ordering invariants, and ",
          "five-estimator dispatch contracts; no unrelated external target."
        ),
        tolerance = NA_real_
      ))
  add("compare", "compare_idiographic",
      c("compare_idiographic", "model_comparison"), kind = "workflow",
      description = "Compare fitted idiographic network methods",
      result_class = "model_comparison",
      equivalence = list(
        status = "validated_internal", reference = "registered estimator summaries",
        scope = "Exact stacking, dispatch, argument routing, and failure isolation.",
        tolerance = 0
      ))
  add("forecast", "validate_forecast",
      c("validate_forecast", "forecast_validation"), kind = "workflow",
      description = "Rolling-origin forecast validation",
      result_class = "forecast_result",
      equivalence = list(
        status = "validated_internal", reference = "direct fitted-model prediction",
        scope = paste0(
          "Rolling-origin split geometry, boundary lags, deterministic metrics, ",
          "and predictions equal direct fitted-model matrix prediction."
        ), tolerance = 0
      ))
  initialized <- TRUE
  invisible(TRUE)
}
