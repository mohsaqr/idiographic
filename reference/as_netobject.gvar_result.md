# Coerce a gvar_result to plottable netobjects

Returns the two networks a graphical VAR contains as Nestimate
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

A `netobject_group`: a named list with `$temporal` (directed) and
`$contemporaneous` (undirected) netobjects.
