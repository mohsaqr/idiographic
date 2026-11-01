# Tidy tables from a subgroup result

Tidy tables from a subgroup result

## Usage

``` r
# S3 method for class 'idiographic_groups'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("groups", "components", "bic"),
  ...
)

# S3 method for class 'idiostats_groups'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("groups", "components", "bic"),
  ...
)
```

## Arguments

- x:

  A
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result.

- row.names, optional:

  Ignored.

- what:

  Which table to return: `"groups"` (one row per person, as
  [`groups()`](https://pak.dynasite.org/idiographic/reference/groups.md)),
  `"components"` (one row per subgroup and term: the component
  regressions of `method = "mixture_regression"`, with the mixing
  `share` and residual `sigma`), or `"bic"` (one row per candidate
  number of components: the mixture's own BIC sweep, reported when
  `method = "mixture_regression"` and `k = "auto"`).

- ...:

  Ignored.

## Value

A `data.frame`. `"components"` has columns `subgroup`, `share`, `sigma`,
`term`, `estimate`. Requesting `"components"` or `"bic"` from a result
that has no such table raises an error of class
`idiographic_missing_table`.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", method = "mixture_regression", k = 2,
                    reps = 5)
as.data.frame(g, what = "components")
#>    subgroup     share    sigma        term   estimate
#> 1        g1 0.3611115 18.06213 (Intercept) 38.8879908
#> 2        g1 0.3611115 18.06213    efficacy  0.1084193
#> 3        g1 0.3611115 18.06213       value  0.1691081
#> 4        g1 0.3611115 18.06213    planning  0.1557136
#> 5        g1 0.3611115 18.06213  monitoring  0.1377967
#> 6        g2 0.6388885 20.63367 (Intercept)  7.0175893
#> 7        g2 0.6388885 20.63367    efficacy  0.2162166
#> 8        g2 0.6388885 20.63367       value  0.1344838
#> 9        g2 0.6388885 20.63367    planning  0.3703243
#> 10       g2 0.6388885 20.63367  monitoring  0.1212466
```
