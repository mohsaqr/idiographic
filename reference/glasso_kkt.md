# Certify a graphical-lasso solution from its optimality conditions

Returns the largest violation of the graphical-lasso stationarity (KKT)
conditions. Because the objective is strictly convex, a value near zero
certifies the global optimum *directly from the estimand*, with no
appeal to any reference solver. For `W = Theta^{-1}` the subgradient
conditions are

- diagonal, unpenalised: \\W\_{ii} = S\_{ii}\\;

- diagonal, penalised: \\W\_{ii} - S\_{ii} = \rho\_{ii}\\;

- off-diagonal with \\\Theta\_{ij} \neq 0\\: \\W\_{ij} - S\_{ij} =
  \rho\_{ij}\\\mathrm{sign}(\Theta\_{ij})\\;

- off-diagonal with \\\Theta\_{ij} = 0\\: \\\|W\_{ij} - S\_{ij}\| \le
  \rho\_{ij}\\.

## Usage

``` r
glasso_kkt(
  x,
  S = NULL,
  rho = NULL,
  penalize_diagonal = NULL,
  zero = NULL,
  active_tol = 1e-08
)
```

## Arguments

- x:

  A `glasso_result` from
  [`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md),
  or a precision matrix.

- S:

  Covariance the model was fit to. Required only when `x` is a bare
  matrix; taken from the fit otherwise.

- rho:

  Penalty (scalar or `p x p` matrix). Required only when `x` is a bare
  matrix.

- penalize_diagonal:

  Logical, whether the diagonal was penalised. Required only when `x` is
  a bare matrix.

- zero:

  Two-column matrix of hard-constrained `(row, col)` index pairs, as
  passed to
  [`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md).
  Taken from the fit when `x` is a `glasso_result`. Constrained entries
  are excluded from the check: at a hard-constrained edge the
  inactive-edge inequality does not apply, because the equality
  constraint carries its own multiplier that absorbs the residual.
  Checking them anyway reports optimal fits as non-optimal.

- active_tol:

  Magnitude above which an off-diagonal entry counts as active. Default
  `1e-8`.

## Value

A single non-negative number: the maximum absolute stationarity
violation. Values near zero certify optimality.

## See also

[`glasso_fit()`](https://pak.dynasite.org/idiographic/reference/glasso_fit.md)

## Examples

``` r
set.seed(1)
x <- matrix(rnorm(200 * 4), ncol = 4)
fit <- glasso_fit(cov(x), rho = 0.05)
glasso_kkt(fit)
#> [1] 2.220446e-16
```
