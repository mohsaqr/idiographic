# External competitor checks are deliberately separate from the offline core
# suite. CRAN and ordinary `R CMD check` runs leave this disabled; the dedicated
# oracle workflow enables it after installing the pinned reference packages.
.idiographic_run_equivalence <- identical(
  tolower(Sys.getenv("IDIOGRAPHIC_RUN_EQUIVALENCE", unset = "false")),
  "true"
)

skip_unless_equivalence <- function() {
  testthat::skip_if_not(
    .idiographic_run_equivalence,
    paste0(
      "external equivalence lane disabled; set ",
      "IDIOGRAPHIC_RUN_EQUIVALENCE=true to run it"
    )
  )
}
