# Build frame F4: the 1 km cells of the IBGE 2022 statistical grid in the
# Vale do Ipojuca microregion (Pernambuco agreste; Caruaru and 15 more
# municipalities), with real study variables per cell:
#
#   pop, households  IBGE, Censo Demográfico 2022, grade estatística 1 km
#                    (BR1KM_20251002), people and private households per cell
#   agri, pasture, mosaic, native, urban
#                    MapBiomas Collection 10, land cover and use 2024 (30 m):
#                    share of the cell in agriculture (classes 18-20, 35, 36,
#                    39-41, 46-48, 62), pasture (15), mosaic of uses (21),
#                    native vegetation (3-6, 11-13, 49, 50) and urban area (24)
#   elev             Copernicus DEM GLO-30, mean altitude (m)
#
# Usage:  Rscript experiments/data/build_f4_ipojuca.R
# Writes experiments/data/f4_ipojuca_cells.parquet (tracked, small). The
# national grid (416 MB zip) is cached in experiments/out/cache (ignored);
# MapBiomas and the DEM are read by window from their public cloud copies.
suppressPackageStartupMessages({
  library(sf)
  library(terra)
  library(dplyr)
  library(tibble)
  library(geobr)
})
sf_use_s2(FALSE)
cache <- "experiments/out/cache/ibge_grid"
dir.create(cache, recursive = TRUE, showWarnings = FALSE)
zip <- file.path(cache, "BR1KM_20251002.zip")
if (!file.exists(file.path(cache, "BR1KM.shp"))) {
  if (!file.exists(zip)) {
    download.file("https://geoftp.ibge.gov.br/recortes_para_fins_estatisticos/grade_estatistica/censo_2022/grade_1km/BR1KM_20251002.zip",
                  zip, mode = "wb")
  }
  unzip(zip, exdir = cache)
}

# region: microregion 26008 (IBGE code), boundaries of 2020 via geobr
region <- read_micro_region(code_micro = 26008, year = 2020, showProgress = FALSE) |>
  st_transform(4674)
bb <- st_bbox(region)
wkt <- st_as_text(st_as_sfc(bb))
grid <- st_read(file.path(cache, "BR1KM.shp"), wkt_filter = wkt, quiet = TRUE)
cent <- suppressWarnings(st_centroid(grid))
inside <- lengths(st_intersects(cent, region)) > 0
cells <- grid[inside, ] |>
  transmute(unit = paste0("c", nome_1KM), pop = as.numeric(TOTAL), households = as.numeric(TOTAL_DOM))
message(nrow(cells), " cells of 1 km2 in the region")

# MapBiomas Collection 10, 2024, read by window
mb <- rast("/vsicurl/https://storage.googleapis.com/mapbiomas-public/initiatives/brasil/collection_10/lulc/coverage/brazil_coverage_2024.tif")
win <- ext(bb[["xmin"]] - 0.01, bb[["xmax"]] + 0.01, bb[["ymin"]] - 0.01, bb[["ymax"]] + 0.01)
mbw <- crop(mb, win)
v <- vect(st_transform(cells, crs(mbw)))
ex <- terra::extract(mbw, v)
names(ex) <- c("id", "class")
agri <- c(18, 19, 20, 35, 36, 39, 40, 41, 46, 47, 48, 62)
native <- c(3, 4, 5, 6, 11, 12, 13, 49, 50)
shares <- ex |>
  group_by(id) |>
  summarise(
    agri = mean(class %in% agri), pasture = mean(class == 15), mosaic = mean(class == 21),
    native = mean(class %in% native), urban = mean(class == 24), .groups = "drop"
  )

# Copernicus DEM GLO-30, tiles covering the window
tiles <- expand.grid(lat = floor(bb[["ymin"]]):floor(bb[["ymax"]]), lon = floor(bb[["xmin"]]):floor(bb[["xmax"]]))
tile_url <- function(lat, lon) {
  ns <- if (lat < 0) sprintf("S%02d", -lat) else sprintf("N%02d", lat)
  ew <- if (lon < 0) sprintf("W%03d", -lon) else sprintf("E%03d", lon)
  name <- sprintf("Copernicus_DSM_COG_10_%s_00_%s_00_DEM", ns, ew)
  sprintf("/vsicurl/https://copernicus-dem-30m.s3.amazonaws.com/%s/%s.tif", name, name)
}
dem <- do.call(merge, lapply(seq_len(nrow(tiles)), \(i) crop(rast(tile_url(tiles$lat[i], tiles$lon[i])), win)))
elev <- terra::extract(dem, vect(st_transform(cells, crs(dem))), fun = mean, na.rm = TRUE)
names(elev) <- c("id", "elev")

xy <- st_coordinates(suppressWarnings(st_centroid(st_transform(cells, 4326))))
out <- cells |>
  st_drop_geometry() |>
  mutate(id = row_number(), lon = xy[, 1], lat = xy[, 2]) |>
  left_join(shares, by = "id") |>
  left_join(elev, by = "id") |>
  select(unit, lat, lon, pop, households, agri, pasture, mosaic, native, urban, elev)
arrow::write_parquet(out, "experiments/data/f4_ipojuca_cells.parquet")
print(summary(out[, -1]))
message("wrote experiments/data/f4_ipojuca_cells.parquet")
