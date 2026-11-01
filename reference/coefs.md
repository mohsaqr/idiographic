# Tidy coefficients of a fitted model

Generic accessor for the coefficient table of a fitted model. Methods
exist for the statistical fits
([`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md),
[`fit_glm()`](https://pak.dynasite.org/idiographic/reference/fit_glm.md),
[`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md),
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md),
[`fit_subgroups()`](https://pak.dynasite.org/idiographic/reference/fit_subgroups.md)),
the network estimators
([`fit_var()`](https://pak.dynasite.org/idiographic/reference/fit_var.md),
[`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md),
[`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md),
[`fit_mlvar_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_bayes.md),
[`fit_mlvar_mplus()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar_mplus.md),
[`fit_var_bayes()`](https://pak.dynasite.org/idiographic/reference/fit_var_bayes.md),
[`fit_usem()`](https://pak.dynasite.org/idiographic/reference/fit_usem.md),
[`fit_gimme()`](https://pak.dynasite.org/idiographic/reference/fit_gimme.md)),
their per-person lists
([`fit_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_var_each.md),
[`fit_graphical_var_each()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var_each.md))
and the rolling network results.

## Usage

``` r
# S3 method for class 'idioml_result'
coefs(x, ...)

coefs(x, ...)

# S3 method for class 'net_mlvar'
coefs(x, ...)

# Default S3 method
coefs(x, ...)

# S3 method for class 'net_mlvar_bayes'
coefs(x, ...)

# S3 method for class 'idiostats_fit'
coefs(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  overall = FALSE,
  sort_by = NULL,
  decreasing = FALSE,
  term = NULL,
  ...
)

# S3 method for class 'net_usem'
coefs(x, ...)

# S3 method for class 'var_result'
coefs(x, ...)

# S3 method for class 'var_bayes_result'
coefs(x, ...)

# S3 method for class 'gvar_result'
coefs(x, ...)

# S3 method for class 'net_gimme'
coefs(x, ...)

# S3 method for class 'var_list'
coefs(x, ...)

# S3 method for class 'gvar_list'
coefs(x, ...)
```

## Arguments

- x:

  A fitted model object.

- ...:

  Passed to methods.

- model, scope, subject:

  Optional filters for consolidated model fits.

- n:

  Optional maximum number of returned rows.

- overall:

  Return only aggregate rows when available?

- sort_by:

  Optional output column used for sorting.

- decreasing:

  Sort in descending order?

- term:

  Optional filter: only these coefficient terms.

## Value

A tidy `data.frame` with one row per coefficient. Statistical fits
return one row per scope, model, person and term (`scope`, `model`,
`estimator`, `subject`, `subgroup`, `term`, `estimate`, `std_error`,
`statistic`, `p_value`).
[`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md)
returns one row per outcome and predictor (`outcome`, `predictor`,
`beta`, `se`, `t`, `p`, `ci_lower`, `ci_upper`, `significant`); the
Bayesian estimators report posterior summaries (`estimate`,
`posterior_sd`, `ci_lower`, `ci_upper`, `p`, `significant`); the
ordinary and graphical VARs return their edges (`network`, `from`, `to`,
`weight`). Per-person lists add a `subject` column.

## Details

For
[`fit_mlvar()`](https://pak.dynasite.org/idiographic/reference/fit_mlvar.md)
only the within-person (temporal) coefficients are tabulated: the lagged
fixed effects of the temporal network. The between-person network is
derived through the `D (I - Gamma)` transformation and has no
coefficient table of its own.

## Examples

``` r
fit <- fit_lm(srl, y = "effort", x = "efficacy", id = "name", time = "day")
coefs(fit, scope = "pooled")
#>    scope model estimator subject subgroup        term   estimate  std_error
#> 1 pooled    lm    native    .all     .all (Intercept) 32.5060708 4.52339554
#> 2 pooled    lm    native    .all     .all    efficacy  0.4878091 0.06319256
#>   statistic      p_value
#> 1  7.186210 2.200421e-08
#> 2  7.719407 4.617938e-09
coefs(fit, term = "efficacy", sort_by = "estimate", n = 5)
#>        scope model estimator subject subgroup     term    estimate  std_error
#> 1 individual    lm    native    Ravi    .none efficacy -0.25715871 0.06375941
#> 2 individual    lm    native  Takumi    .none efficacy  0.01483564 0.05459424
#> 3 individual    lm    native  Ingrid    .none efficacy  0.04585617 0.03830126
#> 4 individual    lm    native   Freja    .none efficacy  0.05452198 0.08719789
#> 5 individual    lm    native   Diana    .none efficacy  0.08210175 0.12357205
#>    statistic      p_value
#> 1 -4.0332666 9.626368e-05
#> 2  0.2717436 7.862785e-01
#> 3  1.1972498 2.335304e-01
#> 4  0.6252672 5.329635e-01
#> 5  0.6644039 5.076856e-01

set.seed(1)
d <- data.frame(A = rnorm(80), B = rnorm(80))
coefs(fit_var(d, vars = c("A", "B")))
#>           network from to      weight
#> 1        temporal    A  A -0.02775576
#> 2        temporal    B  A  0.04237342
#> 3        temporal    A  B -0.01100758
#> 4        temporal    B  B -0.05450831
#> 5 contemporaneous    A  B -0.29792762
```
