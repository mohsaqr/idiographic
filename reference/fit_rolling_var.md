# Estimate rolling-window ordinary VAR networks

Fits
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md)
over ordered, overlapping windows within each subject. This is a simple
time-varying idiographic baseline: every window uses the same lag
construction, scaling, within-person centring, and tidy coefficient
access as
[`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md),
but returns one coefficient table per window.

## Usage

``` r
fit_rolling_var(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  window_size,
  step = 1L,
  scale = TRUE,
  center_within = TRUE,
  delete_missings = TRUE,
  min_obs = NULL,
  subject = NULL,
  keep_fits = FALSE
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

- window_size:

  Integer number of ordered rows per rolling window.

- step:

  Integer number of rows to advance between windows. Default `1`.

- scale:

  Logical. Whether to standardize variables inside each window. Default
  `TRUE`.

- center_within:

  Logical. Whether to centre within person inside each window when more
  than one id is present. Default `TRUE`.

- delete_missings:

  Logical. Drop incomplete current/lagged rows. Default `TRUE`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations before rolling.

- subject:

  Optional vector naming the subject(s) to analyse.

- keep_fits:

  Logical. Store successful `var_result` fits? Default `FALSE`.

## Value

A `rolling_var_result` with `$estimates`, `$windows`, `$failures`, and
optionally `$fits`. `$estimates` is a tidy coefficient table with
subject/window metadata plus `network`, `from`, `to`, and `weight`.

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:5, each = 20),
                beep = rep(1:20, 5),
                A = rnorm(100), B = rnorm(100), C = rnorm(100))
tv <- fit_rolling_var(d, vars = c("A", "B", "C"), id = "id",
                  day = "day", beep = "beep",
                  window_size = 40, step = 20, scale = FALSE)
head(tv$estimates)
#>   subject window start_row end_row start_day end_day start_beep end_beep
#> 1       1      1         1      40         1       2          1       20
#> 2       1      1         1      40         1       2          1       20
#> 3       1      1         1      40         1       2          1       20
#> 4       1      1         1      40         1       2          1       20
#> 5       1      1         1      40         1       2          1       20
#> 6       1      1         1      40         1       2          1       20
#>    network from to      weight
#> 1 temporal    A  A  0.02404912
#> 2 temporal    B  A -0.02792897
#> 3 temporal    C  A  0.06323895
#> 4 temporal    A  B  0.17263795
#> 5 temporal    B  B -0.09875282
#> 6 temporal    C  B -0.07445738
```
