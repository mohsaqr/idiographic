# Report method-equivalence evidence

Returns the equivalence declaration attached by
[`fit_idiographic()`](https://mohsaqr.github.io/idiographic/reference/fit_idiographic.md).
For a result created by a direct `fit_*()` call, the registry can infer
the method from a unique registered result class. The declaration
describes the scope of committed validation; it is not a new statistical
equivalence test.

## Usage

``` r
equivalence(x)
```

## Arguments

- x:

  A fitted object.

## Value

An `idiographic_equivalence` list with `method`, `status`, `reference`,
`scope`, `tolerance`, `notes`, and `source`.

## Examples

``` r
set.seed(2)
d <- data.frame(A = rnorm(40), B = rnorm(40))
fit <- fit_var(d, vars = c("A", "B"), scale = FALSE)
equivalence(fit)
#> Idiographic equivalence declaration
#>   Method:    var
#>   Status:    validated
#>   Reference: stats::lm.fit
#>   Scope:     OLS coefficient engine and package-defined VAR(1) preprocessing.
#>   Tolerance: 1e-10
#>   Notes:     This is engine equivalence, not blanket equivalence to another VAR package.
```
