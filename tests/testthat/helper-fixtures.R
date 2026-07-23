# Shared cell-by-cell comparison helpers used by the fixture-backed and
# equivalence test files. No third-party packages involved.

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
