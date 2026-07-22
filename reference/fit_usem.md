# Build a user-specified unified SEM network

Fits person-specific unified Structural Equation Models (uSEM) for
intensive longitudinal data. A uSEM combines lagged directed effects,
optional contemporaneous directed effects, and optional residual
covariances in one SEM. Unlike
[`fit_gimme()`](https://mohsaqr.github.io/idiographic/reference/fit_gimme.md),
this function does no automated path search: the model is fixed by
`temporal`, `contemporaneous`, `residual_cov`, and `paths`. With
`trim = TRUE`, idiographic uses an independent clean-room
modification-index entry and z-value pruning layer over the declared
candidate set.

## Usage

``` r
fit_usem(
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

  Character string naming the day/session column, or `NULL`. When
  supplied, lag pairs are formed only within the same `(id, day)` block.

- beep:

  Character string naming the measurement-occasion column, or `NULL`.
  Used with `day` to order observations when `time` is not supplied.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to analyse.

- temporal:

  `"ar"` (own-lag only; default), `"all"` (all lagged predictors),
  `"none"`, or a character vector of lavaan regressions such as
  `"A ~ Blag"`.

- contemporaneous:

  `"none"` (default), `"all"` (all directed lag-0 predictors except
  self-regressions), or lavaan regressions such as `"B ~ A"`.

- residual_cov:

  Logical. Estimate residual covariances among current endogenous
  variables? Default `TRUE`.

- trim:

  Logical. If `TRUE`, treat `temporal`, `contemporaneous`, and
  `residual_cov` as an eligible search space: start from the structural
  baseline, add paths by modification index until fit criteria are met,
  then prune weak paths. This is an idiographic clean-room search layer,
  not a clone of any external package. Default `FALSE` fits the exact
  fixed syntax.

- trim_alpha:

  Significance level used for modification-index entry and z-value
  pruning when `trim = TRUE`. Default `0.05`.

- trim_fit_criteria:

  Number of fit criteria that must pass before forward search stops.
  Default `3`.

- cfi_cutoff, tli_cutoff, rmsea_cutoff, srmr_cutoff:

  Fit thresholds used by trimmed uSEM.

- paths:

  Extra lavaan syntax lines to include unchanged.

- exogenous:

  Optional subset of `vars` to treat as exogenous current variables.
  They can predict endogenous variables but are not outcomes.

- standardize:

  Logical. Standardize variables per person before fitting.

- estimator:

  Lavaan estimator. Default `"ml"`.

- seed:

  Optional random seed.

## Value

A `net_usem` object with average `$temporal`, `$contemporaneous`, and
`$residual_cov` matrices, per-subject matrices in `$subjects`, a tidy
coefficient table from
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md),
fit indices, syntax, labels, and configuration metadata.

## See also

[`fit_gimme()`](https://mohsaqr.github.io/idiographic/reference/fit_gimme.md),
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md),
[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)

## Examples

``` r
# \donttest{
set.seed(1)
d <- data.frame(
  id = rep(1:4, each = 30),
  t = rep(seq_len(30), 4),
  A = rnorm(120), B = rnorm(120), C = rnorm(120)
)
fit <- fit_usem(d, vars = c("A", "B", "C"), id = "id", time = "t")
edges(fit)
#>        network from to      weight
#> 1 residual_cov    B  C -0.12338761
#> 2 residual_cov    A  C  0.09763793
#> 3 residual_cov    A  B  0.04235390
# }
```
