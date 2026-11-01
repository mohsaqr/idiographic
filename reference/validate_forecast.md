# Validate one-step forecasts from idiographic VAR models (experimental)

**Experimental.** The rolling-origin design follows standard time-series
cross-validation practice, but unlike the estimators in this package it
has no external reference implementation to validate against, and its
interface, defaults, and reported metrics may change in a future
release.

Performs rolling-origin one-step prediction from
[`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md)
or
[`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md).
Each split fits the estimator on earlier blocks and predicts current
variables in the next block from their lag-1 values. Scaling and
within-person centring parameters are learned from the training split
only, then applied to the assessment split before prediction.

## Usage

``` r
validate_forecast(
  data,
  vars,
  estimator = c("var", "graphical_var"),
  id = NULL,
  day = NULL,
  beep = NULL,
  initial = NULL,
  assess = 1L,
  step = 1L,
  n_splits = NULL,
  block_size = NULL,
  scale = TRUE,
  center_within = TRUE,
  delete_missings = TRUE,
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

- estimator:

  `"var"` (default) for
  [`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md)
  or `"graphical_var"` for
  [`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md).

- id:

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- initial:

  Integer number of ordered blocks in the first training split. Default
  uses 60 percent of blocks, leaving at least one assessment block.

- assess:

  Integer number of blocks to assess per split. Default `1`.

- step:

  Integer number of blocks to advance between splits. Default `1`.

- n_splits:

  Optional maximum number of rolling splits.

- block_size:

  Integer or `NULL`. Consecutive block length used only when neither
  `id` nor `day` is supplied. Defaults to `floor(sqrt(nrow(data)))`.

- scale:

  Logical. Whether to standardize using training-split means and SDs.
  Default `TRUE`.

- center_within:

  Logical. Whether to centre within person using training-split person
  means when more than one id is present. Default `TRUE`.

- delete_missings:

  Logical. Drop incomplete current/lagged assessment rows. Default
  `TRUE`.

- keep_fits:

  Logical. Store fitted split models? Default `FALSE`.

- ...:

  Further arguments passed to the estimator.

## Value

A `forecast_result`. [`summary()`](https://rdrr.io/r/base/summary.html)
returns the forecast metrics, one row per variable plus an `.overall`
row (`variable`, `n`, `mae`, `rmse`, `bias`);
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) returns
the out-of-sample predictions, one row per split, occasion and variable
(`split`, `original_row`, `subject`, `day`, `beep`, `variable`,
`observed`, `predicted`, `residual`, `abs_error`, `squared_error`);
[`failures()`](https://pak.dynasite.org/idiographic/reference/failures.md)
returns the splits that could not be fit. The split boundaries and, with
`keep_fits = TRUE`, the fitted split models are stored in the object.

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:5, each = 12),
                beep = rep(1:12, 5),
                A = rnorm(60), B = rnorm(60), C = rnorm(60))
fc <- validate_forecast(d, vars = c("A", "B", "C"), id = "id",
                        day = "day", beep = "beep",
                        initial = 3, n_splits = 2, scale = FALSE)
summary(fc)
#>   variable  n       mae      rmse       bias
#> 1        A 22 0.6627637 0.7916495  0.2286442
#> 2        B 22 0.7710222 0.8981746 -0.1662394
#> 3        C 22 1.0826584 1.3570916  0.8713974
#> 4 .overall 66 0.8388148 1.0448483  0.3112674
head(as.data.frame(fc))
#>   split original_row subject day beep variable   observed    predicted
#> 1     1           38       1   4    2        A -0.1224092 -0.140025744
#> 2     1           39       1   4    3        A  1.0369296  0.207200030
#> 3     1           40       1   4    4        A  0.7000799  0.583142030
#> 4     1           41       1   4    5        A -0.2276194 -0.395155839
#> 5     1           42       1   4    6        A -0.3164575 -0.066328723
#> 6     1           43       1   4    7        A  0.6338676  0.006242988
#>      residual  abs_error squared_error
#> 1  0.01761653 0.01761653  0.0003103422
#> 2  0.82972953 0.82972953  0.6884510859
#> 3  0.11693790 0.11693790  0.0136744729
#> 4  0.16753643 0.16753643  0.0280684543
#> 5 -0.25012877 0.25012877  0.0625644030
#> 6  0.62762457 0.62762457  0.3939126027
```
