# Build an ordinary least-squares VAR network

Fits a transparent VAR(1) baseline from intensive longitudinal data
using ordinary least squares: current variables are regressed on an
intercept and lag-1 predictors. The lag construction, scaling,
within-person centering, and day-boundary behavior match
[`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md),
but no regularization or EBIC model selection is applied.

## Usage

``` r
fit_var(
  data,
  vars,
  id = NULL,
  day = NULL,
  beep = NULL,
  lags = 1L,
  scale = TRUE,
  center_within = TRUE,
  delete_missings = TRUE,
  min_obs = NULL,
  subject = NULL
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

- lags:

  Integer. Only `1` is supported.

- scale:

  Logical. Whether to standardize variables before lagging. Default
  `TRUE`.

- center_within:

  Logical. Whether to center within person when more than one id is
  present. Default `TRUE`.

- delete_missings:

  Logical. Drop incomplete current/lagged rows. Default `TRUE`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- subject:

  Optional vector naming the subject(s) to analyse.

## Value

A `var_result` object with temporal OLS coefficients, residual
covariance, residual precision, contemporaneous partial correlations,
and tidy access through
[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md),
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md),
[`nodes()`](https://mohsaqr.github.io/idiographic/reference/nodes.md),
and [`summary()`](https://rdrr.io/r/base/summary.html).

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, A = rnorm(80), B = rnorm(80), C = rnorm(80))
fit <- fit_var(d, vars = c("A", "B", "C"), id = "id")
edges(fit)
#>           network from to       weight
#> 1        temporal    C  B  0.113592795
#> 2        temporal    B  C -0.056084686
#> 3        temporal    B  A  0.042216979
#> 4        temporal    A  B -0.030796224
#> 5        temporal    A  C -0.024626586
#> 6        temporal    C  A  0.004625333
#> 7 contemporaneous    A  B -0.302794840
#> 8 contemporaneous    A  C  0.175739891
#> 9 contemporaneous    B  C  0.042015104
```
