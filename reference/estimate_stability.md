# Estimate edge stability by block resampling (experimental)

**Experimental.** The resampling design is methodologically grounded
(block bootstrap for dependent data; edge-stability summaries in the
spirit of bootnet), but unlike the estimators in this package it has no
external reference implementation to validate against, and its
interface, defaults, and reported statistics may change in a future
release.

Refits an idiographic estimator across deterministic block resamples and
summarizes edge-level stability. Blocks preserve within-block time
order: subject-day blocks when `id` and `day` are supplied, subjects
when only `id` is supplied, days when only `day` is supplied, or
consecutive row blocks for a single series. Duplicate blocks receive
temporary ids/day labels before fitting so lag construction never
connects two sampled copies.

## Usage

``` r
estimate_stability(
  data,
  vars,
  estimator = c("var", "graphical_var", "mlvar", "usem", "gimme"),
  id = NULL,
  day = NULL,
  beep = NULL,
  n_resamples = 100L,
  resample = c("block", "split_half"),
  block_size = NULL,
  threshold = 1e-08,
  seed = NULL,
  keep_fits = FALSE,
  ...
)
```

## Arguments

- data:

  A `data.frame` or matrix with columns for variables and optional
  id/day/beep columns.

- vars:

  Character vector of variable names.

- estimator:

  `"var"` for
  [`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md),
  `"graphical_var"` for
  [`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md),
  `"mlvar"` for
  [`build_mlvar()`](https://mohsaqr.github.io/idiographic/reference/build_mlvar.md),
  `"usem"` for
  [`build_usem()`](https://mohsaqr.github.io/idiographic/reference/build_usem.md),
  or `"gimme"` for
  [`build_gimme()`](https://mohsaqr.github.io/idiographic/reference/build_gimme.md).

- id:

  Character. Name of the person-ID column, or `NULL`.

- day:

  Character. Name of the day/session column, or `NULL`.

- beep:

  Character. Name of the measurement-occasion column, or `NULL`.

- n_resamples:

  Integer number of bootstrap/split resamples.

- resample:

  `"block"` samples blocks with replacement; `"split_half"` samples half
  the blocks without replacement on each replicate.

- block_size:

  Integer or `NULL`. Consecutive block length used only when neither
  `id` nor `day` is supplied.

- threshold:

  Numeric. Absolute weight above which an edge is counted as selected.

- seed:

  Optional integer seed for deterministic resampling.

- keep_fits:

  Logical. Store successful resampled fits in the returned object?

- ...:

  Further arguments passed to the estimator.

## Value

A `stability_result` with `$stability` edge statistics, `$original` fit,
`$resample_edges`, `$failures`, and `$config`.

## See also

[`build_var()`](https://mohsaqr.github.io/idiographic/reference/build_var.md),
[`graphical_var()`](https://mohsaqr.github.io/idiographic/reference/graphical_var.md)

## Examples

``` r
set.seed(1)
d <- data.frame(id = 1, day = rep(1:4, each = 12),
                beep = rep(1:12, 4),
                A = rnorm(48), B = rnorm(48), C = rnorm(48))
st <- estimate_stability(d, vars = c("A", "B", "C"), id = "id",
                         day = "day", beep = "beep",
                         n_resamples = 5, seed = 1)
head(st$stability)
#>            network from to    original        mean        sd         q05
#> 10 contemporaneous    A  B  0.13027729  0.13845866 0.0587604  0.06255204
#> 11 contemporaneous    A  C -0.14198048 -0.16134737 0.1837809 -0.36807703
#> 12 contemporaneous    B  C -0.22954327 -0.16365677 0.1239109 -0.29672478
#> 1         temporal    A  A  0.10759527  0.11930456 0.1776873 -0.10205015
#> 4         temporal    A  B -0.02571567  0.03014999 0.1302933 -0.13477600
#> 7         temporal    A  C  0.02149650  0.04130588 0.2217429 -0.30741373
#>            q50         q95 selection_prop positive_prop negative_prop n_success
#> 10  0.13054748  0.20012437              1           1.0           0.0         5
#> 11 -0.16927615  0.10788310              1           0.2           0.8         5
#> 12 -0.13468438 -0.04610904              1           0.0           1.0         5
#> 1   0.16051959  0.30279525              1           0.6           0.4         5
#> 4   0.05018912  0.18010394              1           0.6           0.4         5
#> 7   0.16355377  0.20380351              1           0.6           0.4         5
```
