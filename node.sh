#!/bin/bash
#
# node.sh
set -x  # Enable command debugging
umask g+r  # Set default permissions for newly created files
cd "$1" || exit 1; shift  # Move to the specified directory or exit if it fails
source env.sh  # Source the environment setup script
export WEST_JOBID=$1; shift  # Assign job ID
export SLURM_NODENAME=$1; shift  # Assign node name
export CUDA_VISIBLE_DEVICES_ALLOCATED=$1; shift  # Assign allocated GPUs

# More robust GPU handling
if [ -z "$CUDA_VISIBLE_DEVICES_ALLOCATED" ]; then
    # Fallback to local GPU enumeration if no allocation provided
    export CUDA_VISIBLE_DEVICES=$((SLURM_LOCALID % $(nvidia-smi --list-gpus | wc -l)))
    echo "Using fallback GPU allocation: CUDA_VISIBLE_DEVICES=$CUDA_VISIBLE_DEVICES"
else
    # Parse allocated GPUs and assign based on process index
    IFS=',' read -ra GPU_ARRAY <<< "$CUDA_VISIBLE_DEVICES_ALLOCATED"
    if [ "${#GPU_ARRAY[@]}" -gt 0 ]; then
        export CUDA_VISIBLE_DEVICES=${GPU_ARRAY[0]}
    else
        echo "Warning: No valid GPU allocation found"
        export CUDA_VISIBLE_DEVICES=0
    fi
fi

# Verify CUDA environment
nvidia-smi || echo "Warning: nvidia-smi failed. Check GPU availability"
echo "Starting WEST client processes on: $(hostname)"
echo "Current directory is: $PWD"
echo "CUDA_VISIBLE_DEVICES = $CUDA_VISIBLE_DEVICES"
echo "Environment variables:"
env | sort

# Run the Weighted Ensemble process with error handling
w_run "$@" &> west-$SLURM_NODENAME-node.log
RUN_STATUS=$?

# Enhanced error checking
if [ $RUN_STATUS -ne 0 ]; then
    echo "Error: w_run failed on node $SLURM_NODENAME with status $RUN_STATUS"
    echo "Last 50 lines of log file:"
    tail -n 50 west-$SLURM_NODENAME-node.log
    exit 1
fi

# Final message indicating successful shutdown
echo "Shutting down node $SLURM_NODENAME. All processes completed successfully."