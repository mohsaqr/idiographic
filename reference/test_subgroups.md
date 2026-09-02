# Test whether subgroups exist at all

Every clustering method in this package returns groups on request,
including when there are none to find. This is the verb that can say
**no**.

## Usage

``` r
test_subgroups(data, y, x, id, time = NULL, k_max = 4L, ...)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- x:

  Predictors (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector).

- id:

  Person/unit ID column.

- time:

  Optional ordering column.

- k_max:

  Largest number of subgroups considered.

- ...:

  Ignored.

## Value

An `idiostats_subgroup_test`. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) for the
tidy BIC table.

## Details

People are summarised by their person-specific regression coefficients,
and a Gaussian mixture is fitted to those coefficients for `1..k_max`
components, selecting jointly over the number of components and the
covariance structure by BIC. If one component wins, the evidence does
not support subgroups.

The result also reports the skewness and kurtosis of the coefficients,
because distributional shape is what makes this test lie. In simulation,
a single skewed population produced spurious subgroups in 35-47% of
runs, versus 5-8% under normality. **A significant-looking subgroup
solution on visibly skewed coefficients is not trustworthy.**

## References

Bauer, D. J., & Curran, P. J. (2003). Distributional assumptions of
growth mixture models. *Psychological Methods*, 8(3), 338-363.

## Examples

``` r
test_subgroups(srl, y = "effort", x = "efficacy:monitoring", id = "name")
#> Idiographic Subgroup Test
#>   People:      36
#>   Coefficients: efficacy, value, planning, monitoring
#>   Searched:    k = 1..4, covariance models EII/VII/EEI/EEE/VVV/VVI
#> 
#>   VERDICT:     no subgroups detected (one population fits best)
#>                Clustering these people anyway will still return
#>                groups -- they will not mean anything.
#> 
#>   Use as.data.frame() for the BIC table.
```
