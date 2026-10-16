# Split variables into within-person and between-person parts

Person-mean centring (Curran & Bauer, 2011). Adds two columns for every
variable: `<var>_between`, the person's mean, which is the stable level
that distinguishes one person from another (repeated on each of the
person's rows), and `<var>_within`, the deviation of each occasion from
that stable level. The original columns are kept. A regression on both
columns estimates separate within-person and between-person slopes.
`split_wb()` is a short alias.

## Usage

``` r
split_levels(data, id, vars, time = NULL, keep_all = TRUE)

split_wb(data, id, vars, time = NULL, keep_all = TRUE)
```

## Arguments

- data:

  Long-format data frame.

- id:

  Person identifier column.

- vars:

  Columns to split (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector).

- time:

  Optional time column, kept in the output with `keep_all = FALSE`.

- keep_all:

  Keep every column of `data` (default). With `FALSE`, only the id and
  time columns, the split variables, and their `_between` and `_within`
  parts are returned.

## Value

`data` with `<var>_within` and `<var>_between` columns appended.

## References

Curran, P. J., & Bauer, D. J. (2011). The disaggregation of
within-person and between-person effects in longitudinal models of
change. *Annual Review of Psychology, 62*, 583-619.
[doi:10.1146/annurev.psych.093008.100356](https://doi.org/10.1146/annurev.psych.093008.100356)

## Examples

``` r
split_levels(srl, id = "name", vars = "efficacy") |> head()
#>    name day efficacy    value planning monitoring   effort  control help social
#> 1 Aisha   1 38.23529 58.33333  0.00000  34.210526 53.96825 39.39394   78   60.0
#> 2 Aisha   2 14.70588 47.22222 50.00000   7.894737 79.36508 45.45455   16   10.0
#> 3 Aisha   3 67.64706 52.77778 52.27273  19.736842 77.77778 39.39394   28   55.0
#> 4 Aisha   4 55.88235 63.88889 65.90909  22.368421 93.65079 42.42424   24   47.5
#> 5 Aisha   5 55.88235 36.11111 52.27273  22.368421 71.42857 57.57576   48   57.5
#> 6 Aisha   6 44.11765 61.11111 52.27273  57.894737 82.53968 42.42424   28   62.5
#>   organizing efficacy_within efficacy_between
#> 1   1.612903      -18.684012         56.91931
#> 2  61.290323      -42.213424         56.91931
#> 3  77.419355       10.727753         56.91931
#> 4  37.096774       -1.036953         56.91931
#> 5  75.806452       -1.036953         56.91931
#> 6  30.645161      -12.801659         56.91931
```
