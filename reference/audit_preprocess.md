# Audit preprocessing and lag construction

Builds the same lag-1 design used by
[`graphical_var()`](https://saqr.me/idiographic/reference/graphical_var.md)
and [`build_var()`](https://saqr.me/idiographic/reference/build_var.md),
then returns tidy diagnostics for missingness, day-boundary drops,
simple linear trends, AR(1) persistence, split-half mean/variance drift,
an ADF-style unit-root screen, and zero-variance variables. This is a
preflight tool: it does not fit a network, but it makes the modelling
input explicit before estimating VAR, graphical VAR, uSEM, GIMME, or
mlVAR models.

## Usage

``` r
audit_preprocess(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  scale = TRUE,
  center_within = TRUE,
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

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- scale:

  Logical. Whether to standardize variables before lagging.

- center_within:

  Logical. Whether to center within person when more than one id is
  present.

- delete_missings:

  Logical. If `TRUE`, `$pairs` contains only complete current/lagged
  rows; if `FALSE`, incomplete rows are retained with `NA` lags.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to audit.

- trend_alpha:

  Numeric p-value cutoff for the trend flag.

- ar_threshold:

  Numeric absolute AR(1) cutoff for the high-persistence flag.

- mean_shift_threshold:

  Numeric absolute standardized split-half mean shift cutoff.

- sd_ratio_threshold:

  Numeric split-half SD ratio cutoff.

- unit_root_t_cutoff:

  Numeric cutoff for the ADF-style lag-level t-statistic. Values greater
  than this cutoff are flagged as unit-root risk.

## Value

A `preprocess_audit` object with `pairs`, `counts`, `diagnostics`, and
`matrices`.

## See also

[`build_var()`](https://saqr.me/idiographic/reference/build_var.md),
[`graphical_var()`](https://saqr.me/idiographic/reference/graphical_var.md)

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = 1, beep = 1:40,
                A = rnorm(40), B = rnorm(40))
audit <- audit_preprocess(d, vars = c("A", "B"), id = "id",
                          day = "day", beep = "beep")
audit$counts
#>   subject day n_rows n_lag_possible n_complete_pairs n_retained
#> 1       1   1     40             39               39         39
#>   n_boundary_dropped
#> 1                  1
audit$diagnostics
#>   subject variable  n n_observed missing_prop          mean sd  trend_slope
#> 1       1        A 40         40            0 -1.099517e-17  1 -0.004244703
#> 2       1        B 40         40            0  1.507583e-17  1 -0.008082785
#>      trend_t   trend_p         ar1      ar1_t     ar1_p mean_first_half
#> 1 -0.3062710 0.7610702  0.03744169  0.2281641 0.8207750      0.11108759
#> 2 -0.5851021 0.5619376 -0.10543874 -0.6407008 0.5256656      0.02001441
#>   mean_second_half  mean_shift mean_shift_std mean_shift_p sd_first_half
#> 1      -0.11108759 -0.22217517     0.22217517    0.4894702     1.0299850
#> 2      -0.02001441 -0.04002882     0.04002882    0.9012450     0.8745922
#>   sd_second_half sd_ratio unit_root_coef unit_root_t flag_zero_variance
#> 1      0.9827424 1.048072     -0.9625583   -5.865686              FALSE
#> 2      1.1344059 1.297068     -1.1054387   -6.717223              FALSE
#>   flag_trend flag_high_ar flag_mean_shift flag_sd_shift flag_unit_root
#> 1      FALSE        FALSE           FALSE         FALSE          FALSE
#> 2      FALSE        FALSE           FALSE         FALSE          FALSE
#>   flag_stationarity_risk
#> 1                  FALSE
#> 2                  FALSE
```
