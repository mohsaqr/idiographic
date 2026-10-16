# Tidy model metrics

Tidy model metrics

## Usage

``` r
metrics(
  x,
  model = NULL,
  scope = NULL,
  subject = NULL,
  n = NULL,
  overall = FALSE,
  sort_by = NULL,
  decreasing = FALSE,
  by = c("person", "fold"),
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

  Logical. If `TRUE`, return only overall rows.

- sort_by:

  Optional metric/column to sort by.

- decreasing:

  Sort order when `sort_by` is supplied.

- by:

  Summarise by person (default) or separately within each rolling fold.

- ...:

  Ignored.

## Value

A data frame.
