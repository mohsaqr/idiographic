# Plot within-person correlations with their confidence intervals

One row per person and variable pair, showing the correlation and its
95% confidence interval. Rows are sorted so the strongest positive
correlations are at the top. An interval that crosses the dashed zero
line means the data cannot tell whether the two variables move together
or in opposite directions for that person.

## Usage

``` r
plot_correlations(x, subject = NULL, sort_by = "r", ...)
```

## Arguments

- x:

  A
  [`correlate_persons()`](https://pak.dynasite.org/idiographic/reference/correlate_persons.md)
  result.

- subject:

  Optional filter: only these people.

- sort_by:

  Column to sort rows by; `NULL` keeps the result's order.

- ...:

  Ignored.

## Value

Invisibly, the plotted table (one row per correlation).

## Examples

``` r
r <- correlate_persons(srl, id = "name",
                       vars = c("efficacy", "effort", "monitoring"))
plot_correlations(r, subject = c("Aisha", "Alice"))
```
