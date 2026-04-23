# DGX GROMACS Artifact

This repository is an artifact package for the DGX Spark GROMACS comparison in `test-water/run_compare.sh`.

## Packaged contents

- `test-water/conf.gro`: input coordinates
- `test-water/md.mdp`: MD parameters
- `test-water/topol.top`: system topology
- `test-water/run_compare.sh`: benchmark runner

## Usage

```bash
chmod +x test-water/run_compare.sh
./test-water/run_compare.sh
```

Outputs are written under `test-water/`, including:

- `grompp.out`
- `topol.tpr`
- `run-cuda.log`, `run-cuda.time`, and simulation outputs
- `run-managed.log`, `run-managed.time`, and simulation outputs

## Platform assumptions

- Linux on `aarch64`
- NVIDIA DGX Spark environment
