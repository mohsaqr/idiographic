# Correlate variables within each person

The most common idiographic statistic there is: for each person
separately, how do two variables move together *within* that person. One
row per person per pair.

## Usage

``` r
correlate_persons(
  data,
  id,
  vars = NULL,
  time = NULL,
  subject = NULL,
  variable = NULL,
  sort_by = NULL,
  decreasing = FALSE,
  n = NULL,
  conf_level = 0.95,
  min_n = 4L
)
```

## Arguments

- data:

  Data frame of repeated measures.

- id:

  Person/unit ID column.

- vars:

  Columns to correlate (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector). Defaults to every numeric column other than `id` and
  `time`.

- time:

  Optional ordering column, excluded from `vars` by default.

- subject:

  Optional person(s) to correlate. Defaults to everyone.

- variable:

  Optional variable(s); keeps pairs involving any of them.

- sort_by:

  Optional column of the result to sort by, e.g. `"r"`.

- decreasing:

  Sort order when `sort_by` is supplied.

- n:

  Optional number of rows to keep.

- conf_level:

  Confidence level for the intervals.

- min_n:

  Fewest complete pairs a person needs before a correlation is reported
  rather than `NA`.

## Value

A `data.frame` of one row per person per pair, with class
`idiographic_correlations`.

## Details

A correlation is unchanged by shifting a variable's location, so a
person-specific correlation is already a **within-person** correlation –
centering the data first would not change these numbers. What it is not
is the pooled correlation, which mixes within- and between-person
covariation and can carry the opposite sign.

Confidence intervals and p-values come from the Fisher z transform, on
that person's own usable pairs.

## Examples

``` r
correlate_persons(srl, "name", vars = c("effort", "efficacy", "planning"))
#> PERSON-SPECIFIC CORRELATIONS
#>   Grouping   name
#>   People     36
#>   Pairs      3
#> 
#>   subject   x          y            n       r         95% CI          p
#> -----------------------------------------------------------------------
#>   Aisha     effort     efficacy   156   0.352   [0.21, 0.48]    < 1e-04
#>   Aisha     effort     planning   156   0.380   [0.24, 0.51]    < 1e-04
#>   Aisha     efficacy   planning   156   0.542   [0.42, 0.64]    < 1e-04
#>   Alice     effort     efficacy   156   0.491   [0.36, 0.60]    < 1e-04
#>   Alice     effort     planning   156   0.582   [0.47, 0.68]    < 1e-04
#>   Alice     efficacy   planning   156   0.568   [0.45, 0.67]    < 1e-04
#>   Anika     effort     efficacy   156   0.436   [0.30, 0.56]    < 1e-04
#>   Anika     effort     planning   156   0.630   [0.53, 0.72]    < 1e-04
#>   Anika     efficacy   planning   156   0.577   [0.46, 0.67]    < 1e-04
#>   Astrid    effort     efficacy   156   0.183   [0.03, 0.33]   0.022196
#>   Astrid    effort     planning   156   0.294   [0.14, 0.43]   0.000194
#>   Astrid    efficacy   planning   156   0.375   [0.23, 0.50]    < 1e-04
#> 
#>   ... 96 more rows.

# The strongest person-specific associations, sorted.
correlate_persons(srl, "name", vars = c("effort", "efficacy"),
                  sort_by = "r", decreasing = TRUE, n = 5)
#> PERSON-SPECIFIC CORRELATIONS
#>   Grouping   name
#>   People     5
#>   Pairs      1
#> 
#>   subject   x        y            n       r         95% CI        p
#> -------------------------------------------------------------------
#>   Lars      effort   efficacy   156   0.867   [0.82, 0.90]   <1e-04
#>   Karin     effort   efficacy   156   0.841   [0.79, 0.88]   <1e-04
#>   Hiroshi   effort   efficacy   156   0.837   [0.78, 0.88]   <1e-04
#>   Liv       effort   efficacy   156   0.767   [0.69, 0.83]   <1e-04
#>   Omar      effort   efficacy   156   0.625   [0.52, 0.71]   <1e-04
```
