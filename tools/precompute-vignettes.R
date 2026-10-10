# Pre-compute the vignettes: knit every vignettes/*.Rmd.orig into vignettes/*.Rmd
# with the results and figures embedded, so that building the package (and
# CRAN) only runs pandoc. Run from the package root after installing the
# development version (devtools::install()):
#
#   Rscript tools/precompute-vignettes.R
#
# Figures go to vignettes/figures/<vignette>-<chunk>-<n>.png.
stopifnot(file.exists("DESCRIPTION"))
owd <- setwd("vignettes"); on.exit(setwd(owd), add = TRUE)
for (src in sort(list.files(".", pattern = "\\.Rmd\\.orig$"))) {
  out <- sub("\\.orig$", "", src)
  name <- sub("\\.Rmd$", "", out)
  old <- list.files("figures", pattern = paste0("^", name, "-.*\\.png$"), full.names = TRUE)
  unlink(old)
  knitr::opts_chunk$set(fig.path = paste0("figures/", name, "-"))
  knitr::knit(src, output = out, envir = new.env(), quiet = TRUE)
  txt <- readLines(out)
  txt <- gsub("plot of chunk ([A-Za-z0-9_-]+)", "Figure of the chunk \\1", txt)   # default alt text of knitr
  end <- which(txt == "---")[2]
  txt <- append(txt, c("", paste0("<!-- Generated from ", src, " by tools/precompute-vignettes.R; edit the .orig file. -->")), after = end)
  writeLines(txt, out)
  cat(out, ":", length(list.files("figures", pattern = paste0("^", name, "-"))), "figures\n")
}
