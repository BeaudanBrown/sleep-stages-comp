create_dataset <- function(
  framingham_dem_file,
  framingham_dem_surv_file,
  framingham_brain1_file,
  framingham_brain2_file,
  framingham_cog_file,
  shhs_covar_file,
  shhs_psg1_file,
  shhs_psg2_file,
  shhs_link_file
) {
  ### FOS data
  # Read raw dementia outcomes data
  dem <- load_framingham_dem(framingham_dem_file)
  # dem survival dataset
  dem_surv <- load_framingham_dem_surv(framingham_dem_surv_file)
  # merge dem outcomes
  dem <- merge(dem, dem_surv, by = c("PID", "IDTYPE"), all = TRUE)

  # Brain outcomes
  brain1 <- load_framingham_brain1(framingham_brain1_file)
  # more brain variables
  brain2 <- load_framingham_brain2(framingham_brain2_file)
  # merge brain outcomes
  brain <- merge(
    brain1,
    brain2,
    by = c("IDTYPE", "PID"),
    all = TRUE
  )

  # cognition variables
  cog <- load_framingham_cog(framingham_cog_file)

  ## Merge FOS data
  # Merge the brain and dem datasets
  fos <- merge(brain, dem, by = c("IDTYPE", "PID"), all = TRUE)
  fos <- merge(cog, fos, by = c("IDTYPE", "PID"), all = TRUE)

  ## SHHS variables

  # Covars
  covs <- load_shhs_covars(shhs_covar_file)
  # PSG1
  psg1 <- load_shhs_psg1(shhs_psg1_file)
  # PSG2
  psg2 <- load_shhs_psg2(shhs_psg2_file)

  # combine BL and FU psg data
  psg <- merge(psg1, psg2, by = c("pptidr", "pptidu"), all = TRUE)
  # combine PSG and covariate data
  psg <- merge(psg, covs, by = c("pptidr", "pptidu"), all = TRUE)

  # link SHHS data with Framingham PID
  link <- load_shhs_link(shhs_link_file)

  shhs <- merge(link, psg, all.x = TRUE)

  ## Adjust s2 date to be relative to recruitment
  shhs[, stdatep_s2 := stdatep_s2 + days_studyv1]

  ## join shhs and fos datasets

  dt_raw <- merge(shhs, fos, by = c("IDTYPE", "PID"), all.x = TRUE)
  dt_raw <- dt_raw[!is.na(stdatep_s2)]

  ## Adjust cog dates to be relative to recruitment
  mci_cols <- grep("^impairment_date_", names(dt_raw), value = TRUE)
  mci_cols_adjusted <- paste0(mci_cols, "_adjusted")

  cog_cols <- grep("^COG_DATE_", names(dt_raw), value = TRUE)
  cog_cols_adjusted <- paste0(cog_cols, "_adjusted")

  # Ensure all dates are relative to PSG2
  dt_raw <- dt_raw[,
    (cog_cols_adjusted) := lapply(.SD, function(x) x - dt_raw$stdatep_s2),
    .SDcols = cog_cols
  ]
  dt_raw <- dt_raw[,
    (mci_cols_adjusted) := lapply(.SD, function(x) x - dt_raw$stdatep_s2),
    .SDcols = mci_cols
  ]
  dt_raw <- dt_raw[, DEM_SURVDATE := DEM_SURVDATE - dt_raw$stdatep_s2]

  ## Ensure that only participants with complete PSG data are included
  dt_raw <- dt_raw[
    complete.cases(
      timest1,
      timest2,
      timest34,
      timerem,
      timest1_s2,
      timest2_s2,
      timest34_s2,
      timerem_s2
    ),
  ]
  setnames(
    dt_raw,
    c(
      "timest1",
      "timest2",
      "timest34",
      "timerem",
      "timest1_s2",
      "timest2_s2",
      "timest34_s2",
      "timerem_s2"
    ),
    c(
      "n1",
      "n2",
      "n3",
      "rem",
      "n1_s2",
      "n2_s2",
      "n3_s2",
      "rem_s2"
    )
  )
  dt_raw
}

load_framingham_dem <- function(framingham_dem_file) {
  dem <- fread(framingham_dem_file)

  # extract relevant columns from raw data
  vars <- Hmisc::Cs(
    idtype,
    review_date,
    normal_date,
    impairment_date,
    mild_date,
    moderate_date,
    severe_date,
    eddd,
    PID
  )
  dem <- dem[,
    ..vars
  ]

  # expand to multiple columns for those with several reviews
  dem[order(review_date), num := seq_len(.N), by = c("idtype", "PID")]

  dem <- dcast(
    dem,
    idtype + PID ~ num,
    value.var = setdiff(names(dem), c("idtype", "PID", "num"))
  )

  setnames(dem, "idtype", "IDTYPE")
  dem
}

load_framingham_dem_surv <- function(framingham_dem_surv_file) {
  dem_surv <- fread(framingham_dem_surv_file)

  vars <- Cs(
    idtype,
    DEM_STATUS,
    DEM_SURVDATE,
    PID
  )
  dem_surv <- dem_surv[, ..vars]
  setnames(dem_surv, "idtype", "IDTYPE")
  dem_surv
}

load_framingham_brain1 <- function(framingham_brain1_file) {
  brain1 <- fread(framingham_brain1_file)

  vars <- Cs(
    PID,
    IDTYPE,
    FLAIR_wmh,
    DSE_wmh
  )
  brain1 <- brain1[, ..vars]

  brain1[, mri_assessment := seq_len(.N), by = c("PID", "IDTYPE")]

  # pivot to wide
  brain1 <- dcast(
    brain1,
    IDTYPE + PID ~ mri_assessment,
    value.var = setdiff(names(brain1), c("IDTYPE", "PID", "mri_assessment"))
  )
  brain1
}

load_framingham_brain2 <- function(framingham_brain2_file) {
  brain2 <- fread(framingham_brain2_file)

  vars <- Hmisc::Cs(
    PID,
    IDTYPE,
    Cerebrum_tcv,
    Cerebrum_tcb,
    Cerebrum_gray,
    Cerebrum_white,
    Cerebrum_tcc,
    Left_lateralvent,
    Right_lateralvent,
    Lateralvent,
    Thirdvent,
    Left_hippo,
    Right_hippo,
    Hippo,
    Total_csf,
    Total_gray,
    Total_white,
    Total_brain,
    Status,
    mri_date
  )

  brain2 <- brain2[, ..vars]

  brain2[, mri_assessment := seq_len(.N), by = c("PID", "IDTYPE")]

  brain2 <- dcast(
    brain2,
    formula = PID + IDTYPE ~ mri_assessment,
    value.var = setdiff(names(brain2), c("PID", "IDTYPE", "mri_assessment"))
  )
  brain2
}

load_framingham_cog <- function(framingham_cog_file) {
  cog <- fread(framingham_cog_file)

  vars <- Hmisc::Cs(
    PID,
    IDTYPE,
    TRAILSA,
    TRAILSB,
    LMI,
    LMD,
    LMR,
    VRI,
    VRD,
    VRR,
    PASD,
    HVOT,
    DSF,
    DSB,
    BNT36,
    BNT36_SEMANTIC,
    BNT36_PHONEMIC,
    SIM,
    NP_DATE
  )
  cog <- cog[, ..vars]
  cog <- setnames(cog, "NP_DATE", "COG_DATE")
  cog[, cog_assessment := seq_len(.N), by = c("PID", "IDTYPE")]
  cog <- dcast(
    cog,
    IDTYPE + PID ~ cog_assessment,
    value.var = setdiff(names(cog), c("IDTYPE", "PID", "cog_assessment"))
  )
}

load_shhs_covars <- function(shhs_covar_file) {
  covs <- fread(shhs_covar_file)
  covs[, grep("age|gender|educ|id", names(covs)), with = FALSE]
}

load_shhs_psg1 <- function(shhs_psg1_file) {
  psg1 <- fread(shhs_psg1_file)

  vars <- Cs(
    pptidr,
    pptidu,
    slp_time,
    WASO,
    timest1,
    timest2,
    timest34,
    timerem,
    oahi
  )

  psg1 <- psg1[, ..vars]

  setnames(psg1, c("WASO"), c("waso"))
  psg1
}

load_shhs_psg2 <- function(shhs_psg2_file) {
  psg2 <- fread(shhs_psg2_file)

  vars <- Cs(
    pptidr,
    pptidu,
    stdatep,
    slp_time,
    waso,
    timest1,
    timest2,
    timest34,
    timerem,
    oahi
  )

  psg2 <- psg2[, ..vars]

  setnames(psg2, names(psg2)[-c(1, 2)], paste0(names(psg2)[-c(1, 2)], "_s2"))
  psg2
}

load_shhs_link <- function(shhs_link_file) {
  link <- fread(shhs_link_file)
  # FIXME: Is this correct?
  link <- link[permiss == 1, ]

  vars <- Cs(
    IDTYPE,
    pid,
    days_studyv1,
    pptidr,
    pptidu
  )

  link <- link[!is.na(pid), ]
  link <- link[, ..vars]
  setnames(link, "pid", "PID")
  link
}
