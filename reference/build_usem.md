# Build a user-specified unified SEM network

Fits person-specific unified Structural Equation Models (uSEM) for
intensive longitudinal data. With `trim = FALSE`, the model is fixed by
`temporal`, `contemporaneous`, `residual_cov`, and `paths`. With
`trim = TRUE`, idiographic uses an independent clean-room
modification-index entry and z-value pruning layer over the declared
candidate set.

## Usage

``` r
build_usem(
  data,
  vars,
  id,
  time = NULL,
  day = NULL,
  beep = NULL,
  min_obs = NULL,
  subject = NULL,
  temporal = c("ar", "all", "none"),
  contemporaneous = c("none", "all"),
  residual_cov = TRUE,
  trim = FALSE,
  trim_alpha = 0.05,
  trim_fit_criteria = 3L,
  cfi_cutoff = 0.95,
  tli_cutoff = 0.95,
  rmsea_cutoff = 0.08,
  srmr_cutoff = 0.08,
  paths = NULL,
  exogenous = NULL,
  standardize = FALSE,
  estimator = "ml",
  seed = NULL
)
```

## Arguments

- data:

  A `data.frame` in long format.

- vars:

  Character vector of time-varying variables.

- id:

  Character string naming the person-ID column.

- time:

  Character string naming the within-person ordering column, or `NULL`.

- day:

  Character string naming the day/session column, or `NULL`.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to analyse.

- temporal:

  `"ar"`, `"all"`, `"none"`, or lavaan lagged regressions such as
  `"A ~ Blag"`.

- contemporaneous:

  `"none"`, `"all"`, or lavaan current regressions such as `"B ~ A"`.

- residual_cov:

  Logical. Estimate residual covariances among current endogenous
  variables?

- trim:

  Logical. If `TRUE`, use idiographic's clean-room modification-index
  entry and z-value pruning layer over the declared candidate set.

- trim_alpha:

  Significance level used for modification-index entry and z-value
  pruning when `trim = TRUE`.

- trim_fit_criteria:

  Number of fit criteria that must pass before forward search stops.

- cfi_cutoff, tli_cutoff, rmsea_cutoff, srmr_cutoff:

  Fit thresholds used by trimmed uSEM.

- paths:

  Extra lavaan syntax lines to include unchanged.

- exogenous:

  Optional subset of `vars` to treat as exogenous current variables.

- standardize:

  Logical. Standardize variables per person before fitting.

- estimator:

  Lavaan estimator. Default `"ml"`.

- seed:

  Optional random seed.

## Value

A `net_usem` object with average temporal, contemporaneous, and
residual-covariance networks, per-subject matrices, fit indices, syntax,
and tidy coefficients.

## See also

[`build_gimme()`](https://mohsaqr.github.io/idiographic/reference/build_gimme.md),
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
[`build_mlvar()`](https://mohsaqr.github.io/idiographic/reference/build_mlvar.md)
