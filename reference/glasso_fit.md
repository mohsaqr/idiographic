# Fit a graphical lasso at a fixed penalty

Solves the graphical lasso problem \$\$\min\_{\Theta \succ 0} \\
-\log\det\Theta + \mathrm{tr}(S\Theta) + \sum\_{i \neq j} \rho\_{ij}
\|\Theta\_{ij}\|\$\$ with a pure-R block-coordinate-descent solver
(Friedman, Hastie and Tibshirani, 2008). No compiled code and no
external dependency is involved, so the estimator is available wherever
R is.

The objective is strictly convex, so its minimiser is unique and a
sufficiently converged fit is *the* global optimum regardless of solver.
[`glasso_kkt()`](https://pak.dynasite.org/idiographic/reference/glasso_kkt.md)
certifies that directly from the stationarity conditions, without
reference to any other implementation.

## Usage

``` r
glasso_fit(
  S,
  rho,
  penalize_diagonal = FALSE,
  zero = NULL,
  max_outer = 10000,
  tol_outer = 1e-08,
  max_inner = 10000,
  tol_inner = 1e-10
)
```

## Arguments

- S:

  Covariance or correlation matrix (`p x p`, symmetric, finite).

- rho:

  Either a single non-negative penalty applied to every off-diagonal
  entry, or a `p x p` non-negative matrix of element-wise penalties.

- penalize_diagonal:

  Logical. Penalise the diagonal of `Theta` as well? Default `FALSE`,
  matching the usual EBIC-glasso convention.

- zero:

  Optional two-column matrix of `(row, col)` index pairs whose `Theta`
  entries are hard-constrained to zero. Used for the unpenalised refit
  of a selected edge set. The diagonal is never constrained.

- max_outer, tol_outer:

  Outer (column-sweep) iteration cap and convergence tolerance.

- max_inner, tol_inner:

  Inner (coordinate-descent) iteration cap and convergence tolerance.

## Value

An object of class `glasso_result`: a list with

- `wi`:

  `p x p` estimated precision matrix \\\Theta\\.

- `w`:

  `p x p` estimated (regularised) covariance \\\Theta^{-1}\\.

- `beta`:

  `p x p` matrix of lasso coefficients from the column sweep, reusable
  as a warm start.

- `rho`:

  The penalty as supplied – a scalar or a `p x p` matrix.

- `penalize_diagonal`:

  The diagonal-penalty flag used.

- `zero`:

  The hard zero constraints applied, or `NULL`.

- `S`:

  The covariance the fit was made to, retained so
  [`glasso_kkt()`](https://pak.dynasite.org/idiographic/reference/glasso_kkt.md)
  can certify the result on its own. For large `p` in a resampling loop
  this is a real retention cost;
  [`glasso_path()`](https://pak.dynasite.org/idiographic/reference/glasso_path.md)
  does not retain it.

The `wi` and `w` element names are deliberately identical to those
returned by
[`glasso::glasso()`](https://rdrr.io/pkg/glasso/man/glasso.html), so
existing call sites port unchanged. Use
[`as.data.frame()`](https://rdrr.io/r/base/as.data.frame.html) for a
tidy one-row-per-edge partial-correlation table.

## References

Friedman, J., Hastie, T. and Tibshirani, R. (2008). Sparse inverse
covariance estimation with the graphical lasso. *Biostatistics*, 9(3),
432-441.
[doi:10.1093/biostatistics/kxm045](https://doi.org/10.1093/biostatistics/kxm045)

## See also

[`glasso_path()`](https://pak.dynasite.org/idiographic/reference/glasso_path.md)
for a whole penalty path,
[`glasso_kkt()`](https://pak.dynasite.org/idiographic/reference/glasso_kkt.md)
for an optimality certificate, and
[`fit_graphical_var()`](https://pak.dynasite.org/idiographic/reference/fit_graphical_var.md)
for the estimator that consumes this kernel.

## Examples

``` r
set.seed(1)
z <- rnorm(200)
x <- cbind(A = z + rnorm(200, 0, 0.5), B = z + rnorm(200, 0, 0.5),
           C = rnorm(200), D = rnorm(200))
fit <- glasso_fit(cov(x), rho = 0.05)
fit
#> Graphical Lasso Fit
#>   Variables:      4
#>   Penalty (rho):  0.05
#>   Diagonal:       unpenalised
#>   Nonzero edges:  3 / 6
#> 
#>   as.data.frame(x) | glasso_kkt(x)
as.data.frame(fit)
#>   from to   precision      weight
#> 1    A  B -1.28019985 0.717722622
#> 2    A  C -0.01229880 0.009791151
#> 3    A  D -0.00454654 0.003547031
#> 4    B  C  0.00000000 0.000000000
#> 5    B  D  0.00000000 0.000000000
#> 6    C  D  0.00000000 0.000000000
glasso_kkt(fit)
#> [1] 4.440892e-16
```
