# 10. Comparing methods

``` r

library(idiographic)
data(srl)
vars <- c("efficacy", "value", "planning", "monitoring", "effort")
```

[`compare_idiographic()`](https://mohsaqr.github.io/idiographic/reference/compare_idiographic.md)
runs several estimators on the same data and stacks their summaries into
**one comparison table**, so you read estimators against each other
instead of assembling the comparison by hand.

Each estimator’s own arguments are passed through `estimator_args`. Here
we compare the two single-person temporal estimators on `Grace`.

``` r

cmp <- compare_idiographic(
  srl, vars = vars, id = "name",
  estimators = c("var", "graphical_var"),
  estimator_args = list(
    var = list(subject = "Grace", scale = TRUE),
    graphical_var = list(subject = "Grace", n_lambda = 8, gamma = 0)
  )
)

cmp
#> Idiographic Model Comparison
#>   Requested: 2
#>   Successful: 2
#>   Failures:   0
#>   Tables:     x$comparison | x$failures
#>   Fits:       rerun with keep_fits = TRUE for cograph plots
```

The comparison itself is a tidy `data.frame`:

``` r

as.data.frame(cmp)
#>          method         network n_nodes n_edges density mean_abs_weight
#> 1           var        temporal       5      20     1.0      0.07457677
#> 2           var contemporaneous       5      10     1.0      0.16039547
#> 3 graphical_var        temporal       5       0     0.0      0.00000000
#> 4 graphical_var contemporaneous       5       3     0.3      0.20679444
#>   n_positive n_negative n_self max_abs_weight
#> 1          9         11      5      0.1604470
#> 2          6          4      0      0.4667434
#> 3          0          0      0      0.0000000
#> 4          3          0      0      0.2514403
```

Add more estimators by extending `estimators` and `estimator_args`. The
group methods (`mlvar`, `usem`, `gimme`) are accepted too — they are
heavier, so the full template below is shown but not run here:

``` r

students <- subset(srl, name %in% c("Grace", "Eve", "Aisha", "Alice",
                                    "Bob", "Diana", "Frank", "Heidi"))

compare_idiographic(
  students, vars = vars, id = "name",
  estimators = c("var", "graphical_var", "mlvar", "usem", "gimme"),
  estimator_args = list(
    var = list(subject = "Grace", scale = TRUE),
    graphical_var = list(subject = "Grace", n_lambda = 8, gamma = 0),
    mlvar = list(standardize = TRUE),
    usem = list(time = "day", temporal = "ar", contemporaneous = "all",
                residual_cov = TRUE, trim = TRUE, seed = 1),
    gimme = list(time = "day", ar = TRUE, seed = 1)
  )
)
```
