# ParGaMD: Parallelizable Gaussian Accelerated Molecular Dynamics in OpenMM

ParGaMD combines **Gaussian Accelerated MD (GaMD)** with a **Weighted Ensemble (WE)** approach and **Multiprocess Streaming (MPS)** to speed up protein simulations in **OpenMM**.

## Quick Start

1. **Conventional GaMD (cGaMD) Setup**
   - Prepare your OpenMM system for GaMD (e.g., define force field, integrator, and GaMD parameters).
   - Run the initial cGaMD job to generate the `gamd-restart.dat` file.

2. **Weighted Ensemble (WE) Preparation**
   - In your main directory, ensure you have the necessary WE scripts (e.g., `west.cfg`, `run_WE.sh`).
   - Copy `gamd-restart.dat` and any required restart files (`*.rst7`, etc.) into the WE framework.

3. **Check `west.cfg`**
   - Set `pcoord_len = (number_of_steps / report_interval) + 1`.
   - Adjust any OpenMM-based paths or commands to match your system configuration.

4. **Run ParGaMD with Dependency**
   - If you submitted the cGaMD job via SLURM, note its Job ID:
     ```
     squeue -u <username>
     ```
   - Submit ParGaMD as a dependent job:
     ```
     sbatch --dependency=afterok:<job_id> run_WE.sh
     ```

5. **Postprocessing**
   - After ParGaMD completes, run a postprocessing script (e.g., `run_data.sh`) to collect outputs (`gamd.log`, progress coordinates, etc.).
   - Always submit postprocessing to a compute node to avoid memory issues.

6. **Reweighting & Free Energy Surface (FES)**
   - Extract weights from `gamd.log`:
     ```
     awk 'NR%1==0' gamd.log | awk '{print ($8+$7)/(0.001987*300)" " $2 " " ($8+$7)}' > weights.dat
     ```
   - Combine principal coordinates (e.g., PC1 and PC2):
     ```
     awk 'NR==FNR{a[NR]=$2; next} {print a[FNR], $2}' PC1.dat PC2.dat > output.dat
     ```
   - Generate FES:
     ```
     ./reweight-2d.sh 50 50 0.1 0.1 output.dat 300
     ```
     - Here, **50 50** = max cutoffs, **0.1 0.1** = bin sizes, and **300** = temperature in Kelvin.

> **Note**: **MPS (Multiprocess Streaming)** is implemented for improved parallel performance on HPC clusters.

---
