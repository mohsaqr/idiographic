# Tidy coefficients from a fitted mlvar model

Generic accessor for the tidy coefficient table stored on a
[`build_mlvar()`](https://saqr.me/idiographic/reference/build_mlvar.md)
result. Returns a `data.frame` with one row per `(outcome, predictor)`
pair and columns `outcome`, `predictor`, `beta`, `se`, `t`, `p`,
`ci_lower`, `ci_upper`, `significant`.

## Usage

``` r
coefs(x, ...)

# S3 method for class 'net_mlvar'
coefs(x, ...)

# Default S3 method
coefs(x, ...)

# S3 method for class 'net_mlvar_bayes'
coefs(x, ...)

# S3 method for class 'net_usem'
coefs(x, ...)

# S3 method for class 'var_result'
coefs(x, ...)

# S3 method for class 'var_bayes_result'
coefs(x, ...)

# S3 method for class 'gvar_result'
coefs(x, ...)

# S3 method for class 'net_gimme'
coefs(x, ...)
```

## Arguments

- x:

  A fitted model object — currently only `net_mlvar` is supported.

- ...:

  Unused.

## Value

A tidy `data.frame` of coefficient estimates.

## Details

Only the within-person (temporal) coefficients are tabulated — these are
the lagged fixed effects that populate `fit$temporal`. The
between-subjects effects that go into `fit$between` are handled via the
`D (I - Gamma)` transformation and are not exposed as a separate tidy
table.

## Examples

``` r
# \donttest{
set.seed(1)
n_id <- 8; n_t <- 30; vars <- c("A", "B", "C")
rows <- lapply(seq_len(n_id), function(i) {
  m <- as.data.frame(matrix(rnorm(n_t * 3), ncol = 3))
  names(m) <- vars
  m$id <- i; m$day <- 1L; m$beep <- seq_len(n_t)
  m
})
d <- do.call(rbind, rows)
fit <- build_mlvar(d, vars = vars, id = "id", day = "day", beep = "beep")
#> Warning: Model for 'A': singular fit (random-effects variance near zero).
#> Warning: Model for 'A': boundary (singular) fit: see help('isSingular')
#> Warning: Model for 'B': singular fit (random-effects variance near zero).
#> Warning: Model for 'B': boundary (singular) fit: see help('isSingular')
#> Warning: Model for 'C': singular fit (random-effects variance near zero).
#> Warning: Model for 'C': boundary (singular) fit: see help('isSingular')
#> Warning: Between-subjects network not estimable: a random-intercept SD is 0 (no between-person variance). Returning a zero matrix by convention (mlVAR returns NA here).
print(fit)
#> mlVAR result: 8 subjects, 232 observations, 3 variables (lag 1)
#>   Temporal edges significant at p<0.05: 1 / 9
#> 
#>   Temporal [directed]
#>     weights [-0.131, 0.062]  |  +3 / -6 edges
#>           A     B     C
#>     A -0.13 -0.05 -0.03
#>     B -0.01 -0.08 -0.01
#>     C  0.06  0.02  0.04
#> 
#>   Contemporaneous [undirected]
#>     weights [0.006, 0.085]  |  +3 / -0 edges
#>          A    B    C
#>     A 0.00 0.06 0.08
#>     B 0.06 0.00 0.01
#>     C 0.08 0.01 0.00
#> 
#>   Between [undirected]
#>     no non-zero edges
#>       A B C
#>     A 0 0 0
#>     B 0 0 0
#>     C 0 0 0
#> 
#>   plot(x) | plot(x, layer = "temporal") | plot(x, layer = "between") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
summary(fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       3       6       1      0.03140474          2          4
#> 2 contemporaneous       3       3       1      0.05004674          3          0
#> 3         between       3       0       0      0.00000000          0          0
# }
```
