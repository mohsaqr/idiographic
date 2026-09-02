# How well each learner detects heterogeneity

`lambda` and `lambda_bar` measure how much variation a learner's proxy
actually finds. The best learner is the one that finds the most – which
is **not** the one with the lowest prediction error. A model can predict
the outcome well and still be useless at telling people apart.

## Usage

``` r
learners(x, ...)
```

## Arguments

- x:

  An
  [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
  result.

- ...:

  Ignored.

## Value

A data frame, best first.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300))
d$drug <- rbinom(300, 1, 0.5)
d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
het <- fit_heterogeneity(d, "mood", "x1", "id", target = "cate",
                         treatment = "drug", num_splits = 10)
learners(het)
#>    model    lambda lambda_bar
#> 1   tree 0.9391626   1.861314
#> 2  ridge 0.7115032   2.154811
#> 3 linear 0.7106521   2.156163
```
