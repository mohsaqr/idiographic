# List every model the package knows about

One row per model per backend: what task it can do, which package
provides it, whether that package is installed here, and what its single
tunable parameter is.

## Usage

``` r
models(task = NULL, available = FALSE)
```

## Arguments

- task:

  Optional `"regression"` or `"classification"` filter.

- available:

  Only models whose package is installed here.

## Value

A `data.frame` with class `idiographic_models`.

## Details

Models are named, not numbered: `fit_ml(..., model = "cart")` finds its
own backend, and `estimator =` is needed only to force a particular one
when a model exists in several (`ridge`, `lasso`, `elastic`, `svm`,
`bayes`).

## Examples

``` r
models()
#> MODELS
#>   Registered    37
#>   Usable here   37
#> 
#>   model        estimator      package        regr   class   here    tunes
#> -------------------------------------------------------------------------
#>   mean         native         base            yes       -    yes        -
#>   majority     native         base              -     yes    yes        -
#>   linear       native         base            yes       -    yes        -
#>   logistic     native         base              -     yes    yes        -
#>   ridge        native         base            yes     yes    yes   lambda
#>   lasso        native         base            yes     yes    yes   lambda
#>   elastic      native         base            yes     yes    yes   lambda
#>   pcr          native         base            yes       -    yes    ncomp
#>   knn          native         base            yes     yes    yes        k
#>   tree         native         base            yes     yes    yes        -
#>   boost        native         base            yes     yes    yes   rounds
#>   spline       native         base            yes     yes    yes       df
#>   lda          native         base              -     yes    yes        -
#>   bayes        native         base              -     yes    yes        -
#>   loess        stats          base            yes       -    yes     span
#>   ppr          stats          base            yes       -    yes   nterms
#>   isotonic     stats          base            yes       -    yes        -
#>   cart         rpart          rpart           yes     yes    yes       cp
#>   mlp          nnet           nnet            yes     yes    yes     size
#>   multinom     nnet           nnet              -     yes    yes    decay
#>   gam          mgcv           mgcv            yes     yes    yes        k
#>   qda          MASS           MASS              -     yes    yes        -
#>   ridge        glmnet         glmnet          yes     yes    yes   lambda
#>   lasso        glmnet         glmnet          yes     yes    yes   lambda
#>   elastic      glmnet         glmnet          yes     yes    yes   lambda
#>   forest       ranger         ranger          yes     yes    yes     mtry
#>   extratrees   ranger         ranger          yes     yes    yes     mtry
#>   svm          e1071          e1071           yes     yes    yes     cost
#>   bayes        e1071          e1071             -     yes    yes        -
#>   xgboost      xgboost        xgboost         yes     yes    yes   rounds
#>   ksvm         kernlab        kernlab         yes     yes    yes     cost
#>   gp           kernlab        kernlab         yes     yes    yes        -
#>   pls          pls            pls             yes       -    yes    ncomp
#>   ctree        partykit       partykit        yes     yes    yes    alpha
#>   quantile     quantreg       quantreg        yes       -    yes        -
#>   rf           randomForest   randomForest    yes     yes    yes     mtry
#>   glmboost     mboost         mboost          yes     yes    yes   rounds
#> 
#>   model = names above are enough; estimator = only to disambiguate
models(task = "classification", available = TRUE)
#> MODELS
#>   Registered    29
#>   Usable here   29
#> 
#>   model        estimator      package        regr   class   here    tunes
#> -------------------------------------------------------------------------
#>   majority     native         base              -     yes    yes        -
#>   logistic     native         base              -     yes    yes        -
#>   ridge        native         base            yes     yes    yes   lambda
#>   lasso        native         base            yes     yes    yes   lambda
#>   elastic      native         base            yes     yes    yes   lambda
#>   knn          native         base            yes     yes    yes        k
#>   tree         native         base            yes     yes    yes        -
#>   boost        native         base            yes     yes    yes   rounds
#>   spline       native         base            yes     yes    yes       df
#>   lda          native         base              -     yes    yes        -
#>   bayes        native         base              -     yes    yes        -
#>   cart         rpart          rpart           yes     yes    yes       cp
#>   mlp          nnet           nnet            yes     yes    yes     size
#>   multinom     nnet           nnet              -     yes    yes    decay
#>   gam          mgcv           mgcv            yes     yes    yes        k
#>   qda          MASS           MASS              -     yes    yes        -
#>   ridge        glmnet         glmnet          yes     yes    yes   lambda
#>   lasso        glmnet         glmnet          yes     yes    yes   lambda
#>   elastic      glmnet         glmnet          yes     yes    yes   lambda
#>   forest       ranger         ranger          yes     yes    yes     mtry
#>   extratrees   ranger         ranger          yes     yes    yes     mtry
#>   svm          e1071          e1071           yes     yes    yes     cost
#>   bayes        e1071          e1071             -     yes    yes        -
#>   xgboost      xgboost        xgboost         yes     yes    yes   rounds
#>   ksvm         kernlab        kernlab         yes     yes    yes     cost
#>   gp           kernlab        kernlab         yes     yes    yes        -
#>   ctree        partykit       partykit        yes     yes    yes    alpha
#>   rf           randomForest   randomForest    yes     yes    yes     mtry
#>   glmboost     mboost         mboost          yes     yes    yes   rounds
#> 
#>   model = names above are enough; estimator = only to disambiguate
```
