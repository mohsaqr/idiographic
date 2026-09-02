# Plot subgroups

For a
[`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
result, the stability of each person, grouped by subgroup, with the
chance level drawn in: bars near that line are people the method could
not place. For a fit with subgroups, the metric per subgroup.

## Usage

``` r
plot_subgroups(x, metric = NULL, ...)
```

## Arguments

- x:

  An
  [`find_subgroups()`](https://pak.dynasite.org/idiographic/reference/find_subgroups.md)
  result or a fit built with subgroups.

- metric:

  Metric column, when `x` is a fit.

- ...:

  Passed to base plotting functions.

## Value

Invisibly, the plotted table.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", k = 2, reps = 10)
plot_subgroups(g)
```
