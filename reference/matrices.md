# Print model matrices for idiographic results

`matrices()` is the matrix-oriented companion to
[`summary()`](https://rdrr.io/r/base/summary.html) and
[`edges()`](https://pak.dynasite.org/idiographic/reference/edges.md). It
returns the core estimated matrices and, by default, prints each one
compactly with rounding, so users can inspect coefficients without
digging through object internals.

## Usage

``` r
matrices(x, ...)

# Default S3 method
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'cograph_network'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'netobject'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'netobject_group'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'gvar_result'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'var_result'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'net_mlvar'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'net_usem'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'net_gimme'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'preprocess_result'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'rolling_var_result'
matrices(x, fit = 1L, digits = 3, ..., print = TRUE)

# S3 method for class 'rolling_gvar_result'
matrices(x, fit = 1L, digits = 3, ..., print = TRUE)

# S3 method for class 'stability_result'
matrices(x, digits = 3, ..., print = TRUE)

# S3 method for class 'model_comparison'
matrices(x, fit = 1L, digits = 3, ..., print = TRUE)

# S3 method for class 'var_list'
matrices(x, subject = 1L, digits = 3, ..., print = TRUE)

# S3 method for class 'gvar_list'
matrices(x, subject = 1L, digits = 3, ..., print = TRUE)
```

## Arguments

- x:

  An idiographic result or cograph network/group.

- ...:

  Passed to methods.

- digits:

  Number of digits used for printing. Default `3`.

- print:

  Logical. Print the matrices to the console? Default `TRUE`, which also
  returns the list *invisibly*. Use `print = FALSE` for programmatic
  extraction: the function itself prints nothing and returns the list
  visibly (so a bare call at the console still auto-prints the returned
  value – assign it, or wrap in
  [`invisible()`](https://rdrr.io/r/base/invisible.html), to see nothing
  at all). `print` follows `...` in every method, so it must be named in
  full; it can never be matched positionally or by partial name.

- fit:

  Stored fit name or index for result containers that optionally keep
  fitted models, such as rolling results and model comparisons.

- subject:

  Subject name or index for per-subject VAR/GVAR result lists.

## Value

A named list of matrices: invisibly when `print = TRUE` (the default),
visibly when `print = FALSE`.

## Details

Pass `print = FALSE` to suppress the console output and get the named
list back visibly. That is the form other code should call: extracting
matrices inside a loop, a bootstrap, or a dependent package should not
write to the console.

## Examples

``` r
W <- matrix(c(0, 0.3, -0.2, 0), 2, 2,
            dimnames = list(c("A", "B"), c("A", "B")))
x <- structure(list(weights = W, method = "relative", directed = TRUE),
               class = "cograph_network")
matrices(as_netobject(x))
#> 
#> $weights
#>     A    B
#> A 0.0 -0.2
#> B 0.3  0.0

# programmatic extraction: silent, and returned visibly
str(matrices(as_netobject(x), print = FALSE))
#> List of 1
#>  $ weights: num [1:2, 1:2] 0 0.3 -0.2 0
#>   ..- attr(*, "dimnames")=List of 2
#>   .. ..$ : chr [1:2] "A" "B"
#>   .. ..$ : chr [1:2] "A" "B"
```
