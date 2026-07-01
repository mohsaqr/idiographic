# 5. Multilevel VAR (mlVAR)

``` r

library(idiographic)
data(srl)
vars <- c("efficacy", "value", "planning", "monitoring", "effort")
has_cograph <- requireNamespace("cograph", quietly = TRUE)
```

[`build_mlvar()`](https://mohsaqr.github.io/idiographic/reference/build_mlvar.md)
estimates **group-level** temporal, contemporaneous, and between-person
networks in one multilevel model. Use it when the question moves from
one person’s dynamics to the *average within-person process* and the
*between-person* differences across the whole sample.

## Fit

``` r

mlvar_fit <- build_mlvar(srl, vars = vars, id = "name", standardize = TRUE)

mlvar_fit
#> mlVAR result: 36 subjects, 5548 observations, 5 variables (lag 1)
#>   Temporal edges significant at p<0.05: 2 / 25
#> 
#>   Temporal [directed]
#>     weights [-0.049, 0.044]  |  +17 / -8 edges
#>                efficacy value planning monitoring effort
#>     efficacy      -0.05  0.01     0.01      -0.01   0.00
#>     value          0.00  0.04     0.01      -0.01   0.03
#>     planning       0.00 -0.01     0.00       0.01  -0.02
#>     monitoring     0.03  0.02     0.01       0.01   0.03
#>     effort         0.01 -0.02     0.00       0.00   0.01
#> 
#>   Contemporaneous [undirected]
#>     weights [0.026, 0.274]  |  +10 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.21     0.24       0.16   0.21
#>     value          0.21  0.00     0.19       0.07   0.13
#>     planning       0.24  0.19     0.00       0.03   0.27
#>     monitoring     0.16  0.07     0.03       0.00   0.14
#>     effort         0.21  0.13     0.27       0.14   0.00
#> 
#>   Between [undirected]
#>     weights [-0.086, 0.553]  |  +8 / -2 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.27     0.55       0.11   0.24
#>     value          0.27  0.00    -0.01      -0.09   0.42
#>     planning       0.55 -0.01     0.00       0.00   0.22
#>     monitoring     0.11 -0.09     0.00       0.00   0.18
#>     effort         0.24  0.42     0.22       0.18   0.00
#> 
#>   plot(x) | plot(x, layer = "temporal") | plot(x, layer = "between") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```

Three networks are estimated and shown: the directed temporal network
(average within-person lag-1 effects), the undirected contemporaneous
network, and the undirected between-person network.

## Tidy tables

[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md)
stacks all three networks into one tidy table with a `network` column;
filter or summarise it with ordinary verbs.

``` r

head(edges(mlvar_fit))
#>    network       from       to      weight
#> 1 temporal monitoring   effort  0.03233503
#> 2 temporal      value   effort  0.02867445
#> 3 temporal monitoring efficacy  0.02724030
#> 4 temporal     effort    value -0.02217274
#> 5 temporal monitoring    value  0.01657931
#> 6 temporal   planning   effort -0.01570680

summary(mlvar_fit)
#>           network n_nodes n_edges density mean_abs_weight n_positive n_negative
#> 1        temporal       5      20       1      0.01237276         14          6
#> 2 contemporaneous       5      10       1      0.16471314         10          0
#> 3         between       5      10       1      0.20864447          8          2
```

``` r

matrices(mlvar_fit)
#> 
#> $temporal
#>            efficacy  value planning monitoring effort
#> efficacy     -0.049  0.002    0.002      0.027  0.006
#> value         0.012  0.044   -0.007      0.017 -0.022
#> planning      0.014  0.012   -0.002      0.011  0.005
#> monitoring   -0.007 -0.009    0.015      0.006 -0.004
#> effort        0.001  0.029   -0.016      0.032  0.009
#> 
#> $contemporaneous
#>            efficacy value planning monitoring effort
#> efficacy      0.000 0.207    0.241      0.158  0.208
#> value         0.207 0.000    0.192      0.074  0.126
#> planning      0.241 0.192    0.000      0.026  0.274
#> monitoring    0.158 0.074    0.026      0.000  0.143
#> effort        0.208 0.126    0.274      0.143  0.000
#> 
#> $between
#>            efficacy  value planning monitoring effort
#> efficacy      0.000  0.274    0.553      0.109  0.240
#> value         0.274  0.000   -0.007     -0.086  0.415
#> planning      0.553 -0.007    0.000      0.003  0.220
#> monitoring    0.109 -0.086    0.003      0.000  0.180
#> effort        0.240  0.415    0.220      0.180  0.000
```

## Plot

Draw the whole result, or any single layer by name — including the
between-person network.

``` r

plot(mlvar_fit, layer = "temporal")
```

![](mlvar_files/figure-html/plot-mlvar-1.png)

``` r

plot(mlvar_fit, layer = "between")
```

![](mlvar_files/figure-html/plot-mlvar-between-1.png)
