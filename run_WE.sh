#!/bin/bash

#SBATCH --job-name=gamd_run             # Job name
#SBATCH --account=ahnlab               # Account name
#SBATCH --partition=gpu-ahn            # Partition name
#SBATCH --nodes=1                      # Number of nodes
#SBATCH --ntasks-per-node=1            # Number of tasks per node
#SBATCH --cpus-per-task=64             # Number of CPU cores per task
#SBATCH --gres=gpu:1                   # Request 1 GPU
#SBATCH --time=120:00:00               # Time limit hrs:min:sec
#SBATCH --mail-type=BEGIN,END          # Email notifications
#SBATCH --mail-user=anuthyagatur@ucdavis.edu # Email address

set -x
cd $SLURM_SUBMIT_DIR
source ~/.bashrc

module load conda3/4.X
module load cuda/11.8.0
module load amber/22
source activate openmm_env

export PATH=/home/anugraha/.conda/envs/openmm_env/bin:$PATH
export WEST_SIM_ROOT=$SLURM_SUBMIT_DIR
cd $WEST_SIM_ROOT

export CUDA_MPS_PIPE_DIRECTORY=/tmp/nvidia-mps
export CUDA_MPS_LOG_DIRECTORY=/tmp/nvidia-log
mkdir -p $CUDA_MPS_PIPE_DIRECTORY $CUDA_MPS_LOG_DIRECTORY
nvidia-cuda-mps-control -d

./init.sh || { echo "Error: init.sh failed"; exit 1; }
source env.sh || exit 1
env | sort
SERVER_INFO=$WEST_SIM_ROOT/west_zmq_info.json

num_gpu_per_node=1
workers_per_gpu=32  # Adjust based on memory/GPU capability
total_workers=$((num_gpu_per_node * workers_per_gpu))


rm -rf nodefilelist.txt
scontrol show hostname $SLURM_JOB_NODELIST > nodefilelist.txt


w_run --work-manager=zmq --n-workers=0 --zmq-mode=master --zmq-write-host-info=$SERVER_INFO --zmq-comm-mode=tcp &> west-$SLURM_JOBID-local.log &


for ((n=0; n<60; n++)); do
    if [ -e $SERVER_INFO ]; then
        echo "== server info file $SERVER_INFO =="
        cat $SERVER_INFO
        break
    fi
    sleep 1
done

if ! [ -e $SERVER_INFO ]; then
    echo 'Error: Server failed to start'
    exit 1
fi

for node in $(cat nodefilelist.txt); do
    srun -N1 -n1 bash node.sh $SLURM_SUBMIT_DIR $SLURM_JOBID $node $CUDA_VISIBLE_DEVICES \
        --work-manager=zmq --n-workers=$total_workers --zmq-mode=client --zmq-read-host-info=$SERVER_INFO \
        --zmq-comm-mode=tcp &

    if [ $? -ne 0 ]; then
        echo "Error: srun failed on node $node"
        exit 1
    fi
done

wait


echo quit | nvidia-cuda-mps-control

echo "Weighted ensemble simulation completed successfully"
