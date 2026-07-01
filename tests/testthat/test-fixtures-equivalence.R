fixture_csv <- function(name) {
  utils::read.csv(testthat::test_path("fixtures", name),
                  stringsAsFactors = FALSE)
}

expect_matrix_cells_equal <- function(object, expected, tolerance, label) {
  expect_equal(dim(object), dim(expected), info = paste(label, "dim"))
  rn <- rownames(expected)
  cn <- colnames(expected)
  if (is.null(rn)) rn <- as.character(seq_len(nrow(expected)))
  if (is.null(cn)) cn <- as.character(seq_len(ncol(expected)))
  for (i in seq_len(nrow(expected))) {
    for (j in seq_len(ncol(expected))) {
      cell <- sprintf("%s[%s,%s]", label, rn[i], cn[j])
      if (is.na(object[i, j]) && is.na(expected[i, j])) next
      expect_true(abs(object[i, j] - expected[i, j]) < tolerance, info = cell)
    }
  }
}

expect_vector_cells_equal <- function(object, expected, tolerance, label) {
  expect_equal(length(object), length(expected), info = paste(label, "length"))
  nm <- names(expected)
  if (is.null(nm)) nm <- as.character(seq_along(expected))
  for (i in seq_along(expected)) {
    cell <- sprintf("%s[%s]", label, nm[i])
    if (is.na(object[i]) && is.na(expected[i])) next
    expect_true(abs(object[i] - expected[i]) < tolerance, info = cell)
  }
}

upper_triangle_values <- function(m) {
  idx <- which(upper.tri(m), arr.ind = TRUE)
  out <- m[upper.tri(m)]
  names(out) <- paste(rownames(m)[idx[, 1L]], colnames(m)[idx[, 2L]], sep = ":")
  out
}

test_that("mlVAR augmentation matches the line-by-line fixture", {
  d <- fixture_csv("mlvar-line-input.csv")
  expected <- fixture_csv("mlvar-line-expected.csv")

  aug <- idiographic:::.mlvar_augment_data(
    data = d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    lag = 1L, scaleWithin = FALSE
  )$data

  expect_named(aug, names(expected))
  expect_equal(nrow(aug), nrow(expected))
  for (i in seq_len(nrow(expected))) {
    expect_equal(aug[i, , drop = FALSE], expected[i, , drop = FALSE],
                 tolerance = 1e-12, ignore_attr = TRUE,
                 info = paste("row", i))
  }
})

test_that("graphicalVAR lag design matches the line-by-line fixture", {
  d <- fixture_csv("gvar-line-input.csv")
  expected <- fixture_csv("gvar-line-expected.csv")

  ts <- idiographic:::.gvar_tsdata(
    data = d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
    scale = FALSE, center_within = FALSE, delete_missings = FALSE
  )
  got <- data.frame(ts$data_c, ts$data_l, check.names = FALSE)
  names(got) <- names(expected)

  expect_equal(nrow(got), nrow(expected))
  for (i in seq_len(nrow(expected))) {
    expect_equal(got[i, , drop = FALSE], expected[i, , drop = FALSE],
                 tolerance = 1e-12, ignore_attr = TRUE,
                 info = paste("row", i))
  }
})

test_that("fixture-backed build_mlvar is cell-equivalent to mlVAR", {
  skip_if_not_installed("mlVAR")
  source(testthat::test_path("fixtures", "equivalence-panel.R"), local = TRUE)
  d <- .fixture_equivalence_panel()
  vars <- c("A", "B", "C")

  fit <- suppressWarnings(
    build_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
  )
  ref <- suppressWarnings(mlVAR::mlVAR(
    d, vars = vars, idvar = "id", dayvar = "day", beepvar = "beep",
    estimator = "lmer", temporal = "fixed", contemporaneous = "fixed",
    scale = FALSE, verbose = FALSE
  ))

  expect_matrix_cells_equal(fit$temporal$weights, ref$results$Beta$mean[, , 1],
                            tolerance = 1e-10, label = "temporal")
  expect_vector_cells_equal(upper_triangle_values(fit$contemporaneous$weights),
                            upper_triangle_values(ref$results$Theta$pcor$mean),
                            tolerance = 1e-10,
                            label = "contemporaneous_upper")
  expect_vector_cells_equal(upper_triangle_values(fit$between$weights),
                            upper_triangle_values(ref$results$Omega_mu$pcor$mean),
                            tolerance = 1e-10, label = "between_upper")
})

test_that("fixture-backed graphical_var is cell-equivalent to graphicalVAR", {
  skip_if_not_installed("graphicalVAR")
  source(testthat::test_path("fixtures", "equivalence-panel.R"), local = TRUE)
  d <- .fixture_equivalence_series()
  vars <- c("A", "B", "C")

  fit <- graphical_var(d, vars = vars, id = "id", day = "day", beep = "beep",
                       n_lambda = 12, gamma = 0.5)
  ref <- suppressWarnings(graphicalVAR::graphicalVAR(
    d[, c(vars, "id", "day", "beep")], vars = vars,
    idvar = "id", dayvar = "day", beepvar = "beep",
    nLambda = 12, gamma = 0.5, verbose = FALSE
  ))

  expect_matrix_cells_equal(fit$beta, ref$beta, tolerance = 1e-4,
                            label = "beta")
  expect_matrix_cells_equal(fit$kappa, ref$kappa, tolerance = 1e-4,
                            label = "kappa")
})
