# Offloading Nestimate's idiographic estimators onto `idiographic`

Status: **idiographic side prepared** (v0.3.3). Nestimate side not yet changed.

`Nestimate` (0.8.5) and `idiographic` (0.3.2) each carry a full implementation
of multilevel VAR, of the GIMME search, and of the pure-R graphical-lasso
kernel. This document records what was measured, what changed in `idiographic`
to make the offload possible, and the exact edits the Nestimate side needs.

Everything below was produced by running both packages, not by reading them.

---

## 1. What overlaps

| Nestimate | Lines | idiographic | Verdict |
|---|---:|---|---|
| `build_mlvar()` (`R/mlvar.R`) | 602 | `fit_mlvar()` | **Bit-identical** — pure delegation |
| `.glasso_fit()` (`R/glasso_pure.R`) | 209 | `glasso_fit()` | **Bit-identical** on the shared surface; idiographic is a strict superset |
| `build_gimme()` (`R/gimme.R`) | 1189 | `fit_gimme()` | **Not identical** — idiographic is the faithful one; offload is a correctness upgrade |

Total removable from Nestimate: **~2,000 lines** of estimator code, plus the
`lme4` and `lavaan` Suggests they force.

## 2. Measured evidence

### mlVAR — bit-identical

Same 12-subject × 8-day × 6-beep panel through both packages:

| Layer | `max abs(build_mlvar − fit_mlvar)` |
|---|---:|
| temporal | **0** |
| contemporaneous | **0** |
| between | **0** |

Every column of `coefs()` (`beta`, `se`, `t`, `p`, `ci_lower`, `ci_upper`) also
differs by **exactly 0**. Both are replicas of `mlVAR::mlVAR()` 0.7.3 with
`estimator = "lmer"`, and both reproduce it: idiographic's worst cell against
live mlVAR 0.7.3 over 14 supported structure combinations is **6.1e-16**, with
the temporal and between layers at exactly 0.

The result objects are compatible by construction:

```
Nestimate    class: net_mlvar, netobject_group
idiographic  class: net_mlvar, cograph_group, netobject_group

Nestimate    attrs: coefs, n_obs, n_subjects, lag, standardize, group_col
idiographic  attrs: coefs, n_obs, n_subjects, lag, standardize, group_col,
                    temporal_matrices, scale, scaleWithin, AR, config
```

idiographic's class vector and attribute set are **supersets**. Constituent
names (`temporal`, `contemporaneous`, `between`) are identical and in the same
order.

### Graphical lasso — bit-identical, and a superset

`idiographic::glasso_fit()` vs `Nestimate:::.glasso_fit()` on the shared
scalar-`rho`, unpenalised-diagonal surface: **exactly 0** at every `rho` tested.

Against the `glasso` Fortran reference over 80 fresh configurations
(`p` ∈ {3,5,8,12}, `n` ∈ {40,200}, `rho` ∈ {0.01…0.5}, both diagonal modes):

| Comparison | Worst difference |
|---|---:|
| precision matrix `wi` | 4.2e-10 |
| covariance `w` | 4.4e-11 |
| matrix-valued `rho` (20 configs) | 1.1e-14 |
| zero-constrained refit (20 configs) | 3.6e-10 |

idiographic's kernel additionally supports element-wise penalty matrices, hard
zero constraints, and full input validation — none of which Nestimate's copy
has. **Nothing is lost by deleting Nestimate's version.**

### GIMME — not a drop-in; it is an upgrade

With upstream `gimme` 10.0 as the arbiter, on the same 5-subject panel:

| | `path_counts` | syntax identical | coefficients |
|---|---:|---:|---:|
| `idiographic::fit_gimme` | **0** | **TRUE** | **0** |
| `Nestimate::build_gimme` | 1 | FALSE | 0.276 |

`fit_gimme()` also covers the complete `gimme::gimme()` formal-argument surface
(asserted in the test suite); `build_gimme()` covers a 17-argument subset.

**This offload changes Nestimate's numbers.** It needs a NEWS entry on the
Nestimate side, not a silent swap. The parity test asserts the *direction* of
the gap so it can never be mistaken for agreement.

---

## 3. What changed in `idiographic` to enable this

All additive. No existing export changed signature or behaviour.

### 3.1 The graphical-lasso kernel is now public

```r
glasso_fit(S, rho, penalize_diagonal = FALSE, zero = NULL, ...)
glasso_path(S, rho, penalize_diagonal = FALSE, ...)
glasso_kkt(x, S = NULL, rho = NULL, penalize_diagonal = NULL, ...)
```

`glasso_fit()` returns a `glasso_result` whose `$wi` and `$w` are named exactly
as `glasso::glasso()`'s, so existing call sites port with no edit beyond the
namespace. `as.data.frame()` gives a tidy one-row-per-edge table;
`glasso_kkt()` certifies optimality from the stationarity conditions rather than
against any reference solver.

### 3.2 `matrices()` can now be silent

`matrices()` has always printed to the console and returned its payload
invisibly. That is fine interactively and disqualifying for a dependent package
— a bootstrap calling it 1,000 times would emit 1,000 matrix dumps.

```r
matrices(fit)                 # unchanged: prints, returns invisibly
matrices(fit, print = FALSE)  # NEW: silent, returns the list visibly
```

Threaded through all 16 methods, including the ones that delegate.

### 3.3 `.glasso_kkt_violation()` diagonal-penalty bug fixed

The checker hard-coded the *unpenalised* diagonal condition `W_ii = S_ii`. The
penalised condition is `W_ii − S_ii = rho`, so every `penalize.diagonal = TRUE`
fit was reported as violating stationarity by exactly `rho` — **including
`glasso`'s own Fortran output**, which is how the bug was caught. It now takes
`penalize_diagonal` and reports 8.3e-17 for both implementations.

This was a defect in the *evidence tool*, not in any estimator. No published
number changes.

---

## 4. Nestimate-side migration

### Step 1 — `DESCRIPTION`

```
Imports:
    idiographic (>= 0.3.3),
    ...
```

Drop `lme4` from `Suggests`: `grep -rn "lme4" R/` in Nestimate returns hits in
`R/mlvar.R` only, so it becomes unused the moment `build_mlvar()` delegates.

**Keep `lavaan`.** It is *not* only a GIMME dependency: `R/mcml_pc.R` calls
`lavaan::lavCor()` independently for `cor_method = "polychoric"` (lines 560 and
~1276). Dropping it would break `build_mcml_pc()`.

### Step 2 — delete and delegate

**`R/glasso_pure.R`** — delete the file. Replace the four call sites in
`R/estimators.R` (lines ~1470, ~1513, ~1588, ~1592):

```r
.glasso_fit(S = S, rho = lam, penalize.diagonal = pd, w_init = ..., beta_init = ...)
# becomes
idiographic::glasso_fit(S = S, rho = lam, penalize_diagonal = pd)
```

Two notes. First, `glasso_fit()` does not expose the `w_init` / `beta_init`
warm starts that `.select_ebic()` uses to walk down the lambda path — use
`idiographic::glasso_path()` for the path scan instead, which warm-starts
internally, and `glasso_fit()` for the single tight refit at the selected
lambda. Second, Nestimate's `.soft()` carries a scalar fast path worth ~19% of
`boot_glasso()` runtime; benchmark `boot_glasso()` after the swap and, if it
regresses, raise it as an upstream optimisation on `idiographic` rather than
keeping a private fork.

**`R/mlvar.R`** — replace the body of `build_mlvar()` with a delegation:

```r
build_mlvar <- function(data, vars, id, day = NULL, beep = NULL,
                        lag = 1L, standardize = FALSE) {
  idiographic::fit_mlvar(
    data = data, vars = vars, id = id, day = day, beep = beep,
    lags = lag, scale = standardize, verbose = FALSE
  )
}
```

Argument mapping: `lag` → `lags`, `standardize` → `scale`.

**Delete Nestimate's duplicate S3 methods** — this is not optional. Loading
both packages today emits:

```
Registered S3 methods overwritten by 'Nestimate':
  method            from
  plot.net_gimme    idiographic
  print.net_gimme   idiographic
  print.net_mlvar   idiographic
  summary.net_gimme idiographic
  summary.net_mlvar idiographic
```

Both packages claim the same classes, so whichever loads second wins. The
methods do not error on each other's objects — verified — but they return
*different things*: `idiographic::summary.net_mlvar()` returns a tidy
per-network metrics `data.frame`, while `Nestimate::summary.net_mlvar()`
prints three matrices and returns the coefficient table. Which one a user gets
would depend on library load order, which is not an acceptable contract.

Remove `print.net_mlvar`, `summary.net_mlvar`, `print.net_gimme`,
`summary.net_gimme` and `plot.net_gimme` from Nestimate's NAMESPACE and let
idiographic's own methods serve them.

Also note idiographic's result carries `cograph_group` *before*
`netobject_group` in the class vector; check that no remaining Nestimate method
dispatches on `netobject_group` expecting to win.

**`R/gimme.R`** — replace the body of `build_gimme()` with a delegation to
`idiographic::fit_gimme()`. The formals line up one-to-one except that
`fit_gimme()` has many more. **Add a NEWS entry**: results change, and change
towards `gimme` 10.0.

### Step 3 — verify

Run `validation/run-equivalence.R` in `idiographic` with `Nestimate` installed.
`tests/testthat/test-offload-parity.R` is the gate: it asserts mlVAR and glasso
parity at `tolerance = 0`, asserts the class/attribute superset relation, and
pins the GIMME direction.

---

## 5. Deliberately NOT offloaded

| Nestimate function | Why it stays |
|---|---|
| `.select_ebic()`, `.compute_lambda_path()` | EBIC selection over a 1-D lambda path for a cross-sectional correlation matrix. idiographic's `.gvar_select_ebic()` selects over a 2-D (beta, kappa) grid for a lag-1 VAR. Different problems. |
| `boot_glasso()`, `bootstrap_network()`, `permutation()` | Resampling infrastructure over Nestimate's own network objects. Only the *kernel* moves. |
| `mgm`, `nct`, `hon`, `hypa`, `simplicial`, `mcml`, TNA | Nestimate's actual identity. No idiographic counterpart. |

---

## 6. Open items

1. **Version bump.** These changes are additive; `idiographic` needs `0.3.3`
   with a NEWS entry before Nestimate can declare `idiographic (>= 0.3.3)`.
   idiographic 0.3.2 is mid-CRAN-submission, so sequence the release.
2. **Warm starts.** `glasso_fit()` deliberately does not expose `w_init` /
   `beta_init`. If Nestimate's bootstrap needs them, promote them to the public
   signature rather than reaching into `idiographic:::`.
3. **Circularity.** `idiographic` must never Import or Suggest `Nestimate`. The
   parity tests are tarball-excluded and lane-only precisely to keep that true.
