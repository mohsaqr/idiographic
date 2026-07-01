# ---- Rolling-window ordinary VAR ----

#' Estimate rolling-window ordinary VAR networks
#'
#' @description
#' Fits [build_var()] over ordered, overlapping windows within each subject.
#' This is a simple time-varying idiographic baseline: every window uses the
#' same lag construction, scaling, within-person centering, and tidy coefficient
#' access as [build_var()], but returns one coefficient table per window.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param id Character. Name of the person-ID column, or `NULL` for a single
#'   series.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param window_size Integer number of ordered rows per rolling window.
#' @param step Integer number of rows to advance between windows. Default `1`.
#' @param scale Logical. Whether to standardize variables inside each window.
#'   Default `TRUE`.
#' @param center_within Logical. Whether to center within person inside each
#'   window when more than one id is present. Default `TRUE`.
#' @param delete_missings Logical. Drop incomplete current/lagged rows. Default
#'   `TRUE`.
#' @param min_obs Integer or `NULL`. Keep only subjects with at least this many
#'   observations before rolling.
#' @param subject Optional vector naming the subject(s) to analyse.
#' @param keep_fits Logical. Store successful `var_result` fits? Default
#'   `FALSE`.
#'
#' @return A `rolling_var_result` with `$estimates`, `$windows`, `$failures`,
#'   and optionally `$fits`. `$estimates` is a tidy coefficient table with
#'   subject/window metadata plus `network`, `from`, `to`, and `weight`.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, day = rep(1:5, each = 20),
#'                 beep = rep(1:20, 5),
#'                 A = rnorm(100), B = rnorm(100), C = rnorm(100))
#' tv <- rolling_var(d, vars = c("A", "B", "C"), id = "id",
#'                   day = "day", beep = "beep",
#'                   window_size = 40, step = 20, scale = FALSE)
#' head(tv$estimates)
#' @export
rolling_var <- function(data, vars, id = NULL, day = NULL, beep = NULL,
                        window_size,
                        step = 1L,
                        scale = TRUE,
                        center_within = TRUE,
                        delete_missings = TRUE,
                        min_obs = NULL,
                        subject = NULL,
                        keep_fits = FALSE) {
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  .rolling_check_count(window_size, "window_size")
  .rolling_check_count(step, "step")
  .ido_check_flag(scale, "scale")
  .ido_check_flag(center_within, "center_within")
  .ido_check_flag(delete_missings, "delete_missings")
  .ido_check_flag(keep_fits, "keep_fits")

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  data <- .ido_keep(data, id, min_obs, subject)

  ordered <- .rolling_order_data(data, id, day, beep)
  ids <- unique(ordered$.rolling_subject)
  estimates <- list()
  windows <- list()
  failures <- data.frame(subject = character(), window = integer(),
                         message = character(), stringsAsFactors = FALSE)
  fits <- list()
  pos <- 0L
  fit_pos <- 0L

  for (sid in ids) {
    idx <- which(ordered$.rolling_subject == sid)
    if (length(idx) < window_size) next
    starts <- seq.int(1L, length(idx) - window_size + 1L, by = step)
    for (w in seq_along(starts)) {
      local <- seq.int(starts[w], starts[w] + window_size - 1L)
      rows <- idx[local]
      d_win <- ordered[rows, setdiff(names(ordered), c(".rolling_subject",
                                                       ".rolling_row")),
                       drop = FALSE]
      fit <- tryCatch(
        build_var(d_win, vars = vars, id = id, day = day, beep = beep,
                  scale = scale, center_within = center_within,
                  delete_missings = delete_missings),
        error = function(e) e
      )
      win <- .rolling_window_row(ordered, rows, sid, w, day, beep)
      windows[[length(windows) + 1L]] <- win
      if (inherits(fit, "error")) {
        failures <- rbind(failures,
                          data.frame(subject = as.character(sid), window = w,
                                     message = fit$message,
                                     stringsAsFactors = FALSE))
        next
      }
      tab <- coefs(fit)
      tab <- cbind(win[rep(1L, nrow(tab)), , drop = FALSE], tab)
      estimates[[length(estimates) + 1L]] <- tab
      if (isTRUE(keep_fits)) {
        fit_pos <- fit_pos + 1L
        fits[[fit_pos]] <- fit
        names(fits)[fit_pos] <- paste(sid, w, sep = ":")
      }
      pos <- pos + 1L
    }
  }

  if (length(estimates) == 0L) {
    stop("No rolling VAR windows could be fit. Increase data length, reduce ",
         "`window_size`, or inspect `$failures` from smaller trials.",
         call. = FALSE)
  }
  out <- list(
    estimates = do.call(rbind, estimates),
    windows = do.call(rbind, windows),
    failures = failures,
    fits = if (isTRUE(keep_fits)) fits else NULL,
    n_windows = pos,
    labels = vars,
    config = list(id = id, day = day, beep = beep,
                  window_size = as.integer(window_size),
                  step = as.integer(step), scale = scale,
                  center_within = center_within,
                  delete_missings = delete_missings)
  )
  rownames(out$estimates) <- NULL
  rownames(out$windows) <- NULL
  class(out) <- "rolling_var_result"
  out
}

#' @noRd
.rolling_check_count <- function(x, arg) {
  if (!(is.numeric(x) && length(x) == 1L && is.finite(x) &&
        x >= 1L && x == as.integer(x))) {
    stop("`", arg, "` must be a single finite whole number >= 1.",
         call. = FALSE)
  }
}

#' @noRd
.rolling_order_data <- function(data, id, day, beep) {
  n <- nrow(data)
  idv <- if (is.null(id)) rep("1", n) else as.character(data[[id]])
  dayv <- if (is.null(day)) rep(1L, n) else data[[day]]
  beepv <- if (is.null(beep)) seq_len(n) else data[[beep]]
  ord <- order(idv, dayv, beepv)
  out <- data[ord, , drop = FALSE]
  out$.rolling_subject <- idv[ord]
  out$.rolling_row <- seq_len(n)[ord]
  out
}

#' @noRd
.rolling_window_row <- function(ordered, rows, subject, window, day, beep) {
  first <- rows[1L]
  last <- rows[length(rows)]
  day_col <- if (!is.null(day)) ordered[[day]] else rep(NA, nrow(ordered))
  beep_col <- if (!is.null(beep)) ordered[[beep]] else rep(NA, nrow(ordered))
  data.frame(
    subject = as.character(subject),
    window = as.integer(window),
    start_row = ordered$.rolling_row[first],
    end_row = ordered$.rolling_row[last],
    start_day = as.character(day_col[first]),
    end_day = as.character(day_col[last]),
    start_beep = beep_col[first],
    end_beep = beep_col[last],
    stringsAsFactors = FALSE
  )
}

#' Print method for rolling VAR results
#'
#' @param x A `rolling_var_result` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.rolling_var_result <- function(x, ...) {
  cat("Rolling VAR Result\n")
  cat(sprintf("  Subjects:   %d\n", length(unique(x$windows$subject))))
  cat(sprintf("  Windows:    %d\n", x$n_windows))
  cat(sprintf("  Variables:  %d (%s)\n",
              length(x$labels), paste(x$labels, collapse = ", ")))
  cat("  Tables:     x$estimates | x$windows | x$failures\n")
  if (!is.null(x$fits) && length(x$fits) > 0L) {
    cat("  Cograph:    cograph::splot(x$fits[[1]])\n")
    cat("  Matrices:   matrices(x$fits[[1]])\n")
  } else {
    cat("  Fits:       rerun with keep_fits = TRUE for cograph plots\n")
  }
  invisible(x)
}

#' @export
as.data.frame.rolling_var_result <- function(x, row.names = NULL,
                                             optional = FALSE, ...) {
  x$estimates
}
