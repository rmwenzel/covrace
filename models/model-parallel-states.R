sink(stdout(), type = 'message')
script.start <- proc.time()
cat("Beginning model script\n")

cat("Loading packages\n")
library(sp)
library(rgeos)
library(dplyr)
library(tidyr)
library(sf)
library(spdep)
library(CARBayes)
library(doMPI)

### Set up parallelization
##
#

# create MPI cluster objects for states
cl <- startMPIcluster()

# register cluster with foreach - sets doMPI as parallel backend
registerDoMPI(cl)

### Demographic data
##
#

cat("Creating blockgroup demographic dataframe\n")
# read in blockgroup demographic and provider data
dem <- read.csv('data/us-dem-counts-jan-2021-with-neighbors.csv', header=TRUE, colClasses=c("spatial_id"="character"))

# select columns needed for model
dem <- dem %>% dplyr::select(spatial_id, NativePercent, BlackNotHispPercent, HispanicPercent, Population, NumProviders)

# drop blockgroups are missing population datawrite
dem <- na.omit(dem)

# scale independent variables but not offset
dem <- dem %>% mutate_at(c("NativePercent", "BlackNotHispPercent", "HispanicPercent"), ~(scale(.) %>% as.vector))

### Geographic Data
##
#

cat("Total blockgroups = ", nrow(dem), "\n")

cat("Creating blockgroup spatial dataframe\n")
geom.start <- Sys.time()

# read blockgroup geodata into sf dataframe
geom.sf <- st_read('data/us-test-sites-nov-2020-with-neighbors.shp')

# filter based on demographic dataframe
geom.sf <- geom.sf[geom.sf$spatial_id %in% dem$spatial_id, ]

### Parallel loop over states
##
#

# list of state 2 letter abbreviations
states <- unique(geom.sf$state)

# begin loop
combined_results_df <- foreach(this_state=states, .packages=(.packages()), .combine="rbind") %dopar% {

    cat("Beginning analysis on US state", this_state)
    geom.sf <- geom.sf %>% filter(state == this_state)
    dem <- dem %>% filter(spatial_id %in% geom.sf$spatial_id)
    
    # convert to spatial polygons dataframe
    geom.sp <- as(geom.sf, "Spatial")
    
    # drop blockgroups with missing pop
    geom.sp <- geom.sp[geom.sp$spatial_id %in% dem$spatial_id, ]
    geom.end <- Sys.time()
    cat("Time to build spatial dataframe: ", (geom.end - geom.start)[3], "\n")
    
    ### Geographic Areas Neighbors List
    ##
    #
    
    # create neighbors list
    neighbors_list.start <- Sys.time()
    file_path <- paste("data/neighbors_list_", this_state, ".rds", sep='')
    if (file.exists(file_path)) {
      cat("Loading saved neighbors list\n")
      neighbors_list <- readRDS(file_path)
      
      if (length(neighbors_list) != length(geom.sp)) {
        cat("Saved neighbors list incorrect size - rebuilding\n")
        neighbors_list <- poly2nb(geom.sp, row.names = geom.sp$spatial_id, queen = TRUE, snap = 0)
        saveRDS(neighbors_list, file=file_path)
        neighbors_list.end <- Sys.time()
        cat("Time to build neighbors list: ", (neighbors_list.end - neighbors_list.start)[3], "\n")
      }
      
    } else {
      cat("Building neighbors list\n")
      neighbors_list <- poly2nb(geom.sp, queen = TRUE, snap = 0)
      saveRDS(neighbors_list, file=file_path)
      neighbors_list.end <- Sys.time()
      cat("Time to build neighbors list: ", (neighbors_list.end - neighbors_list.start)[3], "\n")
    }
    
    ### Geographic Areas Neighbor Matrix
    ##
    #
    
    # create neighbors matrix
    neighbors_matrix.start = Sys.time()
    file_path = paste("data/neighbors_matrix_", this_state, ".rds", sep='')
    if (file.exists(file_path)) {
      cat("Loading saved neighbors matrix\n")
      neighbors_matrix <- readRDS(file_path)
      
      if (length(neighbors_matrix) != length(neighbors_list)) {
        cat("Saved neighbors matrix incorrect size - rebuilding\n")
        neighbors_matrix <- nb2mat(neighbors_list, zero.policy = TRUE, style = "B")
        saveRDS(neighbors_matrix, file="../data/neighbors_matrix.rds")
        neighbors_matrix.end <- Sys.time()
        cat("Time to build neighbors matrix: ", (neighbors_matrix.end - neighbors_matrix.start)[3], "\n")
      }
      
    } else {
      cat("Building neighbors matrix\n")
      neighbors_matrix <- nb2mat(neighbors_list, zero.policy = TRUE, style = "B")
      saveRDS(neighbors_matrix, file=file_path)
      neighbors_matrix.end <- Sys.time()
      cat("Time to build neighbors matrix: ", (neighbors_matrix.end - neighbors_matrix.start)[3], "\n")
    }
    
    ### Model Fitting
    ##
    #
    
    model.start = Sys.time()
    file_path = paste("data/model_", this_state, ".rds", sep='')
    if (file.exists(file_path)) {
      print("Loading saved model\n")
      model <- readRDS(file_path)
      
      if (length(model$fitted.values) != length(neighbors_matrix)) {
        print("Saved model incorrect size - refitting\n")
        model <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                             data = dem, family = "poisson", burnin = 100000, n.sample = 1100000, thin = 100, W = neighbors_matrix, 
                             prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01))
        saveRDS(model, file=file_path)
        model.end <- Sys.time()
        cat("Time to fit model: ", (model.end - model.start)[3], "\n")
      }
      
    } else {
      model <- S.CARleroux(formula = NumProviders ~ BlackNotHispPercent + HispanicPercent + NativePercent + offset(log(Population + 1)), 
                           data = dem, family = "poisson", burnin = 100000, n.sample = 1100000, thin = 100, W = neighbors_matrix, 
                           prior.mean.beta = rep(0, times = 4), prior.var.beta = rep(100^2, times = 4), prior.tau2 = c(0.01, 0.01))
      saveRDS(model, file=file_path)
      model.end <- Sys.time()
      cat("Time to fit model: ", (model.end - model.start)[3], "\n")
    }
    
    print("Model Summary\n")
    # print model summary
    print(model)
    
    # print script total run time
    script.end <- Sys.time()
    cat("Script complete - total elapsed time: ", (script.end - script.start)[3], "\n")
    
    ### Results
    ##
    #
    
    print("Model Summary\n")
    # print model summary
    print(model)
    
    # print script total run time
    script.end <- Sys.time()
    cat("Script complete - total elapsed time: ", (script.end - script.start)[3], "\n")
    
    # dump stdout to output file
    sink()
    
    # dataframe of model results
    state_results_df <- as.data.frame(model$summary.results)
    state_results_df$state <- this_state
    state_results_df <- cbind(param = rownames(state_results_df), state_results_df)
    rownames(state_results_df) <- NULL
    state_results_df
}

# save results to disk
write.csv(combined_results_df, file="model/model-results/parallel-states.csv")


### Close down
##
#

# close cluster
closeCluster(cl)

# exit
mpi.quit()
