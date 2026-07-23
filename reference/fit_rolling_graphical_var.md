# Estimate rolling-window graphical VAR networks

Fits
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md)
over ordered, overlapping windows within each subject. This is the
time-varying graphical VAR companion to
[`fit_rolling_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_var.md):
every window uses graphical VAR's lag construction, EBIC/penalty
settings, and tidy coefficient access, then returns one coefficient
table per window.

## Usage

``` r
fit_rolling_graphical_var(
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
  keep_fits = FALSE,
  ...
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

  Logical. Store successful `gvar_result` fits? Default `FALSE`.

- ...:

  Further arguments passed to
  [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md),
  such as `n_lambda`, `gamma`, `lambda_beta`, or `lambda_kappa`.

## Value

A `rolling_gvar_result` with `$estimates`, `$windows`, `$failures`, and
optionally `$fits`. `$estimates` is a tidy coefficient table with
subject/window metadata plus `network`, `from`, `to`, and `weight`.

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:5, each = 20),
                beep = rep(1:20, 5),
                A = rnorm(100), B = rnorm(100), C = rnorm(100))
tv <- fit_rolling_graphical_var(d, vars = c("A", "B", "C"), id = "id",
                            day = "day", beep = "beep",
                            window_size = 50, step = 25,
                            scale = FALSE, n_lambda = 5)
head(tv$estimates)
#>   subject window start_row end_row start_day end_day start_beep end_beep
#> 1       1      1         1      50         1       3          1       10
#> 2       1      1         1      50         1       3          1       10
#> 3       1      1         1      50         1       3          1       10
#> 4       1      1         1      50         1       3          1       10
#> 5       1      1         1      50         1       3          1       10
#> 6       1      1         1      50         1       3          1       10
#>    network from to weight
#> 1 temporal    A  A      0
#> 2 temporal    B  A      0
#> 3 temporal    C  A      0
#> 4 temporal    A  B      0
#> 5 temporal    B  B      0
#> 6 temporal    C  B      0
```
