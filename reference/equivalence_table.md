# Package-wide equivalence and validation ledger

Returns one tidy row for every registered estimator and workflow. Unlike
[`equivalence()`](https://mohsaqr.github.io/idiographic/reference/equivalence.md),
which refines the declaration for one fitted object,
`equivalence_table()` exposes the package-wide evidence boundary before
a model is fitted. A `closed` evidence status means the declared scope
has an executable oracle, engine, recovery, or internal-consistency
contract; it does not turn native extensions into claims about an
unrelated package.

## Usage

``` r
equivalence_table(method = NULL)
```

## Arguments

- method:

  Optional registered method name or alias. `NULL` returns all built-in
  and currently registered methods.

## Value

A data frame with method, kind, declared status, evidence status,
reference, numerical tolerance bounds, scope, and notes.

## Examples

``` r
equivalence_table()
#>                   method      kind             status evidence_status
#> 10                 gimme estimator          validated          closed
#> 4          graphical_var estimator          validated          closed
#> 5     graphical_var_each estimator          validated          closed
#> 13                    ml estimator   validated_native          closed
#> 6                  mlvar estimator          validated          closed
#> 7            mlvar_bayes estimator            partial         bounded
#> 8            mlvar_mplus estimator          delegated     conditional
#> 12 rolling_graphical_var estimator validated_internal          closed
#> 11           rolling_var estimator validated_internal          closed
#> 9                   usem estimator          validated          closed
#> 1                    var estimator          validated          closed
#> 3              var_bayes estimator            partial         bounded
#> 2               var_each estimator          validated          closed
#> 16               compare  workflow validated_internal          closed
#> 17              forecast  workflow validated_internal          closed
#> 14            preprocess  workflow validated_internal          closed
#> 15             stability  workflow validated_internal          closed
#>                          reference tolerance_min tolerance_max
#> 10               gimme::gimme 10.0         0e+00         5e-05
#> 4       graphicalVAR::graphicalVAR         1e-06         1e-06
#> 5       graphicalVAR::graphicalVAR         1e-06         1e-06
#> 13 base-R engines and closed forms            NA            NA
#> 6                     mlVAR::mlVAR         1e-08         1e-08
#> 7                       Mplus DSEM            NA            NA
#> 8  mlVAR::mlVAR(estimator='Mplus')            NA            NA
#> 12  idiographic::fit_graphical_var         0e+00         0e+00
#> 11            idiographic::fit_var         0e+00         0e+00
#> 9                   lavaan::lavaan         1e-08         1e-08
#> 1                    stats::lm.fit         1e-10         1e-10
#> 3            Mplus ESTIMATOR=BAYES         2e-02         3e-02
#> 2             idiographic::fit_var         0e+00         0e+00
#> 16  registered estimator summaries         0e+00         0e+00
#> 17  direct fitted-model prediction         0e+00         0e+00
#> 14       shared lag-design engines         0e+00         0e+00
#> 15      registered base estimators            NA            NA
#>                                                                                                                                                                                                                                                                scope
#> 10 Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#> 4                                                                                                                                                                                                     Supported lag-1 settings, including tested beta/kappa options.
#> 5                                                                                                                                                 Every returned subject fit is compared directly with an upstream lag-1 graphicalVAR fit on the same subject panel.
#> 13                                                                                             All regression/classification model families, selectors, prediction, and tuning controls are exercised; linear and logistic engines are cell-equal to lm.fit/glm.fit.
#> 6                                                                                                                                   Direct oracle matrix for every supported lag-1 lmer temporal and contemporaneous structure, plus 20 real ESM fixed/fixed panels.
#> 7                                                                                                                Five fixed bivariate fixtures, one univariate random-AR fixture, multivariate recovery, missing-data recovery, and explicit MCMC control contracts.
#> 8                                                                                                                                  Complete backend argument-forwarding and output-conversion contract; the statistical estimator is the delegated licensed backend.
#> 12                                                                                                                              Every retained window is a registered graphical VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 11                                                                                                                                        Every retained window is a registered VAR fit; direct-window equality, boundaries, and planted-change recovery are tested.
#> 9                                                                                                                                                 Fixed-syntax estimates for raw/standardized panels and ML/MLR engines; trimming remains a native search procedure.
#> 1                                                                                                                                                                                                   OLS coefficient engine and package-defined VAR(1) preprocessing.
#> 3                                                                                                                                                Three frozen bivariate Mplus fixtures, an OLS cross-check, and executable burn-in/thinning/retained-draw contracts.
#> 2                                                                                                                                                                                                                                Exact per-subject wrapper behavior.
#> 16                                                                                                                                                                                                Exact stacking, dispatch, argument routing, and failure isolation.
#> 17                                                                                                                                 Rolling-origin split geometry, boundary lags, deterministic metrics, and predictions equal direct fitted-model matrix prediction.
#> 14                                                                                                                                 Exact shared GVAR lag-design equality plus deterministic diagnostic, filtering, detrending, missingness, and threshold contracts.
#> 15                                                                                                                              Deterministic block/split-half resampling, ordering invariants, and five-estimator dispatch contracts; no unrelated external target.
#>                                                                                                                                                                                                                                                                             notes
#> 10 Unsupported S-GIMME, latent-variable, convolution, ordinal, LASSO, and multiple-solution modes error explicitly instead of inheriting this supported-surface claim. gimme 10.0 itself fails on the audited ar=FALSE fixture, so that local mode remains a supported extension.
#> 4                                                                                                                                                                                                            The declared tolerance follows the expanded committed oracle matrix.
#> 5                                                                                                                                                                                                                                                                                
#> 13                                                                                                                                                                                                                                                                               
#> 6                                                                                                                 Real-panel evidence covers lag 1 with scale=FALSE; the synthetic oracle matrix additionally covers validated multi-lag, preprocessing, and unique-model slices.
#> 7                                                                                                                                                                                                      Full random-slope and missing-data feature equivalence is not established.
#> 8                                                                                                                              The committed suite tests the complete wrapper boundary with a contract double. Running Mplus itself remains conditional on a licensed executable.
#> 12                                                                                                                                                                                                                                                                               
#> 11                                                                                                                                                                                                                                                                               
#> 9                                                                                                                                                                                                                                                                                
#> 1                                                                                                                                                                                                     This is engine equivalence, not blanket equivalence to another VAR package.
#> 3                                                                                                                                                                                                                               Tolerance is statistical and parameter-dependent.
#> 2                                                                                                                                                                                                                                                                                
#> 16                                                                                                                                                                                                                                                                               
#> 17                                                                                                                                                                                                                                                                               
#> 14                                                                                                                                                                                                                                                                               
#> 15                                                                                                                                                                                                                                                                               
equivalence_table("gimme")
#>   method      kind    status evidence_status         reference tolerance_min
#> 1  gimme estimator validated          closed gimme::gimme 10.0             0
#>   tolerance_max
#> 1         5e-05
#>                                                                                                                                                                                                                                                               scope
#> 1 Direct bivariate and three-variable standard/hybrid/VAR oracle matrix covering search outputs, fit statistics, corrections, alpha, stopping rules, standardization, fit/group cutoffs, forced paths, exogenous variables, and uneven panels, plus recovery tests.
#>                                                                                                                                                                                                                                                                            notes
#> 1 Unsupported S-GIMME, latent-variable, convolution, ordinal, LASSO, and multiple-solution modes error explicitly instead of inheriting this supported-surface claim. gimme 10.0 itself fails on the audited ar=FALSE fixture, so that local mode remains a supported extension.
```
