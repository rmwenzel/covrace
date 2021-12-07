#!/bin/bash
#SBATCH -p general
#SBATCH -t 02:00:00
#SBATCH --cpus-per-task=8 --mem=20g

module load R/4.0.3-foss-2020b  GDAL/3.2.1-foss-2020b
Rscript model.R 10000 0.5