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

A data.frame of predictions.
