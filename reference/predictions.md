# Tidy held-out predictions

Tidy held-out predictions

## Usage

``` r
predictions(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  overall = FALSE,
  sort_by = NULL,
  decreasing = FALSE,
  ...
)
```

## Arguments

- x:

  An idiographic fit.

- model, scope, subject:

  Optional filters.

- n:

  Optional number of rows to return.

- overall:

  Logical. If `TRUE`, return only overall rows when present.

- sort_by:

  Optional column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- ...:

  Ignored.

## Value

A data frame.
