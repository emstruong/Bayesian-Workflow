#!/usr/bin/env Rscript
# verify_imports.R
#
# Static analysis: check that every tidyverse function call in the four
# files we modified has its source package listed in that file's library()
# block.
#
# Motivation (from adversarial review):
#  - Runtime checks give false confidence: brms/cmdstanr load dplyr/tibble
#    transitively, masking missing explicit imports.
#  - exists("filter") is always TRUE because stats::filter is in base R.
#  - Package search-path ordering matters for bare (unqualified) calls.
#  - %>% requires dplyr ATTACHED; |> needs nothing.
#
# This script does NOT execute any R model code.  It parses source text only.
# Run with: Rscript verify_imports.R
#
# Exit codes: 0 = all clean, 1 = one or more issues found.

# ---------------------------------------------------------------------------
# Configuration
# ---------------------------------------------------------------------------

TARGET_FILES <- c(
  "sharks/sharks.R",
  "sleep_study/shrinkage_plots_gaussian.R",
  "sleep_study/shrinkage_plots_lognormal.R",
  "birthdays/birthdays.R"
)

# Canonical function-to-package mapping.
# Only functions that are UNAMBIGUOUS (not re-exported by multiple packages
# and not available in base R) are listed.  Ambiguous names (filter, select,
# lag, etc.) are handled in the AMBIGUOUS_CALLS table below.
FN_TO_PKG <- list(
  # ggplot2 ------------------------------------------------------------------
  ggplot         = "ggplot2", aes            = "ggplot2",
  geom_point     = "ggplot2", geom_line      = "ggplot2",
  geom_path      = "ggplot2", geom_bar       = "ggplot2",
  geom_col       = "ggplot2", geom_histogram = "ggplot2",
  geom_density   = "ggplot2", geom_boxplot   = "ggplot2",
  geom_violin    = "ggplot2", geom_ribbon    = "ggplot2",
  geom_area      = "ggplot2", geom_tile      = "ggplot2",
  geom_raster    = "ggplot2", geom_segment   = "ggplot2",
  geom_abline    = "ggplot2", geom_hline     = "ggplot2",
  geom_vline     = "ggplot2", geom_text      = "ggplot2",
  geom_label     = "ggplot2", geom_errorbar  = "ggplot2",
  geom_jitter    = "ggplot2", geom_smooth    = "ggplot2",
  geom_step      = "ggplot2", geom_rug       = "ggplot2",
  geom_spoke     = "ggplot2", geom_sf        = "ggplot2",
  facet_wrap     = "ggplot2", facet_grid     = "ggplot2",
  theme          = "ggplot2", theme_bw       = "ggplot2",
  theme_classic  = "ggplot2", theme_minimal  = "ggplot2",
  theme_void     = "ggplot2", theme_dark     = "ggplot2",
  theme_gray     = "ggplot2", theme_light    = "ggplot2",
  element_text   = "ggplot2", element_line   = "ggplot2",
  element_rect   = "ggplot2", element_blank  = "ggplot2",
  scale_x_continuous = "ggplot2", scale_y_continuous = "ggplot2",
  scale_x_discrete   = "ggplot2", scale_y_discrete   = "ggplot2",
  scale_color_manual = "ggplot2", scale_fill_manual  = "ggplot2",
  scale_color_viridis_c = "ggplot2", scale_color_viridis_d = "ggplot2",
  scale_fill_viridis_c  = "ggplot2", scale_fill_viridis_d  = "ggplot2",
  scale_shape_manual    = "ggplot2", scale_linetype_manual = "ggplot2",
  scale_alpha            = "ggplot2", scale_size             = "ggplot2",
  coord_cartesian = "ggplot2", coord_flip    = "ggplot2",
  coord_map       = "ggplot2", coord_fixed   = "ggplot2",
  coord_polar     = "ggplot2", coord_sf      = "ggplot2",
  labs     = "ggplot2", ggtitle  = "ggplot2",
  xlab     = "ggplot2", ylab     = "ggplot2",
  xlim     = "ggplot2", ylim     = "ggplot2",
  annotate = "ggplot2", annotation_custom = "ggplot2",
  stat_qq  = "ggplot2", stat_qq_line = "ggplot2",
  after_stat = "ggplot2", after_scale = "ggplot2",
  unit     = "ggplot2", margin   = "ggplot2",
  rel      = "ggplot2", arrow    = "ggplot2",
  waiver   = "ggplot2", ggproto  = "ggplot2",
  `%+%`    = "ggplot2",

  # dplyr (non-ambiguous names only) ----------------------------------------
  mutate       = "dplyr",  transmute    = "dplyr",
  arrange      = "dplyr",  distinct     = "dplyr",
  pull         = "dplyr",  tally        = "dplyr",
  count        = "dplyr",  add_count    = "dplyr",
  left_join    = "dplyr",  right_join   = "dplyr",
  inner_join   = "dplyr",  full_join    = "dplyr",
  anti_join    = "dplyr",  semi_join    = "dplyr",
  bind_rows    = "dplyr",  bind_cols    = "dplyr",
  case_when    = "dplyr",  coalesce     = "dplyr",
  if_else      = "dplyr",  between      = "dplyr",
  row_number   = "dplyr",  dense_rank   = "dplyr",
  n_distinct   = "dplyr",  cummean      = "dplyr",
  across       = "dplyr",  everything   = "dplyr",
  starts_with  = "dplyr",  ends_with    = "dplyr",
  contains     = "dplyr",  num_range    = "dplyr",
  all_of       = "dplyr",  any_of       = "dplyr",
  join_by      = "dplyr",  slice_head   = "dplyr",
  slice_tail   = "dplyr",  slice_sample = "dplyr",
  slice_min    = "dplyr",  slice_max    = "dplyr",

  # tibble (NOT re-exported by dplyr) ----------------------------------------
  add_column          = "tibble",
  rownames_to_column  = "tibble",
  column_to_rownames  = "tibble",
  tribble             = "tibble",
  tibble_row          = "tibble",
  enframe             = "tibble",
  deframe             = "tibble",
  has_name            = "tibble",

  # tibble functions that dplyr DOES re-export (flag if neither is loaded)
  tibble      = "tibble|dplyr",
  as_tibble   = "tibble|dplyr",
  glimpse     = "tibble|dplyr",
  add_row     = "tibble|dplyr",

  # tidyr --------------------------------------------------------------------
  pivot_longer    = "tidyr", pivot_wider     = "tidyr",
  gather          = "tidyr", spread          = "tidyr",
  separate        = "tidyr", separate_rows   = "tidyr",
  unite           = "tidyr", nest            = "tidyr",
  unnest          = "tidyr", complete        = "tidyr",
  fill            = "tidyr", replace_na      = "tidyr",
  drop_na         = "tidyr", crossing        = "tidyr",
  nesting         = "tidyr", chop            = "tidyr",
  unchop          = "tidyr", hoist           = "tidyr",
  pack            = "tidyr", unpack          = "tidyr",

  # readr --------------------------------------------------------------------
  read_csv        = "readr", read_csv2       = "readr",
  read_tsv        = "readr", read_delim      = "readr",
  read_fwf        = "readr", write_csv       = "readr",
  write_tsv       = "readr", write_delim     = "readr",
  cols            = "readr", cols_only       = "readr",

  # purrr --------------------------------------------------------------------
  map          = "purrr",  map2         = "purrr",
  pmap         = "purrr",  imap         = "purrr",
  walk         = "purrr",  walk2        = "purrr",
  map_chr      = "purrr",  map_dbl      = "purrr",
  map_int      = "purrr",  map_lgl      = "purrr",
  map_df       = "purrr",  map_dfr      = "purrr",
  map_dfc      = "purrr",  reduce       = "purrr",
  accumulate   = "purrr",  keep         = "purrr",
  discard      = "purrr",  compact      = "purrr",
  every        = "purrr",  some         = "purrr",
  none         = "purrr",  negate       = "purrr",
  safely       = "purrr",  possibly     = "purrr",
  quietly      = "purrr",  transpose    = "purrr",
  partial      = "purrr",  compose      = "purrr",
  as_mapper    = "purrr",  pluck        = "purrr",
  chuck        = "purrr",  set_names    = "purrr",
  list_modify  = "purrr",  modify       = "purrr",

  # stringr ------------------------------------------------------------------
  str_c           = "stringr", str_length      = "stringr",
  str_pad         = "stringr", str_trunc       = "stringr",
  str_trim        = "stringr", str_detect      = "stringr",
  str_match       = "stringr", str_replace     = "stringr",
  str_replace_all = "stringr", str_split       = "stringr",
  str_subset      = "stringr", str_extract     = "stringr",
  str_extract_all = "stringr", str_locate      = "stringr",
  str_locate_all  = "stringr", str_sub         = "stringr",
  str_to_lower    = "stringr", str_to_upper    = "stringr",
  str_to_title    = "stringr", str_count       = "stringr",
  str_starts      = "stringr", str_ends        = "stringr",
  str_wrap        = "stringr", str_glue        = "stringr",
  str_dup         = "stringr", str_sort        = "stringr",
  str_order       = "stringr", word            = "stringr",
  fixed           = "stringr", coll            = "stringr",
  regex           = "stringr", boundary        = "stringr",

  # forcats ------------------------------------------------------------------
  fct_reorder  = "forcats", fct_rev      = "forcats",
  fct_infreq   = "forcats", fct_inorder  = "forcats",
  fct_relevel  = "forcats", fct_recode   = "forcats",
  fct_collapse = "forcats", fct_drop     = "forcats",
  fct_other    = "forcats", fct_lump     = "forcats",
  fct_unique   = "forcats", fct_count    = "forcats",
  as_factor    = "forcats", fct_anon     = "forcats",

  # magrittr (pipe) ----------------------------------------------------------
  `%>%` = "dplyr|magrittr"  # dplyr re-exports %>% from magrittr
)

# Functions whose name conflicts with another package; flag when the
# non-preferred package is ALSO loaded in the same file.
AMBIGUOUS_CALLS <- list(
  filter    = list(preferred = "dplyr", conflicts = c("stats")),
  select    = list(preferred = "dplyr", conflicts = c("MASS")),
  lag       = list(preferred = "dplyr", conflicts = c("stats")),
  rename    = list(preferred = "dplyr", conflicts = c("plyr")),
  matches   = list(preferred = "dplyr", conflicts = c("testthat")),
  intersect = list(preferred = "dplyr", conflicts = c("base")),
  union     = list(preferred = "dplyr", conflicts = c("base")),
  setdiff   = list(preferred = "dplyr", conflicts = c("base")),
  hour      = list(preferred = "lubridate", conflicts = c("base")),
  minute    = list(preferred = "lubridate", conflicts = c("base"))
)

# ---------------------------------------------------------------------------
# Helpers
# ---------------------------------------------------------------------------

extract_libraries <- function(filepath) {
  lines <- readLines(filepath, warn = FALSE)
  # Match: library(pkg), library("pkg"), library('pkg'), require(pkg)
  pat <- "^\\s*(library|require)\\([\"']?([A-Za-z0-9._]+)[\"']?\\)"
  hits <- regmatches(lines, regexpr(pat, lines, perl = TRUE))
  sub("^\\s*(?:library|require)\\([\"']?([A-Za-z0-9._]+)[\"']?\\).*",
      "\\1", hits, perl = TRUE)
}

extract_fn_calls <- function(filepath) {
  lines <- readLines(filepath, warn = FALSE)
  # Strip comment lines (both #' prose and #| chunk opts and # inline)
  code_lines <- grep("^\\s*#", lines, value = TRUE, invert = TRUE)
  # Extract bare identifiers followed by '(' (function calls)
  m <- gregexpr("[A-Za-z_.][A-Za-z0-9_.]*(?=\\s*\\()", code_lines, perl = TRUE)
  fns <- unlist(regmatches(code_lines, m))
  # Also extract pipe operators
  if (any(grepl("%>%", code_lines))) fns <- c(fns, "%>%")
  unique(fns)
}

pkg_satisfies <- function(required_pkg_spec, loaded_pkgs) {
  # required_pkg_spec may be "pkg" or "pkg1|pkg2" (either satisfies)
  options <- strsplit(required_pkg_spec, "\\|")[[1]]
  any(options %in% loaded_pkgs)
}

check_file <- function(relpath, base_dir) {
  filepath <- file.path(base_dir, relpath)
  cat(sprintf("\n--- %s\n", relpath))

  if (!file.exists(filepath)) {
    cat("  [ERROR] File not found\n")
    return(FALSE)
  }

  loaded  <- extract_libraries(filepath)
  fn_calls <- extract_fn_calls(filepath)
  issues  <- character(0)

  # 1. Check pipe operator
  if ("%>%" %in% fn_calls && !any(c("dplyr", "magrittr", "tidyverse") %in% loaded)) {
    issues <- c(issues,
      "  [FAIL] %>% used but neither dplyr nor magrittr is explicitly loaded")
  }

  # 2. Check each function call against FN_TO_PKG
  for (fn in fn_calls) {
    if (!fn %in% names(FN_TO_PKG)) next
    required <- FN_TO_PKG[[fn]]
    if (!pkg_satisfies(required, loaded)) {
      issues <- c(issues, sprintf(
        "  [FAIL] %s() — requires %s, but not in library() calls", fn, required))
    }
  }

  # 3. Warn about ambiguous calls where the conflicting package IS loaded
  for (fn in fn_calls) {
    if (!fn %in% names(AMBIGUOUS_CALLS)) next
    info <- AMBIGUOUS_CALLS[[fn]]
    loaded_conflicts <- intersect(info$conflicts, loaded)
    if (length(loaded_conflicts) > 0) {
      issues <- c(issues, sprintf(
        "  [WARN] %s() is ambiguous: both %s (preferred) and %s are loaded",
        fn, info$preferred, paste(loaded_conflicts, collapse = ", ")))
    }
  }

  # 4. Transitive availability note (informational only)
  transitive_providers <- c("brms", "cmdstanr", "rstan", "rstanarm")
  loaded_transitive <- intersect(transitive_providers, loaded)
  if (length(loaded_transitive) > 0) {
    cat(sprintf(
      "  [NOTE] Transitive provider(s) loaded: %s — these pull in dplyr,\n",
      paste(loaded_transitive, collapse = ", ")))
    cat("         tibble, ggplot2, etc. transitively; missing explicit loads\n")
    cat("         may still work at runtime but are fragile.\n")
  }

  if (length(issues) == 0) {
    cat("  [PASS] All checked function calls have explicit library() sources\n")
    return(TRUE)
  } else {
    for (i in issues) cat(i, "\n")
    return(FALSE)
  }
}

# ---------------------------------------------------------------------------
# Main
# ---------------------------------------------------------------------------

base_dir <- tryCatch(
  normalizePath(dirname(sys.frame(1)$ofile), mustWork = TRUE),
  error = function(e) getwd()
)

cat("=== verify_imports.R — static import analysis ===\n")
cat(sprintf("Base directory: %s\n", base_dir))
cat("(No R model code is executed; this is a source-text scan only.)\n")

results <- vapply(TARGET_FILES, check_file, logical(1), base_dir = base_dir)

cat("\n=== SUMMARY ===\n")
for (i in seq_along(TARGET_FILES)) {
  cat(sprintf("  [%s] %s\n",
              if (results[i]) "PASS" else "FAIL", TARGET_FILES[[i]]))
}

cat("\nKey limitations of this static analysis (see adversarial review):\n")
cat("  - Transitive package loads (e.g. brms->dplyr) are NOT checked here.\n")
cat("  - Search-path ordering and masking are NOT verified.\n")
cat("  - Bare filter() vs dplyr::filter() distinction is NOT enforced.\n")
cat("  - For a definitive check, run in an renv-locked environment where\n")
cat("    only the explicitly listed packages are installed.\n")

if (all(results)) {
  cat("\nAll checks passed.\n")
  quit(status = 0L)
} else {
  cat(sprintf("\n%d of %d file(s) had issues.\n", sum(!results), length(results)))
  quit(status = 1L)
}
