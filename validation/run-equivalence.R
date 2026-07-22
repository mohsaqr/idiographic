Sys.setenv(IDIOGRAPHIC_RUN_EQUIVALENCE = "true")

if (!requireNamespace("pkgload", quietly = TRUE) ||
    !requireNamespace("testthat", quietly = TRUE)) {
  stop("The equivalence lane requires the development tools 'pkgload' and ",
       "'testthat'.", call. = FALSE)
}

pkgload::load_all(".", quiet = TRUE)

testthat::test_local(
  ".",
  filter = paste(
    c(
      "fixtures-equivalence", "expanded-equivalence", "package-closure",
      "registry", "hardening", "graphical-var", "mlvar$", "mlvar-real20",
      "gimme$", "glasso", "usem-equivalence"
    ),
    collapse = "|"
  ),
  reporter = "summary",
  stop_on_failure = TRUE,
  stop_on_warning = FALSE
)
