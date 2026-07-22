# Fit idiographic supervised machine-learning models

Fits train/test supervised prediction models in an idiographic design:
each subject can receive a model trained only on that subject's earlier
rows, and the same held-out rows can also be scored by a pooled model
trained on all subjects' earlier rows. This mirrors individualized
modelling designs where person-specific prediction is compared against a
nomothetic pooled baseline.

The implementation is dependency-free beyond base R. Regression supports
mean baseline, ordinary least squares, ridge, lasso, elastic net,
principal component regression, k-nearest neighbours, and a one-split
regression tree. Binary classification supports majority baseline,
logistic regression, ridge/lasso/elastic-net logistic regression, linear
discriminant analysis, Gaussian naive Bayes, k-nearest neighbours, and a
one-split classification tree. Predictors are standardized using
training rows only.

## Usage

``` r
fit_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...
)

fit_idiographic_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...
)

fit_individualized_ml(
  data,
  outcome,
  predictors,
  id,
  day = NULL,
  beep = NULL,
  task = c("auto", "regression", "classification"),
  model = NULL,
  estimator = NULL,
  compare = c("both", "individual", "pooled"),
  test_prop = 0.2,
  min_train = 10L,
  min_test = 1L,
  lambda = 1,
  alpha = 0.5,
  k = 5L,
  n_components = NULL,
  max_iter = 100L,
  tol = 1e-06,
  standardize = TRUE,
  keep_fits = FALSE,
  ...
)
```

## Arguments

- data:

  A `data.frame` or matrix.

- outcome:

  Character. Name of the outcome column.

- predictors:

  Character vector of predictor columns.

- id:

  Character. Name of the subject/person ID column.

- day, beep:

  Optional ordering columns. Rows are ordered by `id`, `day`, and `beep`
  before the last rows for each subject are held out.

- task:

  `"auto"`, `"regression"`, or `"classification"`. Auto treats a numeric
  outcome as regression and a two-level non-numeric outcome as binary
  classification.

- model:

  `NULL` for the task default, `"all"` for all native models for the
  selected task, or a character vector of simple model names. Regression
  models are `"mean"`, `"linear"`, `"ridge"`, `"lasso"`, `"elastic"`,
  `"pcr"`, `"knn"`, and `"tree"`. Classification models are
  `"majority"`, `"logistic"`, `"ridge"`, `"lasso"`, `"elastic"`,
  `"lda"`, `"bayes"`, `"knn"`, and `"tree"`.

- estimator:

  `NULL` for each model's default estimator, or a named character
  vector/list mapping model names to estimator names. The native base-R
  estimator is `"native"`. This is where package-specific backends
  belong when the same model can be estimated more than one way.

- compare:

  Which models to fit: `"both"` (default), `"individual"`, or
  `"pooled"`.

- test_prop:

  Proportion of each subject's ordered rows held out from the end of the
  series. Default `0.2`.

- min_train:

  Minimum complete training rows required for a model. Default `10`.

- min_test:

  Minimum held-out rows required per subject. Default `1`.

- lambda:

  Ridge penalty for `model = "ridge"`. The intercept is not penalized.
  Also used by lasso and elastic-net models. Default `1`.

- alpha:

  Elastic-net mixing value in `[0, 1]`; `0` is ridge and `1` is lasso.
  Default `0.5`.

- k:

  Number of neighbours for `model = "knn"`. Default `5`.

- n_components:

  Number of principal components for `model = "pcr"`. Default uses
  `min(5, n_predictors, n_train - 1)`.

- max_iter:

  Maximum iterations for coordinate-descent penalized models. Default
  `100`.

- tol:

  Convergence tolerance for iterative models. Default `1e-6`.

- standardize:

  Logical. Standardize predictors using training-set means and SDs?
  Default `TRUE`.

- keep_fits:

  Logical. Store fitted internal model objects? Default `FALSE`.

- ...:

  Optional model controls using the same names as the explicit tuning
  arguments (`lambda`, `alpha`, `k`, `n_components`, `max_iter`, or
  `tol`). Unknown names are rejected.

## Value

An `idioml_result` with `$predictions`, `$metrics`, `$coefficients`,
`$failures`, and optionally `$fits`.

## Examples

``` r
set.seed(1)
d <- data.frame(
  id = rep(1:4, each = 40),
  beep = rep(seq_len(40), 4),
  x1 = rnorm(160),
  x2 = rnorm(160)
)
d$y <- 0.4 * d$x1 - 0.2 * d$x2 + rep(c(-1, 0, 1, 0.5), each = 40) +
  rnorm(160, sd = 0.4)
fit <- fit_ml(d, outcome = "y", predictors = c("x1", "x2"),
              id = "id", beep = "beep",
              model = c("linear", "ridge", "knn"))
fit$metrics
#>    model_scope  model estimator  subject  n       mae      rmse         bias
#> 1   individual linear    native        1  8 0.2602382 0.3388925 -0.132200668
#> 2   individual linear    native        2  8 0.2887113 0.3627328  0.157750319
#> 3   individual linear    native        3  8 0.2501121 0.2978203 -0.009658380
#> 4   individual linear    native        4  8 0.2612697 0.3098112  0.148353248
#> 5   individual linear    native .overall 32 0.2650828 0.3282922  0.041061130
#> 6       pooled linear    native        1  8 1.1804243 1.2236208 -1.180424339
#> 7       pooled linear    native        2  8 0.2856309 0.3237540 -0.024507423
#> 8       pooled linear    native        3  8 0.8801380 0.9214521  0.880138016
#> 9       pooled linear    native        4  8 0.4933548 0.5310231  0.454456439
#> 10      pooled linear    native .overall 32 0.7098870 0.8266081  0.032415673
#> 11  individual  ridge    native        1  8 0.2614158 0.3398072 -0.129031698
#> 12  individual  ridge    native        2  8 0.2870193 0.3584553  0.149567187
#> 13  individual  ridge    native        3  8 0.2506596 0.2956046 -0.012167456
#> 14  individual  ridge    native        4  8 0.2654623 0.3128727  0.150465021
#> 15  individual  ridge    native .overall 32 0.2661392 0.3275784  0.039708263
#> 16      pooled  ridge    native        1  8 1.1798534 1.2231056 -1.179853350
#> 17      pooled  ridge    native        2  8 0.2861670 0.3238204 -0.025176810
#> 18      pooled  ridge    native        3  8 0.8799316 0.9205587  0.879931570
#> 19      pooled  ridge    native        4  8 0.4941607 0.5312146  0.454016038
#> 20      pooled  ridge    native .overall 32 0.7100282 0.8262058  0.032229362
#> 21  individual    knn    native        1  8 0.3427481 0.4141662 -0.114633011
#> 22  individual    knn    native        2  8 0.2694113 0.3249243  0.079682638
#> 23  individual    knn    native        3  8 0.3632406 0.4311461 -0.068122016
#> 24  individual    knn    native        4  8 0.2321593 0.2620751  0.063469361
#> 25  individual    knn    native .overall 32 0.3018898 0.3645819 -0.009900757
#> 26      pooled    knn    native        1  8 1.3048115 1.4279777 -1.304811489
#> 27      pooled    knn    native        2  8 0.4151028 0.4879138 -0.119434885
#> 28      pooled    knn    native        3  8 0.7232043 0.8077458  0.694195799
#> 29      pooled    knn    native        4  8 0.3696358 0.4220594  0.251212393
#> 30      pooled    knn    native .overall 32 0.7031886 0.8814431 -0.119709546
#>        r_squared
#> 1   0.4144348391
#> 2   0.3214098292
#> 3   0.5115456522
#> 4   0.6594514839
#> 5   0.8557560754
#> 6  -6.6338738994
#> 7   0.4594144402
#> 8  -3.6758536331
#> 9  -0.0004871863
#> 10  0.0855168155
#> 11  0.4112697020
#> 12  0.3373199064
#> 13  0.5187866186
#> 14  0.6526878237
#> 15  0.8563826451
#> 16 -6.6274468214
#> 17  0.4591929214
#> 18 -3.6667911531
#> 19 -0.0012089385
#> 20  0.0864067679
#> 21  0.1254178629
#> 22  0.4554994851
#> 23 -0.0236801627
#> 24  0.7563107437
#> 25  0.8221038679
#> 26 -9.3966674298
#> 27 -0.2277789510
#> 28 -2.5930623617
#> 29  0.3679784493
#> 30 -0.0398361620
coefs(fit)
#>    model_scope  model estimator subject        term    estimate
#> 1   individual linear    native       1 (Intercept) -0.96107292
#> 2   individual linear    native       1          x1  0.25337360
#> 3   individual linear    native       1          x2 -0.23750576
#> 4   individual linear    native       2 (Intercept)  0.05715842
#> 5   individual linear    native       2          x1  0.39138661
#> 6   individual linear    native       2          x2 -0.28957196
#> 7   individual linear    native       3 (Intercept)  1.03869967
#> 8   individual linear    native       3          x1  0.34337762
#> 9   individual linear    native       3          x2 -0.12250569
#> 10  individual linear    native       4 (Intercept)  0.25287730
#> 11  individual linear    native       4          x1  0.32024855
#> 12  individual linear    native       4          x2 -0.23906608
#> 13      pooled linear    native .pooled (Intercept)  0.09691561
#> 14      pooled linear    native .pooled          x1  0.30358901
#> 15      pooled linear    native .pooled          x2 -0.26264255
#> 16  individual  ridge    native       1 (Intercept) -0.96107292
#> 17  individual  ridge    native       1          x1  0.24355249
#> 18  individual  ridge    native       1          x2 -0.22809709
#> 19  individual  ridge    native       2 (Intercept)  0.05715842
#> 20  individual  ridge    native       2          x1  0.37730475
#> 21  individual  ridge    native       2          x2 -0.27822555
#> 22  individual  ridge    native       3 (Intercept)  1.03869967
#> 23  individual  ridge    native       3          x1  0.33246863
#> 24  individual  ridge    native       3          x2 -0.11822288
#> 25  individual  ridge    native       4 (Intercept)  0.25287730
#> 26  individual  ridge    native       4          x1  0.31143366
#> 27  individual  ridge    native       4          x2 -0.23347643
#> 28      pooled  ridge    native .pooled (Intercept)  0.09691561
#> 29      pooled  ridge    native .pooled          x1  0.30113002
#> 30      pooled  ridge    native .pooled          x2 -0.26049099
#> 31  individual    knn    native       1           k  5.00000000
#> 32  individual    knn    native       2           k  5.00000000
#> 33  individual    knn    native       3           k  5.00000000
#> 34  individual    knn    native       4           k  5.00000000
#> 35      pooled    knn    native .pooled           k  5.00000000
```
