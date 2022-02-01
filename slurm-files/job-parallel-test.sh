#!/bin/bash
#SBATCH --ntasks=50 
#SBATCH --cpus-per-task=1
#SBATCH --mem-per-cpu=5g
#SBATCH --job-name='parallel-states-test'
#SBATCH --output='/home/ena26/covrace/slurm-files/job-parallel-states-test-out.txt'
#SBATCH --open-mode=append
#SBATCH --mail-user=rmw@sidekicktutoring.biz
#SBATCH --mail-type=ALL


module purge
module load miniconda

source activate covrace_env_farnam

mpirun Rscript --save /home/ena26/covrace/model-parallel-states-test.R