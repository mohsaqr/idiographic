# Predict from an idiographic ML result

Predict from an idiographic ML result

## Usage

``` r
# S3 method for class 'idioml_result'
predict(
  object,
  newdata = NULL,
  scope = c("pooled", "individual"),
  model = NULL,
  estimator = NULL,
  type = c("response", "class"),
  ...
)
```

## Arguments

- object:

  An `idioml_result`.

- newdata:

  Optional new data. If `NULL`, the stored test-set predictions are
  returned.

- scope:

  `"pooled"` or `"individual"`.

- model:

  Fitted model name to use. Default is the first fitted model.

- estimator:

  Fitted estimator/backend for `model`. Default is that model's first
  fitted estimator.

- type:

  `"response"` for numeric predictions/probabilities or `"class"` for
  classification labels.

- ...:

  Ignored.

## Value

A `data.frame` of predictions. With `newdata = NULL`, the stored
held-out predictions of the chosen scope, model and estimator, one row
per test occasion; otherwise one row per row of `newdata`.

## Examples

``` r
# Predicting new rows needs the fitted models, so keep them.
fit <- fit_ml(srl, "effort", c("efficacy", "planning"), "name",
              model = "ridge", keep_fits = TRUE)
predict(fit, newdata = head(srl), scope = "pooled")
#>   model_scope model estimator subject original_row predicted
#> 1      pooled ridge    native   Aisha            1  35.49444
#> 2      pooled ridge    native   Aisha            2  44.40581
#> 3      pooled ridge    native   Aisha            3  61.59341
#> 4      pooled ridge    native   Aisha            4  62.36215
#> 5      pooled ridge    native   Aisha            5  57.93781
#> 6      pooled ridge    native   Aisha            6  54.28221
```
