# Coerce a gvar_result to plottable netobjects

Returns the temporal lag layer(s) and contemporaneous network as
netobjects, so each renders directly with
[`cograph::splot()`](https://sonsoles.me/cograph/reference/splot.html)
(or any netobject verb) without the caller transposing matrices or
dropping intercept columns. The temporal network is oriented
`[from = predictor(t-1), to = outcome(t)]`.

## Usage

``` r
# S3 method for class 'gvar_result'
as_netobject(x, ...)
```

## Arguments

- x:

  A `gvar_result`.

- ...:

  Ignored.

## Value

A `netobject_group`: a named list with `$temporal` for a lag-1 model, or
one `temporal_lagN` element per multi-lag model, plus
`$contemporaneous`.
