# Fit a graphical lasso over a path of penalties

Runs
[`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md)
at every penalty in `rho`, warm-starting each fit from the previous one.
This is the kernel behind bootstrap and resampling workflows that need
many refits of the same covariance.

## Usage

``` r
glasso_path(
  S,
  rho,
  penalize_diagonal = FALSE,
  max_outer = 10000,
  tol_outer = 1e-04,
  max_inner = 10000,
  tol_inner = 1e-04
)
```

## Arguments

- S:

  Covariance or correlation matrix (`p x p`, symmetric, finite).

- rho:

  Numeric vector of non-negative penalties, used in the order supplied.

- penalize_diagonal:

  Logical. Penalise the diagonal of `Theta` as well? Default `FALSE`,
  matching the usual EBIC-glasso convention.

- max_outer, max_inner:

  Outer (column-sweep) and inner (coordinate-descent) iteration caps, as
  in
  [`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md).

- tol_outer, tol_inner:

  Convergence tolerances. The defaults are the looser path tolerances
  (`1e-4`), matching
  [`glasso::glassopath()`](https://rdrr.io/pkg/glasso/man/glassopath.html):
  path scanning selects among well-separated models, so machine
  precision at every rung buys nothing. Refit the selected penalty with
  [`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md)
  when the returned matrix itself must be at full precision.

## Value

An object of class `glasso_path_result`: a list with `w` and `wi`, each
a `p x p x length(rho)` array indexed in the order `rho` was supplied,
plus the `rho` vector itself. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) for a
tidy one-row-per-edge-per-penalty table.

## See also

[`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md)

## Examples

``` r
set.seed(1)
z <- rnorm(200)
x <- cbind(A = z + rnorm(200, 0, 0.5), B = z + rnorm(200, 0, 0.5),
           C = rnorm(200), D = rnorm(200))
path <- glasso_path(cov(x), rho = c(0.01, 0.05, 0.2))
path
#> Graphical Lasso Path
#>   Variables:      4
#>   Penalties:      3 (0.01 to 0.2)
#>   Nonzero edges:  4, 3, 1
#> 
#>   as.data.frame(x)
as.data.frame(path)
#>     rho from to   precision      weight
#> 1  0.01    A  B -1.49912964 0.751703867
#> 2  0.01    A  C -0.04203394 0.031587449
#> 3  0.01    C  D -0.02373780 0.027607344
#> 4  0.01    A  D -0.03528085 0.025989049
#> 5  0.01    B  C  0.00000000 0.000000000
#> 6  0.01    B  D  0.00000000 0.000000000
#> 7  0.05    A  B -1.28019986 0.717722626
#> 8  0.05    A  C -0.01229880 0.009791150
#> 9  0.05    A  D -0.00454654 0.003547031
#> 10 0.05    B  C  0.00000000 0.000000000
#> 11 0.05    B  D  0.00000000 0.000000000
#> 12 0.05    C  D  0.00000000 0.000000000
#> 13 0.20    A  B -0.77729717 0.588053200
#> 14 0.20    A  C  0.00000000 0.000000000
#> 15 0.20    B  C  0.00000000 0.000000000
#> 16 0.20    A  D  0.00000000 0.000000000
#> 17 0.20    B  D  0.00000000 0.000000000
#> 18 0.20    C  D  0.00000000 0.000000000
```
