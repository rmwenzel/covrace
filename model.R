sink(stdout(), type = 'message')
script.start <- proc.time()
cat("Beginning model script\n")

cat("Loading packages\n")
library(rgeos)
library(dplyr)
library(sf)
library(sp)
library(spdep)
library(CARBayes)

cat("Creating blockgroup demographic dataframe\n")
# read in blockgroup demographic and provider data
dem <- read.csv('data/us-dem-counts-jan-2021.csv', header=TRUE, colClasses=c("spatial_id"="character"))

# select columns needed for model
dem <- dem %>% dplyr::select(spatial_id, BlackNotHispPercent, HispanicPercent, NativePercent, Population, NumProviders)

# note - some blockgroups are missing population data, we're waiting for update
# from Simply Analytics - we drop values for now
dem <- na.omit(dem)

# scale independent variables but not offset
dem <- dem %>% mutate_at(c("BlackNotHispPercent", "HispanicPercent", "NativePercent"), ~(scale(.) %>% as.vector))

# command line arguments
args <- commandArgs(trailingOnly = TRUE)
# size of dataframe
size <- args[1]
if (size != 'all') {
    # select random blockgroup by index
    indices <- sample.int(nrow(dem), size)
    dem = dem %>% slice(c(0:size))
}
# value for rho model parameter - fixed numerical value in [0,1] saves run time, if NULL rho is estimated
rho_val <- as.numeric(args[2])
if (is.na(rho_val)) {
    rho_val = NULL
}

cat("Rho val = ", rho_val, "\n")

cat("Total blockgroups = ", nrow(dem), "\n")
cat("Number of blockgroups selected = ", size, "\n")


cat("Reading blockgroup spatial data shapefile\n")
# read in blockgroup geodata
geom.sf <- st_read('data/us-test-sites-nov-2020.shp')
# drop blockgroups with missing pop
geom.sf <- geom.sf[geom.sf$spatial_id %in% dem$spatial_id, ]

cat("Creating blockgroup spatial dataframe\n")
geom.sp <- as(geom.sf, "Spatial")




# create neighbors list
neighbors.start <- proc.time()
if (file.exists("data/neighbors.rds")) {
  cat("Loading saved neighbors list\n")
  neighbors <- readRDS("data/neighbors.rds")
  
  if (length(neighbors) != length(geom.sp)) {
    cat("Saved neighbors list incorrect size - rebuilding\n")
    neighbors <- poly2nb(geom.sp, queen = TRUE, snap = 0)
    saveRDS(neighbors, file="data/neighbors.rds")
    neighbors.end <- proc.time()
    cat("Time to build neighbors list: ", (neighbors.end - neighbors.start)[3], "\n")
  }
  
} else {
    cat("Building neighbors list\n")
    neighbors <- poly2nb(geom.sp, queen = TRUE, snap = 0)
    saveRDS(neighbors, file="data/neighbors.rds")
    neighbors.end <- Sys.time()
    cat("Time to build neighbors list: ", (neighbors.end - neighbors.start)[3], "\n")
}

# load/create neighbors matrix
neighbors_mat.start = proc.time()
if (file.exists("data/neighbors_mat.rds")) {
  cat("Loading saved neighbors matrix\n")
  neighbors_mat <- readRDS("data/neighbors_mat.rds")
  
  if (length(neighbors_mat) != length(neighbors)) {
    cat("Saved neighbors matrix incorrect size - rebuilding\n")
    neighbors_mat <- nb2mat(neighbors, zero.policy = TRUE, style = "B")
     # omit all zero rows (blockgroups with no neighbors)
    no_nb <- apply(neighbors_mat, 1, sum) == 0
    neighbors_mat <- neighbors_mat[!no_nb, !no_nb]
    saveRDS(neighbors, file="data/neighbors.rds")
    neighbors_mat.end <- proc.time()
    cat("Time to build neighbors matrix: ", (neighbors_mat.end - neighbors_mat.start)[3], "\n")
  }
  
} else {
    cat("Building neighbors matrix\n")
    neighbors_mat <- nb2mat(neighbors, zero.policy = TRUE, style = "B")
     # omit all zero rows (blockgroups with no neighbors)
    no_nb <- apply(neighbors_mat, 1, sum) == 0
    neighbors_mat <- neighbors_mat[!no_nb, !no_nb]
    saveRDS(neighbors_mat, file="data/neighbors_mat.rds")
    neighbors_mat.end <- proc.time()
    cat("Time to build neighbors matrix: ", (neighbors_mat.end - neighbors_mat.start)[3], "\n")
}

# fit model
model.start = proc.time()
if (file.exists("data/ns.rds")) {
  cat("Loading saved model\n")
  ns <- readRDS("data/ns.rds")
  
  if (length(ns$fitted.values) != length(neighbors_mat)) {
    cat("Saved model incorrect size - refitting\n")
    ns <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                  data = dem, family = "poisson", burnin = 100000, n.sample = 1100000, thin = 100, W = neighbors_mat, 
                  prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01),
                  rho = rho_val)
    saveRDS(neighbors, file="data/ns.rds")
    model.end <- proc.time()
    cat("Time to fit model: ", (model.end - model.start)[3], "\n")
  }
  
} else {
    ns <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                  data = dem, family = "poisson", burnin = 100000, n.sample = 1100000, thin = 100, W = neighbors_mat, 
                  prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01), rho = rho_val)
    model.end <- proc.time()
    cat("Time to fit model: ", (model.end - model.start)[3], "\n")
}

cat("Model Summary\n")
# print model summary
print(ns)

# save model
saveRDS(neighbors, file="data/ns.rds")
saveRDS(ns, file="data/ns.rds")

# print script total run time
script.end <-proc.time()
cat("Script complete - total elapsed time: ", (script.end - script.start)[3], "\n")
sink()