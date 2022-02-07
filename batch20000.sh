#!/bin/bash
#SBATCH -p general
#SBATCH -t 4-00:00:00
#SBATCH --cpus-per-task=8 --mem=50g

module load R/4.0.3-foss-2020b  GDAL/3.2.1-foss-2020b
Rscript model.R 20000 0.5