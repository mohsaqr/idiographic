# External equivalence lane

This directory is intentionally excluded from the CRAN source package. It
contains competitor-generated fixtures and the larger real-panel validation
corpus; none of these files is needed to install, load, or use idiographic.

Run the lane from the repository root after installing the reference packages:

```sh
Rscript validation/run-equivalence.R
```

The runner sets `IDIOGRAPHIC_RUN_EQUIVALENCE=true` and executes the committed
oracle tests. Ordinary `R CMD check` and CRAN checks leave that switch disabled,
so the distributable core remains offline-first. The GitHub
`oracle-equivalence` workflow installs the pinned competitors and runs the same
lane.

The 20-panel mlVAR corpus lives under `validation/fixtures/mlvar-real20/` and
contains raw CSV panels, frozen mlVAR 0.7.3 RDS outputs, provenance, and the
documented missing-ID, irregular-gap, sparse-panel, and degenerate-between
cases.
