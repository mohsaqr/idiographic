# Register an idiographic estimator or workflow

Register an idiographic estimator or workflow

## Usage

``` r
register_estimator(
  name,
  fit,
  aliases = character(),
  kind = c("estimator", "workflow"),
  description = "",
  result_class = character(),
  equivalence = list(),
  overwrite = FALSE
)
```

## Arguments

- name:

  Unique canonical method name.

- fit:

  A function, or a single character string naming a function.

- aliases:

  Optional alternative method names.

- kind:

  Either `"estimator"` or `"workflow"`.

- description:

  Short human-readable description.

- result_class:

  Optional result classes used to infer equivalence metadata for objects
  produced by direct calls to the estimator.

- equivalence:

  A named list describing the validation status, reference, scope,
  tolerance, and notes. Missing fields receive conservative defaults.

- overwrite:

  Logical. Replace an existing registration with the same canonical
  name. Aliases owned by another method are never overwritten.

## Value

`register_estimator()` invisibly returns the new registration.

## Examples

``` r
demo_fitter <- function(data, ...) structure(list(data = data),
                                             class = "demo_result")
register_estimator("demo", demo_fitter, result_class = "demo_result")
get_estimator("demo")
#> function (data, ...) 
#> structure(list(data = data), class = "demo_result")
#> <environment: 0x56076f3fffe8>
remove_estimator("demo")
```
