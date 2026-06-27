# Fit one idiographic graphical VAR per subject -> a named list of networks.

#' Fit a graphical VAR for every subject
#'
#' Applies [graphical_var()] to each subject separately, returning one
#' person-specific network per individual — the idiographic "all individuals"
#' workflow. Subjects that cannot be fit (too few lag pairs after listwise
#' deletion) are dropped with a warning.
#'
#' @inheritParams graphical_var
#' @param id Character. The subject-id column (required here).
#' @param ... Further arguments passed to [graphical_var()] (e.g. `n_lambda`,
#'   `gamma`, `scale`).
#' @return A named list of `gvar_result` objects (class `gvar_list`), one element
#'   per subject, named by subject id.
#' @export
graphical_var_each <- function(data, vars, id, day = NULL, beep = NULL,
                               min_obs = NULL, ...) {
  stopifnot(is.data.frame(data), is.character(vars), length(vars) >= 2L,
            is.character(id), length(id) == 1L, id %in% names(data))

  data <- .ido_keep(data, id, min_obs)
  ids  <- unique(data[[id]])

  fits <- lapply(ids, function(s) {
    tryCatch(
      graphical_var(data, vars = vars, id = id, day = day, beep = beep,
                    subject = s, ...),
      error = function(e) NULL
    )
  })
  names(fits) <- as.character(ids)

  failed <- vapply(fits, is.null, logical(1))
  if (any(failed)) {
    warning(sum(failed), " subject(s) could not be fit and were dropped: ",
            paste(names(fits)[failed], collapse = ", "), call. = FALSE)
    fits <- fits[!failed]
  }
  structure(fits, class = "gvar_list")
}

#' Print a list of per-subject graphical VARs
#'
#' @param x A `gvar_list`.
#' @param ... Unused.
#' @return `x`, invisibly.
#' @export
print.gvar_list <- function(x, ...) {
  if (length(x) == 0L) {
    cat("Idiographic graphical VARs\n")
    cat("  Subjects:               0 (none could be fit)\n")
    return(invisible(x))
  }
  edges <- vapply(x, function(g) sum(g$PCC[upper.tri(g$PCC)] != 0), integer(1))
  cat("Idiographic graphical VARs\n")
  cat(sprintf("  Subjects:               %d\n", length(x)))
  cat(sprintf("  Variables:              %d\n", length(x[[1]]$labels)))
  cat(sprintf("  Contemporaneous edges:  median %g (range %d-%d)\n",
              stats::median(edges), min(edges), max(edges)))
  cat(sprintf("  Access a subject with x[[\"%s\"]]\n", names(x)[1]))
  invisible(x)
}
