# Plottable netobjects from an mlVAR fit

Returns the three networks as netobjects oriented for plotting (temporal
edges run predictor -\> outcome, matching `fit_graphical_var`), so
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
renders them consistently. The raw `fit$temporal$weights` keep mlVAR's
`[outcome, predictor]` layout for equivalence.

## Usage

``` r
# S3 method for class 'net_mlvar'
as_netobject(x, ...)
```

## Arguments

- x:

  A `net_mlvar` object.

- ...:

  Unused.

## Value

A `netobject_group` with `$temporal`, `$contemporaneous`, `$between`.
