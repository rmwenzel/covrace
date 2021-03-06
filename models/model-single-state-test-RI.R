sink(stdout(), type = 'message')
script.start <- proc.time()
cat("Beginning model script", "\n")


cat("Loading packages\n")
library(sp)
library(rgeos)
library(dplyr)
library(tidyr)
library(sf)
library(spdep)
library(CARBayes)



cat("Creating blockgroup demographic dataframe\n")
# read in blockgroup demographic and provider data
dem <- read.csv('../data/us-dem-counts-jan-2021.csv', header=TRUE, colClasses=c("spatial_id"="character"))

# select columns needed for model
dem <- dem %>% dplyr::select(spatial_id, NativePercent, BlackNotHispPercent, HispanicPercent, Population, NumProviders)

# drop blockgroups are missing population datawrite
dem <- na.omit(dem)

# scale independent variables but not offset
dem <- dem %>% mutate_at(c("NativePercent", "BlackNotHispPercent", "HispanicPercent"), ~(scale(.) %>% as.vector))



cat("Creating blockgroup spatial dataframe\n")
geom.start <- Sys.time()

# read blockgroup geodata into sf dataframe
geom.sf <- st_read('../data/us-test-sites-nov-2020.shp')

# split name in separate columns
geom.sf <- geom.sf %>% separate(name, c("blockgroup", "county", "state"), sep = ",") %>% mutate(across(c("blockgroup", "county", "state"), trimws))

# filter based on demographic dataframe
geom.sf <- geom.sf[geom.sf$spatial_id %in% dem$spatial_id, ]

# subset small state for testing
this_state = 'RI'
cat("Testing on state", this_state)
geom.sf <- geom.sf %>% filter(state == this_state)
dem <- dem %>% filter(spatial_id %in% geom.sf$spatial_id)

# convert to spatial polygons dataframe
geom.sp <- as(geom.sf, "Spatial")

# drop blockgroups with missing pop
geom.sp <- geom.sp[geom.sp$spatial_id %in% dem$spatial_id, ]
geom.end <- Sys.time()
cat("Time to build spatial dataframe: ", geom.end - geom.start, "\n")



# create neighbors list
neighbors_list.start <- Sys.time()
file_path <- paste("../data/neighbors_list_", this_state, ".rds", sep='')
if (file.exists(file_path)) {
  cat("Loading saved neighbors list\n")
  neighbors_list <- readRDS(file_path)
  
  if (length(neighbors_list) != length(geom.sp)) {
    cat("Saved neighbors list incorrect size - rebuilding\n")
    neighbors_list <- poly2nb(geom.sp, row.names = geom.sp$spatial_id, queen = TRUE, snap = 0)
    saveRDS(neighbors_list, file=file_path)
    neighbors_list.end <- Sys.time()
    cat("Time to build neighbors list: ", neighbors_list.end - neighbors_list.start, "\n")
  }
  
} else {
  cat("Building neighbors list\n")
  neighbors_list <- poly2nb(geom.sp, queen = TRUE, snap = 0)
  saveRDS(neighbors_list, file=file_path)
  neighbors_list.end <- Sys.time()
  cat("Time to build neighbors list: ", neighbors_list.end - neighbors_list.start, "\n")
}



# create neighbors matrix
neighbors_matrix.start = Sys.time()
file_path = paste("../data/neighbors_matrix_", this_state, ".rds", sep='')
if (file.exists(file_path)) {
  cat("Loading saved neighbors matrix\n")
  neighbors_matrix <- readRDS(file_path)
  
  if (length(neighbors_matrix) != length(neighbors_list)) {
    cat("Saved neighbors matrix incorrect size - rebuilding\n")
    neighbors_matrix <- nb2mat(neighbors_list, zero.policy = TRUE, style = "B")
    saveRDS(neighbors_matrix, file="../data/neighbors_matrix.rds")
    neighbors_matrix.end <- Sys.time()
    cat("Time to build neighbors matrix: ", neighbors_matrix.end - neighbors_matrix.start, "\n")
  }
  
} else {
  cat("Building neighbors matrix\n")
  neighbors_matrix <- nb2mat(neighbors_list, zero.policy = TRUE, style = "B")
  saveRDS(neighbors_matrix, file=file_path)
  neighbors_matrix.end <- Sys.time()
  cat("Time to build neighbors matrix: ", neighbors_matrix.end - neighbors_matrix.start, "\n")
}



# get and output areas with no neighbors
no_neighbors_indices <- which(rowSums(neighbors_matrix) == 0, arr.ind = TRUE)
cat("For state", this_state, "these blockgroups have no neighbors: ")
for (i in no_neighbors_indices){
  cat(geom.sf[i,]$name)
}

# drop areas with no neighbors
dem <- dem[-no_neighbors_indices,]
neighbors_matrix <- neighbors_matrix[-no_neighbors_indices,-no_neighbors_indices]

# run model
model.start = Sys.time()
file_path = paste("../data/model_", this_state, ".rds", sep='')
if (file.exists(file_path)) {
  print("Loading saved model\n")
  model <- readRDS(file_path)
  
  if (length(model$fitted.values) != length(neighbors_matrix)) {
    print("Saved model incorrect size - refitting\n")
    model <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                         data = dem, family = "poisson", burnin = 10, n.sample = 20, thin = 1, W = neighbors_matrix, 
                         prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01))
    saveRDS(model, file=file_path)
    model.end <- Sys.time()
    cat("Time to fit model: ", model.end - model.start, "\n")
  }
  
} else {
  model <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                       data = dem, family = "poisson", burnin = 10, n.sample = 20, thin = 1, W = neighbors_matrix, 
                       prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01))
  saveRDS(model, file=file_path)
  model.end <- Sys.time()
  cat("Time to fit model: ", model.end - model.start, "\n")
}

print("Model Summary\n")
# print model summary
print(model)

# print script total run time
script.end <- Sys.time()
cat("Script complete - total elapsed time: ", script.end - script.start, "\n")
