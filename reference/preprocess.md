# Preprocess and audit idiographic time-series data

Builds the same lag-1 design used by
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
and
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md),
optionally detrends or differences each series, and returns tidy
diagnostics for missingness, day-boundary drops, simple linear trends,
AR(1) persistence, split-half mean/variance drift, an ADF-style
unit-root screen, and zero-variance variables. It makes the modelling
input explicit before estimating VAR, graphical VAR, uSEM, GIMME, or
mlVAR models; with `detrend` it also cleans a non-stationary series in
place so the flags can be rechecked on the transformed data.

## Usage

``` r
preprocess(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  scale = TRUE,
  center_within = TRUE,
  detrend = "none",
  checks = c("trend", "high_ar", "unit_root", "mean_shift", "sd_shift", "zero_variance"),
  delete_missings = TRUE,
  min_obs = NULL,
  subject = NULL,
  trend_alpha = 0.05,
  ar_threshold = 0.95,
  mean_shift_threshold = 0.8,
  sd_ratio_threshold = 2,
  unit_root_t_cutoff = -2.86
)
```

## Arguments

- data:

  A `data.frame` or matrix with columns for variables and optional
  id/day/beep columns.

- vars:

  Character vector of variable names.

- id:

  Character. Name of the person-ID column, or `NULL` for a single
  series.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- scale:

  Logical. Whether to standardize variables before lagging. Default
  `TRUE`.

- center_within:

  Logical. Whether to center within person when more than one id is
  present. Default `TRUE`.

- detrend:

  How to remove non-stationarity from each series before lagging. Either
  a single string applied to every variable, or a **named character
  vector** giving a per-variable method (unlisted variables are left
  untouched, e.g. `c(planning = "difference", value = "linear")`). The
  available methods are:

  `"none"`

  :   Default; diagnose only, transform nothing.

  `"auto"`

  :   Detrend only the subject-series that are flagged, leaving the
      stationary ones untouched: differencing a stochastic trend (unit
      root or near-unit-root persistence) and linearly detrending a
      deterministic trend. The "clean whoever needs it" option – no
      subsetting, one call over everyone. Can be set per variable too.

  `"linear"`

  :   Replace the series with the residuals of a within-person
      regression on a linear time index.

  `"difference"`

  :   First-difference the series within id/day blocks.

  The diagnostics and the returned design reflect the detrended series,
  so the trend and unit-root flags can be rechecked after cleaning.

- checks:

  Character vector selecting which stationarity checkups to run: any of
  `"trend"`, `"high_ar"`, `"unit_root"`, `"mean_shift"`, `"sd_shift"`,
  `"zero_variance"`. Defaults to all of them. Deselecting a check turns
  its flag off in the report, in the `flag_stationarity_risk` roll-up,
  and in the `"auto"` detrend decision, so you can screen for only what
  you care about.

- delete_missings:

  Logical. If `TRUE`, `$pairs` contains only complete current/lagged
  rows; if `FALSE`, first rows of blocks and incomplete rows are
  retained with `NA` lags, matching `.gvar_tsdata()`. Default `TRUE`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to preprocess.

- trend_alpha:

  Numeric p-value cutoff for the trend flag. Default `0.05`.

- ar_threshold:

  Numeric absolute AR(1) cutoff for the high-persistence flag. Default
  `0.95`.

- mean_shift_threshold:

  Numeric absolute standardized split-half mean shift cutoff. Default
  `0.8`.

- sd_ratio_threshold:

  Numeric split-half SD ratio cutoff. Default `2`.

- unit_root_t_cutoff:

  Numeric cutoff for the ADF-style lag-level t-statistic. Values greater
  than this cutoff are flagged as unit-root risk. Default `-2.86`, a
  common large-sample intercept-only screening cutoff.

## Value

A `preprocess_result` object with:

- `pairs`:

  The ordered current/lagged design table, including `intercept` and
  `L1_*` columns.

- `counts`:

  Per-subject/per-day row and lag-pair counts.

- `diagnostics`:

  Per-subject/per-variable missingness, trend, AR(1), split-half drift,
  unit-root screen, and stationarity risk indicators.

- `matrices`:

  The exact `data_c` and `data_l` matrices returned by the VAR/GVAR
  preprocessing path.

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = 1, beep = 1:40,
                A = cumsum(rnorm(40)), B = rnorm(40))
pp <- preprocess(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep")
#> 1 of 2 subject-series show a trend or unit-root that can bias the temporal network. preprocess() only diagnosed this; to clean just the series that need it, re-run with:
#>   preprocess(data = d, vars = c("A", "B"), id = "id", day = "day", beep = "beep", detrend = "auto")
pp$counts
#>   subject day n_rows n_lag_possible n_complete_pairs n_retained
#> 1       1   1     40             39               39         39
#>   n_boundary_dropped
#> 1                  1
pp$diagnostics
#>   subject variable  n n_observed missing_prop         mean sd  trend_slope
#> 1       1        A 40         40            0 2.637593e-17  1  0.054326088
#> 2       1        B 40         40            0 1.507583e-17  1 -0.008082785
#>      trend_t      trend_p        ar1      ar1_t        ar1_p mean_first_half
#> 1  5.0683995 1.072035e-05  0.8271452 10.1409016 3.128890e-12     -0.65545859
#> 2 -0.5851021 5.619376e-01 -0.1054387 -0.6407008 5.256656e-01      0.02001441
#>   mean_second_half  mean_shift mean_shift_std mean_shift_p sd_first_half
#> 1       0.65545859  1.31091717     1.31091717 3.485167e-06     0.8382505
#> 2      -0.02001441 -0.04002882     0.04002882 9.012450e-01     0.8745922
#>   sd_second_half sd_ratio unit_root_coef unit_root_t flag_zero_variance
#> 1      0.6674518 1.255897     -0.1728548   -2.119221              FALSE
#> 2      1.1344059 1.297068     -1.1054387   -6.717223              FALSE
#>   flag_trend flag_high_ar flag_mean_shift flag_sd_shift flag_unit_root
#> 1       TRUE        FALSE            TRUE         FALSE           TRUE
#> 2      FALSE        FALSE           FALSE         FALSE          FALSE
#>   flag_stationarity_risk
#> 1                   TRUE
#> 2                  FALSE
# Difference the trending series and recheck the flags:
preprocess(d, vars = c("A", "B"), id = "id", day = "day", beep = "beep",
           detrend = "difference")$diagnostics
#>   subject variable  n n_observed missing_prop        mean        sd
#> 1       1        A 40         39        0.025  0.06550595 0.5281272
#> 2       1        B 40         39        0.025 -0.01177038 1.4990982
#>    trend_slope    trend_t   trend_p         ar1      ar1_t        ar1_p
#> 1 -0.004133590 -0.5450014 0.5890229  0.03985218  0.2375795 0.8135542319
#> 2 -0.004349215 -0.2013219 0.8415496 -0.54633732 -3.8973207 0.0004063707
#>   mean_first_half mean_second_half  mean_shift mean_shift_std mean_shift_p
#> 1     0.138499769     -0.003838187 -0.14233796     0.26951451    0.4081080
#> 2     0.001675254     -0.024543733 -0.02621899     0.01748984    0.9570363
#>   sd_first_half sd_second_half sd_ratio unit_root_coef unit_root_t
#> 1      0.544007      0.5167972 1.052651     -0.9601478   -5.723937
#> 2      1.293586      1.7055629 1.318476     -1.5463373  -11.030864
#>   flag_zero_variance flag_trend flag_high_ar flag_mean_shift flag_sd_shift
#> 1              FALSE      FALSE        FALSE           FALSE         FALSE
#> 2              FALSE      FALSE        FALSE           FALSE         FALSE
#>   flag_unit_root flag_stationarity_risk
#> 1          FALSE                  FALSE
#> 2          FALSE                  FALSE
```
