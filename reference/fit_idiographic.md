# Fit an idiographic model through the unified interface

`fit_idiographic()` dispatches every built-in estimator and workflow
through the same entry point. Arguments may be supplied directly or in
`params`, which makes a stored configuration directly replayable. Direct
arguments and `params` must both be named and cannot overlap; this turns
otherwise ambiguous duplicate arguments into an immediate, informative
error.

## Usage

``` r
fit_idiographic(data, method, ..., params = list())
```

## Arguments

- data:

  A data frame or matrix passed to the selected method.

- method:

  A registered method name or alias.

- ...:

  Named arguments passed directly to the selected method.

- params:

  A named list of additional method arguments.

## Value

The selected method's result, unchanged except for lightweight dispatch
and equivalence metadata attributes.

## Examples

``` r
set.seed(1)
d <- data.frame(A = rnorm(80), B = rnorm(80))
fit <- fit_idiographic(d, "var", vars = c("A", "B"), scale = FALSE)
fit2 <- fit_idiographic(d, "ols-var",
                        params = list(vars = c("A", "B"), scale = FALSE))
equivalence(fit)
#> Idiographic equivalence declaration
#>   Method:    var
#>   Status:    validated
#>   Reference: stats::lm.fit
#>   Scope:     OLS coefficient engine and package-defined VAR(1) preprocessing.
#>   Tolerance: 1e-10
#>   Notes:     This is engine equivalence, not blanket equivalence to another VAR package.
```
