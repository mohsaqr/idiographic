# Fine printing: print methods should SHOW the estimated networks (Nestimate
# style) -- a weight-range line and the labelled weight matrix -- not just an
# accessor menu.

test_that("print.var_result shows network blocks and weight ranges", {
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"))
  fit <- fit_var(d, vars = attr(d, "vars"), id = "id")
  out <- capture.output(print(fit))
  expect_true(any(grepl("Temporal \\[directed\\]", out)))
  expect_true(any(grepl("Contemporaneous \\[undirected\\]", out)))
  expect_true(any(grepl("weights \\[", out)))
  # the weight matrix is printed with variable labels
  expect_true(any(grepl("\\bA\\b", out)))
})

test_that("print stays invisible and returns the object", {
  d <- synth_single(n_t = 120, vars = c("A", "B", "C"))
  fit <- fit_var(d, vars = attr(d, "vars"), id = "id")
  expect_output(res <- withVisible(print(fit)))
  expect_false(res$visible)
  expect_identical(res$value, fit)
})

test_that(".ido_print_networks matches edges()/as_netobject orientation", {
  d <- synth_single(n_t = 150, vars = c("A", "B", "C"))
  fit <- fit_var(d, vars = attr(d, "vars"), id = "id")
  g <- as_netobject(fit)
  out <- capture.output(print(fit))
  # directedness tags in the print reflect the netobject directedness
  expect_equal(isTRUE(g$temporal$directed), TRUE)
  expect_true(any(grepl("Temporal \\[directed\\]", out)))
  expect_true(any(grepl("Contemporaneous \\[undirected\\]", out)))
})

test_that("an empty network prints a 'no non-zero edges' line, not an error", {
  z <- matrix(0, 3, 3, dimnames = list(c("A", "B", "C"), c("A", "B", "C")))
  out <- capture.output(.ido_print_net_block(z, "Temporal", directed = TRUE))
  expect_true(any(grepl("no non-zero edges", out)))
})
