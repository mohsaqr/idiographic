# Fit an ordinary least-squares VAR for every subject

Applies
[`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md)
to each subject separately, returning one transparent person-specific
OLS VAR result per individual. This is the unregularized companion to
[`fit_graphical_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var_each.md)
and is useful as an equivalence baseline for checking lag construction,
scaling, and temporal coefficient direction.

## Usage

``` r
fit_var_each(data, vars, id, day = NULL, beep = NULL, min_obs = NULL, ...)
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
  [`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md).

## Value

A named list of `var_result` objects (class `var_list`), one element per
subject, named by subject id. Subjects that cannot be fit are dropped
with a warning.

## Examples

``` r
set.seed(1)
d <- data.frame(
  id = rep(1:3, each = 40),
  day = rep(1, 120),
  beep = rep(seq_len(40), 3),
  A = rnorm(120), B = rnorm(120), C = rnorm(120)
)
fits <- fit_var_each(d, vars = c("A", "B", "C"), id = "id",
                       day = "day", beep = "beep")
fits
#> Idiographic OLS VARs
#>   Subjects:       3
#>   Variables:      3
#>   Lag pairs:      median 39 (range 39-39)
#>   Temporal edges: median 9 (range 9-9)
#>   Access:         edges(x) | matrices(x, subject = "1") | plot(x, subject = "1")
edges(fits)
#>    subject         network from to       weight
#> 1        1        temporal    B  A -0.334449439
#> 2        1        temporal    C  A -0.268308164
#> 3        1        temporal    A  B  0.123451891
#> 4        1        temporal    B  C -0.096399247
#> 5        1        temporal    A  C  0.078323279
#> 6        1        temporal    C  B -0.071241298
#> 7        1 contemporaneous    B  C -0.235617628
#> 8        1 contemporaneous    A  B  0.042767980
#> 9        1 contemporaneous    A  C -0.013305561
#> 10       2        temporal    A  C -0.242893972
#> 11       2        temporal    C  B  0.238052275
#> 12       2        temporal    B  C -0.134676220
#> 13       2        temporal    A  B  0.080957526
#> 14       2        temporal    C  A -0.070842824
#> 15       2        temporal    B  A  0.054567914
#> 16       2 contemporaneous    A  B -0.332758490
#> 17       2 contemporaneous    A  C  0.282896400
#> 18       2 contemporaneous    B  C -0.000641728
#> 19       3        temporal    B  A -0.220206978
#> 20       3        temporal    C  A -0.179718696
#> 21       3        temporal    A  B  0.174612034
#> 22       3        temporal    A  C  0.159131762
#> 23       3        temporal    B  C  0.097882095
#> 24       3        temporal    C  B  0.033223272
#> 25       3 contemporaneous    A  B  0.302546919
#> 26       3 contemporaneous    B  C -0.180732931
#> 27       3 contemporaneous    A  C  0.159837858
matrices(fits, subject = "1")
#> 
#> $beta
#>   (Intercept)     A      B      C
#> A      -0.003 0.073 -0.334 -0.268
#> B      -0.012 0.123 -0.312 -0.071
#> C      -0.026 0.078 -0.096 -0.288
#> 
#> $temporal
#>       A      B      C
#> A 0.073 -0.334 -0.268
#> B 0.123 -0.312 -0.071
#> C 0.078 -0.096 -0.288
#> 
#> $residual_cov
#>        A      B      C
#> A  0.881  0.043 -0.022
#> B  0.043  0.937 -0.221
#> C -0.022 -0.221  0.934
#> 
#> $kappa
#>        A      B     C
#> A  1.137 -0.049 0.015
#> B -0.049  1.133 0.267
#> C  0.015  0.267 1.134
#> 
#> $PCC
#>        A      B      C
#> A  0.000  0.043 -0.013
#> B  0.043  0.000 -0.236
#> C -0.013 -0.236  0.000
#> 
#> $PDC
#>        A      B      C
#> A  0.073  0.119  0.076
#> B -0.317 -0.290 -0.093
#> C -0.259 -0.069 -0.269
```
