# Implementation Plan: Sleep Stage Composition Analysis

## Purpose

This file is a compact technical roadmap. Live implementation status, blockers, and next actions are tracked in coordinator Beads epic `coordinator-xyb`, not in markdown checklists.

## Stable Checkpoints

- Simulated data infrastructure exists and is the privacy-safe development path.
- The intended SHHS-2 exposure is the 5-part composition `(n1_s2, n2_s2, n3_s2, waso_s2, rem_s2)`.
- The LMTP path includes an explicit no-intervention reference fit for contrast estimation.
- A 0-minute LMTP substitution should give a risk ratio near 1.
- SHHS-2 duration adjustment belongs in `slp_time_s2`; SHHS-1 `slp_time` should not be added on top of raw SHHS-1 stage-minute adjustment.

## Active Technical Focus

- Stabilize the targets-branched `lmtp_tmle_substitutions` path.
- Finish the duration/formula contract needed for the 5-part exposure definition.
- Keep the current locked formula contract narrow: SHHS-1 raw stage-minute splines, `slp_time_s2`, `s1_incomplete`, and additive-only broader confounder terms until the final confounder pass.
- Keep the simulation, test, and spec layers aligned to the 5-part SHHS-2 exposure contract.
- Verify the LMTP and simulation/test contracts after those fixes land.

## Remaining Roadmap

### Phase 0: Simulation

- Finish validation targets and validation summary wiring.
- Extend scenarios for effect modification, competing risk, and richer DGP checks.
- Add optional missingness and MRI simulation only if needed for downstream verification.

### Phase 1: 5-Part Composition Alignment

- Keep all downstream composition helpers, substitution code, and density checks aligned to four ILR coordinates.
- Preserve the `survSplit()` / `make_cuts()` guardrails that avoid degenerate `timegroup` knots.

### Phase 2: Model Specification

- Finish centralized formula construction.
- Add SHHS-1 adjustment terms, interaction structure, duration handling, and minimal confounder coverage.
- Add the `s1_incomplete` indicator and keep duration semantics explicit.

### Phase 3: Multiple Imputation

- Restructure imputation to return a real `mids` object.
- Add pooling utilities and MI-aware fitting/prediction helpers.
- Rewire targets so MI is part of the main analysis path instead of a side branch.

Current branch state on `lmtp`:

- `data_targets.R` already returns a real `imp_mids` target plus `imp_datasets` materialized from all imputations.
- The main remaining single-imputation drift is the legacy analysis scaffold in `analysis_targets.R` that still depends on `imp` for:
  - `timegroup_cuts`
  - `dt_surv_long`
  - `dt_surv_wide`
  - `comp_limits`
  - `lmtp_surv_cols`
  - `lmtp_baseline_covars`
  - the top-level `comparison_contract`
- The MI-first migration order should be:
  - move the shared analysis scaffold above both pooled and LMTP onto completed-dataset bundles instead of `imp`
  - keep `imp` only as a temporary compatibility target until no analysis targets depend on it
  - once no analysis targets depend on `imp`, demote or remove the legacy single-complete target
- The support-aware substitution grid is already MI-driven: directional support frontiers are computed per imputation and combined conservatively across imputations before downstream analysis.

### Phase 4: Isotemporal Substitution

- Complete the substitution grid, bounded shift application, density screening, and summary targets for the 5-part exposure.
- Keep `n_intervened` and similar intervention diagnostics in the derived outputs rather than in markdown notes.

### Phase 5: MRI Outcomes

- Add MRI dataset preparation, model formulas, fitted models, and substitution summaries.
- Keep MRI timing assumptions explicit in code and specs.

### Phase 6: Bootstrap and Ideal Composition

- Add the bootstrap x MI execution structure.
- Compute uncertainty intervals for substitution and ideal-composition outputs.
- Generate and filter the ideal-composition grid under the finalized density/modeling rules.

Current branch state on `lmtp`:

- `R/bootstrap_utils.R::run_bootstrap_rep()` already follows the intended bootstrap-within-MI execution order:
  - bootstrap resample raw prepared data
  - run `impute_data()` in the bootstrap sample
  - materialize all completed datasets
  - fit pooled models and substitution summaries inside each completed dataset
  - average contrasts across imputations for one bootstrap replicate
- The remaining bootstrap work is now mostly graph/documentation/test cleanup:
  - verify the top-level bootstrap targets continue to consume the MI-aware pooled lane and shared substitution contract
  - add target-graph tests that lock in resample-before-impute ordering
  - update Beads/docs so the remaining work is not described as if bootstrap still uses a single completed dataset

### Phase 7: Reporting

- Build the reporting layer only after the analysis contracts above are stable.
- Keep generated tables/figures derived from targets outputs, not hand-maintained docs.

## Repo Pointers

- Live tracking: coordinator Beads epic `coordinator-xyb`
- Simulation spec: `specs/simulation.md`
- Analysis spec: `specs/analysis.md`
- Model spec: `specs/models.md`
- Canonical code map: `CODEBASE_MAP.md`
