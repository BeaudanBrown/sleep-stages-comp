data_targets <- list(
  tar_target(
    framingham_dem_file,
    file.path(framingham_dir, "vr_demrev_2018_a_1254d_v1.csv"),
    format = "file"
  ),
  tar_target(
    framingham_dem_surv_file,
    file.path(framingham_dir, "vr_demsurv_2018_a_1281d.csv"),
    format = "file"
  ),
  tar_target(
    framingham_brain1_file,
    file.path(framingham_dir, "t_mrbrwmh_2019_a_1328d.csv"),
    format = "file"
  ),
  tar_target(
    framingham_brain2_file,
    file.path(framingham_dir, "t_mrbrnm3_2019_a_1906d.csv"),
    format = "file"
  ),
  tar_target(
    framingham_cog_file,
    file.path(framingham_dir, "vr_np_2018_a_1185d.csv"),
    format = "file"
  ),

  tar_target(
    shhs_covar_file,
    file.path(shhs_dir, "SHHS_1/shhs1final_13jun2014_5839.csv"),
    format = "file"
  ),
  tar_target(
    shhs_psg1_file,
    file.path(shhs_dir, "SHHS_1/shhs1final_PSG_15jan2014_5839.csv"),
    format = "file"
  ),
  tar_target(
    shhs_psg2_file,
    file.path(shhs_dir, "SHHS_2/shhs2final_PSG_15jan2014_4103.csv"),
    format = "file"
  ),
  tar_target(
    shhs_link_file,
    file.path(shhs_dir, "ParentStudy_SHHSLink/parent_shhs_public_2016.csv"),
    format = "file"
  ),

  tar_target(
    dt_raw,
    create_dataset(
      framingham_dem_file,
      framingham_dem_surv_file,
      framingham_brain1_file,
      framingham_brain2_file,
      framingham_cog_file,
      shhs_covar_file,
      shhs_psg1_file,
      shhs_psg2_file,
      shhs_link_file
    )
  ),

  tar_target(dt, prepare_dataset(dt_raw)),

  tar_target(comp_limits, make_comp_limits(dt))
)
