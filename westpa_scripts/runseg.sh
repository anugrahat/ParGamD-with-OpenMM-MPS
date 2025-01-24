#!/bin/bash
module load cuda/11.8.0

# Enhanced debugging
if [ -n "$SEG_DEBUG" ]; then
    set -x
    env | sort
    nvidia-smi || echo "Warning: nvidia-smi failed"
    python -c "import openmm; print('OpenMM version:', openmm.__version__)" || echo "Warning: OpenMM import failed"
fi

# GPU Assignment with modulo operation for multiple processes per GPU
AVAILABLE_GPUS=$(nvidia-smi --list-gpus | wc -l)
if [ $AVAILABLE_GPUS -eq 0 ]; then
    echo "Error: No GPUs found on the system"
    exit 1
fi

if [ -z "$CUDA_VISIBLE_DEVICES_ALLOCATED" ]; then
    echo "CUDA_VISIBLE_DEVICES_ALLOCATED is empty. Falling back to SLURM_LOCALID."
    export CUDA_VISIBLE_DEVICES=$((SLURM_LOCALID % AVAILABLE_GPUS))
else
    # Use modulo to wrap around when WM_PROCESS_INDEX exceeds number of GPUs
    CUDA_DEVICES=($(echo $CUDA_VISIBLE_DEVICES_ALLOCATED | tr ',' ' '))
    NUM_DEVICES=${#CUDA_DEVICES[@]}
    if [ $NUM_DEVICES -eq 0 ]; then
        echo "Warning: No GPUs in CUDA_VISIBLE_DEVICES_ALLOCATED, using GPU 0"
        export CUDA_VISIBLE_DEVICES=0
    else
        DEVICE_INDEX=$((WM_PROCESS_INDEX % NUM_DEVICES))
        export CUDA_VISIBLE_DEVICES=${CUDA_DEVICES[$DEVICE_INDEX]}
    fi
fi

echo "Assigned GPU: $CUDA_VISIBLE_DEVICES for WM_PROCESS_INDEX: $WM_PROCESS_INDEX (out of $AVAILABLE_GPUS GPUs)"

# Create and move into simulation directory
mkdir -pv "$WEST_CURRENT_SEG_DATA_REF"
cd "$WEST_CURRENT_SEG_DATA_REF" || exit 1

# Link necessary files
ln -sfv "$WEST_SIM_ROOT/common_files/chignolin.prmtop" .
ln -sfv "$WEST_SIM_ROOT/common_files/gamd-restart.dat" .
ln -sfv "$WEST_SIM_ROOT/common_files/upper_dual_temp.xml" .
ln -sfv "$WEST_SIM_ROOT/common_files/chignolin.rst" .


sed -i 's|<directory>.*</directory>|<directory>.</directory>|' upper_dual_temp.xml




# Before running GaMD simulation, handle checkpoint files
if [ "$WEST_CURRENT_ITER" -eq 1 ]; then
    echo "First iteration - copying initial checkpoint file"
    cp -v "$WEST_SIM_ROOT/common_files/gamd_restart.checkpoint" ./gamd_restart.checkpoint
else
    echo "Subsequent iteration - using parent checkpoint"
    cp -v "$WEST_PARENT_DATA_REF/gamd_restart.checkpoint" ./gamd_restart.checkpoint
fi

# Debug output
echo "Current directory: $(pwd)"
echo "Directory exists and is writable: $([ -w . ] && echo 'yes' || echo 'no')"
echo "XML contents after modification:"
cat upper_dual_temp.xml

# Run the GaMD simulation with logging
GAMD_LOG="gamd.log"
echo "Starting GaMD simulation..."
python "$WEST_SIM_ROOT/common_files/gamdRunner" \
    -r --restart \
    -p CUDA \
    -d $CUDA_VISIBLE_DEVICES \
    xml upper_dual_temp.xml 2>&1 | tee $GAMD_LOG

# Check if simulation generated outputs
if [ ! -f "gamd_restart.checkpoint" ] || [ ! -f "output_restart.dcd" ]; then
    echo "Error: GaMD simulation failed to generate output files"
    echo "Contents of current directory:"
    ls -l
    echo "Last 50 lines of GaMD log:"
    tail -n 50 $GAMD_LOG
    exit 1
fi

# Analysis: RMSD and Radius of Gyration
RMSD_FILE="rmsd_ca.xvg"
RG_FILE="rg_ca.xvg"
CPPTRAJ_LOG="cpptraj.log"

COMMAND="parm chignolin.prmtop\n"
COMMAND+="trajin output_restart.dcd\n"  # Changed from seg.nc to output.dcd
COMMAND+="reference $WEST_SIM_ROOT/common_files/chignolin.pdb\n"
COMMAND+="rms rmsd_ca @CA reference out $RMSD_FILE mass\n"
COMMAND+="radgyr rg_ca @CA out $RG_FILE\n"
COMMAND+="go\n"

echo -e "${COMMAND}" | cpptraj > "$CPPTRAJ_LOG" 2>&1

if [ $? -ne 0 ]; then
    echo "Error: cpptraj failed. Check $CPPTRAJ_LOG for details."
    exit 1
fi

# Collect data for WEST_PCOORD_RETURN
if [ -f "$RMSD_FILE" ] && [ -f "$RG_FILE" ]; then
    > "$WEST_PCOORD_RETURN"
    paste <(awk 'NR>1 {print $2}' "$RMSD_FILE") \
          <(awk 'NR>1 {print $2}' "$RG_FILE") >> "$WEST_PCOORD_RETURN"
else
    echo "Error: RMSD or Rg file missing."
    exit 1
fi

if [ -n "$SEG_DEBUG" ]; then
    head -v "$WEST_PCOORD_RETURN"
fi

