# ---- Edge stability / reliability by block resampling ----

#' Estimate edge stability by block resampling (experimental)
#'
#' @description
#' **Experimental.** The resampling design is methodologically grounded (block
#' bootstrap for dependent data; edge-stability summaries in the spirit of
#' bootnet), but unlike the estimators in this package it has no external
#' reference implementation to validate against, and its interface, defaults,
#' and reported statistics may change in a future release.
#'
#' Refit an idiographic estimator across deterministic block resamples and
#' summarize edge-level stability. Blocks preserve within-block time order:
#' subject-day blocks when `id` and `day` are supplied, subjects when only `id`
#' is supplied, days when only `day` is supplied, or consecutive row blocks for
#' a single series. Duplicate blocks receive temporary ids/day labels before
#' fitting so lag construction never connects two sampled copies.
#'
#' @param data A `data.frame` or matrix with columns for variables and optional
#'   id/day/beep columns.
#' @param vars Character vector of variable names.
#' @param estimator `"var"` (default) for [fit_var()], `"graphical_var"` for
#'   [fit_graphical_var()], `"mlvar"` for [fit_mlvar()], `"usem"` for
#'   [fit_usem()], or `"gimme"` for [fit_gimme()].
#' @param id Character. Name of the person-ID column, or `NULL`.
#' @param day Character. Name of the day/session column, or `NULL`.
#' @param beep Character. Name of the measurement-occasion column, or `NULL`.
#' @param n_resamples Integer number of bootstrap/split resamples.
#' @param resample `"block"` samples blocks with replacement; `"split_half"`
#'   samples half the blocks without replacement on each replicate.
#' @param block_size Integer or `NULL`. Consecutive block length used only when
#'   neither `id` nor `day` is supplied. Defaults to `floor(sqrt(nrow(data)))`.
#' @param threshold Numeric. Absolute weight above which an edge is counted as
#'   selected. Default `1e-8`.
#' @param seed Optional integer seed for deterministic resampling.
#' @param keep_fits Logical. Store successful resampled fits in the returned
#'   object? Default `FALSE`.
#' @param ... Further arguments passed to the estimator.
#'
#' @return A `stability_result` with `$stability` edge statistics, `$original`
#'   fit, `$resample_edges`, `$failures`, and `$config`.
#' @examples
#' set.seed(1)
#' d <- data.frame(id = 1, day = rep(1:4, each = 12),
#'                 beep = rep(1:12, 4),
#'                 A = rnorm(48), B = rnorm(48), C = rnorm(48))
#' st <- estimate_stability(d, vars = c("A", "B", "C"), id = "id",
#'                          day = "day", beep = "beep",
#'                          n_resamples = 5, seed = 1)
#' head(st$stability)
#' @export
estimate_stability <- function(data, vars,
                               estimator = c("var", "graphical_var", "mlvar",
                                             "usem", "gimme"),
                               id = NULL, day = NULL, beep = NULL,
                               n_resamples = 100L,
                               resample = c("block", "split_half"),
                               block_size = NULL,
                               threshold = 1e-8,
                               seed = NULL,
                               keep_fits = FALSE,
                               ...) {
  estimator <- match.arg(estimator)
  resample <- match.arg(resample)
  stopifnot(is.data.frame(data) || is.matrix(data))
  stopifnot(is.character(vars), length(vars) >= 2L)
  stopifnot(is.numeric(n_resamples), length(n_resamples) == 1L,
            is.finite(n_resamples), n_resamples >= 1L,
            n_resamples == as.integer(n_resamples))
  stopifnot(is.numeric(threshold), length(threshold) == 1L,
            is.finite(threshold), threshold >= 0)
  .ido_check_flag(keep_fits, "keep_fits")

  data <- as.data.frame(data)
  if (!all(vars %in% names(data))) {
    stop("Variables not found in data: ",
         paste(setdiff(vars, names(data)), collapse = ", "), call. = FALSE)
  }
  .ido_check_col(id, "id", data)
  .ido_check_col(day, "day", data)
  .ido_check_col(beep, "beep", data)
  if (estimator %in% c("mlvar", "usem", "gimme") && is.null(id)) {
    stop("estimator = '", estimator, "' requires an `id` column.",
         call. = FALSE)
  }
  if (!is.null(block_size)) {
    stopifnot(is.numeric(block_size), length(block_size) == 1L,
              is.finite(block_size), block_size >= 2L,
              block_size == as.integer(block_size))
  }

  original <- .stability_fit(estimator, data, vars, id, day, beep, ...)
  original_edges <- .stability_edges(original)
  plan <- .stability_plan(data, id, day, beep, block_size)
  if (nrow(plan$blocks) < 2L && identical(resample, "split_half")) {
    stop("split_half resampling requires at least two blocks.", call. = FALSE)
  }

  if (!is.null(seed)) set.seed(seed)
  fits <- vector("list", n_resamples)
  edge_tabs <- vector("list", n_resamples)
  failures <- data.frame(resample = integer(), message = character(),
                         stringsAsFactors = FALSE)

  for (b in seq_len(n_resamples)) {
    selected <- .stability_select_blocks(nrow(plan$blocks), resample)
    boot <- .stability_resample_data(data, plan, selected, id, day)
    fit <- tryCatch(
      .stability_fit(estimator, boot$data, vars,
                     id = boot$id, day = boot$day, beep = boot$beep, ...),
      error = function(e) e
    )
    if (inherits(fit, "error")) {
      failures <- rbind(failures,
                        data.frame(resample = b, message = fit$message,
                                   stringsAsFactors = FALSE))
      next
    }
    if (isTRUE(keep_fits)) fits[[b]] <- fit
    tab <- .stability_edges(fit)
    tab$resample <- b
    edge_tabs[[b]] <- tab
  }

  edge_tabs <- edge_tabs[!vapply(edge_tabs, is.null, logical(1))]
  if (length(edge_tabs) == 0L) {
    stop("No resampled fits succeeded.", call. = FALSE)
  }
  resample_edges <- do.call(rbind, edge_tabs)
  rownames(resample_edges) <- NULL
  stability <- .stability_summarise(original_edges, resample_edges, threshold)

  out <- list(
    stability = stability,
    original = original,
    resample_edges = resample_edges,
    failures = failures,
    fits = if (isTRUE(keep_fits)) fits else NULL,
    n_success = length(edge_tabs),
    n_resamples = as.integer(n_resamples),
    config = list(estimator = estimator, resample = resample,
                  threshold = threshold, seed = seed, id = id, day = day,
                  beep = beep, block_size = plan$block_size)
  )
  class(out) <- "stability_result"
  out
}

#' @noRd
.stability_fit <- function(estimator, data, vars, id, day, beep, ...) {
  if (identical(estimator, "var")) {
    fit_var(data, vars = vars, id = id, day = day, beep = beep, ...)
  } else if (identical(estimator, "graphical_var")) {
    fit_graphical_var(data, vars = vars, id = id, day = day, beep = beep, ...)
  } else if (identical(estimator, "mlvar")) {
    fit_mlvar(data, vars = vars, id = id, day = day, beep = beep, ...)
  } else if (identical(estimator, "usem")) {
    fit_usem(data, vars = vars, id = id, day = day, beep = beep, ...)
  } else {
    fit_gimme(data, vars = vars, id = id, day = day, beep = beep, ...)
  }
}

#' @noRd
.stability_edges <- function(fit) {
  out <- if (inherits(fit, c("var_result", "gvar_result"))) {
    coefs(fit)
  } else {
    edges(fit, include_self = TRUE)
  }
  need <- c("network", "from", "to", "weight")
  if (!all(need %in% names(out))) {
    stop("Estimator produced no standard edge table with columns: ",
         paste(need, collapse = ", "), call. = FALSE)
  }
  out <- out[, need, drop = FALSE]
  rownames(out) <- NULL
  out
}

#' @noRd
.stability_plan <- function(data, id, day, beep, block_size) {
  n <- nrow(data)
  key <- if (!is.null(id) && !is.null(day)) {
    paste(data[[id]], data[[day]], sep = "\r")
  } else if (!is.null(id)) {
    paste(data[[id]], sep = "\r")
  } else if (!is.null(day)) {
    paste(data[[day]], sep = "\r")
  } else {
    if (is.null(block_size)) block_size <- max(2L, floor(sqrt(n)))
    paste(ceiling(seq_len(n) / block_size), sep = "\r")
  }
  if (is.null(block_size)) block_size <- NA_integer_

  split_idx <- split(seq_len(n), key)
  blocks <- data.frame(
    block = seq_along(split_idx),
    key = names(split_idx),
    n_rows = vapply(split_idx, length, integer(1)),
    stringsAsFactors = FALSE
  )
  list(indices = split_idx, blocks = blocks, block_size = block_size,
       beep = beep)
}

#' @noRd
.stability_select_blocks <- function(n_blocks, resample) {
  if (identical(resample, "block")) {
    sample.int(n_blocks, size = n_blocks, replace = TRUE)
  } else {
    sample.int(n_blocks, size = ceiling(n_blocks / 2), replace = FALSE)
  }
}

#' @noRd
.stability_resample_data <- function(data, plan, selected, id, day) {
  tmp_id <- ".idiographic_stability_id"
  tmp_day <- ".idiographic_stability_day"
  tmp_beep <- ".idiographic_stability_beep"
  if (any(c(tmp_id, tmp_day, tmp_beep) %in% names(data))) {
    stop("Input data already contains reserved stability columns.", call. = FALSE)
  }

  parts <- lapply(seq_along(selected), function(pos) {
    idx <- plan$indices[[selected[pos]]]
    d <- data[idx, , drop = FALSE]
    if (!is.null(plan$beep)) {
      d <- d[order(d[[plan$beep]]), , drop = FALSE]
    }
    d[[tmp_id]] <- if (!is.null(id) && !is.null(day)) {
      as.character(d[[id]])
    } else if (!is.null(id)) {
      paste0(as.character(d[[id]]), "__", pos)
    } else {
      "1"
    }
    d[[tmp_day]] <- if (!is.null(day)) pos else pos
    d[[tmp_beep]] <- seq_len(nrow(d))
    d
  })
  out <- do.call(rbind, parts)
  rownames(out) <- NULL
  list(data = out, id = tmp_id, day = tmp_day, beep = tmp_beep)
}

#' @noRd
.stability_key <- function(x) paste(x$network, x$from, x$to, sep = "\r")

#' @noRd
.stability_summarise <- function(original_edges, resample_edges, threshold) {
  original_edges$key <- .stability_key(original_edges)
  resample_edges$key <- .stability_key(resample_edges)
  keys <- unique(c(original_edges$key, resample_edges$key))
  reps <- sort(unique(resample_edges$resample))

  rows <- lapply(keys, function(k) {
    proto <- original_edges[match(k, original_edges$key), , drop = FALSE]
    if (is.na(proto$key[1L])) {
      proto <- resample_edges[match(k, resample_edges$key), , drop = FALSE]
    }
    original_weight <- original_edges$weight[match(k, original_edges$key)]
    if (is.na(original_weight)) original_weight <- 0
    w <- numeric(length(reps))
    for (i in seq_along(reps)) {
      hit <- which(resample_edges$resample == reps[i] &
                   resample_edges$key == k)
      w[i] <- if (length(hit)) resample_edges$weight[hit[1L]] else 0
    }
    qs <- stats::quantile(w, probs = c(0.05, 0.5, 0.95), names = FALSE,
                          na.rm = TRUE, type = 8)
    data.frame(
      network = proto$network[1L],
      from = proto$from[1L],
      to = proto$to[1L],
      original = original_weight,
      mean = mean(w),
      sd = if (length(w) > 1L) stats::sd(w) else NA_real_,
      q05 = qs[1L],
      q50 = qs[2L],
      q95 = qs[3L],
      selection_prop = mean(abs(w) > threshold),
      positive_prop = mean(w > threshold),
      negative_prop = mean(w < -threshold),
      n_success = length(w),
      stringsAsFactors = FALSE
    )
  })
  out <- do.call(rbind, rows)
  rownames(out) <- NULL
  out[order(out$network, out$from, out$to), , drop = FALSE]
}

#' Print method for stability results
#'
#' @param x A `stability_result` object.
#' @param ... Ignored.
#' @return `x`, invisibly.
#' @export
print.stability_result <- function(x, ...) {
  cat("Idiographic Stability Result\n")
  cat(sprintf("  Estimator:      %s\n", x$config$estimator))
  cat(sprintf("  Resampling:     %s\n", x$config$resample))
  cat(sprintf("  Successful:     %d / %d\n", x$n_success, x$n_resamples))
  cat(sprintf("  Edge rows:      %d\n", nrow(x$stability)))
  cat("  Table:          x$stability\n")
  cat("  Cograph:        cograph::splot(x$original)\n")
  cat("  Matrices:       matrices(x$original)\n")
  invisible(x)
}

#' @export
as.data.frame.stability_result <- function(x, row.names = NULL,
                                           optional = FALSE, ...) {
  x$stability
}

#' @export
summary.stability_result <- function(object, ...) object$stability
