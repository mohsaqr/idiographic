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
