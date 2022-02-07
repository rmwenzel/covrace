#!/bin/bash
#SBATCH -p bigmem
#SBATCH -t 3-00:00:00
#SBATCH --cpus-per-task=16 --mem=1000g

module load R/4.0.3-foss-2020b  GDAL/3.2.1-foss-2020b
Rscript model.R 100000 0.5