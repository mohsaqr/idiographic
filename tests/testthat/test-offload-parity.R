# Offload parity gate: Nestimate -> idiographic.
#
# Nestimate carries its own copies of the mlVAR estimator, the GIMME search, and
# the pure-R graphical-lasso kernel. These tests are the contract that lets
# Nestimate delete them and call idiographic instead. They are excluded from the
# CRAN tarball and run only in the equivalence lane, because they require a
# Nestimate installation that idiographic must never depend on.
#
# The bar is different per estimator, and deliberately so:
#   * mlVAR  -- BIT-IDENTICAL. Both packages implement the same mlVAR 0.7.3
#               replica, so any difference is a regression in one of them.
#   * glasso -- BIT-IDENTICAL on the shared scalar-rho surface. idiographic's
#               kernel is a strict superset (matrix rho, zero constraints,
#               input validation).
#   * GIMME  -- NOT identical, and must not be asserted so. Against upstream
#               gimme 10.0, idiographic reproduces the search exactly while
#               Nestimate does not. The offload is a deliberate correctness
#               upgrade; the test pins that direction, not agreement.

# testthat sources each test file in its own environment, so the gimme 10.0
# reference harness from test-expanded-equivalence.R is not in scope here.
# Keep a local copy rather than moving it into a shipped helper-*.R file
# (which would put competitor-calling code into the CRAN tarball).
.offload_gimme10 <- function(data, ...) {
  fun <- get("gimme", envir = asNamespace("gimme"))
  capture_line <- paste(deparse(body(fun)[[2L]]), collapse = " ")
  if (grepl("as.list", capture_line, fixed = TRUE) &&
      grepl("sys.frame", capture_line, fixed = TRUE)) {
    # gimme 10.0's argument-capture expression recursively evaluates promises
    # under recent R. Replacing only that bookkeeping assignment leaves the
    # search, pruning, fitting, and extraction as upstream code.
    body(fun)[[2L]] <- quote(
      arguments <- as.list(match.call(expand.dots = TRUE))
    )
  }
  invisible(utils::capture.output(
    result <- suppressMessages(fun(data = data, plot = FALSE, ...))
  ))
  result
}

skip_offload <- function() {
  skip_unless_equivalence()
  skip_if_not_installed("Nestimate")
}

.offload_panel <- function(seed = 5150, p = 3L, n_id = 12L, n_day = 8L,
                           n_beep = 6L) {
  set.seed(seed)
  B <- matrix(stats::rnorm(p * p, 0, 0.12), p, p)
  diag(B) <- 0.35
  do.call(rbind, lapply(seq_len(n_id), function(s) {
    mu <- stats::rnorm(p, 0, 0.6)
    do.call(rbind, lapply(seq_len(n_day), function(dd) {
      y <- matrix(0, n_beep, p)
      y[1L, ] <- stats::rnorm(p)
      for (t in seq_len(n_beep - 1L)) {
        y[t + 1L, ] <- as.numeric(B %*% y[t, ]) + stats::rnorm(p, 0, 0.9)
      }
      z <- as.data.frame(sweep(y, 2L, mu, `+`))
      names(z) <- paste0("V", seq_len(p))
      z$id <- s
      z$day <- dd
      z$beep <- seq_len(n_beep)
      z
    }))
  }))
}

test_that("fit_mlvar() is bit-identical to Nestimate::build_mlvar()", {
  skip_offload()
  d <- .offload_panel()
  vars <- paste0("V", 1:3)

  nes <- suppressWarnings(suppressMessages(
    Nestimate::build_mlvar(d, vars = vars, id = "id", day = "day",
                           beep = "beep", lag = 1L, standardize = FALSE)))
  idi <- suppressWarnings(suppressMessages(
    fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep",
              lags = 1L, scale = FALSE, verbose = FALSE)))

  for (layer in c("temporal", "contemporaneous", "between")) {
    expect_equal(idi[[layer]]$weights, nes[[layer]]$weights,
                 tolerance = 0, ignore_attr = TRUE,
                 info = paste("layer:", layer))
  }

  cn <- coefs(nes)
  ci <- coefs(idi)
  expect_setequal(names(cn), names(ci))
  ord <- match(paste(cn$outcome, cn$predictor), paste(ci$outcome, ci$predictor))
  expect_false(anyNA(ord))
  for (col in c("beta", "se", "t", "p", "ci_lower", "ci_upper")) {
    expect_equal(ci[[col]][ord], cn[[col]], tolerance = 0, info = col)
  }
})

test_that("the idiographic net_mlvar contract is a superset of Nestimate's", {
  skip_offload()
  d <- .offload_panel()
  vars <- paste0("V", 1:3)
  nes <- suppressWarnings(suppressMessages(
    Nestimate::build_mlvar(d, vars = vars, id = "id", day = "day",
                           beep = "beep")))
  idi <- suppressWarnings(suppressMessages(
    fit_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep",
              scale = FALSE, verbose = FALSE)))

  # every class Nestimate consumers dispatch on must still be present
  expect_true(all(class(nes) %in% class(idi)))
  # same constituents, in the same order
  expect_identical(names(idi), names(nes))
  # every attribute Nestimate consumers read must still be present
  expect_true(all(setdiff(names(attributes(nes)), c("names", "class")) %in%
                    names(attributes(idi))))
})

test_that("glasso_fit() reproduces Nestimate's private kernel on the shared surface", {
  skip_offload()
  set.seed(31)
  p <- 6L
  x <- matrix(stats::rnorm(200 * p), 200, p)
  S <- stats::cov(x)
  S <- S / mean(diag(S))
  nes_fit <- get(".glasso_fit", envir = asNamespace("Nestimate"))
  for (rho in c(0.01, 0.1, 0.3)) {
    ref <- nes_fit(S, rho = rho, penalize.diagonal = FALSE)
    expect_equal(glasso_fit(S, rho = rho)$wi, ref$wi,
                 tolerance = 0, ignore_attr = TRUE,
                 info = paste("rho:", rho))
  }
})

test_that("fit_gimme() is the faithful GIMME; the offload is an upgrade", {
  skip_offload()
  skip_if_not_installed("gimme", minimum_version = "10.0")

  set.seed(6161)
  p <- 3L; n_id <- 5L; n_t <- 80L
  B <- matrix(0, p, p); diag(B) <- 0.4; B[2L, 1L] <- 0.3; B[3L, 2L] <- 0.25
  per <- lapply(seq_len(n_id), function(s) {
    y <- matrix(0, n_t, p); y[1L, ] <- stats::rnorm(p)
    for (t in seq_len(n_t - 1L)) {
      y[t + 1L, ] <- as.numeric(B %*% y[t, ]) + stats::rnorm(p, 0, 0.8)
    }
    z <- as.data.frame(y); names(z) <- paste0("V", seq_len(p)); z
  })
  names(per) <- paste0("s", seq_len(n_id))
  d <- do.call(rbind, lapply(seq_len(n_id), function(s) {
    z <- per[[s]]; z$id <- s; z$time <- seq_len(n_t); z
  }))
  vars <- paste0("V", seq_len(p))

  ref <- .offload_gimme10(per, ar = TRUE, standardize = FALSE,
                            groupcutoff = 0.75)
  idi <- suppressWarnings(suppressMessages(fit_gimme(
    d, vars = vars, id = "id", time = "time", ar = TRUE,
    standardize = FALSE, groupcutoff = 0.75, seed = 1)))
  nes <- suppressWarnings(suppressMessages(Nestimate::build_gimme(
    d, vars = vars, id = "id", time = "time", ar = TRUE,
    standardize = FALSE, groupcutoff = 0.75, seed = 1)))

  # idiographic reproduces upstream exactly ...
  expect_equal(idi$path_counts, ref$path_counts, tolerance = 0,
               ignore_attr = TRUE)
  expect_equal(unname(idi$coefs), unname(ref$path_est_mats), tolerance = 0)

  # ... and Nestimate's own search does not, which is why the offload changes
  # Nestimate's numbers. Assert the gap explicitly so this is never mistaken
  # for a drop-in swap.
  expect_gt(max(abs(nes$path_counts - ref$path_counts)), 0)
})
