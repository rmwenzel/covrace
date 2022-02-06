sink(stdout(), type = 'message')
script.start <- proc.time()
cat("Beginning cleaning and processing script\n")

cat("Loading packages\n")
library(sp)
library(rgeos)
library(dplyr)
library(tidyr)
library(sf)
library(spdep)
library(doMPI)


### Clean and transform demographic data
##
#


# read in blockgroup demographic and provider data, zero population blockgroups ommitted
dem <- read.csv('data/dem/us-dem-counts-jan-2021.csv', header=TRUE, colClasses=c("spatial_id"="character"))

# select columns needed for model
dem <- dem %>% dplyr::select(spatial_id, name.x, NativePercent, BlackNotHispPercent, HispanicPercent, Population, NumProviders)

# omit rows with missing values (all are in Population column)
dem <- na.omit(dem)

# omit rows with zero population
dem <- dem %>% filter(Population != 0)

# split name into separate columns
dem <- dem %>% separate(name.x, c("blockgroup", "county", "state"), sep = ",") %>% mutate(across(c("blockgroup", "county", "state"), trimws))

# scale independent variables but not offset
dem <- dem %>% mutate_at(c("NativePercent", "BlackNotHispPercent", "HispanicPercent"), ~(scale(.) %>% as.vector))

# save to disk as rds object
saveRDS(dem, file="data/dem/us-dem-counts-jan-2021-clean.rds")


### Clean and transform geographic data
##
#


# read blockgroup geodata into sf dataframe
geom.sf <- st_read('data/geom/us-test-sites-nov-2020.shp')

# filter based on demographic dataframe
geom.sf <- geom.sf[geom.sf$spatial_id %in% dem$spatial_id, ]

# split name into separate columns
geom.sf <- geom.sf %>% separate(name, c("blockgroup", "county", "state"), sep = ",") %>% mutate(across(c("blockgroup", "county", "state"), trimws))

# convert to spatial polygons dataframe
geom.sp <- as(geom.sf, "Spatial")

# save as RDS for fast loading and saving
saveRDS(geom.sp, file="data/geom/us-test-sites-nov-2020-clean.rds")


### Split data in equal size groups to distribute across cores
##
#


# get sorted list of state blockgroup counts
state_bg_counts <- dem %>% count(state) %>% arrange(n)

### code for local machine with limited cores

  # # split into roughly equal groups by count, one less than avilable cores
  # num_cores <- parallel::detectCores()
  # num_groups <- num_cores - 2
  # state_groups <- vector("list", num_groups)

  # for (i in c(1:num_groups)) {
  #   # get evenly spaced indices
  #   indices <- seq(from=i, to=length(state_bg_counts$n), by=num_groups)
  #   # subset states with these indices
  #   group <- state_bg_counts %>% slice(indices) %>% pull(state)
  #   # add to group list
  #   state_groups[[i]] <- group

### code for farnam, sufficient cores for each state

  
### Parallelizing across groups, split data by state for later parallel model fitting
##
#
  
  
# create MPI cluster objects for states
cl <- startMPIcluster()

# register cluster with foreach - sets doMPI as parallel backend
registerDoMPI(cl)

# list of state 2 letter abbreviations
states <- unique(geom.sf$state)

# parallelize across states
foreach(this_group=states, .packages=(.packages()), .inorder=FALSE, .verbose=FALSE,
        .errorhandling="pass") %dopar% {
          
  # filter demographic data
  this_state_dem <- dem %>% filter(state == this_state)
  # filter geomgraphic dataframe
  this_state_geom.sf <- geom.sf %>% filter(state == this_state)
  # convert to spatial polygons dataframe
  this_state_geom.sp <- as(this_state_geom.sf, "Spatial")
  # save as RDS for fast loading and saving
  saveRDS(this_state_dem, file=paste("data/dem/", this_state, "-dem-counts-jan-2021-clean.rds", sep=""))
  saveRDS(this_state_geom.sp, file=paste("data/geom/", this_state, "-test-sites-nov-2020-clean.rds", sep=""))
}
