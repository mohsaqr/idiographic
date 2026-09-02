# Study how something varies across people

Estimates a person-varying quantity, tests whether it genuinely varies,
sorts people by it, and describes who sits at the extremes.

## Usage

``` r
fit_heterogeneity(
  data,
  y,
  x,
  id,
  target = c("cate", "error", "gain"),
  treatment = NULL,
  model = c("linear", "ridge", "tree"),
  estimator = "native",
  time = NULL,
  num_splits = 100L,
  prop_aux = 0.5,
  n_groups = 4L,
  clan = NULL,
  split = c("person", "occasion"),
  conf_level = 0.95,
  ...
)
```

## Arguments

- data:

  Data frame.

- y:

  Outcome column name.

- x:

  Predictors: names, numeric positions, `a:b` range, formula, or data
  frame.

- id:

  Person/unit ID column.

- target:

  What varies across people: `"cate"`, `"error"`, or `"gain"`.

- treatment:

  Binary treatment column. Required when `target = "cate"`.

- model:

  Candidate models for the proxy. The winner is chosen by how well it
  *detects* heterogeneity (see
  [`learners()`](https://pak.dynasite.org/idiographic/reference/learners.md)),
  not by prediction error.

- estimator:

  Backend for the proxy models. See
  [`fit_ml()`](https://pak.dynasite.org/idiographic/reference/fit_ml.md).

- time:

  Optional ordering column.

- num_splits:

  Number of random splits. More splits, less seed-dependence.

- prop_aux:

  Share of the sample used to learn the proxy in each split.

- n_groups:

  Number of sorted groups.

- clan:

  Person-level columns to describe the extreme groups with. Defaults to
  the predictors.

- split:

  `"person"` (persons are the independent units) or `"occasion"` (split
  rows within each person). `gain` requires `"occasion"`, since a person
  needs rows in both halves to have a model of their own.

- conf_level:

  Confidence level.

- ...:

  Passed to the proxy models.

## Value

An `idiographic_heterogeneity` object. See
[`heterogeneity()`](https://pak.dynasite.org/idiographic/reference/heterogeneity.md),
[`clan()`](https://pak.dynasite.org/idiographic/reference/clan.md), and
[`learners()`](https://pak.dynasite.org/idiographic/reference/learners.md).

## Details

What varies is chosen by `target`:

- `cate`:

  How much a `treatment` helped. Needs `treatment`.

- `error`:

  How predictable each person is. Sorted groups run from the people the
  model serves best to the people it fails.

- `gain`:

  How much a person-specific model beats a pooled one for this person –
  for whom idiographic modelling actually pays off. Positive means
  modelling them alone helped.

The reported quantities, for any target:

- `average`:

  The quantity, averaged over everyone. For `cate` this is the ATE.

- `group:g1..gK`:

  Sorted groups, from the lowest value of the quantity to the highest.

- `group:top-bottom`:

  The gap between the extremes. If its interval excludes zero, the
  quantity genuinely differs across people.

- `heterogeneity`:

  The slope of the held-out scores on the proxy. A significant slope
  means the variation is real and predictable, not noise.

Inference follows the paper: the data are split many times, each split
is analysed separately, and results are aggregated by median with a
conservative interval and a doubled p-value. A single split is
seed-dependent, which is the problem this design exists to solve.
Standard errors are clustered on the person throughout.

Note that these splits are *random*, not time-ordered. The question here
is whether a quantity varies across people, not whether the future can
be forecast;
[`fit_rolling()`](https://pak.dynasite.org/idiographic/reference/fit_rolling.md)
is the verb for the latter.

## References

Chernozhukov, V., Demirer, M., Duflo, E., & Fernandez-Val, I. (2020).
Generic Machine Learning Inference on Heterogeneous Treatment Effects in
Randomized Experiments. arXiv:1712.04802.

## Examples

``` r
set.seed(1)
d <- data.frame(id = rep(1:10, each = 30), day = rep(1:30, 10),
                x1 = rnorm(300), x2 = rnorm(300))
d$drug <- rbinom(300, 1, 0.5)
d$mood <- 2 * d$drug * (d$x1 > 0) + 0.5 * d$x1 + rnorm(300, sd = 0.5)

het <- fit_heterogeneity(d, y = "mood", x = c("x1", "x2"), id = "id",
                         target = "cate", treatment = "drug",
                         num_splits = 20)
heterogeneity(het)
#>   target model           effect   estimate std_error   conf_low conf_high
#> 1   cate  tree          average 1.04035991 0.1119039  0.7357513 1.3449685
#> 2   cate  tree    heterogeneity 0.93966622 0.1134357  0.5916619 1.2880932
#> 3   cate  tree         group:g1 0.03954251 0.1381655 -0.3460203 0.4249075
#> 4   cate  tree         group:g2 0.18144586 0.1774303 -0.3046805 0.6478898
#> 5   cate  tree         group:g3 1.66341355 0.2812181  0.8943487 2.5374715
#> 6   cate  tree         group:g4 2.20589914 0.2151240  1.6270498 2.8758411
#> 7   cate  tree group:top-bottom 2.09155128 0.2361300  1.5546881 2.7754934
#>        p_value   n n_people splits
#> 1 0.0013997455 150        5     20
#> 2 0.0034196399 150        5     20
#> 3 0.5241434951 150        5     20
#> 4 0.7718019897 150        5     20
#> 5 0.0090585589 150        5     20
#> 6 0.0008237084 150        5     20
#> 7 0.0017107797 150        5     20
clan(het)
#>   target model variable    estimate std_error   conf_low conf_high      p_value
#> 1   cate  tree       x1  1.41249841 0.1187707  1.1037501  1.760570 0.0005504121
#> 2   cate  tree       x2 -0.02888505 0.1712446 -0.4815505  0.477836 1.0000000000
#>    n n_people splits
#> 1 75        5     20
#> 2 75        5     20
```
