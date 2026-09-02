#' Assign ordered train/valid/test roles within each person
#'
#' Rows are assumed to be already ordered by `id` (and `time`). Within each
#' person the final `test_prop` of rows becomes `test`, the `valid_prop` of the
#' remaining rows immediately before them becomes `valid`, and everything
#' earlier becomes `train`. Holding out the *last* rows keeps the evaluation
#' honest for time-ordered data.
#'
#' `valid` rows exist only when `valid_prop > 0`, which is what `fit_ml(tune =
#' TRUE)` requests. Without tuning there is no validation set and no rows are
#' wasted.
#'
#' @noRd
.idio_roles <- function(data, y, x, id, test_prop = 0.2, min_train = 10L,
                        min_test = 1L, valid_prop = 0, min_valid = 0L) {
  .idio_proportion(test_prop, "test_prop")
  .idio_count(min_train, "min_train")
  .idio_count(min_test, "min_test")
  if (!(is.numeric(valid_prop) && length(valid_prop) == 1L &&
        is.finite(valid_prop) && valid_prop >= 0 && valid_prop < 1)) {
    stop("`valid_prop` must be a number in [0, 1).", call. = FALSE)
  }

  needed <- c(y, x)
  subjects <- unique(as.character(data[[id]]))
  role <- rep("skip", nrow(data))

  parts <- lapply(subjects, .idio_roles_one, data = data, id = id,
                  needed = needed, test_prop = test_prop,
                  min_train = min_train, min_test = min_test,
                  valid_prop = valid_prop, min_valid = min_valid)

  assigned <- do.call(rbind, lapply(parts, `[[`, "assign"))
  if (!is.null(assigned)) role[assigned$index] <- assigned$role

  failures <- do.call(rbind, lapply(parts, `[[`, "failure"))
  if (is.null(failures)) failures <- .idio_empty_failures()

  list(role = role, failures = failures)
}

.idio_roles_one <- function(subject, data, id, needed, test_prop, min_train,
                            min_test, valid_prop, min_valid) {
  idx <- which(as.character(data[[id]]) == subject)
  n <- length(idx)

  n_test <- min(max(as.integer(min_test), ceiling(n * test_prop)), n - 1L)
  if (!is.finite(n_test) || n_test < min_test) {
    return(list(assign = NULL,
                failure = .idio_split_failure(subject,
                                              "Too few rows for train/test split.")))
  }

  n_rest <- n - n_test
  n_valid <- if (valid_prop > 0) {
    min(max(as.integer(min_valid), ceiling(n_rest * valid_prop)), n_rest - 1L)
  } else {
    0L
  }
  if (!is.finite(n_valid) || n_valid < 0L) n_valid <- 0L

  n_train <- n_rest - n_valid
  train_idx <- idx[seq_len(n_train)]
  valid_idx <- if (n_valid > 0L) idx[n_train + seq_len(n_valid)] else integer()
  test_idx <- idx[n_rest + seq_len(n_test)]

  complete <- function(i) {
    if (!length(i)) return(integer())
    i[stats::complete.cases(data[i, needed, drop = FALSE])]
  }
  train_ok <- complete(train_idx)
  valid_ok <- complete(valid_idx)
  test_ok <- complete(test_idx)

  if (length(train_ok) < min_train || length(test_ok) < min_test ||
      (valid_prop > 0 && length(valid_ok) < max(1L, min_valid))) {
    msg <- sprintf(
      "Insufficient complete rows (train = %d, valid = %d, test = %d).",
      length(train_ok), length(valid_ok), length(test_ok)
    )
    return(list(assign = NULL, failure = .idio_split_failure(subject, msg)))
  }

  list(
    assign = data.frame(
      index = c(train_ok, valid_ok, test_ok),
      role = rep(c("train", "valid", "test"),
                 c(length(train_ok), length(valid_ok), length(test_ok))),
      stringsAsFactors = FALSE
    ),
    failure = NULL
  )
}

.idio_split_failure <- function(subject, message) {
  data.frame(scope = "split", model = ".split", estimator = ".split",
             subject = subject, message = message, stringsAsFactors = FALSE)
}

.idio_empty_failures <- function() {
  data.frame(scope = character(), model = character(), estimator = character(),
             subject = character(), message = character(),
             stringsAsFactors = FALSE)
}

.idio_count <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) &&
        x >= 1L && x == as.integer(x))) {
    stop("`", arg, "` must be a whole number >= 1.", call. = FALSE)
  }
}

.idio_proportion <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) && x > 0 && x < 1)) {
    stop("`", arg, "` must be a number between 0 and 1.", call. = FALSE)
  }
}
