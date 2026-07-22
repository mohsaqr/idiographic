# Package-wide method, argument, and equivalence closure

Audit date: 2026-07-22 Package version: `idiographic` 0.1.0

## Closure result

The package surface is closed under an explicit evidence contract:

- all 17 registered estimators and workflows have a tested declaration;
- all 315 current public method arguments occur exactly once in the
  executable
  [`argument_coverage()`](https://mohsaqr.github.io/idiographic/reference/argument_coverage.md)
  ledger;
- no method or argument is `unknown`, `not_assessed`, or `unassessed`;
- unsupported modes error or warn explicitly instead of silently
  inheriting an equivalence claim; and
- native extensions and licensed backends are labelled separately from
  direct numerical equivalence.

This is **complete package evidence closure**, not blanket numerical
identity to one external package. The package contains several native
workflows for which no one-to-one competitor exists. For those methods,
closure means tested internal contracts and an explicit absence of an
external-equivalence claim.

The live ledgers are public:

``` r

equivalence_table()
argument_coverage()
```

Package tests require every future registered method and formal argument
to appear in those ledgers, preventing the audit from silently becoming
stale.

## Equivalence in numbers

| Measure                                              |           Result |
|------------------------------------------------------|-----------------:|
| Methods with an explicit tested evidence declaration |   17 / 17 (100%) |
| Public argument cells classified                     | 315 / 315 (100%) |
| Strictly closed method declarations                  |  14 / 17 (82.4%) |
| Statistically bounded Mplus fixture declarations     |   2 / 17 (11.8%) |
| Licensed delegated backend declaration               |    1 / 17 (5.9%) |
| Open or unassessed method declarations               |      0 / 17 (0%) |
| Open or unassessed argument cells                    |     0 / 315 (0%) |

The strict score rose from 13/17 (76.5%) to 14/17 (82.4%) by expanding
GIMME from a bivariate fixture boundary to a supported-surface oracle
matrix. The remaining three declarations are not missing
implementations: two are native Bayesian estimators whose external Mplus
comparison is necessarily statistical and fixture-bounded, and one
delegates to a licensed Mplus executable. Calling those three “exactly
equivalent” without broader licensed runs would overstate the evidence.

## Method-level result

| Method | Closure | Reference | Committed boundary |
|----|----|----|----|
| [`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md) | closed | [`stats::lm.fit`](https://rdrr.io/r/stats/lmfit.html) | Cell-level OLS engine equality, tolerance `1e-10`; preprocessing is package-defined. |
| [`fit_var_each()`](https://mohsaqr.github.io/idiographic/reference/fit_var_each.md) | closed | [`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md) | Exact per-subject wrapper contract. |
| [`fit_var_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_var_bayes.md) | bounded | frozen Mplus BAYES | Three bivariate fixtures with parameter-dependent statistical tolerances `0.02`–`0.03`, plus OLS and MCMC-control checks. |
| [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md) | closed | `graphicalVAR` 0.4.1 | Lag-1 beta/kappa option matrix, multi-ID centering, missing rows, and tolerance `1e-6`. Multi-lag/unequal-grid fits are labelled extensions. |
| [`fit_graphical_var_each()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var_each.md) | closed | `graphicalVAR` 0.4.1 | Every returned subject fit is compared with the same-data upstream subject fit at `1e-6`. |
| [`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md) | closed | `mlVAR` 0.7.3 | All 12 supported lag-1 lmer structure combinations, unique/lm modes, preparation and selected multi-lag controls, plus 20 real fixed/fixed panels at `1e-8`. |
| [`fit_mlvar_bayes()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_bayes.md) | bounded | frozen Mplus DSEM | Five fixed bivariate and one random-AR fixture; advanced random-residual and imputation modes are recovery-validated, not called Mplus-equivalent. |
| [`fit_mlvar_mplus()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar_mplus.md) | conditional | delegated Mplus backend | Complete argument-forwarding and result-conversion contract is tested with a contract double; statistical execution requires a licensed Mplus installation. |
| [`fit_usem()`](https://mohsaqr.github.io/idiographic/reference/fit_usem.md) | closed | `lavaan` | Fixed syntax, raw/standardized data, and ML/MLR engines at `1e-8`; trimming is a labelled native search extension. |
| [`fit_gimme()`](https://mohsaqr.github.io/idiographic/reference/fit_gimme.md) | closed | `gimme` 10.0 | Exact search, syntax, count, coefficient, and psi agreement on bivariate and three-variable standard/hybrid/VAR panels; fit tables agree within `5e-5`. Includes exogenous variables, uneven panels, and interacting controls; unsupported upstream families reject explicitly. |
| [`fit_rolling_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_var.md) | closed internal | [`fit_var()`](https://mohsaqr.github.io/idiographic/reference/fit_var.md) | Direct-window equality, boundaries, and planted-change recovery. |
| [`fit_rolling_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_rolling_graphical_var.md) | closed internal | [`fit_graphical_var()`](https://mohsaqr.github.io/idiographic/reference/fit_graphical_var.md) | Direct-window equality, boundaries, and planted-change recovery. |
| [`fit_ml()`](https://mohsaqr.github.io/idiographic/reference/fit_ml.md) | closed native | base-R engines/closed forms | All model families and selectors exercised; linear/logistic cells equal `lm.fit`/`glm.fit`. |
| [`preprocess()`](https://mohsaqr.github.io/idiographic/reference/preprocess.md) | closed internal | shared lag design | Exact design equality plus deterministic diagnostics, filtering, detrending, missingness, and threshold behavior. |
| [`estimate_stability()`](https://mohsaqr.github.io/idiographic/reference/estimate_stability.md) | closed internal | registered estimators | Deterministic resampling, ordering, and five-estimator dispatch; no unrelated external target. |
| [`compare_idiographic()`](https://mohsaqr.github.io/idiographic/reference/compare_idiographic.md) | closed internal | registered summaries | Exact stacking, routing, failure isolation, and retained-fit behavior. |
| [`validate_forecast()`](https://mohsaqr.github.io/idiographic/reference/validate_forecast.md) | closed internal | direct fitted prediction | Split geometry, boundary lags, metrics, and direct matrix-prediction equality. |

Summary: 14 declarations are closed directly or internally, two are
bounded to their committed external fixtures, and one is conditional on
a licensed backend. There are zero open declarations.

## Argument-level result

[`argument_coverage()`](https://mohsaqr.github.io/idiographic/reference/argument_coverage.md)
derives its rows from the actual function formals, so the ledger
currently contains exactly 315 cells. Evidence classes include direct
oracle/engine equality, statistical fixtures, recovery, internal
validation, delegated forwarding, supported extension, explicit
rejection, and explicit warning boundary.

Important closures that were previously thin or absent include:

- graphical VAR iteration caps, EBIC tie handling, beta/kappa grid sizes
  and minima, prepared matrices, missing rows, multi-ID centering, and
  per-subject upstream comparison;
- mlVAR `scaleWithin`, `nCores`, aligned comparison lags, known means,
  detrending, multi-lag fixed fits, all supported random-effect
  structures, missing-ID behavior, duplicate keys, irregular gaps, and
  singular between networks;
- GIMME 10.0 `indiv_correct`, `alpha`, `stop_crit`, standardization,
  fit/group cutoffs, forced paths, current Bonferroni/FDR spellings,
  multivariate and uneven panels, exogenous-variable matrix structure,
  full fit tables, and interacting hybrid/FDR/standardization controls;
- Bayesian non-default burn-in and thinning, retained-draw accounting,
  random-residual recovery, and within-model imputation recovery;
- Mplus wrapper forwarding for every named backend argument and `...`,
  working directory behavior, executable discovery boundary, and output
  conversion;
- standardized ML/MLR uSEM engine equality; and
- native idiographic-ML linear and logistic engine equality.

## Real-data mlVAR evidence

The repository’s separate `validation/` lane contains 20 raw ESM panels
and 20 frozen outputs generated directly with
[`mlVAR::mlVAR()`](https://rdrr.io/pkg/mlVAR/man/mlVAR.html) 0.7.3.
Native
[`fit_mlvar()`](https://mohsaqr.github.io/idiographic/reference/fit_mlvar.md)
refits each panel in the opt-in equivalence suite. These competitor
fixtures are intentionally excluded from the offline CRAN tarball.

| Layer           | Maximum absolute difference | Committed tolerance |
|-----------------|----------------------------:|--------------------:|
| Temporal        |                         `0` |              `1e-8` |
| Contemporaneous |                  `1.23e-15` |              `1e-8` |
| Between         |                  `1.53e-10` |              `1e-8` |

Dataset 0008 preserves one missing ID. Dataset 0022 preserves the sparse
panel structure. Datasets 0003 and 0022 preserve the documented case
where upstream between-network cells are non-estimable (`NA`) and
idiographic returns its zero-network plotting convention. Duplicate
observation keys now error clearly.

The old Dynalytics R/JS outputs are not used as the mlVAR oracle: they
implement a distinct pooled OLS + EBIC-glasso algorithm. Their
data-quality lessons were retained, while the committed reference
networks were regenerated with the actual competitor package.

## Reproducibility contract

- `DESCRIPTION` declares the oracle package floors used by CI:
  `graphicalVAR >= 0.4.1`, `mlVAR >= 0.7.3`, and `gimme >= 10.0`.
- `corpcor`, `data.table`, and `jsonlite` are direct test suggestions
  rather than accidental transitive dependencies.
- `.github/workflows/oracle-equivalence.yaml` installs the declared
  oracle packages, prints their versions, and runs focused equivalence
  tests without allowing missing competitors to turn the job green.
- The complete source tests, source-package build, installed-package
  checks, generated documentation, and vignette rebuild are the final
  release gate.

## Final verification snapshot

- Complete source suite: 1,488 assertions passed, zero failures, zero
  warnings, and one contextual skip because `cograph` was installed.
- Static integrity: all 68 R source/test files parsed;
  `git diff --check` was clean.
- Built CRAN artifact: the 20 real-panel CSVs and 20 frozen mlVAR RDS
  oracles are excluded and remain in `validation/`; the public
  closure-ledger help pages are included.
- Installed artifact: `R CMD check --no-manual` ran the
  installed-package tests, examples, dependency checks, documentation
  checks, and vignette rebuild and finished with `Status: OK`.

## Claim that documentation may use

> `idiographic` has complete package-wide evidence closure: every
> registered method and public argument is classified and tested under a
> direct, statistical, internal, delegated, extension, or
> explicit-rejection contract. Numerical equivalence remains method- and
> configuration-specific; use
> [`equivalence()`](https://mohsaqr.github.io/idiographic/reference/equivalence.md)
> or
> [`equivalence_table()`](https://mohsaqr.github.io/idiographic/reference/equivalence_table.md)
> to inspect the exact boundary.
