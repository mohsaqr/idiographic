#' Shared preparation for every fitter
#'
#' Validates the data, resolves the predictor selector, decides the task,
#' orders the rows, assigns train/valid/test roles, resolves any subgroup
#' mapping, and builds the fitting units. Every `fit_*()` function walks this
#' one path, which is what keeps their outputs interchangeable.
#'
#' @noRd
.idio_prepare <- function(data, y, x, id, time = NULL, scope = "both",
                          subgroup = NULL, test_prop = 0.2, min_train = 10L,
                          min_test = 1L, valid_prop = 0,
                          task = c("auto", "regression", "classification"),
                          roles_fun = NULL, exclude = NULL,
                          allow_person_constant = FALSE) {
  task <- match.arg(task)
  data <- .idio_check_data(data, y, id)

  # The outcome, the ID, the treatment and the weights can never be predictors.
  # The time column can: in growth data the predictor often IS time, so it is
  # only dropped when a range or positional selector swept it in by accident.
  drop <- c(y, id, exclude)
  if (is.character(subgroup) && length(subgroup) == 1L &&
      subgroup %in% names(data)) {
    drop <- c(drop, subgroup)
  }
  x <- .idio_resolve_x(data, x, exclude = drop, soft_exclude = time)

  if (task == "auto") {
    task <- if (is.numeric(data[[y]])) "regression" else "classification"
  }
  y_info <- NULL
  if (task == "classification") {
    y_info <- .idio_binary_outcome(data[[y]])
    data[[y]] <- y_info$y
  }

  scopes <- .idio_scope(scope)
  # A person-level covariate cannot be estimated by a person-specific model.
  # Pooled models are fine with it, so only complain when we actually need
  # within-person variation. A within-between model is the exception: there a
  # person-constant predictor is legitimate, because it is purely between.
  if (any(c("individual", "subgroup") %in% scopes) && !allow_person_constant) {
    .idio_stop_person_constant(data, x, id)
  }
  ord <- .idio_order(data, id, time)
  data <- data[ord, , drop = FALSE]
  data$.idio_row <- ord

  roles <- if (is.null(roles_fun)) {
    .idio_roles(data, y, x, id, test_prop = test_prop, min_train = min_train,
                min_test = min_test, valid_prop = valid_prop)
  } else {
    roles_fun(data, y, x, id)
  }
  data$.idio_role <- roles$role

  groups <- .idio_resolve_groups(data, id, subgroup)
  units <- .idio_units(data, id, scopes, groups)
  if (!length(units)) {
    stop("No person had enough complete rows to fit any model.", call. = FALSE)
  }

  list(data = data, x = x, task = task, y_info = y_info, scopes = scopes,
       groups = groups, units = units, failures = roles$failures)
}

#' Validate the shared scoped-fit structure
#' @noRd
.idio_validate_fit <- function(x, require_spec = FALSE) {
  required <- c("spec", "fits", "predictions", "metrics", "coefs", "tuning",
                "failures")
  missing <- setdiff(required, names(x))
  if (length(missing)) {
    stop("Invalid idiographic fit: missing field(s): ",
         paste(missing, collapse = ", "), ".", call. = FALSE)
  }
  if (!inherits(x, "idiographic_fit") || !inherits(x, "idiostats_fit")) {
    stop("Invalid idiographic fit: compatibility classes are incomplete.",
         call. = FALSE)
  }
  if (!is.list(x$fits)) {
    stop("Invalid idiographic fit: `fits` must be a list.", call. = FALSE)
  }
  tables <- c("predictions", "metrics", "coefs", "tuning", "failures")
  bad_tables <- tables[!vapply(x[tables], is.data.frame, logical(1))]
  if (length(bad_tables)) {
    stop("Invalid idiographic fit: table field(s) are not data frames: ",
         paste(bad_tables, collapse = ", "), ".", call. = FALSE)
  }
  if (isTRUE(require_spec) && !is.list(x$spec)) {
    stop("Invalid idiographic fit: `spec` must be a list.", call. = FALSE)
  }
  invisible(x)
}

#' Assemble a fitted idiographic object from per-unit results
#' @noRd
.idio_assemble <- function(results, failures, task, y_info, spec,
                           tuning = NULL, data = NULL) {
  ok <- !vapply(results, function(r) inherits(r, "error") || is.null(r),
                logical(1))
  bad <- results[!ok]
  if (length(bad)) {
    failures <- rbind(failures, do.call(rbind, lapply(bad, function(e) {
      .idio_failure(attr(e, "idio_scope") %||% NA_character_,
                    attr(e, "idio_model") %||% NA_character_,
                    attr(e, "idio_estimator") %||% NA_character_,
                    attr(e, "idio_subject") %||% NA_character_,
                    conditionMessage(e))
    })))
  }
  results <- results[ok]
  if (!length(results)) {
    # Say WHY. "See the reported failures" is useless when the failures are the
    # only thing standing between the user and an answer.
    reason <- if (nrow(failures)) {
      counts <- sort(table(failures$message), decreasing = TRUE)
      sprintf(" Most common reason (%d of %d): %s",
              counts[[1L]], nrow(failures), names(counts)[1L])
    } else {
      ""
    }
    stop("No model produced predictions.", reason, call. = FALSE)
  }

  preds <- do.call(rbind, lapply(results, `[[`, "pred"))
  rownames(preds) <- NULL
  coefs <- do.call(rbind, lapply(results, `[[`, "coefs"))
  rownames(coefs) <- NULL

  fits <- lapply(results, `[[`, "fit")
  names(fits) <- vapply(results, `[[`, character(1), "key")

  mets <- if (task == "classification") {
    .idio_classification_metrics(preds, y_info$positive)
  } else {
    .idio_regression_metrics(preds)
  }

  out <- structure(
    list(spec = spec, fits = fits, predictions = preds, metrics = mets,
         coefs = coefs, tuning = tuning %||% .idio_empty_tuning(),
         failures = failures, y_info = y_info, data = data),
    class = c("idiographic_fit", "idiostats_fit")
  )
  .idio_validate_fit(out, require_spec = !is.null(spec))
  out
}

#' Key a fitted unit for the `fits` list
#' @noRd
.idio_unit_key <- function(unit, model) {
  label <- if (unit$scope == "individual") unit$subject else unit$subgroup
  paste(unit$scope, model, label, sep = ":")
}

#' Attach unit context to an error so failures stay tidy
#' @noRd
.idio_tag_error <- function(e, unit, model, estimator) {
  attr(e, "idio_scope") <- unit$scope
  attr(e, "idio_model") <- model
  attr(e, "idio_estimator") <- estimator
  attr(e, "idio_subject") <- unit$subject
  e
}
