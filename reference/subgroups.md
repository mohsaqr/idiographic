# Focus an idiographic fit on subgroup models

Focus an idiographic fit on subgroup models

## Usage

``` r
subgroups(x, label = NULL)
```

## Arguments

- x:

  An idiographic fit.

- label:

  Optional subgroup label(s). Defaults to every subgroup.

## Value

An idiographic fit view.

## Examples

``` r
g <- find_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                    id = "name", k = 2, reps = 10)
fit <- fit_subgroups(srl, y = "effort", x = "efficacy:monitoring",
                     id = "name", subgroup = g, time = "day")
fit |> subgroups() |> metrics(overall = TRUE)
#>      scope model estimator  subject subgroup    n    rmse      mae      bias
#> 1 subgroup    lm    native .overall     .all 1150 19.6146 15.79144 0.8497595
#>   r_squared
#> 1  0.466897
```
