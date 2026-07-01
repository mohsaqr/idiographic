# Fit an ordinary least-squares VAR for every subject

Applies
[`build_var()`](https://saqr.me/idiographic/reference/build_var.md) to
each subject separately, returning one transparent person-specific OLS
VAR result per individual. This is the unregularized companion to
[`graphical_var_each()`](https://saqr.me/idiographic/reference/graphical_var_each.md)
and is useful as an equivalence baseline for checking lag construction,
scaling, and temporal coefficient direction.

## Usage

``` r
build_var_each(
  data,
  vars,
  id,
  day = NULL,
  beep = NULL,
  min_obs = NULL,
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

  Character. Name of the person-ID column; required.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- min_obs:

  Integer or `NULL`. Keep only subjects with at least this many
  observations.

- ...:

  Further arguments passed to
  [`build_var()`](https://saqr.me/idiographic/reference/build_var.md).

## Value

A named list of `var_result` objects (class `var_list`), one element per
subject, named by subject id. Subjects that cannot be fit are dropped
with a warning.

## See also

[`build_var()`](https://saqr.me/idiographic/reference/build_var.md),
[`graphical_var_each()`](https://saqr.me/idiographic/reference/graphical_var_each.md)

## Examples

``` r
set.seed(1)
d <- data.frame(
  id = rep(1:3, each = 40),
  day = rep(1, 120),
  beep = rep(seq_len(40), 3),
  A = rnorm(120), B = rnorm(120), C = rnorm(120)
)
fits <- build_var_each(d, vars = c("A", "B", "C"), id = "id",
                       day = "day", beep = "beep")
fits[["1"]]
#> OLS VAR Result
#>   Variables:      3 (A, B, C)
#>   Observations:   39
#>   Temporal edges: 9 / 9
#>   Contemp edges:  3 / 3
#> 
#>   Temporal [directed]
#>     weights [-0.334, 0.123]  |  +3 / -6 edges
#>           A     B     C
#>     A  0.07  0.12  0.08
#>     B -0.33 -0.31 -0.10
#>     C -0.27 -0.07 -0.29
#> 
#>   Contemporaneous [undirected]
#>     weights [-0.236, 0.043]  |  +1 / -2 edges
#>           A     B     C
#>     A  0.00  0.04 -0.01
#>     B  0.04  0.00 -0.24
#>     C -0.01 -0.24  0.00
#> 
#>   plot(x) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```
