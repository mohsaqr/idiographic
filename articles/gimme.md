# 7. GIMME

``` r

library(idiographic)
data(srl)
vars <- c("efficacy", "value", "planning", "monitoring", "effort")
has_cograph <- requireNamespace("cograph", quietly = TRUE)
```

[`build_gimme()`](https://mohsaqr.github.io/idiographic/reference/build_gimme.md)
searches individual models and **promotes paths shared by enough
people** to the group level. As with uSEM, pass the shipped `day` column
as `time`. We fit a handful of students so the example runs quickly.

``` r

students <- subset(srl, name %in% c("Grace", "Eve", "Aisha", "Alice",
                                    "Bob", "Diana", "Frank", "Heidi"))

gimme_fit <- build_gimme(students, vars = vars, id = "name", time = "day",
                         ar = TRUE, groupcutoff = 0.75, seed = 1)

gimme_fit
#> GIMME Network Analysis
#> ------------------------------ 
#> Subjects:   8 
#> Variables:  5  ( efficacy, value, planning, monitoring, effort )
#> AR paths:   yes 
#> Hybrid:     no 
#> 
#> Group-level paths found: 2 
#>    effort~planning 
#>    monitoring~efficacy 
#> 
#> Individual-level paths:  mean 2.5, range 1-4
#> 
#> Proportion of subjects with each path:
#> 
#>   Temporal [directed]
#>     weights [1.000, 1.000]  |  +5 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy          1     0        0          0      0
#>     value             0     1        0          0      0
#>     planning          0     0        1          0      0
#>     monitoring        0     0        0          1      0
#>     effort            0     0        0          0      1
#> 
#>   Contemporaneous [directed]
#>     weights [0.125, 1.000]  |  +14 / -0 edges
#>                efficacy value planning monitoring effort
#>     efficacy       0.00  0.25     0.38       1.00   0.12
#>     value          0.12  0.00     0.25       0.00   0.00
#>     planning       0.12  0.00     0.00       0.12   1.00
#>     monitoring     0.00  0.38     0.00       0.00   0.12
#>     effort         0.12  0.25     0.00       0.25   0.00
#> 
#>   plot(x)  (faithful gimme-style mixed network) | plot(x, layer = "temporal") 
#>   edges(x) | nodes(x) | summary(x) | coefs(x) | matrices(x)
```

The printout lists the group-level paths and then shows, for the
temporal and contemporaneous networks, the **proportion of subjects**
carrying each path — the quantity GIMME displays.

## Tidy tables

[`edges()`](https://mohsaqr.github.io/idiographic/reference/edges.md)
returns one tidy row per path with a `level` column marking group-level
versus individual-level paths;
[`coefs()`](https://mohsaqr.github.io/idiographic/reference/coefs.md)
gives the per-subject estimates.

``` r

head(edges(gimme_fit))
#>           network       from         to weight level
#> 1        temporal   efficacy   efficacy      1 group
#> 2        temporal      value      value      1 group
#> 3        temporal   planning   planning      1 group
#> 4        temporal monitoring monitoring      1 group
#> 5        temporal     effort     effort      1 group
#> 6 contemporaneous   efficacy monitoring      1 group

head(coefs(gimme_fit))
#>   subject         network       from         to  weight
#> 1   Aisha        temporal   efficacy   efficacy  0.1428
#> 2   Aisha        temporal      value      value  0.1150
#> 3   Aisha        temporal   planning   planning -0.0340
#> 4   Aisha        temporal monitoring monitoring -0.0009
#> 5   Aisha        temporal     effort     effort  0.1293
#> 6   Aisha contemporaneous   efficacy      value  0.4799
```

``` r

matrices(gimme_fit)
#> 
#> $temporal_counts
#>            efficacy value planning monitoring effort
#> efficacy          8     0        0          0      0
#> value             0     8        0          0      0
#> planning          0     0        8          0      0
#> monitoring        0     0        0          8      0
#> effort            0     0        0          0      8
#> 
#> $temporal_avg
#>            efficacy value planning monitoring effort
#> efficacy     -0.006 0.000    0.000      0.000   0.00
#> value         0.000 0.045    0.000      0.000   0.00
#> planning      0.000 0.000    0.043      0.000   0.00
#> monitoring    0.000 0.000    0.000     -0.027   0.00
#> effort        0.000 0.000    0.000      0.000   0.02
#> 
#> $contemporaneous_counts
#>            efficacy value planning monitoring effort
#> efficacy          0     1        1          0      1
#> value             2     0        0          3      2
#> planning          3     2        0          0      0
#> monitoring        8     0        1          0      2
#> effort            1     0        8          1      0
#> 
#> $contemporaneous_avg
#>            efficacy value planning monitoring effort
#> efficacy      0.000 0.037    0.044      0.000  0.055
#> value         0.101 0.000    0.000      0.138  0.119
#> planning      0.172 0.121    0.000      0.000  0.000
#> monitoring    0.325 0.000   -0.051      0.000 -0.027
#> effort        0.068 0.000    0.358      0.054  0.000
#> 
#> $path_counts
#>            efficacylag valuelag planninglag monitoringlag effortlag efficacy
#> efficacy             8        0           0             0         0        0
#> value                0        8           0             0         0        2
#> planning             0        0           8             0         0        3
#> monitoring           0        0           0             8         0        8
#> effort               0        0           0             0         8        1
#>            value planning monitoring effort
#> efficacy       1        1          0      1
#> value          0        0          3      2
#> planning       2        0          0      0
#> monitoring     0        1          0      2
#> effort         0        8          1      0
#> 
#> $contemp_cov
#>            efficacy value planning monitoring effort
#> efficacy          0     0        0          0      0
#> value             0     0        0          0      0
#> planning          0     0        0          0      0
#> monitoring        0     0        0          0      0
#> effort            0     0        0          0      0
#> 
#> $contemp_cov_avg
#>            efficacy value planning monitoring effort
#> efficacy          0     0        0          0      0
#> value             0     0        0          0      0
#> planning          0     0        0          0      0
#> monitoring        0     0        0          0      0
#> effort            0     0        0          0      0
```

## Plot

[`plot()`](https://rdrr.io/r/graphics/plot.default.html) draws the
faithful gimme-style mixed network: **dashed** edges are lag-1
(temporal), **solid** edges are contemporaneous, edge width is the
proportion of subjects with the path, and **black** edges are
group-level.

``` r

plot(gimme_fit)
```

![](gimme_files/figure-html/plot-gimme-1.png)
