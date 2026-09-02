# Split repeated-measures variance into within- and between-person parts

The first question to ask of any repeated-measures variable: is the
variation mostly *between* people (some people simply score higher) or
*within* people (everyone moves around a lot over time)? The answer
decides whether person-specific modelling can pay off at all.

## Usage

``` r
variance_components(x, ...)

# S3 method for class 'data.frame'
variance_components(x, vars = NULL, id, method = c("anova", "reml"), ...)

# S3 method for class 'idiostats_wb'
variance_components(x, ...)
```

## Arguments

- x:

  A data frame of repeated measures, or a
  [`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
  result.

- ...:

  Ignored.

- vars:

  Columns to decompose (any
  [`fit_lm()`](https://pak.dynasite.org/idiographic/reference/fit_lm.md)
  selector). Defaults to every numeric column other than `id`.

- id:

  Person/unit ID column.

- method:

  `"anova"` (base R, the default) or `"reml"` (needs `lme4`).

## Value

A `data.frame` with class `idiographic_variance`. For a data frame: one
row per variable, with `variable`, `n`, `people`, `var_within`,
`var_between`, `var_total`, `icc`, `reliability`. For a fitted model:
one row per grouping level, with `level`, `variance`, `sd`, `icc`.

## Details

Called on a **data frame**, the default estimator is the one-way
random-effects ANOVA, which handles unbalanced panels through the usual
`n0` correction rather than assuming equal numbers of occasions per
person:

\$\$\sigma^2\_{between} = (MS\_{between} - MS\_{within}) / n_0, \qquad
\sigma^2\_{within} = MS\_{within}\$\$

`method = "reml"` fits `v ~ 1 + (1 | id)` with `lme4` instead. The two
agree closely on balanced data; REML is preferable when the panel is
badly unbalanced.

`icc` is the share of variance that lies between people. A high `icc`
means people differ mostly in *level*, and a pooled model that ignores
the person will be badly confounded. A low `icc` means most of the
action is within-person, which is what idiographic modelling is for.

`reliability` is a different question – how precisely each person's
*mean* is measured, given how many occasions they contributed. A
variable can have a low `icc` (little between-person variance) and still
have high `reliability` (that little variance is measured well).

Called on a
[`fit_within_between()`](https://pak.dynasite.org/idiographic/reference/fit_within_between.md)
result fitted with `estimator = "reml"` or `"ml"`, it returns the
**model's** variance components instead: one row per grouping level plus
the residual, which is what a null multilevel model is usually run to
obtain.

## Examples

``` r
variance_components(srl, vars = "efficacy:organizing", id = "name")
#> VARIANCE COMPONENTS
#>   Grouping   name
#>   Method     anova
#> 
#>                  Within    Between     ICC   Reliability
#> --------------------------------------------------------
#>   efficacy     472.5379   249.7267   0.346         0.988
#>   value        502.4351   208.0738   0.293         0.985
#>   planning     498.5651   217.8932   0.304         0.986
#>   monitoring   467.1183   437.6607   0.484         0.993
#>   effort       522.5017   207.7688   0.285         0.984
#>   control      552.2896   337.4665   0.379         0.990
#>   help         440.6868   327.0538   0.426         0.991
#>   social       469.0540   443.5421   0.486         0.993
#>   organizing   519.6494   251.0974   0.326         0.987
#> 
#>   ICC         share of variance lying BETWEEN groups
#>   Reliability precision of each group's own mean
```
