# Registered idiographic estimators

`idiographic` uses a small registry to give estimators and workflows one
stable dispatch interface. Package methods are registered lazily, so the
registry does not depend on source-file load order. Third-party methods
can register either a function or the name of a function available in
the package namespace or calling environment.

## Usage

``` r
list_estimators(kind = NULL)
```

## Arguments

- kind:

  Optional character vector selecting `"estimator"` and/or `"workflow"`
  registrations.

## Value

`list_estimators()` returns one row per registration.

## Examples

``` r
list_estimators()
#>                     name      kind             function_name
#> 10                 gimme estimator                 fit_gimme
#> 4          graphical_var estimator         fit_graphical_var
#> 5     graphical_var_each estimator    fit_graphical_var_each
#> 13                    ml estimator                    fit_ml
#> 6                  mlvar estimator                 fit_mlvar
#> 7            mlvar_bayes estimator           fit_mlvar_bayes
#> 8            mlvar_mplus estimator           fit_mlvar_mplus
#> 12 rolling_graphical_var estimator fit_rolling_graphical_var
#> 11           rolling_var estimator           fit_rolling_var
#> 9                   usem estimator                  fit_usem
#> 1                    var estimator                   fit_var
#> 3              var_bayes estimator             fit_var_bayes
#> 2               var_each estimator              fit_var_each
#> 16               compare  workflow       compare_idiographic
#> 17              forecast  workflow         validate_forecast
#> 14            preprocess  workflow                preprocess
#> 15             stability  workflow        estimate_stability
#>                                                                                 aliases
#> 10                                                                 fit_gimme, gimme_sem
#> 4                                                 fit_graphical_var, gvar, graphicalvar
#> 5                                                     fit_graphical_var_each, gvar_each
#> 13 fit_ml, idiographic_ml, fit_idiographic_ml, individualized_ml, fit_individualized_ml
#> 6                                                             fit_mlvar, multilevel_var
#> 7                       fit_mlvar_bayes, bayes_mlvar, bayesian_mlvar, dsem, native_dsem
#> 8                                                    fit_mlvar_mplus, mplus, mplus_dsem
#> 12                                              fit_rolling_graphical_var, rolling_gvar
#> 11                                                                      fit_rolling_var
#> 9                                                                       fit_usem, u_sem
#> 1                                                                 fit_var, ols, ols_var
#> 3                                                fit_var_bayes, bayes_var, bayesian_var
#> 2                                                            fit_var_each, ols_var_each
#> 16                                                compare_idiographic, model_comparison
#> 17                                               validate_forecast, forecast_validation
#> 14                                                               prepare, preprocessing
#> 15                                              estimate_stability, bootstrap_stability
#>           result_class available                                description
#> 10           net_gimme      TRUE      Group and individual uSEM path search
#> 4          gvar_result      TRUE   Sparse graphical VAR with EBIC selection
#> 5            gvar_list      TRUE              One graphical VAR per subject
#> 13       idioml_result      TRUE    Idiographic supervised machine learning
#> 6            net_mlvar      TRUE   Frequentist fixed-effects multilevel VAR
#> 7      net_mlvar_bayes      TRUE        Native Bayesian multilevel VAR/DSEM
#> 8            net_mplus      TRUE       Licensed Mplus-backed multilevel VAR
#> 12 rolling_gvar_result      TRUE               Rolling-window graphical VAR
#> 11  rolling_var_result      TRUE                Rolling-window ordinary VAR
#> 9             net_usem      TRUE                Person-specific unified SEM
#> 1           var_result      TRUE              Ordinary least-squares VAR(1)
#> 3     var_bayes_result      TRUE                     Native Bayesian VAR(1)
#> 2             var_list      TRUE               One ordinary VAR per subject
#> 16    model_comparison      TRUE Compare fitted idiographic network methods
#> 17     forecast_result      TRUE         Rolling-origin forecast validation
#> 14   preprocess_result      TRUE       Preprocessing and data-quality audit
#> 15    stability_result      TRUE         Edge-stability resampling workflow
list_estimators("workflow")
#>         name     kind       function_name
#> 3    compare workflow compare_idiographic
#> 4   forecast workflow   validate_forecast
#> 1 preprocess workflow          preprocess
#> 2  stability workflow  estimate_stability
#>                                   aliases      result_class available
#> 3   compare_idiographic, model_comparison  model_comparison      TRUE
#> 4  validate_forecast, forecast_validation   forecast_result      TRUE
#> 1                  prepare, preprocessing preprocess_result      TRUE
#> 2 estimate_stability, bootstrap_stability  stability_result      TRUE
#>                                  description
#> 3 Compare fitted idiographic network methods
#> 4         Rolling-origin forecast validation
#> 1       Preprocessing and data-quality audit
#> 2         Edge-stability resampling workflow
```
