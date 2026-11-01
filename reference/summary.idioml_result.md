# Summary method for idiographic ML fits

Summary method for idiographic ML fits

## Usage

``` r
# S3 method for class 'idioml_result'
summary(object, ...)
```

## Arguments

- object:

  An `idioml_result`.

- ...:

  Ignored.

## Value

A `data.frame` of held-out metrics with one row per `model_scope`,
model, estimator and person: `n`, `mae`, `rmse`, `bias` and `r_squared`
for regression, accuracy-type metrics for classification.
