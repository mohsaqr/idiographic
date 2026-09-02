# Plot the within/between split of variance

One bar per variable, split into the share of variance lying within
people and between people. Variables at the top are the ones where
people differ in level; variables at the bottom are the ones that move
within a person.

## Usage

``` r
plot_variance(x, sort_by = "icc", ...)
```

## Arguments

- x:

  A
  [`variance_components()`](https://pak.dynasite.org/idiographic/reference/variance_components.md)
  result.

- sort_by:

  Sort bars by this column; `NULL` keeps input order.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted table.

## Examples

``` r
v <- variance_components(srl, vars = "efficacy:organizing", id = "name")
plot_variance(v)
```
