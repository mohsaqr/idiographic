#' Build the list of fitting units for a fit
#'
#' A *unit* is one model to be fitted: a scope, the label its coefficients are
#' filed under, its subgroup label, and the rows it owns. Pooled, individual and
#' subgroup models differ only in which rows they see, so every fitter can be
#' written as a single `lapply()` over units instead of nested branching.
#'
#' `subject` here is the label used for the *coefficient* table: a pooled or
#' subgroup model has one coefficient set, so it is filed under `.all`. The
#' prediction table always carries the real person ID of each row, which is what
#' lets pooled and individual models be compared person by person.
#'
#' @noRd
.idio_units <- function(data, id, scopes, groups = NULL) {
  ids <- as.character(data[[id]])
  eligible <- unique(ids[data$.idio_role != "skip"])

  units <- list()

  if ("pooled" %in% scopes) {
    units <- c(units, list(list(
      scope = "pooled", subject = ".all", subgroup = ".all",
      rows = which(ids %in% eligible)
    )))
  }

  if ("subgroup" %in% scopes) {
    if (is.null(groups)) {
      stop("`scope` includes \"subgroup\" but no `subgroup` was supplied.",
           call. = FALSE)
    }
    members <- groups[names(groups) %in% eligible]
    labels <- sort(unique(as.character(members)))
    units <- c(units, lapply(labels, function(g) {
      list(scope = "subgroup", subject = ".all", subgroup = g,
           rows = which(ids %in% names(members)[members == g]))
    }))
  }

  if ("individual" %in% scopes) {
    units <- c(units, lapply(sort(eligible), function(s) {
      list(scope = "individual", subject = s, subgroup = ".none",
           rows = which(ids == s))
    }))
  }

  units
}

#' Resolve a subgroup specification to a named subject -> label vector
#'
#' Accepts an `idiostats_groups` object, a grouping column in `data`, a named
#' vector, or a two-column data frame. The caller never has to assemble the
#' mapping by hand.
#'
#' @noRd
.idio_resolve_groups <- function(data, id, subgroup) {
  if (is.null(subgroup)) return(NULL)
  ids <- as.character(data[[id]])

  if (inherits(subgroup, "idiostats_groups")) {
    subgroup <- subgroup$groups
  }
  if (is.data.frame(subgroup)) {
    if (!all(c("subject", "subgroup") %in% names(subgroup))) {
      stop("A subgroup data frame needs `subject` and `subgroup` columns.",
           call. = FALSE)
    }
    out <- stats::setNames(as.character(subgroup$subgroup),
                           as.character(subgroup$subject))
  } else if (is.character(subgroup) && length(subgroup) == 1L &&
             subgroup %in% names(data)) {
    tab <- unique(data.frame(subject = ids,
                             subgroup = as.character(data[[subgroup]]),
                             stringsAsFactors = FALSE))
    if (anyDuplicated(tab$subject)) {
      stop("Subgroup column `", subgroup,
           "` must be constant within each person.", call. = FALSE)
    }
    out <- stats::setNames(tab$subgroup, tab$subject)
  } else if (!is.null(names(subgroup))) {
    out <- stats::setNames(as.character(subgroup), names(subgroup))
  } else {
    stop("`subgroup` must be an idiostats_groups object, a column name in ",
         "`data`, a named vector, or a data frame with subject/subgroup ",
         "columns.", call. = FALSE)
  }

  missing <- setdiff(unique(ids), names(out))
  if (length(missing) == length(unique(ids))) {
    stop("No person in `data` matches the supplied subgroup labels.",
         call. = FALSE)
  }
  out[!is.na(out)]
}

#' Rows of a unit holding a given role
#' @noRd
.idio_unit_rows <- function(data, unit, role) {
  data[intersect(unit$rows, which(data$.idio_role %in% role)), , drop = FALSE]
}
