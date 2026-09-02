# Tidy subgroup assignments

Tidy subgroup assignments

## Usage

``` r
groups(
  x,
  subgroup = NULL,
  subject = NULL,
  sort_by = NULL,
  decreasing = FALSE,
  n = NULL,
  ...
)
```

## Arguments

- x:

  An
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result, or a fit built with subgroups.

- subgroup, subject:

  Optional filters.

- sort_by:

  Optional column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- n:

  Optional number of rows.

- ...:

  Ignored.

## Value

A data frame of subgroup assignments.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", k = 2, reps = 10)
groups(g, sort_by = "stability", decreasing = TRUE, n = 5)
#>   subject subgroup            method stability n_assignments
#> 1     Bob       g2 effect_clustering 0.8941176            10
#> 2    Ivan       g2 effect_clustering 0.8941176            10
#> 3    Judy       g2 effect_clustering 0.8941176            10
#> 4    Lars       g2 effect_clustering 0.8941176            10
#> 5      Li       g2 effect_clustering 0.8941176            10
```
