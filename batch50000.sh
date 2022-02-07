#!/bin/bash
#SBATCH -p bigmem
#SBATCH -t 3-00:00:00
#SBATCH --cpus-per-task=8 --mem=500g

module load R/4.0.3-foss-2020b  GDAL/3.2.1-foss-2020b
Rscript model.R 50000 0.5