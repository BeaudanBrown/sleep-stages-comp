library(data.table)
library(compositions)
library(Hmisc)
library(survival)
library(testthat)

project_root <- normalizePath(
  file.path(testthat::test_path(), "..", ".."),
  winslash = "/",
  mustWork = TRUE
)

r_files <- list.files(
  file.path(project_root, "R"),
  pattern = "\\.R$",
  full.names = TRUE
)
r_files <- setdiff(r_files, file.path(project_root, "R", "scratch.R"))
for (path in r_files) {
  source(path)
}
