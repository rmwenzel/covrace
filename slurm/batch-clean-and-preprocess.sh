#!/bin/bash
#SBATCH --ntasks=50 
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=5g
#SBATCH --job-name='parallel-clean-and-preprocess'
#SBATCH --output='/home/ena26/covrace/slurm/job-outputs/parallel-clean-and-preprocess-job%j-out.txt'
#SBATCH --open-mode=append
#SBATCH --mail-user=rmw@sidekicktutoring.biz
#SBATCH --mail-type=ALL


module purge
module load miniconda

source activate covrace_env_farnam

mpirun Rscript --save data/clean-and-preprocess.R