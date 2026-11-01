# Tidy tables of a rolling network result

Tidy tables of a rolling network result

## Usage

``` r
# S3 method for class 'rolling_var_result'
as.data.frame(
  x,
  row.names = NULL,
  optional = FALSE,
  what = c("estimates", "windows"),
  ...
)
```

## Arguments

- x:

  A `rolling_var_result` from
  [`fit_rolling_var()`](https://pak.dynasite.org/idiographic/reference/fit_rolling_var.md).

- row.names, optional:

  Ignored; part of the
  [`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html)
  generic.

- what:

  `"estimates"` (default) for one row per window and edge, or
  `"windows"` for one row per window with its subject, start and end.

- ...:

  Ignored.

## Value

A base `data.frame`. For `"estimates"`, one row per subject, window,
network and edge: `subject`, `window`, the window bounds (`start_row`,
`end_row`, `start_day`, `end_day`, `start_beep`, `end_beep`), `network`,
`from`, `to` and `weight`. For `"windows"`, one row per window with its
subject and bounds. The failures of individual windows are returned by
[`failures()`](https://pak.dynasite.org/idiographic/reference/failures.md).

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, A = rnorm(100), B = rnorm(100))
tv <- fit_rolling_var(d, vars = c("A", "B"), id = "id",
                      window_size = 50, step = 25, scale = FALSE)
head(as.data.frame(tv))
#>   subject window start_row end_row start_day end_day start_beep end_beep
#> 1       1      1         1      50      <NA>    <NA>         NA       NA
#> 2       1      1         1      50      <NA>    <NA>         NA       NA
#> 3       1      1         1      50      <NA>    <NA>         NA       NA
#> 4       1      1         1      50      <NA>    <NA>         NA       NA
#> 5       1      1         1      50      <NA>    <NA>         NA       NA
#> 6       1      2        26      75      <NA>    <NA>         NA       NA
#>           network from to       weight
#> 1        temporal    A  A  0.028012221
#> 2        temporal    B  A  0.052366683
#> 3        temporal    A  B  0.048925584
#> 4        temporal    B  B -0.130995652
#> 5 contemporaneous    A  B  0.023139527
#> 6        temporal    A  A -0.008412032
as.data.frame(tv, what = "windows")
#>   subject window start_row end_row start_day end_day start_beep end_beep
#> 1       1      1         1      50      <NA>    <NA>         NA       NA
#> 2       1      2        26      75      <NA>    <NA>         NA       NA
#> 3       1      3        51     100      <NA>    <NA>         NA       NA
```
