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
#> 1        g1 0.3887867 18.25083 (Intercept) 37.6276491
#> 2        g1 0.3887867 18.25083    efficacy  0.1539743
#> 3        g1 0.3887867 18.25083       value  0.1294227
#> 4        g1 0.3887867 18.25083    planning  0.1828805
#> 5        g1 0.3887867 18.25083  monitoring  0.1110485
#> 6        g2 0.6112133 20.66396 (Intercept)  6.8401929
#> 7        g2 0.6112133 20.66396    efficacy  0.2379747
#> 8        g2 0.6112133 20.66396       value  0.1003651
#> 9        g2 0.6112133 20.66396    planning  0.3807770
#> 10       g2 0.6112133 20.66396  monitoring  0.1169605
```
