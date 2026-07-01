# ---- plot() methods: one verb to draw any idiographic result ----------------
#
# Every estimator result is cograph-ready, but users should not have to reach
# into the object (`cograph::splot(fit[["temporal"]])`) to draw a single layer.
# `plot(fit)` draws the whole result; `plot(fit, layer = "temporal")` draws one
# network. The plumbing (which sub-network, how to orient it) stays inside these
# methods, so analysis code is one tidy verb call.

#' Plot an idiographic network result
#'
#' S3 `plot()` methods that render any idiographic result with
#' [cograph::splot()]. Call `plot(fit)` to draw the full result (every network
#' panel) or pass `layer` to draw a single network -- `"temporal"`,
#' `"contemporaneous"`, `"between"` (mlVAR), or `"residual_cov"` (uSEM) -- without
#' indexing into the object.
#'
#' @param x An idiographic result (`var_result`, `gvar_result`, `net_mlvar`,
#'   `net_usem`, `net_gimme`, `var_list`, `rolling_var_result`,
#'   `rolling_gvar_result`, or `stability_result`).
#' @param layer Optional network name to draw on its own. `NULL` (default) draws
#'   the whole result. Available names are reported if an unknown one is given.
#' @param ... Further arguments forwarded to [cograph::splot()].
#' @return Invisibly, the object that was plotted (a `cograph`/ggplot object).
#' @name plot_idiographic
#' @examplesIf requireNamespace("cograph", quietly = TRUE)
#' set.seed(1)
#' d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
#' fit <- build_var(d, vars = c("A", "B", "C"), id = "id")
#' plot(fit)
#' plot(fit, layer = "temporal")
NULL

#' @keywords internal
#' Ensure the optional 'cograph' plotting backend is available.
#'
#' cograph stays a Suggests dependency (so estimation-only installs stay light),
#' but it is offered for on-demand install the first time a plot is drawn. The
#' prompt + install happen ONLY in an interactive session and ONLY with explicit
#' user consent; in non-interactive runs (R CMD check, tests, scripts) this never
#' installs anything and simply errors with instructions.
#' @noRd
.ido_require_cograph <- function(what = "plot") {
  if (requireNamespace("cograph", quietly = TRUE)) return(invisible(TRUE))
  if (interactive()) {
    ans <- tryCatch(
      utils::askYesNo(sprintf(
        "%s() needs the 'cograph' package, which is not installed. Install it now?",
        what), default = FALSE),
      error = function(e) FALSE)
    if (isTRUE(ans)) {
      utils::install.packages("cograph")
      if (requireNamespace("cograph", quietly = TRUE)) return(invisible(TRUE))
    }
  }
  stop(what, "() requires the 'cograph' package for rendering. ",
       "Install it with install.packages('cograph').", call. = FALSE)
}

#' Draw a whole result or a single named layer with cograph::splot().
#' @keywords internal
#' @noRd
.ido_splot <- function(x, layer = NULL, ...) {
  .ido_require_cograph("plot")
  # Always render via as_netobject(), which orients directed temporal networks
  # for plotting (edges run predictor -> outcome). Delegating the whole object
  # to cograph::splot(x) would instead draw the stored `[outcome, predictor]`
  # temporal matrix directly, reversing every cross-lagged arrow.
  g <- as_netobject(x)
  if (!is.null(layer)) {
    if (!layer %in% names(g)) {
      stop("Unknown layer '", layer, "'. Available layers: ",
           paste(names(g), collapse = ", "), ".", call. = FALSE)
    }
    return(invisible(cograph::splot(g[[layer]], ...)))
  }
  # Whole result: one correctly-oriented panel per network.
  nms <- names(g)
  if (is.null(nms)) nms <- paste0("network", seq_along(g))
  op <- graphics::par(mfrow = c(1, length(g)), mar = c(2, 2, 3, 2))
  on.exit(graphics::par(op), add = TRUE)
  dots <- list(...); user_title <- dots$title; dots$title <- NULL
  for (i in seq_along(g)) {
    lab <- paste0(toupper(substring(nms[i], 1, 1)), substring(nms[i], 2))
    ttl <- if (is.null(user_title)) lab else paste(user_title, "-", lab)
    do.call(cograph::splot, c(list(x = g[[i]], title = ttl), dots))
  }
  invisible(x)
}

#' @rdname plot_idiographic
#' @export
plot.var_result <- function(x, layer = NULL, ...) .ido_splot(x, layer, ...)

#' @rdname plot_idiographic
#' @export
plot.gvar_result <- function(x, layer = NULL, ...) .ido_splot(x, layer, ...)

#' @rdname plot_idiographic
#' @export
plot.var_bayes_result <- function(x, layer = NULL, ...) .ido_splot(x, layer, ...)

#' @rdname plot_idiographic
#' @export
plot.net_mlvar <- function(x, layer = NULL, ...) .ido_splot(x, layer, ...)

#' @rdname plot_idiographic
#' @export
plot.net_usem <- function(x, layer = NULL, ...) .ido_splot(x, layer, ...)

#' @rdname plot_idiographic
#' @param weight For GIMME: `"prop"` (proportion of subjects, default) or
#'   `"coef"` (group-average coefficient) for edge width.
#' @export
plot.net_gimme <- function(x, layer = NULL, weight = c("prop", "coef"), ...) {
  weight <- match.arg(weight)
  # Default: the faithful gimme-style mixed network (dashed lag / solid
  # contemporaneous, group vs individual colouring). A named layer draws the
  # plain p-node temporal or contemporaneous network instead.
  if (is.null(layer)) {
    return(invisible(plot_gimme(x, weight = weight, ...)))
  }
  .ido_splot(x, layer, ...)
}

#' @rdname plot_idiographic
#' @param subject For a `var_list` / `gvar_list`: the subject name (or index) to
#'   draw. Defaults to the first subject.
#' @export
plot.var_list <- function(x, subject = 1L, layer = NULL, ...) {
  fit <- .ido_pick_fit(x, subject, "subject")
  .ido_splot(fit, layer, ...)
}

#' @rdname plot_idiographic
#' @export
plot.gvar_list <- function(x, subject = 1L, layer = NULL, ...) {
  fit <- .ido_pick_fit(x, subject, "subject")
  .ido_splot(fit, layer, ...)
}

#' @rdname plot_idiographic
#' @param fit For rolling results: the stored window fit (name or index) to
#'   draw. Requires `keep_fits = TRUE` at fit time. Defaults to the first window.
#' @export
plot.rolling_var_result <- function(x, fit = 1L, layer = NULL, ...) {
  .ido_splot(.ido_pick_fit(x$fits, fit, "fit"), layer, ...)
}

#' @rdname plot_idiographic
#' @export
plot.rolling_gvar_result <- function(x, fit = 1L, layer = NULL, ...) {
  .ido_splot(.ido_pick_fit(x$fits, fit, "fit"), layer, ...)
}

#' @rdname plot_idiographic
#' @export
plot.stability_result <- function(x, layer = NULL, ...) {
  .ido_splot(x$original, layer, ...)
}
