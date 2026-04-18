# Mathematical / Code Issues Requiring Author Review

A multi-agent scan (code bugs, mathematical notation, statistical correctness, Stan/R deprecations) was run over the repository. The following issues were found but left for author review because they involve code semantics that could plausibly be intentional (or because the intended fix depends on context the scanner could not verify).

Fixes that were applied directly are listed at the bottom for reference.

---

## 1. `misc/chapter_06/section_06_02/rats.R` — Line 93

**Context:** This block writes `rats_3.pdf`, plotting posterior draws from `fit_3` (defined line 80, with `sims_3 <- fit_3$draws(...)` on line 85).

**Current code (lines 93–98):**

```r
for (s in sample(nrow(sims_2), 20)) {
  curve(invlogit(sims_3$a[s] + sims_3$b[s] * x),
        from = -1, to = 1,
        col = "red", lwd = 0.5,
        add = TRUE)
}
```

**Concern:** The loop draws indices from `nrow(sims_2)` but indexes into `sims_3`. This looks like a copy-paste from the earlier `fit_2` plotting block (lines 65–70), where both sampling and indexing correctly use `sims_2`. If `sims_2` and `sims_3` have the same number of rows this is harmless, but the indices no longer correspond to actual `sims_3` draws — they're a random subsample of positions that happens to be compatible.

**Suggested fix:**

```r
for (s in sample(nrow(sims_3), 20)) {
```

**Review needed:** Confirm `sims_2` here is unintentional and should be `sims_3`.

---

## 2. `sharks/sharks.R` — Lines 94, 282, 295

**Current code (three locations, same pattern):**

```r
dplyr::filter(SharksexTrackNo ==
                c("WSF1 T1", "WSF1 T10"))
```

**Concern:** `==` with a vector on the right side compares elementwise with recycling — it does not select rows whose value is in the set. It will emit a warning in current dplyr/vctrs and can silently return the wrong rows when the input has an odd length. Line 70 of the same file already uses the correct idiom:

```r
filter(!SharksexTrackNo %in% c("WSF9 T4", "WSF9 T3 B "))
```

**Suggested fix (all three locations):**

```r
dplyr::filter(SharksexTrackNo %in%
                c("WSF1 T1", "WSF1 T10"))
```

**Review needed:** Confirm `==` was not deliberate. Given the other filter in the same file uses `%in%`, this looks like a bug.

---

## 3. `world_cup/worldcup_sqrt_continuous_nojacobian.stan` — Lines ~48

**Current code (generated quantities block):**

```stan
real round15 = round(1.5);
real round25 = round(2.5);
```

**Concern:** These two quantities appear declared but never used anywhere downstream (neither in the model, nor consumed from R). They may be leftover debugging/exploration that should be removed, or they may be deliberately exposed to illustrate Stan's banker's rounding behavior (`round(1.5) = 2`, `round(2.5) = 2`).

**Suggested action:** Either remove them if unused, or add a one-line `#'` comment in the `.R` file explaining the pedagogical purpose.

**Review needed:** Confirm intent.

---

## Fixes applied directly (for reference)

| File | Line | Change |
|---|---|---|
| `dogs/dogs.R` | 332 | `\matrhm{beta}(1,1) is` → `\mathrm{beta}(1,1)$ is` (typo + missing `$`) |
| `dogs/dogs.R` | 368 | Second `$x_{1jt}$` → `$x_{2jt}$` (matches equation on line 364: shocks and avoidances) |
| `resources.qmd` | 58, 60–63, 65 | 6× `https:://` → `https://` |
| `birthdays/birthdays.R` | 123, 137 | Added `.groups = "drop"` to `summarise()` (silences dplyr ≥ 1.0.0 warning) |
| `declining_exponentials/declining_exponentials.R` | 205 | Prose equation `\log\epsilon_i \sim \operatorname{normal}(0,\log\sigma)` → `\operatorname{normal}(0,\sigma)` to match the Stan model `y ~ lognormal(log(y_pred), sigma)` and the simulation code `epsilon <- exp(rnorm(N, 0, sigma))` |

## False positives that were intentionally not flagged

The initial automated scan surfaced several items that were verified and dismissed:

- **`normal(0, s)` priors on `<lower=0>` parameters** across many `.stan` files (`golf_angle_distance_binomial.stan`, `gpbf*.stan`, `exponential_positive*.stan`, etc.). These are the standard Stan idiom for a half-normal prior — the constraint automatically truncates the support with the correct Jacobian.
- **`vector<lower=0, upper=5>[2] theta; theta ~ normal(3, 1);`** in `movies/ratings_1.stan`. This is a valid truncated-normal prior.
- **`multiple_choice/logit_guessing_multilevel.stan`** offset/multiplier sizing `[K]` for `a`, `b`: consistent with usage (`a[item] + b[item] .* x_adj[student]`). Items are size K, students are size J.
- **Golf half-normal wording**: prose says "half-normal(0,1)" and code uses `normal(0, 1)` on a `<lower=0>` parameter — these are mathematically identical.
