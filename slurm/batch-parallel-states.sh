#!/bin/bash
#SBATCH --ntasks=50 
#SBATCH --cpus-per-task=4
#SBATCH --mem-per-cpu=5g
#SBATCH --job-name='parallel-states'
#SBATCH --output='/home/ena26/covrace/slurm-files/parallel-states-job%j-out.txt'
#SBATCH --open-mode=append
#SBATCH --mail-user=rmw@sidekicktutoring.biz
#SBATCH --mail-type=ALL


module purge
module load miniconda

source activate covrace_env_farnam

mpirun Rscript --save ../model/model-parallel-states.R