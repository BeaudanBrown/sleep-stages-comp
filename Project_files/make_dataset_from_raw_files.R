## Libraries
library(data.table)
library(tidyverse)
library(here)
library(Hmisc)
library(dotenv)
load_dot_env()

### FOS data

# dementia outcomes

## Read dementia outcomes from FOS data

# Read raw dementia outcomes data
framingham_dir <- Sys.getenv("FRAMINGHAM_DIR")
dem <- fread(here(framingham_dir, "vr_demrev_2018_a_1254d_v1.csv"))

# extract relevant columns from raw data
dem <- dem[
  ,
  list(
    idtype, review_date, normal_date, impairment_date, mild_date,
    moderate_date, severe_date, eddd, PID
  )
]

# expand to multiple columns for those with several reviews

dem[order(review_date), num := 1:.N, by = c("idtype", "PID")]

dem <- dcast(
  dem,
  idtype + PID ~ num,
  value.var = setdiff(names(dem), c("idtype", "PID", "num"))
)

# dem survival dataset

dem2 <- fread(here(framingham_dir, "vr_demsurv_2018_a_1281d.csv"))

dem <- merge(dem, dem2, by = c("PID", "idtype"), all = TRUE)

dem <- setnames(dem, "idtype", "IDTYPE")


# Brain outcomes

brain1 <- fread(here(framingham_dir, "t_mrbrwmh_2019_a_1328d.csv"))

brain1 <- brain1[, list(PID, IDTYPE, FLAIR_wmh, DSE_wmh)]

brain1[, mri_assessment := 1:.N, by = c("PID", "IDTYPE")]

# pivot to wide

brain1 <- dcast(
  brain1,
  IDTYPE + PID ~ mri_assessment,
  value.var = setdiff(names(brain1), c("IDTYPE", "PID", "mri_assessment"))
)

# more brain variables

brain2 <- fread(here(framingham_dir, "t_mrbrnm3_2019_a_1906d.csv"))

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

brain2[, mri_assessment := 1:.N, by = c("PID", "IDTYPE")]

brain2 <- dcast(
  brain2,
  formula = PID + IDTYPE ~ mri_assessment,
  value.var = setdiff(names(brain2), c("PID", "IDTYPE", "mri_assessment"))
)

# merge brain outcomes

brain <- merge(
  brain1,
  brain2,
  by = c("IDTYPE", "PID"),
  all = TRUE
)

# cognition variables

cog <- fread(here(framingham_dir, "vr_np_2018_a_1185d.csv"))
vars <- Cs(
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
cog[, cog_assessment := 1:.N, by = c("PID", "IDTYPE")]
cog <- dcast(
  cog,
  IDTYPE + PID ~ cog_assessment,
  value.var = setdiff(names(cog), c("IDTYPE", "PID", "cog_assessment"))
)

## Merge FOS data

# Merge the brain and dem datasets
fos <- merge(brain, dem, by = c("IDTYPE", "PID"), all = TRUE)
fos <- merge(cog, fos, by = c("IDTYPE", "PID"), all = TRUE)

### SHHS variables

## date of PSG and link with FOS

shhs_dir <- Sys.getenv("SHHS_DIR")

## SHHS variables

# age, sex, and education

covs <- fread(here(shhs_dir, "SHHS_1", "shhs1final_13jun2014_5839.csv"))

ase <- covs[, grep("age|gender|educ|id", names(covs)), with = FALSE]

# PSG1

psg1 <- fread(here(shhs_dir, "SHHS_1", "shhs1final_PSG_15jan2014_5839.csv"))

vars <- Cs(
  pptidr, pptidu, slp_time, WASO, timest1,
  timest2, timest34, timerem, oahi
)

psg1 <- psg1[, ..vars]

# PSG2

psg2 <- fread(here(shhs_dir, "SHHS_2", "shhs2final_PSG_15jan2014_4103.csv"))

vars <- Cs(
  pptidr, pptidu, stdatep, slp_time, waso, timest1,
  timest2, timest34, timerem, oahi
)

psg2 <- psg2[, ..vars]

setnames(psg2, names(psg2)[-c(1, 2)], paste0(names(psg2)[-c(1, 2)], "_s2"))

# combine BL and FU psg data

psg <- merge(psg1, psg2, by = c("pptidr", "pptidu"), all = TRUE)

# combine PSG and covariate data

psg <- merge(psg, ase, by = c("pptidr", "pptidu"), all = TRUE)

# link SHHS data with Framingham PID

link <- fread(here(shhs_dir, "ParentStudy_SHHSLink", "parent_shhs_public_2016.csv"))
link <- link[!is.na(pid), ]

setnames(link, "pid", "PID")

shhs <- merge(link, psg, all.x = TRUE)
## Adjust s2 date to be relative to recruitment
shhs[, stdatep_s2 := stdatep_s2 + days_studyv1]

## join shhs and fos datasets

df <- merge(shhs, fos, by = c("IDTYPE", "PID"), all.x = TRUE)
df <- df[!is.na(stdatep_s2)]
