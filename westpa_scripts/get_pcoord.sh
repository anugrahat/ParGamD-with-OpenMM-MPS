#!/bin/bash

##############################################################################
# Example driver script to compute RMSD and Rg over 101 frames using cpptraj
# for a single WESTPA segment. Adjust paths and references as needed.
#
# WESTPA environment variables that must be set:
#   - $WEST_SIM_ROOT          : Path to the simulation root
#   - $WEST_STRUCT_DATA_REF   : Trajectory file for this segment (e.g., a DCD)
#   - $WEST_PCOORD_RETURN     : File to which pcoord data must be written
#   - $CPPTRAJ                : Path/command for cpptraj
#   - $SEG_DEBUG (optional)   : If set, script runs in debug mode (prints commands, etc.)
#
# This script assumes your trajectory contains 101 frames, matching the
# shape (101,2) that WESTPA expects for pcoords: e.g. 101 lines with
# [RMSD, Rg].
##############################################################################

# 1. If debugging is enabled, turn on shell debugging and print environment
if [ -n "$SEG_DEBUG" ]; then
  set -x
  env | sort
fi

# 2. Move to the simulation root directory
cd "$WEST_SIM_ROOT" || {
  echo "Error: Could not cd to \$WEST_SIM_ROOT=$WEST_SIM_ROOT" >&2
  exit 1
}

# 3. Create temporary files for storing RMSD and Rg data
RMSD_FILE=$(mktemp --tmpdir rmsd_XXXX.xvg)
RG_FILE=$(mktemp --tmpdir rg_XXXX.xvg)

# 4. Build the cpptraj command string
#    We assume $WEST_STRUCT_DATA_REF is a DCD with 101 frames total.
#    The '1 101 1' notation means read frames from 1 to 101 with stride 1 (cpptraj is 1-indexed).
COMMAND="parm $WEST_SIM_ROOT/common_files/chignolin.prmtop\n"
COMMAND+="trajin $WEST_STRUCT_DATA_REF 1 400 1\n"
COMMAND+="reference $WEST_SIM_ROOT/common_files/chignolin.pdb\n"
COMMAND+="rms ca-rmsd @CA reference out $RMSD_FILE mass\n"
COMMAND+="radgyr ca-rg @CA out $RG_FILE mass\n"
COMMAND+="go"

# 5. Execute cpptraj, passing the multi-line command via standard input
if ! echo -e "${COMMAND}" | "$CPPTRAJ"; then
  echo "Error: cpptraj execution failed!" >&2
  rm -f "$RMSD_FILE" "$RG_FILE"
  exit 1
fi

# 6. Extract the RMSD and Rg columns from ALL frames. 
#    - 'NR>1' in awk skips any header line in the .xvg file.
#    - $2 is the second column, which typically contains the RMSD or Rg values.
#    - We then 'paste' them column by column into $WEST_PCOORD_RETURN.
paste <(awk 'NR>1 {print $2}' "$RMSD_FILE") \
      <(awk 'NR>1 {print $2}' "$RG_FILE") \
      > "$WEST_PCOORD_RETURN"

# 7. If debug is enabled, show the first few lines of the resulting pcoord file
if [ -n "$SEG_DEBUG" ]; then
  echo "Preview of \$WEST_PCOORD_RETURN:"
  head -v "$WEST_PCOORD_RETURN"
  echo "Number of lines in \$WEST_PCOORD_RETURN: $(wc -l < "$WEST_PCOORD_RETURN")"
fi

# 8. Clean up temporary files

exit 0
