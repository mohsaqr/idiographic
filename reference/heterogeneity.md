# Tidy heterogeneity results

Tidy heterogeneity results

## Usage

``` r
heterogeneity(x, effect = NULL, model = NULL, all_models = FALSE, ...)
```

## Arguments

- x:

  An
  [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
  result.

- effect, model:

  Optional filters. `model` defaults to the learner that best detects
  heterogeneity.

- all_models:

  Logical. Return every candidate learner instead of the best.

- ...:

  Ignored.

## Value

A data frame.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300))
d$drug <- rbinom(300, 1, 0.5)
d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
het <- fit_heterogeneity(d, "mood", "x1", "id", target = "cate",
                         treatment = "drug", num_splits = 10)
heterogeneity(het)
#>   target model           effect   estimate  std_error   conf_low conf_high
#> 1   cate  tree          average 0.98929364 0.07953251  0.8089807 1.1632544
#> 2   cate  tree    heterogeneity 1.00280638 0.06348478  0.8276626 1.1629990
#> 3   cate  tree         group:g1 0.03585938 0.15515352 -0.4364311 0.4618684
#> 4   cate  tree         group:g2 0.07832096 0.09910079 -0.1571242 0.3867399
#> 5   cate  tree         group:g3 1.82196461 0.16149449  1.5139295 2.3377881
#> 6   cate  tree         group:g4 2.08522316 0.14394120  1.6728870 2.5344708
#> 7   cate  tree group:top-bottom 2.11813203 0.19153650  1.5739739 2.6305122
#>        p_value   n n_people splits
#> 1 0.0003745494 150        5     10
#> 2 0.0002313619 150        5     10
#> 3 1.0000000000 150        5     10
#> 4 0.5595166759 150        5     10
#> 5 0.0009821228 150        5     10
#> 6 0.0003252114 150        5     10
#> 7 0.0007508202 150        5     10
```
