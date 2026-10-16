# Compare within-person and between-person correlations

Computes two distributions of correlations for every pair of variables,
following Fisher, Medaglia and Jeronimus (2018):

## Usage

``` r
correlate_levels(data, id, vars, time = NULL, lag_adjust = FALSE, min_n = 10L)
```

## Arguments

- data:

  Long-format data frame.

- id:

  Person identifier column.

- vars:

  Variables to correlate (at least two).

- time:

  Optional column giving the order of occasions within persons.

- lag_adjust:

  Remove first-order temporal dependence before computing within-person
  correlations.

- min_n:

  Minimum number of complete pairs for a correlation to be computed,
  within a person or across persons at one occasion.

## Value

A data frame of class `idiographic_level_correlations`, one row per
correlation, with columns `level` (`"within"` or `"between"`), `unit`
(the person for `"within"`, the occasion number for `"between"`), `x`,
`y`, `n` (complete pairs), and `r`. Summaries per pair are returned by
[`summary()`](https://rdrr.io/r/base/summary.html) and by
`as.data.frame(x, what = "summary")`.

## Details

- **within persons** (intraindividual): one correlation per person,
  computed across that person's occasions;

- **between persons** (interindividual): one correlation per occasion,
  computed across persons. Each person's series is ordered by `time`;
  the first observations of all persons form the first cross-sectional
  data set, the second observations form the second, and so on.

If group-level results generalise to individuals, the two distributions
have similar means and similar spreads. A within-person spread that is
several times larger than the between-person spread indicates that the
group correlation describes few individuals well.

With `lag_adjust = TRUE`, within-person correlations are computed on
residuals after regressing each variable on its own lag-1 value and the
lag-1 value of the other variable, which removes first-order temporal
dependence. The original authors repeated this step until the
Durbin-Watson test was non-significant; a single first-order adjustment
is used here. Between-person correlations are always computed from the
observed values.

## References

Fisher, A. J., Medaglia, J. D., & Jeronimus, B. F. (2018). Lack of
group-to-individual generalizability is a threat to human subjects
research. *Proceedings of the National Academy of Sciences, 115*(27),
E6106-E6115.
[doi:10.1073/pnas.1711978115](https://doi.org/10.1073/pnas.1711978115)

## Examples

``` r
lv <- correlate_levels(srl, id = "name", vars = c("efficacy", "effort"),
                       time = "day")
summary(lv)
#>          x      y n_within mean_within median_within sd_within n_between
#> 1 efficacy effort       36   0.3637722     0.3587067 0.2498384       156
#>   mean_between median_between sd_between mean_difference sd_ratio
#> 1    0.5034717      0.5096236  0.1373181      -0.1396996 1.819413
```
