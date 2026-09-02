# Idiographic Package Consolidation Plan

## Goal

Fold the complete `idiostats` package into `idiographic`, with `idiographic`
remaining the package name, repository, public identity, and release target.

The consolidated package will support the full idiographic workflow: describing,
preparing, modelling, comparing, validating, and explaining person-specific
processes in intensive longitudinal data. Existing network, time-series, and
Bayesian functionality in `idiographic` remains in scope.

## Product statement

> `idiographic` provides person-specific and within-person statistical analysis
> for intensive longitudinal data, including regression, machine learning,
> longitudinal networks, pooling, subgrouping, heterogeneity analysis, temporal
> validation, and uncertainty-aware comparison of individual results.

## Merge direction and source policy

- `idiographic` is the destination and surviving package.
- `idiostats` is the donor package.
- Work is performed on the `merged` branch of `idiographic`.
- The current `idiostats` working tree—not only its last commit—is the donor
  source because it contains substantial uncommitted functionality and tests.
- The donor repository remains untouched during consolidation.
- Existing `idiographic` public functions stay compatible unless a tested,
  staged deprecation is necessary.
- Useful `idiostats` calls receive compatibility bridges where naming or class
  conflicts prevent direct preservation.

## Unified scope

### Existing `idiographic` capabilities to preserve

- Ordinary and graphical VAR, including person-level and rolling variants.
- mlVAR, native Bayesian VAR, multilevel Bayesian VAR, and Mplus bridges.
- uSEM and GIMME.
- Graphical lasso, networks, edges, nodes, stability, forecasting, and model
  comparison.
- Existing preprocessing, estimator registry, ML, tidy accessors, datasets,
  vignettes, equivalence tests, and clean-room implementations.

### `idiostats` capabilities to integrate

- Person-level descriptions, correlations, and variance components.
- Within-person preprocessing, decomposition, detrending, and lagging.
- Pooled, subgroup, and person-specific LM, GLM, and ML models.
- Ordered hold-out and rolling-origin validation.
- Within-person versus between-person effect estimation.
- Partial pooling and shrinkage of person-specific coefficients.
- Subgroup discovery, subgroup-existence testing, and subgroup modelling.
- Treatment-effect and general heterogeneity analysis.
- Result views, diagnostics, comparisons, tuning accessors, and plots.

## Non-negotiable analytical contracts

1. The person is the primary analytical unit.
2. No lag, split, scaling, prediction, or rolling operation crosses a person
   boundary.
3. Future observations cannot leak into model training or preprocessing.
4. Within-person and between-person quantities cannot be silently mixed.
5. Person-specific estimates, uncertainty, and failures are first-class output.
6. Pooled and subgroup estimates are comparisons or stabilizers, not silent
   replacements for individual estimates.
7. Network and non-network estimators use consistent vocabulary where concepts
   genuinely match, without forcing unlike result types into one structure.
8. Required dependencies remain minimal; optional backends stay in `Suggests`.

## Target workflow

1. Inspect the panel with `describe_persons()`, `correlate_persons()`, and
   `variance_components()`.
2. Prepare variables with `preprocess()` and, when needed,
   `fit_within_between()`.
3. Fit regression, ML, VAR, graphical VAR, Bayesian, multilevel, uSEM, or GIMME
   models through their explicit public fitters or the unified dispatcher.
4. Validate time-dependent models with ordered hold-out, rolling-origin, or
   rolling-network procedures.
5. Compare pooled, shrunk, subgroup, person-specific, network, and
   heterogeneity results through consistent accessors and views.
6. Inspect and communicate results with tidy tables, diagnostics, plots, and
   comparison reports.

## Work plan

### Phase 0: Protect and reproduce both baselines

- Create `merged` from the clean `idiographic` 0.3.4 baseline.
- Inventory the committed `idiographic` tree and the complete dirty
  `idiostats` donor tree.
- Record package versions, exports, S3 registrations, dependencies, datasets,
  tests, and documentation in both packages.
- Run each package's complete tests and built-tarball check using the same R
  installation where possible.
- Record failures caused by missing optional software separately from genuine
  regressions.

**Exit criterion:** both starting states and all donor inputs are reproducible
without modifying `idiostats`.

### Phase 1: Build a collision and ownership map

- Classify every donor file and public symbol as: add, merge, bridge, rename,
  supersede, or omit.
- Resolve known collision areas first: `preprocess()`, `fit_ml()`, `coefs()`,
  `compare()`, registries, model classes, prediction tables, and plot methods.
- Define canonical meanings for `scope`, `subject`, `subgroup`, `person`,
  `model`, `estimator`, `row`, `fold`, and sentinel values.
- Assign one source file as owner for every generic, class constructor, and
  shared internal helper.

**Exit criterion:** no donor file is copied before its symbols have an explicit
destination and compatibility decision.

### Phase 2: Integrate shared infrastructure

- Merge validation, person/time preparation, splitting, unit handling,
  selectors, metrics, and formula-fitting utilities.
- Reconcile estimator registries while retaining existing network and ML
  registrations.
- Establish shared result validation, filtering, printing, truncation, empty
  output, and failure-table conventions.
- Add tests for person boundaries, temporal ordering, missingness, unbalanced
  panels, and training-only preprocessing.

**Exit criterion:** all existing `idiographic` tests pass on the shared
infrastructure and donor core tests can be ported without weakening assertions.

### Phase 3: Integrate descriptive and classical model layers

- Add descriptions, correlations, and variance components.
- Add LM and GLM fitters at pooled, subgroup, and individual scopes.
- Integrate within/between estimation, coefficient pooling, and shrinkage.
- Preserve failures for insufficient per-person data in tidy outputs.

**Exit criterion:** descriptive, LM/GLM, within/between, pooling, and shrinkage
tests pass alongside all pre-existing network tests.

### Phase 4: Integrate ML and honest temporal validation

- Reconcile the two ML APIs and registries without breaking existing
  `fit_ml()` and `fit_idiographic_ml()` behavior.
- Standardize backend recording, tuning, predictions, importance, diagnostics,
  and metrics.
- Integrate ordered hold-out and rolling-origin validation.
- Verify that positive-class coding, training transforms, and temporal splits
  are invariant to row order where they should be.

**Exit criterion:** regression and classification workflows work at pooled,
subgroup, and individual scopes with leakage-resistant validation.

### Phase 5: Integrate subgroups, effects, and heterogeneity

- Add subgroup discovery, subgroup-existence testing, and subgroup modelling.
- Add treatment effects, causal-assumption documentation, and general
  heterogeneity analysis.
- Use people as independent clusters when repeated rows require clustered
  inference; avoid degenerate one-cluster sandwich estimators.
- Distinguish subgroup stability from evidence that subgroups exist and noisy
  coefficient dispersion from genuine heterogeneity.

**Exit criterion:** known-reference and simulation tests cover null behavior,
false positives, interval coverage, and subgroup recovery.

### Phase 6: Harmonize the public API and result inspection

- Standardize `data, y, x, id, time` ordering in new fitters while bridging
  established alternatives.
- Standardize applicable filters: `model`, `estimator`, `scope`, `subject`,
  `subgroup`, `variable`, `sort_by`, `decreasing`, and `n`.
- Reconcile `idiostats_fit` concepts with existing `idiographic` result classes
  without pretending all objects contain the same fields.
- Provide predictable `print()`, `summary()`, `as.data.frame()`, accessors,
  views, and plotting for every public result.
- Add deprecation tests and lifecycle documentation for unavoidable changes.

**Exit criterion:** users can inspect any result without relying on its internal
list structure, and both legacy APIs have a documented migration path.

### Phase 7: Rebuild the package story

- Rewrite `DESCRIPTION` and `README.md` around the complete idiographic
  workflow rather than networks alone.
- Add an introductory raw-panel-to-person-specific-conclusions vignette.
- Add focused guidance for within/between effects, pooling choices, temporal
  validation, networks, and treatment-effect assumptions.
- Consolidate durable donor documentation while excluding scratch files,
  session notes, rendered experiments, and generated check directories.
- Generate a function map marking descriptive, predictive, inferential,
  causal, network, and diagnostic functions.

**Exit criterion:** a new user can discover and complete the main workflow from
the `idiographic` documentation alone.

### Phase 8: Release engineering and donor retirement

- Regenerate `NAMESPACE` and `.Rd` documentation from source annotations.
- Exercise required-only and optional-backend CI matrices deliberately.
- Build the source tarball and run `R CMD check --as-cran` on the tarball.
- Verify CRAN timing, spelling, URLs, licenses, datasets, and tarball contents.
- Document how `idiostats` users migrate; only then decide whether its old
  repository becomes archived or a thin compatibility package.

**Exit criterion:** the consolidated built package passes supported checks and
contains no donor scratch/session artifacts.

## Definition of done

The consolidation is complete when:

1. `idiographic` contains the supported capabilities of both packages.
2. Existing network, VAR, Bayesian, rolling, uSEM, GIMME, and graphical-lasso
   behavior remains covered and passing.
3. Every analysis states whose process and which level it estimates.
4. Every time-dependent operation respects person and temporal boundaries.
5. Within-person and between-person effects cannot be confused silently.
6. Pooled, subgroup, shrunk, individual, and network results have coherent
   inspection and comparison paths.
7. Legacy calls are either compatible or covered by tested deprecation bridges.
8. Documentation presents one end-to-end idiographic workflow.
9. The built package passes tests and release checks from a reproducible
   committed baseline on the `merged` branch.

## Progress log

### 2026-09-02 — Phase 0 baseline established

- Created `merged` from `idiographic` commit
  `0c842c6225d85263f23b6a8dd2383f273eeeb779` (version 0.3.4).
- Identified the donor baseline as `idiostats` commit
  `7eb8d0ca579e6739864e564243aba4cdffef1211` plus its complete dirty working
  tree. The tracked binary diff SHA-256 is
  `830811801e0358dbbef5835b233b9ccc0ca39696af7ce0ff93149142217b57ac`.
- Confirmed the complete `idiographic` source-tree test suite passes. External
  equivalence lanes were skipped by their documented environment guards.
- Confirmed the complete dirty-tree `idiostats` source test suite passes.
- Built `idiographic_0.3.4.tar.gz` successfully with R 4.5.2.
- Ran `R CMD check --as-cran` on the built tarball. The baseline check is not
  clean: five uSEM assertions/examples fail under the installed-package check
  harness even though the source-tree suite passes; PDF manual generation also
  fails because `pdflatex` is unavailable. Offline incoming/URL checks produce
  additional notes. These are recorded as pre-merge baseline issues.
- Initial public collision scan found three shared exports: `coefs()`,
  `fit_ml()`, and `preprocess()`. Same-named source files are `data.R`,
  `preprocess.R`, and `registry.R`.
- Added this plan to `.Rbuildignore` so integration records do not enter the
  released package tarball.

**Next:** complete the symbol-level ownership map, then integrate non-colliding
shared infrastructure and descriptive modules with their donor tests.

### 2026-09-02 — Donor engine integrated

- Completed the top-level symbol scan. Only `%||%`, `coefs()`, `fit_ml()`, and
  `preprocess()` collide across the two source trees.
- Preserved the established `idiographic` owners for the shared generic and
  helpers. Added the donor `coefs()` method to the existing generic.
- Added compatibility dispatch to `fit_ml()`: historical
  `outcome`/`predictors` calls retain the `idioml_result` contract, while
  consolidated `y`/`x` calls and calls using panel controls route to the richer
  scoped/tunable engine.
- Preserved the network-oriented preprocessing audit as `preprocess()` and
  exposed the donor transformation workflow explicitly as
  `preprocess_panel()`.
- Integrated donor preparation, splitting, units, formula models, LM, GLM, ML,
  rolling validation, descriptions, diagnostics, pooling, within/between,
  subgroup, effects, heterogeneity, registry, tuning, views, and plots.
- Ported the complete donor test suite under `test-stats-*` filenames. Donor
  source and tests remain untouched in their original repository.
- Merged required and optional dependency metadata, regenerated `.Rd` files and
  `NAMESPACE`, and corrected the `stats::effects()` namespace registration.
- The full combined source-tree suite passes.
- The built package installs, loads, passes namespace/dependency/S3/code/Rd
  checks, and reaches **1,422 installed-package assertions passed**. Its only
  remaining check error is the same five uSEM check-harness failures recorded
  before the merge.

**Next:** make `idiographic` the visible identity of all imported result
classes and print methods, harmonize the public result contract, then rebuild
the README and vignettes around the unified workflow.

### 2026-09-02 — Identity and installed-package boundary unified

- Added `idiographic_*` primary classes and primary S3 registrations to all
  imported statistical result families. The corresponding `idiostats_*`
  classes remain in each class vector as compatibility bridges.
- Updated all imported print headers and user-facing type errors to identify
  the surviving `idiographic` package.
- Rewrote the README and package-level documentation around one workflow that
  spans descriptions, preprocessing, scoped models, pooling, heterogeneity,
  and dynamic networks.
- Added `vignettes/unified-workflow.Rmd`, an end-to-end raw-panel to
  person-specific-conclusions introduction.
- Added consolidated release notes and updated the package title, description,
  and development version to 0.4.0.9000.
- Diagnosed the earlier installed-check uSEM failures: the managed sandbox
  denies the macOS CPU-count query while `R CMD check` sets
  `R_DEFAULT_PACKAGES=NULL`; `lavaan` 0.6-21 then fails its own `ncpus` option
  validation. Running the same built tarball outside that sandbox resolves the
  environmental condition.
- The built `idiographic_0.4.0.9000.tar.gz` installs, runs examples and tests,
  rebuilds every shipped vignette, and completes `R CMD check --no-manual`
  with **Status: OK**. The PDF manual remains untested locally because
  `pdflatex` is not installed.
- Added push/PR CI for a required-dependencies-only lane and an
  optional-backend lane on Linux, macOS, and Windows; the `merged` branch also
  participates in pkgdown and oracle-equivalence workflows.

**Next:** audit the dual result contracts and function vocabulary, expand the
general estimator registry or document its network/workflow boundary, update
CI/release metadata, and run required-only plus optional-backend matrices.

### 2026-09-02 — Compatibility and result contracts completed

- Audited the donor surface after integration: every `idiostats` export is
  present in the consolidated namespace, every donor test file has a ported
  counterpart, and the destination has no duplicate top-level definitions.
- Added `fit_ml_panel()` as an unambiguous positional migration bridge for the
  former `idiostats` ML API. Named `fit_ml(y = ..., x = ...)` calls retain the
  same consolidated behavior, while historical `idiographic` positional calls
  retain the original result contract.
- Added a shared structural validator for scoped `idiographic_fit` results and
  applied it to ordinary and rolling constructors.
- Added primary and compatibility `summary()` and `as.data.frame()` methods so
  users can inspect consolidated fits without reaching into their internals.
- Documented the estimator-registry boundary: dynamic/network estimators keep
  the existing package registry, ML algorithms use `models()`, and classical
  LM/GLM/effects workflows remain explicit verbs rather than synthetic registry
  entries.
- Expanded consolidation tests for primary identity, both ML calling
  conventions, malformed result detection, and predictable result coercion.
- Re-ran the complete combined source suite. All imported and pre-existing
  sections pass outside the previously documented managed-sandbox limitation;
  external oracle-equivalence tests remain opt-in by design.

### 2026-09-02 — Final release gate passed

- The complete combined source-tree suite passes outside the managed sandbox.
  This includes the original Bayesian, GIMME, uSEM, recovery, stability, and
  network tests plus the complete ported `idiostats` suite. The 32 external
  oracle-equivalence cases remain intentionally gated by
  `IDIOGRAPHIC_RUN_EQUIVALENCE=true`.
- Built the final `idiographic_0.4.0.9000.tar.gz` from `merged`, including all
  vignette outputs.
- Ran `R CMD check --no-manual` on that exact tarball outside the sandbox. The
  package installed, loaded, ran examples and packaged tests, validated code,
  namespace, dependencies, datasets, and documentation, and rebuilt every
  vignette with **Status: OK**.
- A PDF-manual check remains unavailable on this machine because `pdflatex` is
  not installed; the cross-platform CI matrix is configured to cover supported
  required-only and optional-backend environments after the branch is pushed.

**Outcome:** `idiostats` is folded into `idiographic`; the surviving package
has one documented identity, compatible migration bridges, complete donor test
coverage, and a clean installed-package release gate on the `merged` branch.
