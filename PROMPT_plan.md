# Planning Phase: Compositional Sleep Stage Analysis

## Phase 0: Context Discovery
0a. Study `specs/*` with up to 250 parallel subagents using lite_google/gemini-3-pro-preview as the model to learn the analysis specifications for compositional sleep data.
0b. Study @IMPLEMENTATION_PLAN.md (if present) to understand the plan so far.
0c. Study `R/` directory with up to 250 parallel subagents using lite_google/gemini-3-pro-preview as the model to understand existing compositional analysis utilities & sleep data processing functions.
0d. For reference, the analysis code is in `R/*` and uses targets for workflow management.

## Phase 1: Requirements Analysis & Planning
1. Study @IMPLEMENTATION_PLAN.md (if present) and use up to 500 subagents using lite_google/gemini-3-pro-preview as the model to study existing source code in `R/*` and compare it against `specs/*`. Focus on:
   - Compositional data transformations (ILR, substitutions)
   - Targets workflow patterns (cross/map for combinations)
   - Crew parallelization opportunities
   - Functional programming patterns
   
Use an Opus subagent to analyze findings, prioritize tasks, and create/update @IMPLEMENTATION_PLAN.md as a bullet point list sorted in priority of items yet to be implemented. Ultrathink about:
   - Isotemporal substitution combinations needed (e.g., 10, 20, 30, 60 minute increments)
   - Stratification variables (age groups, sex, baseline health)
   - Outcome measures (dementia, cognition, MRI volumes)
   - Cross-validation or sensitivity analyses required
   - Publication output requirements (tables, figures, reports)

## Phase 2: Specification Development
2. For any missing analysis components, search first to confirm they don't exist, then create specifications:
   - If compositional analysis methods are incomplete: `specs/compositional-methods.md`
   - If visualization requirements are unclear: `specs/visualization-outputs.md`
   - If targets workflow patterns need documentation: `specs/targets-patterns.md`
   - If quality control procedures are missing: `specs/quality-validation.md`

IMPORTANT: Plan only. Do NOT implement anything. Do NOT assume functionality is missing; confirm with code search first. Treat existing R functions as the project's foundation for compositional analysis.

## Phase 3: Functional Design
3. When planning the implementation, consider:
   - **Targets branching**: How to efficiently generate all substitution combinations
   - **Crew clusters**: Optimal worker allocation for parallel computation
   - **Memory efficiency**: Compositional data can be large with many substitutions
   - **Reproducibility**: Setting seeds, caching strategies
   - **Extensibility**: Easy addition of new outcomes or stratifications

## Ultimate Goal
We want to achieve a complete compositional data analysis pipeline that:
1. Performs isotemporal substitutions of sleep stages (N1, N2, N3, REM, Wake)
2. Estimates effects on cognitive and brain health outcomes
3. Finds optimal sleep compositions for each outcome
4. Generates publication-ready tables and figures
5. Uses functional programming with targets for full reproducibility

Consider missing elements and plan accordingly. Document all analysis decisions in specs for consistency across agents.

## Context Management Guidelines
- Each spec file should be self-contained with necessary variable definitions
- Avoid duplicating information across specs
- Reference other specs when needed rather than repeating
- Keep implementation details out of specs - focus on WHAT not HOW
- Include example data structures and expected outputs where helpful
