# Visualization Specification

## Overview
This specification defines the visualization outputs for the compositional sleep analysis, focusing on publication-ready figures that effectively communicate isotemporal substitution effects and optimal sleep compositions.

## Core Visualizations

### 1. Risk Ratio Plot by Minutes
**Purpose**: Display substitution effects as risk ratios across time increments

**Structure**:
- X-axis: Minutes substituted (15, 30, 45, 60)
- Y-axis: Risk ratio (log scale)
- Lines: Different substitution pairs (e.g., N1→N3, N2→N3)
- Horizontal reference line at RR=1

**Design Elements**:
- Error bars for 95% confidence intervals
- Different line types/colors for each substitution
- Facets by outcome if multiple
- Annotations for statistical significance

### 2. Cumulative Risk Comparison
**Purpose**: Show cumulative incidence over time for different compositions

**Structure**:
- X-axis: Follow-up time (years)
- Y-axis: Cumulative incidence (%)
- Lines: 
  - Best composition (lowest risk)
  - Worst composition (highest risk)
  - Average/typical composition
  - Reference (no intervention)

**Design Elements**:
- Shaded confidence bands
- Clear legend with composition details
- Risk table below plot showing numbers at risk

### 3. Compositional Ternary Diagrams
**Purpose**: Visualize 3-component subcompositions and outcomes

**Options**:
- N1-N2-N3 (NREM stages)
- Wake-NREM-REM (major states)
- Custom user-defined triplets

**Features**:
- Contour lines for outcome levels
- Individual points for participants
- Optimal composition marked
- Density overlay for data distribution

### 4. Optimal Composition Radar Plot
**Purpose**: Compare optimal vs. average sleep composition

**Structure**:
- Axes: Each sleep stage (wake, n1, n2, n3, rem)
- Scale: Minutes or percentages
- Lines: Population average, optimal, confidence region

**Variations**:
- By outcome (dementia, cognition, brain volume)
- By subgroup (age, sex)
- Include "healthy sleeper" reference

### 5. Time-Varying Effects
**Purpose**: Show how substitution effects change over follow-up

**Structure**:
- X-axis: Follow-up time (years)
- Y-axis: Cumulative incidence or effect size
- Lines: Different substitution scenarios
- Shading: Confidence bands

**Key Comparisons**:
- No intervention (reference)
- 30 min more N3 from N1
- 30 min more N3 from wake
- Optimal reallocation

## Statistical Graphics

### 6. Density Check Visualization
**Purpose**: QC plot showing which compositions are plausible

**Structure**:
- Scatterplot matrix of ILR coordinates
- Points colored by Mahalanobis distance
- Contour lines for density threshold
- Highlight excluded compositions

### 7. Model Diagnostics Multi-Panel
**Purpose**: Assess model assumptions and fit

**Panels**:
1. Residual vs. fitted
2. Q-Q plot
3. Scale-location
4. Influential observations

**Compositional Specific**:
- ILR residuals
- Composition residuals in simplex

### 8. Imputation Diagnostic Plots
**Purpose**: Validate imputation quality

**Types**:
- Density overlap (observed vs. imputed)
- Trace plots for convergence
- Missing data patterns

## Interactive Visualizations

### 9. Substitution Explorer (Shiny/Plotly)
**Features**:
- Select from/to activities
- Adjust substitution amount
- Choose outcome
- View effect in real-time

### 10. Composition Simulator
**Features**:
- Drag sliders for each stage
- See predicted outcome
- Compare to optimal
- Show uncertainty

## Publication Figures

### Main Manuscript (3-4 figures)

**Figure 1**: Study Flow and Sleep Distributions
- Panel A: CONSORT-style flow diagram
- Panel B: Stacked bar chart of sleep stages
- Panel C: Density plot by age group

**Figure 2**: Primary Substitution Effects
- Heatmap for all 30-minute substitutions
- Focus on N3 as target
- Include statistical significance

**Figure 3**: Optimal Compositions
- Radar plots for each outcome
- Compare to population average
- Highlight clinical implications

**Figure 4**: Stratified Effects
- Forest plot by age and sex
- Key substitutions only
- Interaction p-values

### Supplementary Figures

**Figure S1**: Complete substitution grid (all times)
**Figure S2**: Sensitivity analyses
**Figure S3**: Model diagnostic plots
**Figure S4**: Compositional geometry explained
**Figure S5**: Longitudinal trajectories

## Technical Specifications

### Output Formats
- **Vector**: PDF/SVG for publication
- **Raster**: PNG at 300 DPI for submission
- **Data**: Underlying data in CSV

### Styling Guidelines
```r
# Consistent theme
theme_composition <- theme_minimal() +
  theme(
    text = element_text(family = "Arial", size = 10),
    panel.grid.minor = element_blank(),
    legend.position = "bottom"
  )

# Color palettes
outcomes_palette <- c(
  "dementia" = "#E41A1C",
  "cognition" = "#377EB8", 
  "brain_volume" = "#4DAF4A"
)

# Substitution colors (diverging)
substitution_palette <- colorRampPalette(
  c("#053061", "#2166AC", "#F7F7F7", "#D6604D", "#67001F")
)
```

### Accessibility
- Color-blind safe palettes (viridis, Okabe-Ito)
- Sufficient contrast ratios
- Alternative text for all figures
- Pattern fills for print versions

### Size and Layout
- Single column: 3.5 inches wide
- Double column: 7 inches wide
- Maximum height: 9 inches
- Minimum font size: 8pt

## Quality Checks

### Pre-Publication Checklist
- [ ] All axes labeled with units
- [ ] Legends clear and complete
- [ ] Statistical significance explained
- [ ] Sample sizes noted
- [ ] Consistent style across figures
- [ ] Data-ink ratio optimized
- [ ] Color reproduction in grayscale
- [ ] File sizes reasonable (<10MB)

### Reproducibility
- Figure generation scripted
- Random seed set for layouts
- Version control for all plots
- Raw data archived

## Implementation Notes

### Performance
- Pre-compute dense grids
- Cache ggplot objects
- Use data.table for aggregation
- Parallel rendering for multiple formats

### Modularity  
- Separate data prep from plotting
- Reusable theme functions
- Parameterized plot functions
- Easy to update styles globally