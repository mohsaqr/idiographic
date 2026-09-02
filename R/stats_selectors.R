.idio_check_data <- function(data, y, id) {
  if (!(is.data.frame(data) || is.matrix(data))) {
    stop("`data` must be a data frame or matrix.", call. = FALSE)
  }
  data <- as.data.frame(data)
  if (!(is.character(y) && length(y) == 1L && y %in% names(data))) {
    stop("`y` must be one outcome column name in `data`.", call. = FALSE)
  }
  if (!(is.character(id) && length(id) == 1L && id %in% names(data))) {
    stop("`id` must be one ID column name in `data`.", call. = FALSE)
  }
  data
}

#' Resolve any predictor selector to a character vector
#'
#' `exclude` names columns that can never be predictors (the outcome, the ID,
#' the treatment, the weights): they are dropped however they were selected.
#'
#' `soft_exclude` names columns that should not be swept in *by accident* -- the
#' time column above all. A range or positional selector spanning the time
#' column almost certainly did not mean to include it. But when the user names
#' it outright, they mean it: in growth data the predictor very often IS time
#' (`Reaction ~ Days`, `weight ~ Time`, `distance ~ age`), and silently dropping
#' it leaves no predictors at all.
#'
#' @noRd
.idio_resolve_x <- function(data, x, exclude = character(),
                            soft_exclude = character()) {
  explicit <- character()

  if (inherits(x, "formula")) {
    x <- attr(stats::terms(x), "term.labels")
    explicit <- x                                   # `~ a + b` names a and b
  } else if (is.data.frame(x) || is.matrix(x)) {
    x <- names(as.data.frame(x))
    if (is.null(x)) stop("Predictor data frame/matrix must have names.",
                         call. = FALSE)
  } else if (is.numeric(x)) {
    if (any(!is.finite(x)) || any(x != as.integer(x))) {
      stop("Numeric `x` must be whole-number column positions.",
           call. = FALSE)
    }
    if (any(x < 1L | x > ncol(data))) {
      stop("Numeric `x` contains positions outside `data`.", call. = FALSE)
    }
    x <- names(data)[as.integer(x)]
  } else if (is.character(x)) {
    # A literal column name is explicit; an "a:b" range token is not.
    explicit <- x[x %in% names(data)]
    x <- unlist(lapply(x, .idio_expand_x_token, data = data), use.names = FALSE)
  } else {
    stop("`x` must be column names, numeric positions, a formula, or a ",
         "data frame/matrix.", call. = FALSE)
  }

  x <- unique(as.character(x))
  x <- setdiff(x, exclude)
  x <- setdiff(x, setdiff(soft_exclude, explicit))
  if (!length(x)) stop("No predictors selected.", call. = FALSE)
  missing <- setdiff(x, names(data))
  if (length(missing)) {
    stop("Predictor column(s) not found in `data`: ",
         paste(missing, collapse = ", "), call. = FALSE)
  }
  non_numeric <- x[!vapply(data[x], is.numeric, logical(1))]
  if (length(non_numeric)) {
    stop("Predictor column(s) must be numeric: ",
         paste(non_numeric, collapse = ", "), call. = FALSE)
  }
  x
}

.idio_expand_x_token <- function(token, data) {
  if (length(token) != 1L || is.na(token) || !nzchar(token)) return(character())
  if (token %in% names(data)) return(token)
  if (!grepl(":", token, fixed = TRUE)) return(token)
  parts <- strsplit(token, ":", fixed = TRUE)[[1L]]
  if (length(parts) != 2L || !all(parts %in% names(data))) return(token)
  i <- match(parts[1L], names(data))
  j <- match(parts[2L], names(data))
  names(data)[seq.int(i, j)]
}

#' Predictors that never move within a person
#'
#' A person-level covariate (body weight, sex, condition) is constant inside
#' each person, so a person-specific model cannot estimate its effect: the
#' column is collinear with that person's intercept. Left alone this surfaces as
#' an NA coefficient, then a dropped person, then the baffling complaint that
#' too few people have usable coefficients. Name the real problem instead.
#'
#' @noRd
.idio_person_constant <- function(data, x, id) {
  key <- as.character(data[[id]])
  x[vapply(x, function(v) {
    within_sd <- tapply(data[[v]], key, function(z) {
      s <- stats::sd(z, na.rm = TRUE)
      if (is.finite(s)) s else 0
    })
    all(within_sd < .Machine$double.eps^0.5, na.rm = TRUE)
  }, logical(1))]
}

.idio_stop_person_constant <- function(data, x, id, what = "person-specific") {
  bad <- .idio_person_constant(data, x, id)
  if (!length(bad)) return(invisible(NULL))
  stop("Predictor(s) constant within every person: ",
       paste(bad, collapse = ", "),
       ". A ", what, " model cannot estimate them -- they never vary inside a ",
       "person. Drop them, use them as `moderators`, or fit with ",
       "scope = \"pooled\".", call. = FALSE)
}

.idio_scope <- function(scope) {
  scope <- match.arg(scope, c("both", "pooled", "individual", "subgroup",
                             "all"))
  switch(scope,
         both = c("pooled", "individual"),
         all = c("pooled", "subgroup", "individual"),
         pooled = "pooled",
         individual = "individual",
         subgroup = "subgroup")
}

.idio_order <- function(data, id, time = NULL) {
  if (!is.null(time)) {
    if (!(is.character(time) && length(time) == 1L && time %in% names(data))) {
      stop("`time` must be NULL or one column name in `data`.", call. = FALSE)
    }
    order(data[[id]], data[[time]], seq_len(nrow(data)))
  } else {
    order(data[[id]], seq_len(nrow(data)))
  }
}
