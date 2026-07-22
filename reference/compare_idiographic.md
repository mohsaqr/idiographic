# Compare idiographic estimators on one dataset

Fits one or more idiographic estimators to the same data and returns a
tidy per-method/per-network comparison table. This is a reporting layer:
it does not define a new model, and each row is computed from the
estimator's own [`summary()`](https://rdrr.io/r/base/summary.html)
method plus common edge-table accessors.

## Usage

``` r
compare_idiographic(
  data,
  vars,
  estimators = c("var", "graphical_var"),
  id = NULL,
  day = NULL,
  beep = NULL,
  estimator_args = list(),
  keep_fits = FALSE
)
```

## Arguments

- data:

  A `data.frame` or matrix with columns for variables and optional
  id/day/beep columns.

- vars:

  Character vector of variable names.

- estimators:

  Character vector naming registered network estimators to fit. Built-in
  values are `"var"`, `"var_bayes"`, `"graphical_var"`, `"mlvar"`,
  `"mlvar_bayes"`, `"mlvar_mplus"`, `"usem"`, and `"gimme"`.

- id:

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- estimator_args:

  Named list of per-estimator argument lists, e.g.
  `list(graphical_var = list(n_lambda = 8), usem = list(temporal = "ar"))`.

- keep_fits:

  Logical. Store fitted model objects? Default `FALSE`.

## Value

A `model_comparison` object with `$comparison`, `$failures`, and
optionally `$fits`. `$comparison` is a tidy `data.frame` with one row
per method/network.

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:4, each = 15),
                beep = rep(1:15, 4),
                A = rnorm(60), B = rnorm(60), C = rnorm(60))
cmp <- compare_idiographic(
  d, vars = c("A", "B", "C"), id = "id", day = "day", beep = "beep",
  estimators = c("var", "graphical_var"),
  estimator_args = list(graphical_var = list(n_lambda = 5))
)
cmp$comparison
#>          method         network n_nodes n_edges density mean_abs_weight
#> 1           var        temporal       3       6       1      0.09014205
#> 2           var contemporaneous       3       3       1      0.08260114
#> 3 graphical_var        temporal       3       0       0      0.00000000
#> 4 graphical_var contemporaneous       3       0       0      0.00000000
#>   n_positive n_negative n_self max_abs_weight
#> 1          3          3      3      0.1899219
#> 2          2          1      0      0.1304348
#> 3          0          0      0      0.0000000
#> 4          0          0      0      0.0000000
```
