# The model registry.
#
# Before this existed a caller had to know which backend a model lived in --
# `fit_ml(..., model = "forest", estimator = "ranger")` -- which is knowledge
# about the package's plumbing, not about the modelling question. The registry
# maps a model NAME to everything needed to fit it, so `model = "forest"` is
# enough and `estimator =` is only for disambiguation when the same model
# exists in more than one backend (ridge, lasso and elastic do; svm and bayes
# do).
#
# Adding an algorithm means adding one row here plus a fit and a predict
# branch. Nothing else in the package needs to change.

#' Every model the package can fit
#'
#' Columns: `model`, `estimator` (the backend), `package` (NA when base R or
#' hand-written), `regression`/`classification` (whether the task is
#' supported), and `parameter` (the single tunable, NA when there is none).
#'
#' Order matters: when a model name appears under several estimators, the
#' FIRST row wins as the default, which is why every native implementation is
#' listed before its external equivalent.
#'
#' @noRd
.idio_registry <- function() {
  spec <- function(model, estimator, package, regression, classification,
                   parameter = NA_character_) {
    data.frame(model = model, estimator = estimator, package = package,
               regression = regression, classification = classification,
               parameter = parameter, stringsAsFactors = FALSE)
  }
  rbind(
    # -- hand-written, base R only ------------------------------------------
    spec("mean",      "native", NA, TRUE,  FALSE),
    spec("majority",  "native", NA, FALSE, TRUE),
    spec("linear",    "native", NA, TRUE,  FALSE),
    spec("logistic",  "native", NA, FALSE, TRUE),
    spec("ridge",     "native", NA, TRUE,  TRUE,  "lambda"),
    spec("lasso",     "native", NA, TRUE,  TRUE,  "lambda"),
    spec("elastic",   "native", NA, TRUE,  TRUE,  "lambda"),
    spec("pcr",       "native", NA, TRUE,  FALSE, "ncomp"),
    spec("knn",       "native", NA, TRUE,  TRUE,  "k"),
    spec("tree",      "native", NA, TRUE,  TRUE),
    spec("boost",     "native", NA, TRUE,  TRUE,  "rounds"),
    spec("spline",    "native", NA, TRUE,  TRUE,  "df"),
    spec("lda",       "native", NA, FALSE, TRUE),
    spec("bayes",     "native", NA, FALSE, TRUE),
    # -- base R, via stats --------------------------------------------------
    spec("loess",     "stats",  NA, TRUE,  FALSE, "span"),
    spec("ppr",       "stats",  NA, TRUE,  FALSE, "nterms"),
    spec("isotonic",  "stats",  NA, TRUE,  FALSE),
    # -- packages that ship with R -----------------------------------------
    spec("cart",      "rpart",  "rpart", TRUE,  TRUE,  "cp"),
    spec("mlp",       "nnet",   "nnet",  TRUE,  TRUE,  "size"),
    spec("multinom",  "nnet",   "nnet",  FALSE, TRUE,  "decay"),
    spec("gam",       "mgcv",   "mgcv",  TRUE,  TRUE,  "k"),
    spec("qda",       "MASS",   "MASS",  FALSE, TRUE),
    # -- optional backends --------------------------------------------------
    spec("ridge",     "glmnet", "glmnet", TRUE, TRUE,  "lambda"),
    spec("lasso",     "glmnet", "glmnet", TRUE, TRUE,  "lambda"),
    spec("elastic",   "glmnet", "glmnet", TRUE, TRUE,  "lambda"),
    spec("forest",    "ranger", "ranger", TRUE, TRUE,  "mtry"),
    spec("extratrees", "ranger", "ranger", TRUE, TRUE, "mtry"),
    spec("svm",       "e1071",  "e1071",  TRUE, TRUE,  "cost"),
    spec("bayes",     "e1071",  "e1071",  FALSE, TRUE),
    spec("xgboost",   "xgboost", "xgboost", TRUE, TRUE, "rounds"),
    spec("ksvm",      "kernlab", "kernlab", TRUE, TRUE, "cost"),
    spec("gp",        "kernlab", "kernlab", TRUE, TRUE),
    spec("pls",       "pls",    "pls",    TRUE,  FALSE, "ncomp"),
    spec("ctree",     "partykit", "partykit", TRUE, TRUE, "alpha"),
    spec("quantile",  "quantreg", "quantreg", TRUE, FALSE),
    spec("rf",        "randomForest", "randomForest", TRUE, TRUE, "mtry"),
    spec("glmboost",  "mboost", "mboost", TRUE,  TRUE,  "rounds")
  )
}

#' Registry rows that can do this task
#' @noRd
.idio_registry_for <- function(task) {
  reg <- .idio_registry()
  reg[if (task == "regression") reg$regression else reg$classification, ,
      drop = FALSE]
}

#' Models available for a task and estimator
#'
#' `estimator = "auto"` means "any backend", which is what makes `model =`
#' alone sufficient.
#'
#' @noRd
.idio_ml_choices <- function(task, estimator = "native") {
  reg <- .idio_registry_for(task)
  if (!identical(estimator, "auto")) {
    if (!estimator %in% .idio_registry()$estimator) {
      stop("Unknown estimator: ", estimator, call. = FALSE)
    }
    reg <- reg[reg$estimator == estimator, , drop = FALSE]
  }
  unique(reg$model)
}

#' Resolve a model name to the backend that will fit it
#'
#' With `estimator = "auto"` the first registered backend wins, which is always
#' the native or base-R one where a choice exists -- so the default stays
#' dependency-free and a caller only names an estimator to override that.
#'
#' @noRd
.idio_resolve_model <- function(model, task, estimator = "auto") {
  reg <- .idio_registry_for(task)
  rows <- reg[reg$model == model, , drop = FALSE]
  if (!nrow(rows)) {
    available <- paste(sort(unique(reg$model)), collapse = ", ")
    other <- .idio_registry()
    other <- other[other$model == model, , drop = FALSE]
    hint <- if (nrow(other)) {
      paste0("\n\"", model, "\" exists, but not for ", task, ".")
    } else {
      ""
    }
    stop("Unknown model \"", model, "\" for ", task, ".", hint,
         "\nAvailable: ", available, call. = FALSE)
  }
  if (!identical(estimator, "auto")) {
    rows <- rows[rows$estimator == estimator, , drop = FALSE]
    if (!nrow(rows)) {
      stop("Model \"", model, "\" is not provided by estimator \"", estimator,
           "\". It is provided by: ",
           paste(reg$estimator[reg$model == model], collapse = ", "), ".",
           call. = FALSE)
    }
  }
  row <- rows[1L, , drop = FALSE]
  if (!is.na(row$package)) .idio_require(row$package, row$estimator)
  row
}

#' Which backends are usable right now
#'
#' A model whose package is not installed is still registered; it simply cannot
#' be fitted until the package is there. `available` says which is which, so
#' `model = "all"` can skip the ones that would only error.
#'
#' @noRd
.idio_registry_available <- function(task, estimator = "auto") {
  reg <- .idio_registry_for(task)
  if (!identical(estimator, "auto")) {
    reg <- reg[reg$estimator == estimator, , drop = FALSE]
  }
  installed <- is.na(reg$package) |
    vapply(reg$package, function(p) {
      is.na(p) || requireNamespace(p, quietly = TRUE)
    }, logical(1))
  unique(reg$model[installed])
}

#' List every model the package knows about
#'
#' One row per model per backend: what task it can do, which package provides
#' it, whether that package is installed here, and what its single tunable
#' parameter is.
#'
#' Models are named, not numbered: `fit_ml(..., model = "cart")` finds its own
#' backend, and `estimator =` is needed only to force a particular one when a
#' model exists in several (`ridge`, `lasso`, `elastic`, `svm`, `bayes`).
#'
#' @param task Optional `"regression"` or `"classification"` filter.
#' @param available Only models whose package is installed here.
#' @return A `data.frame` with class `idiographic_models`.
#' @examples
#' models()
#' models(task = "classification", available = TRUE)
#' @export
models <- function(task = NULL, available = FALSE) {
  reg <- .idio_registry()
  if (!is.null(task)) {
    task <- match.arg(task, c("regression", "classification"))
    reg <- reg[if (task == "regression") reg$regression else reg$classification,
               , drop = FALSE]
  }
  reg$installed <- vapply(reg$package, function(p) {
    is.na(p) || requireNamespace(p, quietly = TRUE)
  }, logical(1))
  reg$package[is.na(reg$package)] <- "base"
  if (available) reg <- reg[reg$installed, , drop = FALSE]
  rownames(reg) <- NULL
  structure(reg, class = c("idiographic_models", "idiostats_models",
                           "data.frame"))
}

#' @export
print.idiostats_models <- function(x, ...) {
  tab <- as.data.frame(x)
  if (!.idio_printable(tab, c("model", "estimator", "package"))) {
    return(print.data.frame(tab, ...))
  }
  cat("MODELS\n")
  .idio_print_info(rbind(
    c("Registered", format(nrow(tab))),
    c("Usable here", format(sum(tab$installed)))
  ))
  cat("\n")
  yesno <- function(v) ifelse(v, "yes", "-")
  .idio_print_block(
    cbind(tab$model, tab$estimator, tab$package, yesno(tab$regression),
          yesno(tab$classification), yesno(tab$installed),
          ifelse(is.na(tab$parameter), "-", tab$parameter)),
    headers = c("model", "estimator", "package", "regr", "class", "here",
                "tunes"),
    n_left = 3L
  )
  cat("\n  model = names above are enough; estimator = only to disambiguate\n")
  invisible(x)
}
