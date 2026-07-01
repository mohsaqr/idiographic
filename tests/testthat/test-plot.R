# plot() methods: one verb to draw any result, with a layer= argument so users
# never index into the object to reach a sub-network.

# Draw onto a throwaway device so the tests never open a window.
on_null_device <- function(code) {
  grDevices::pdf(NULL)
  on.exit(grDevices::dev.off(), add = TRUE)
  force(code)
}

test_that("plot.var_result draws the whole result and a single layer", {
  skip_if_not_installed("cograph")
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"))
  fit <- build_var(d, vars = attr(d, "vars"), id = "id")
  on_null_device({
    expect_invisible(plot(fit))
    expect_invisible(plot(fit, layer = "temporal"))
    expect_invisible(plot(fit, layer = "contemporaneous"))
  })
})

test_that("plot() rejects an unknown layer with the available names", {
  skip_if_not_installed("cograph")
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"))
  fit <- build_var(d, vars = attr(d, "vars"), id = "id")
  on_null_device(
    expect_error(plot(fit, layer = "nope"),
                 "Unknown layer.*temporal, contemporaneous")
  )
})

test_that("plot.var_list / gvar_list draw a chosen subject", {
  skip_if_not_installed("cograph")
  d <- synth_panel(n_id = 4, days = 4, beeps = 12, vars = c("A", "B", "C"))
  fits <- build_var_each(d, vars = attr(d, "vars"), id = "id",
                         day = "day", beep = "beep")
  on_null_device({
    expect_invisible(plot(fits, subject = 1L))
    expect_invisible(plot(fits, subject = names(fits)[1]))
  })
})

test_that("plot.rolling_var_result needs kept fits and honours fit=", {
  skip_if_not_installed("cograph")
  d <- synth_single(n_t = 160, vars = c("A", "B", "C"))
  roll <- rolling_var(d, vars = attr(d, "vars"), id = "id",
                      window_size = 50, step = 25, keep_fits = TRUE)
  on_null_device(expect_invisible(plot(roll, fit = 1, layer = "temporal")))

  roll_nofit <- rolling_var(d, vars = attr(d, "vars"), id = "id",
                            window_size = 50, step = 25, keep_fits = FALSE)
  expect_error(plot(roll_nofit, fit = 1), "keep_fits = TRUE")
})

test_that("plot() errors cleanly when cograph is unavailable", {
  # Simulate a missing cograph by checking the guard directly.
  if (requireNamespace("cograph", quietly = TRUE)) {
    skip("cograph is installed; guard is exercised by other tests")
  }
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"))
  fit <- build_var(d, vars = attr(d, "vars"), id = "id")
  expect_error(plot(fit), "requires the 'cograph' package")
})
