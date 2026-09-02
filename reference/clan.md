# Who is in the extreme groups

Compares the average of each variable between the people the quantity is
highest for and the people it is lowest for. Turns "the top group gains
2.0" into "the top group is the people with high `x1`".

## Usage

``` r
clan(x, model = NULL, all_models = FALSE, ...)
```

## Arguments

- x:

  An
  [`fit_heterogeneity()`](https://pak.dynasite.org/idiographic/reference/fit_heterogeneity.md)
  result.

- model:

  Optional learner. Defaults to the best one.

- all_models:

  Logical. Return every candidate learner.

- ...:

  Ignored.

## Value

A data frame: one row per variable, the top-minus-bottom difference.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:10, each = 30), x1 = rnorm(300), x2 = rnorm(300))
d$drug <- rbinom(300, 1, 0.5)
d$mood <- 2 * d$drug * (d$x1 > 0) + rnorm(300, sd = 0.5)
het <- fit_heterogeneity(d, "mood", c("x1", "x2"), "id", target = "cate",
                         treatment = "drug", num_splits = 10)
clan(het)
#>   target model variable    estimate std_error   conf_low conf_high     p_value
#> 1   cate  tree       x1  1.50578390 0.1101152  1.2797923 1.7605698 0.000335071
#> 2   cate  tree       x2 -0.06151033 0.2363533 -0.7353957 0.5208415 1.000000000
#>    n n_people splits
#> 1 75        5     10
#> 2 75        5     10
```
