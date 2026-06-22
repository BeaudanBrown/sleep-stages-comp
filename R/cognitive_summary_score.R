get_cog_score <- function(data) {
  data[, `:=`(
    S_TRAILSB_s1 = (-log(TRAILSB_s1) + 4.32) / 0.45,
    S_LMC_s1 = ((LMI_s1 + LMD_s1) - 22.08) / 6.75,
    S_VRC_s1 = ((VRI_s1 + VRD_s1) - 17.22) / 6.33,
    S_SIM_s1 = (SIM_s1 - 16.75) / 3.55,
    S_TRAILSB_s2 = (-log(TRAILSB_s2) + 4.32) / 0.45,
    S_LMC_s2 = ((LMI_s2 + LMD_s2) - 22.08) / 6.75,
    S_VRC_s2 = ((VRI_s2 + VRD_s2) - 17.22) / 6.33,
    S_SIM_s2 = (SIM_s2 - 16.75) / 3.55
  )]

  data[, `:=`(
    pc1_s1 = 0.35 *
      S_TRAILSB_s1 +
      0.31 * S_LMC_s1 +
      0.37 * S_VRC_s1 +
      0.35 * S_SIM_s1,
    pc1_s2 = 0.35 *
      S_TRAILSB_s2 +
      0.31 * S_LMC_s2 +
      0.37 * S_VRC_s2 +
      0.35 * S_SIM_s2
  )]

  data[, .SD, .SDcols = !patterns("^S_")]
}
