# Code Formatting and Linting Guide

This document covers how to apply consistent formatting and linting to all R code
in the repository using **air** (formatter) and **lintr** (linter).

> **Note on `jarl`:** No established R linting tool named `jarl` is known to the
> scanner that produced this document. If you meant a specific tool, please
> clarify and this guide can be extended. The closest candidates are `flint`
> (a lintr extension) or `styler` (an alternative formatter). This guide covers
> `lintr` comprehensively.

---

## 1. `air` — R Code Formatter

`air` is a fast, opinionated R code formatter written in Rust, developed by
Posit (the makers of RStudio). It is similar in spirit to `prettier` for
JavaScript. It formats code but does **not** change semantics.

### Installation

`air` is a standalone CLI tool, not an R package. Install one of these ways:

**macOS (Homebrew):**
```sh
brew install posit/tap/air
```

**Linux / Windows — download binary:**
```sh
# Find the latest release at:
# https://github.com/posit-dev/air/releases
# Download the appropriate binary for your platform and put it on your PATH.
```

**From R (wrapper, if available):**
```r
pak::pak("posit-dev/air")   # installs the R wrapper which bundles the binary
```

Verify installation:
```sh
air --version
```

### Formatting the entire repository

From the repository root, run:

```sh
# Format all .R files recursively (dry-run — shows what would change):
air format --check .

# Apply formatting in-place:
air format .
```

To format only specific case-study directories:
```sh
air format birthdays/ sharks/ golf/ nabiximols/
```

### What air changes

air enforces:
- **Indentation:** 2 spaces (no tabs)
- **Line length:** 80 characters (configurable; see `air.toml` below)
- **Trailing whitespace:** removed
- **Blank lines:** normalized (max 1 consecutive blank line inside functions,
  max 2 between top-level expressions)
- **Spacing around operators:** `x <- 1`, `f(x = 1)`, `x + y`
- **Function call formatting:** long calls broken across lines with consistent
  hanging indentation

### Configuring air

Create an `air.toml` in the repository root to customize behavior:

```toml
[format]
line-width = 100      # increase from default 80 to suit this codebase
indent-width = 2      # default, matches existing style
magic-trailing-comma = true  # keep multi-line arg lists multi-line
```

### Note for this repository

Because most `.R` files in this repository are **Quarto spin scripts** (prose in
`#'` comments, knitr chunk options as `#|` comments), air will format only the
R *code* portions and leave `#'` and `#|` comment lines untouched. This is the
correct behavior.

**Estimated impact:** The static scan found:
- **97 lines** exceed 120 characters (many are long Stan-printing calls or
  data-frame construction chains)
- **1,275 lines** have trailing whitespace

---

## 2. `lintr` — R Code Linter

`lintr` performs static analysis without running any code and flags style,
correctness, and potential bug issues.

### Installation

```r
install.packages("lintr")
```

### Running lintr on the repository

```r
library(lintr)

# Lint every .R file in the repository:
lint_dir(".", pattern = "\\.R$")

# Lint a single file:
lint("birthdays/birthdays.R")

# Lint and view results as a data frame:
as.data.frame(lint_dir("."))
```

From the command line:
```sh
Rscript -e 'lintr::lint_dir(".")'
```

### Recommended `.lintr` configuration

Create a `.lintr` file at the repository root:

```
linters: linters_with_defaults(
  line_length_linter(100),
  assignment_linter(),
  trailing_whitespace_linter(),
  T_and_F_symbol_linter(),
  infix_spaces_linter(),
  commas_linter(),
  object_name_linter(regexes = NULL),  # disable: mixed naming conventions
  indentation_linter(indent = 2L),
  condition_linter(),
  redundant_equals_linter()
)

exclusions: list(
  "verify_imports.R" = list(trailing_whitespace_linter = Inf),
  "misc" = Inf    # misc/ scripts are external examples, skip entirely
)
```

### Issues found in this repository by category

The following issues were identified by static scan. Counts are approximate.

#### HIGH: Trailing whitespace — ~1,275 lines across all files

Trailing spaces at end of lines. `air format` fixes these automatically.

**Affected files:** widespread — every case-study `.R` file has some.

**lintr rule:** `trailing_whitespace_linter`

---

#### MEDIUM: Lines exceeding 100 characters — ~97 lines

Long lines reduce readability and diff legibility. Most occur in:
- `birthdays/birthdays.R` — long `#'` prose lines and data pipeline chains
- `problems/problems.R` — Stan model calls with many arguments
- `park_rule/park_rule.R` — `glmer()` formula lines

**lintr rule:** `line_length_linter(100)`

**air fix:** `air format --line-width 100 .`

---

#### MEDIUM: `&` instead of `&&` in scalar `if()` conditions

Using `&` (vectorized) instead of `&&` (short-circuit, scalar) in `if()`
conditions is a correctness risk: `&` evaluates both sides always and
returns a vector, while `if()` expects a scalar.

**Example (found in original `print_stan_file`):**
```r
# Before:
if (isTRUE(getOption("knitr.in.progress")) &
      identical(knitr::opts_current$get("results"), "asis"))

# After (fixed in this branch):
if (isTRUE(getOption("knitr.in.progress")) &&
      (identical(results_opt, "asis") || identical(output_opt, "asis")))
```

**Note:** This was already fixed in the `claude/scan-math-code-issues` branch
for all `print_stan_file`/`print_stan_code` definitions.

**lintr rule:** `condition_linter()` (warns about `&`/`|` in conditions)

---

#### LOW: `T` and `F` used instead of `TRUE` and `FALSE` — ~22 occurrences

`T` and `F` are just global variables that can be overwritten; `TRUE`/`FALSE`
are language constants. Using `T`/`F` is technically correct but fragile.

**Files with occurrences:**
- `misc/chapter_05/section_05_09/kilpis_priorcheck.R`
- `misc/chapter_05/section_05_10/logit_priors.R`
- `misc/chapter_06/section_06_02/rats.R`
- Several other misc/ scripts

**lintr rule:** `T_and_F_symbol_linter`

**Safe fix:** Replace `T` → `TRUE`, `F` → `FALSE` (but only in the above files,
not inside string literals or column names).

---

#### LOW: Inconsistent assignment operator — widespread

The repository mixes `<-` (idiomatic R) and `=` (also valid at top level).
`lintr`'s `assignment_linter` flags `=` used as assignment **outside function
calls**. Function arguments (`f(x = 1)`) are NOT flagged.

**Examples:**
```r
# Flagged:
x = 5
data = list(N = N, x = x)

# Not flagged (function argument):
cmdstan_model(..., pedantic = TRUE)
```

This is **stylistic only** in R — `=` works identically to `<-` at top level.
Consider enabling this linter only if you want strict house style.

**lintr rule:** `assignment_linter()`

---

#### LOW: Spacing issues — localized

Some files have inconsistent spacing around operators or after commas. `air`
normalizes these automatically.

**lintr rules:** `infix_spaces_linter`, `commas_linter`

---

#### INFORMATIONAL: Object naming conventions

The codebase uses a mix of:
- `snake_case` (dominant: `fit_1`, `sims_3`, `mean_births`)
- `camelCase` (some brms objects: `birthdays.df`, `ws_HMM`)
- `.`-separated (legacy: `fit_p.m1`)

`lintr`'s `object_name_linter` would flag the non-snake-case names. Given
the mixed origins of the case studies, **this linter is recommended off** (set
`object_name_linter(regexes = NULL)` in `.lintr`).

---

### Running lintr in CI

Add to a GitHub Actions workflow:

```yaml
- name: Lint R code
  run: |
    Rscript -e "
      lints <- lintr::lint_dir('.')
      if (length(lints) > 0) {
        print(lints)
        stop(length(lints), ' lint(s) found.')
      }
    "
```

Or using the `r-lib/actions` linting action:
```yaml
- uses: r-lib/actions/lint@v2
```

---

## 3. Suggested workflow combining air + lintr

```sh
# Step 1: Format (fixes whitespace, indentation, line breaks)
air format .

# Step 2: Lint (catches remaining issues air doesn't touch)
Rscript -e 'lintr::lint_dir(".")'

# Step 3: Review remaining lint warnings manually
# (especially T/F → TRUE/FALSE, assignment operator, long lines)
```

---

## 4. Files excluded from automated formatting

The following directories contain code that was not written for this repository
and should be excluded from bulk formatting to preserve original style:

- `misc/` — external example scripts reproduced from other sources
- `*/saved_fit/` — cached model objects, no R source

Add these to `.lintr` exclusions and pass `--exclude-dir` to `air` if supported.

---

## 5. Inline code blocks without language specifiers (syntax highlighting)

During the scan, several `#'` prose sections were found with fenced code blocks
(` ``` `) that lack a language tag, causing no syntax highlighting in the
rendered HTML. These are separate from the `print_stan_file` issue (fixed on the
`claude/scan-math-code-issues` branch).

| File | Lines | Content | Correct tag |
|---|---|---|---|
| `declining_exponentials/declining_exponentials.R` | 92–96, 144–147, 392–396 | Stan code snippets | `` ```stan `` |
| `digits/digits.R` | 274–278, 289–291 | R `options()` calls | `` ```r `` |
| `problems/problems.R` | 605–609, 906–911 | Stan console/warning output | `` ```text `` |

**Fix pattern** (example from `declining_exponentials.R` line 92):
```
Before: #' ```
After:  #' ```stan
```

These fixes belong in the `claude/scan-math-code-issues` branch (see that
branch's `math_code_issues.md` for context).
