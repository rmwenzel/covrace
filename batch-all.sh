#!/bin/bash
#SBATCH -p bigmem
#SBATCH -t 3-00:00:00
#SBATCH -J batch-all-fixed-rho
#SBATCH -o "batch-all-fixed-rho.out"
#SBATCH --cpus-per-task=16 
#SBATCH --mem=1505g

module load R/4.0.3-foss-2020b  GDAL/3.2.1-foss-2020b
Rscript model.R  all 0.5