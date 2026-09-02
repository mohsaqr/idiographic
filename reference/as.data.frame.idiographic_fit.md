# Convert a consolidated fit to its prediction table

Convert a consolidated fit to its prediction table

## Usage

``` r
# S3 method for class 'idiographic_fit'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)

# S3 method for class 'idiostats_fit'
as.data.frame(x, row.names = NULL, optional = FALSE, ...)
```

## Arguments

- x:

  A consolidated `idiographic_fit`.

- row.names:

  Ignored.

- optional:

  Ignored.

- ...:

  Filters passed to
  [`predictions()`](https://pak.dynasite.org/idiographic/reference/predictions.md).

## Value

A prediction `data.frame`.
