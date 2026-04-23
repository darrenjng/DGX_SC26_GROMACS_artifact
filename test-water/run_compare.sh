#!/usr/bin/env bash
set -euo pipefail

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TESTDIR="${ROOT}/test-water"
GMX_BIN="${ROOT}/runtime/bin/gmx"
GMXDATA="${ROOT}/runtime/share/gromacs"
GMXLIB="${GMXDATA}/top"
CUDA_LIBDIR="${ROOT}/runtime/cuda/lib"
MANAGED_LIBDIR="${ROOT}/runtime/managed/lib"
export GMX_MAXBACKUP=-1

fail() {
    echo "Error: $*" >&2
    exit 1
}

setup_env() {
    local libdir="$1"
    export GMXDATA GMXLIB
    export LD_LIBRARY_PATH="${libdir}${LD_LIBRARY_PATH:+:${LD_LIBRARY_PATH}}"
}

run_grompp() {
    setup_env "${CUDA_LIBDIR}"
    echo "Preparing topol.tpr with grompp..."
    if ! "${GMX_BIN}" grompp -f md.mdp -c conf.gro -p topol.top -o topol.tpr > grompp.out 2>&1; then
        echo "grompp failed. Contents of grompp.out:" >&2
        cat grompp.out >&2 || true
        exit 1
    fi
}

run_case() {
    local libdir="$1"
    local name="$2"

    setup_env "${libdir}"
    echo "Running ${name}..."
    /usr/bin/time -f 'ELAPSED=%e
MAXRSS_KB=%M' -o "${name}.time" \
        "${GMX_BIN}" mdrun -s topol.tpr -deffnm "${name}" -nb gpu -pme cpu -bonded cpu -update cpu -pin on
}

print_case_summary() {
    local name="$1"
    local elapsed
    local rss_kb
    local core_time
    local wall_time

    elapsed="$(awk -F= '/^ELAPSED=/{print $2}' "${name}.time")"
    rss_kb="$(awk -F= '/^MAXRSS_KB=/{print $2}' "${name}.time")"
    read -r core_time wall_time < <(awk '/^[[:space:]]*Time:/{print $2, $3}' "${name}.log" | tail -n 1)

    echo "${name}:"
    echo "  total elapsed (s): ${elapsed}"
    echo "  compute time (core t, s): ${core_time}"
    echo "  gromacs wall time (s): ${wall_time}"
    echo "  host peak rss (KB): ${rss_kb}"
}

cd "${TESTDIR}"

[[ -x "${GMX_BIN}" ]] || fail "missing executable: ${GMX_BIN}"
[[ -d "${CUDA_LIBDIR}" ]] || fail "missing CUDA library directory: ${CUDA_LIBDIR}"
[[ -d "${MANAGED_LIBDIR}" ]] || fail "missing managed library directory: ${MANAGED_LIBDIR}"
[[ -d "${GMXLIB}/oplsaa.ff" ]] || fail "missing forcefield directory: ${GMXLIB}/oplsaa.ff"
[[ -f conf.gro && -f md.mdp && -f topol.top ]] || fail "missing one or more test-water input files"

run_grompp
run_case "${CUDA_LIBDIR}" run-cuda
run_case "${MANAGED_LIBDIR}" run-managed

echo
echo "== Performance summary =="
grep -E 'Performance|Time:' run-cuda.log run-managed.log

echo
echo "== Runtime summary =="
print_case_summary run-cuda
print_case_summary run-managed
