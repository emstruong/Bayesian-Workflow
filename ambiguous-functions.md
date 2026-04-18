# Ambiguous Function Calls in Bayesian-Workflow

Scan of all 52 R files for function names that exist in multiple loaded packages
or conflict with base R. **No critical issues were found** — all ambiguous calls
are safe given the actual packages loaded in each file, but the table below
documents where qualifying with `pkg::fn()` would improve explicitness.

---

## Executive Summary

| Function | Conflicting Packages | Calls | Files Affected | Risk |
|---|---|---|---|---|
| `filter()` | dplyr vs `stats::filter` (time-series) | 30 | 9 | Low |
| `select()` | dplyr vs `MASS::select` | 37 | 7 | Low |
| `hour()` / `minute()` | lubridate vs base datetime | 10 | 1 (`sharks`) | Very low |
| `rename()` | dplyr vs `plyr::rename` | 2 | 2 (`shrinkage_plots_*`) | Very low |
| `matches()` | tidyselect vs `testthat::matches` | 3 | 1 (`variable_selection`) | Very low |

### Why risk is low across the board
- `MASS` is never explicitly loaded in any file — so `select()` has no real competitor.
- `stats::filter()` is a time-series convolution filter, conceptually distinct; no file uses it.
- `lubridate` is explicitly loaded in `sharks/sharks.R` before any `hour()`/`minute()` calls.
- `plyr` is never loaded; `testthat` is never loaded.

---

## Detailed Findings by File

### `birthdays/birthdays.R`
Libraries include: dplyr (via tidyverse → now explicit), ggplot2, readr, tibble, tictoc,
cmdstanr, posterior, tinytable, loo, bayesplot, ggdist, patchwork, ggrepel, RColorBrewer

| Function | Calls | Lines (sample) | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 19 | 1006, 1110, 1220, 1291, 1324… | `stats::filter` | Safe — all in dplyr pipe chains |
| `select()` | 19 | (paired with filter chains) | `MASS::select` | Safe — MASS not loaded |

**Recommendation:** Optionally prefix heavy-use calls as `dplyr::filter()` / `dplyr::select()`.

---

### `dogs/dogs.R`
Libraries include: ggplot2, bayesplot, patchwork, tidybayes, brms, dplyr, tibble, tinytable…

| Function | Calls | Lines (sample) | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 12 | 97, 171, 176, 482, 488, 503… | `stats::filter` | Safe — many already qualified `dplyr::filter()` |
| `select()` | 6 | 162, 356, 391, 429, 470… | `MASS::select` | Safe — MASS not loaded |

---

### `loo_comparison/loo_comparison.R`
Libraries include: tidyr, dplyr, tibble, loo, brms, rstanarm, posterior, ggplot2, ggdist…

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 1 | 212 | `stats::filter` | Safe |
| `select()` | 6 | 131, 263, 343, 358, 465… | `MASS::select` | Safe — some already `dplyr::select()` |

---

### `misc/chapter_12/section_12_04/underdetermined.R`
Libraries include: rprojroot, dplyr, tidyr, ggplot2, bayesplot, patchwork, cmdstanr, posterior

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 3 | 23, 122, 125 | `stats::filter` | Safe |

---

### `nabiximols/nabiximols.R`
Libraries include: tidyr, dplyr, tibble, modelr, loo, brms, cmdstanr, rstan, posterior,
ggplot2, tidybayes, ggdist, tinytable, priorsense…

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 2 | 612, 615 | `stats::filter` | Safe |
| `select()` | 6 | 192, 215, 235, 249, 615… | `MASS::select` | Safe |

---

### `problems/problems.R`
Libraries include: rprojroot, cmdstanr, posterior, tidyr, dplyr, ggplot2, bayesplot…

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 6 | 787, 788, 815, 816, 853… | `stats::filter` | Safe |
| `select()` | 3 | 776, 804, 842 | `MASS::select` | Safe |

---

### `roaches/roaches.R`
Libraries include: loo, brms, cmdstanr, ggplot2, khroma, ggdist, posterior, priorsense,
dplyr, tibble, reliabilitydiag

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 1 | 934 | `stats::filter` | Safe |

---

### `sharks/sharks.R`
Libraries include: rprojroot, dplyr, ggplot2, CircStats, patchwork, **lubridate**,
moveHMM, bayesplot, tidyr, cmdstanr

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 4 | 71, 95, 283, 296 | `stats::filter` | Safe — some already `dplyr::filter()` |
| `hour()` | 5 | 382, 383, 630, 645, 664 | base date fns | Very low — lubridate explicit |
| `minute()` | 5 | 382, 383, 631, 646, 665 | base date fns | Very low — lubridate explicit |

---

### `sleep_study/shrinkage_plots_gaussian.R` and `shrinkage_plots_lognormal.R`
Libraries include: brms, dplyr, ggplot2, tibble, ggrepel

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 1 each | 32 / 33 | `stats::filter` | Safe |
| `rename()` | 1 each | 56 / 58 | `plyr::rename` | Safe — plyr not loaded |

---

### `sleep_study/sleep_study.R`
Libraries include: rprojroot, ggplot2, patchwork, dplyr, loo, brms, priorsense

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 1 | 85 | `stats::filter` | Safe |

---

### `variable_selection/variable_selection.R`
Libraries include: brms, cmdstanr, posterior, loo, projpred, ggplot2, dplyr,
matrixStats, ggdist, doFuture, doRNG…

| Function | Calls | Lines | Conflict | Assessment |
|---|---|---|---|---|
| `filter()` | 4 | 351, 381, 410, 439 | `stats::filter` | Safe |
| `select()` | 2 | 129, 130 | `MASS::select` | Safe — used with `matches()` in tidyselect context |
| `matches()` | 3 | 128, 129, 130 | `testthat::matches` | Safe — testthat not loaded |

---

## Recommendations

1. **Optional but good practice**: Qualify the most-called ambiguous functions with `dplyr::` in
   the heaviest files (`birthdays/birthdays.R`, `dogs/dogs.R`) to make intent explicit and
   future-proof against someone adding MASS or stats-heavy packages later.

2. **No immediate action required**: Zero calls were found where the wrong package's function
   would silently execute — all conflicts are with packages not loaded in the same file.

3. **Future maintenance note**: If any file later adds `library(MASS)` or begins using
   `stats::filter()` for time-series work, qualify the dplyr calls immediately to prevent
   silent masking.

---

*Generated 2026-04-18 by automated scan of 52 R files.*
