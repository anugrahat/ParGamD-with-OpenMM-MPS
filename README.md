# ParGaMD: Parallelizable Gaussian Accelerated Molecular Dynamics in OpenMM

ParGaMD combines Gaussian Accelerated MD (GaMD) with a Weighted Ensemble (WE) approach and **multiprocess streaming (MPS)** for faster sampling of protein conformational space.

## Quick Start

1. **Run Conventional GaMD (cGaMD):**
   - Go to the `cMD` folder and submit:
     ```
     sbatch run_cmd.sh
     ```
   - This generates `gamd-restart.dat`, which holds GaMD parameters.

2. **Set Up Weighted Ensemble (WE):**
   - In the main directory, `run_WE.sh` automatically copies `gamd-restart.dat` and `bstate.rst` into the WE framework.

3. **Adjust `west.cfg`:**
   - Ensure `pcoord_len = nstlim/ntpr + 1` in `west.cfg`.
   - `nstlim` and `ntpr` come from `common_files/md.in`.

4. **Submit ParGaMD After cGaMD Completes:**
   - Check your cGaMD job ID:
     ```
     squeue -u <username>
     ```
   - Submit ParGaMD with a dependency:
     ```
     sbatch --dependency=afterok:<job_id> run_WE.sh
     ```
   - Update `NODELOC` in `env.sh` to the current run directory if needed.

5. **Postprocessing:**
   - After the simulation finishes, submit:
     ```
     sbatch run_data.sh
     ```
   - This collects output into `gamd.log` and `PC.dat` (progress coordinates).

6. **Reweighting & Free Energy Surface (FES):**
   - Extract weights:
     ```
     awk 'NR%1==0' gamd.log | awk '{print ($8+$7)/(0.001987*300)" " $2 " " ($8+$7)}' > weights.dat
     ```
   - Combine PC1 and PC2 (if 2D):
     ```
     awk 'NR==FNR{a[NR]=$2; next} {print a[FNR], $2}' PC1.dat PC2.dat > output.dat
     ```
   - Generate FES:
     ```
     ./reweight-2d.sh 50 50 0.1 0.1 output.dat 300
     ```
   - Adjust cutoff, bin spacing, and temperature (in Kelvin) as needed.

**Note:** MPS (Multiprocess Streaming) has been implemented to improve parallel performance.

---

