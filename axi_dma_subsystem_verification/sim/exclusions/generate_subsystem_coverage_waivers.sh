#!/usr/bin/env bash
# Prepare, edit, and validate subsystem coverage exclusions in independent
# stages.  Keeping the stages separate avoids repeating URG work when the
# Verdi Coverage GUI or URG exits unexpectedly.
set -euo pipefail

script_dir="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
project_root="$(cd "${script_dir}/../.." && pwd)"
work_dir="${WAIVER_WORK_DIR:-${project_root}/build/coverage_waiver_review}"
report_dir="${work_dir}/urg_uncovered"
audit_tsv="${work_dir}/coverage_closure_audit.tsv"
candidate_tsv="${work_dir}/approved_unreachable_candidates.tsv"
urg_bin="${URG:-urg}"
verdi_bin="${VERDI:-verdi}"
# The lab image exposes Python 2.7 as "python".  The helper intentionally uses
# only syntax and APIs supported by Python 2.7.
python_bin="${PYTHON:-python}"
audit_metrics="${WAIVER_AUDIT_METRICS:-line+cond+tgl+fsm+branch+assert}"
# Repack the source regression into a smaller code-focused VDB before opening
# it in Verdi.  This also gives URG a chance to normalize database metadata
# that may trigger a Verdi V-2023.12-SP2 loader crash.
normalize_metrics="${WAIVER_NORMALIZE_METRICS:-line+cond+tgl+fsm+branch}"
# URG can emit commented full-exclusion templates containing the database
# checksums and object identities needed to build a strict .el without Verdi.
template_metrics="${WAIVER_TEMPLATE_METRICS:-line+cond+tgl+fsm+branch}"
# Code-only reporting is the stable default for V-2023.12-SP2.  Override this
# variable when an assertion/group-inclusive final dashboard is required.
validation_metrics="${WAIVER_URG_METRICS:-line+cond+tgl+fsm+branch}"

usage() {
  echo "Usage:" >&2
  echo "  $0 normalize  <regression.vdb> <normalized.vdb>" >&2
  echo "  $0 template   <regression.vdb> <template_dir>" >&2
  echo "  $0 prepare    <regression.vdb>" >&2
  echo "  $0 edit       <regression.vdb> [output.el]" >&2
  echo "  $0 edit-empty <regression.vdb> [output.el]" >&2
  echo "  $0 report     <regression.vdb> [output.el]" >&2
  echo >&2
  echo "Stages:" >&2
  echo "  normalize   Repack the source into a code-focused VDB for Verdi." >&2
  echo "  template    Dump strict exclusion templates without starting Verdi." >&2
  echo "  prepare     Generate the uncovered URG report and audited TSV files." >&2
  echo "  edit        Open the selected VDB directly in Verdi Coverage." >&2
  echo "  edit-empty  Open an empty Verdi Coverage GUI; load the printed VDB" >&2
  echo "              manually if direct loading is unstable." >&2
  echo "  report      Apply the saved .el file and generate the final report." >&2
}

require_command() {
  executable="$1"
  if ! command -v "${executable}" >/dev/null 2>&1; then
    echo "ERROR: executable not found: ${executable}" >&2
    exit 2
  fi
}

mode="${1:-}"
vdb_arg="${2:-}"

case "${mode}" in
  normalize|template|prepare|edit|edit-empty|report)
    ;;
  *)
    usage
    exit 2
    ;;
esac

if [[ -z "${vdb_arg}" ]]; then
  usage
  exit 2
fi
if [[ ! -d "${vdb_arg}" ]]; then
  echo "ERROR: VDB directory does not exist: ${vdb_arg}" >&2
  exit 2
fi
vdb_dir="$(cd "${vdb_arg}" && pwd)"

if [[ "${mode}" == "normalize" ]]; then
  require_command "${urg_bin}"
  normalized_arg="${3:-}"
  if [[ -z "${normalized_arg}" ]]; then
    echo "ERROR: normalize requires an output VDB path." >&2
    usage
    exit 2
  fi
  mkdir -p "$(dirname "${normalized_arg}")"
  normalized_vdb="$(cd "$(dirname "${normalized_arg}")" && pwd)/$(basename "${normalized_arg}")"
  if [[ -e "${normalized_vdb}" ]]; then
    echo "ERROR: normalized VDB target already exists:" >&2
    echo "       ${normalized_vdb}" >&2
    echo "Choose a new output name so a failed or older VDB is not reused." >&2
    exit 2
  fi
  normalized_report="${WAIVER_NORMALIZE_REPORT:-${normalized_vdb%.vdb}_urg}"

  echo "Repacking the regression VDB with metrics: ${normalize_metrics}"
  echo "  Source: ${vdb_dir}"
  echo "  VDB:    ${normalized_vdb}"
  echo "  Report: ${normalized_report}"
  "${urg_bin}" -dir "${vdb_dir}" \
    -metric "${normalize_metrics}" \
    -dbname "${normalized_vdb}" \
    -report "${normalized_report}"

  if [[ ! -d "${normalized_vdb}" ]]; then
    echo "ERROR: URG returned without creating the normalized VDB:" >&2
    echo "       ${normalized_vdb}" >&2
    exit 4
  fi
  echo "Normalized VDB created: ${normalized_vdb}"
  echo "Use this same VDB for prepare, edit, and report."
  echo "Next command:"
  echo "  $0 prepare '${normalized_vdb}'"
  exit 0
fi

if [[ "${mode}" == "template" ]]; then
  require_command "${urg_bin}"
  template_arg="${3:-}"
  if [[ -z "${template_arg}" ]]; then
    echo "ERROR: template requires a new output directory." >&2
    usage
    exit 2
  fi
  mkdir -p "$(dirname "${template_arg}")"
  template_dir="$(cd "$(dirname "${template_arg}")" && pwd)/$(basename "${template_arg}")"
  if [[ -e "${template_dir}" ]]; then
    echo "ERROR: template target already exists:" >&2
    echo "       ${template_dir}" >&2
    echo "Choose a new directory so stale or partial templates are not reused." >&2
    exit 2
  fi
  mkdir -p "${template_dir}"

  echo "Dumping full exclusion templates without Verdi ..."
  echo "  VDB:      ${vdb_dir}"
  echo "  Metrics:  ${template_metrics}"
  echo "  Output:   ${template_dir}"
  set +e
  (
    cd "${template_dir}"
    "${urg_bin}" -dir "${vdb_dir}" \
      -metric "${template_metrics}" \
      -dump full_exclusions \
      -report template_report
  )
  urg_status=$?
  set -e

  template_count="$(find "${template_dir}" -type f -name 'fullexclude.*' -size +0c | wc -l)"
  if (( template_count == 0 )); then
    echo "ERROR: URG returned without creating fullexclude.* templates:" >&2
    echo "       ${template_dir}" >&2
    echo "       URG status: ${urg_status}" >&2
    exit 4
  fi
  if (( urg_status != 0 )); then
    echo "WARNING: URG exited with status ${urg_status} after writing templates." >&2
    echo "The non-empty templates are preserved for review; template_report" >&2
    echo "may be incomplete and must not be used as the final dashboard." >&2
  fi
  echo "Generated ${template_count} exclusion template file(s):"
  find "${template_dir}" -type f -name 'fullexclude.*' -size +0c -print
  echo
  echo "These files contain the VDB checksums and exact coverage object IDs."
  echo "Do not uncomment every entry.  Filter only the approved WAIVE rows."
  exit 0
fi

output_el="${3:-${script_dir}/subsystem_unreachable.el}"
mkdir -p "$(dirname "${output_el}")"
output_el="$(cd "$(dirname "${output_el}")" && pwd)/$(basename "${output_el}")"

if [[ "${mode}" == "prepare" ]]; then
  require_command "${urg_bin}"
  require_command "${python_bin}"

  if ! "${python_bin}" -c \
       'import sys; sys.exit(0 if sys.version_info >= (2, 7) else 1)'; then
    echo "ERROR: coverage audit requires Python 2.7 or newer: ${python_bin}" >&2
    exit 2
  fi
  python_version="$("${python_bin}" -c \
    'import sys; print(sys.version.split()[0])')"
  echo "Coverage audit Python: ${python_bin} (${python_version})"

  mkdir -p "${work_dir}"
  echo "Generating a fresh ${audit_metrics} report from:"
  echo "  ${vdb_dir}"
  "${urg_bin}" -dir "${vdb_dir}" -metric "${audit_metrics}" \
    -report "${report_dir}"

  "${python_bin}" "${script_dir}/audit_urg_code_coverage.py" \
    "${report_dir}" \
    --output "${audit_tsv}" \
    --waiver-candidates "${candidate_tsv}"

  test_count="$(awk -F '\t' \
    'NR > 1 && $5 == "TEST" {count++} END {print count+0}' \
    "${audit_tsv}")"
  review_count="$(awk -F '\t' \
    'NR > 1 && $5 == "REVIEW" {count++} END {print count+0}' \
    "${audit_tsv}")"
  scope_count="$(awk -F '\t' \
    'NR > 1 && $5 == "SCOPE" {count++} END {print count+0}' \
    "${audit_tsv}")"
  waive_count="$(awk -F '\t' \
    'NR > 1 && $5 == "WAIVE" {count++} END {print count+0}' \
    "${audit_tsv}")"

  echo "Audit summary: TEST=${test_count} WAIVE=${waive_count} SCOPE=${scope_count} REVIEW=${review_count}"
  echo "Full audit:                 ${audit_tsv}"
  echo "Approved waiver candidates: ${candidate_tsv}"
  if (( test_count != 0 )); then
    echo "WARNING: reachable TEST targets remain in this VDB." >&2
  fi
  if (( review_count != 0 )); then
    echo "WARNING: REVIEW rows are not approved waiver candidates." >&2
  fi
  if (( scope_count != 0 )); then
    echo "WARNING: SCOPE rows require separate verification-plan approval." >&2
  fi
  echo
  echo "Next command:"
  echo "  $0 edit '${vdb_dir}' '${output_el}'"
  exit 0
fi

if [[ "${mode}" == "edit" || "${mode}" == "edit-empty" ]]; then
  require_command "${verdi_bin}"
  if [[ ! -s "${candidate_tsv}" ]]; then
    echo "ERROR: waiver candidate list is missing or empty:" >&2
    echo "       ${candidate_tsv}" >&2
    echo "Run the prepare stage first." >&2
    exit 2
  fi

  echo "Approved selection/evidence list:"
  echo "  ${candidate_tsv}"
  echo "VDB to open:"
  echo "  ${vdb_dir}"
  echo "Save All Exclusions to this exact path:"
  echo "  ${output_el}"
  echo
  echo "Select only rows marked WAIVE; do not exclude TEST, REVIEW, or SCOPE rows."

  set +e
  if [[ "${mode}" == "edit" ]]; then
    "${verdi_bin}" -cov -covdir "${vdb_dir}"
  else
    echo "Open the VDB manually from the Verdi Coverage GUI."
    "${verdi_bin}" -cov
  fi
  verdi_status=$?
  set -e

  if (( verdi_status != 0 )); then
    echo "ERROR: Verdi exited with status ${verdi_status}; no .el file was confirmed." >&2
    echo "Retry this stage only.  If direct loading failed, use edit-empty." >&2
    exit "${verdi_status}"
  fi
  if [[ ! -s "${output_el}" ]]; then
    echo "ERROR: Verdi closed without creating a non-empty exclusion file:" >&2
    echo "       ${output_el}" >&2
    echo "Run this edit stage again and use File -> Save All Exclusions." >&2
    exit 3
  fi

  echo "Exclusion file created: ${output_el}"
  echo "Next command:"
  echo "  $0 report '${vdb_dir}' '${output_el}'"
  exit 0
fi

require_command "${urg_bin}"
if [[ ! -s "${output_el}" ]]; then
  echo "ERROR: exclusion file is missing or empty:" >&2
  echo "       ${output_el}" >&2
  echo "Complete the edit stage before generating the final report." >&2
  exit 3
fi

timestamp="$(date +%Y%m%d_%H%M%S)"
validation_report="${WAIVER_REPORT_DIR:-${work_dir}/urg_with_subsystem_waivers_${timestamp}}"
echo "Applying exclusions with strict VDB matching ..."
echo "  VDB:     ${vdb_dir}"
echo "  EL:      ${output_el}"
echo "  Metrics: ${validation_metrics}"
echo "  Report:  ${validation_report}"
"${urg_bin}" -dir "${vdb_dir}" \
  -metric "${validation_metrics}" \
  -elfile "${output_el}" -excl_strict \
  -report "${validation_report}"

if [[ ! -s "${validation_report}/dashboard.html" ]]; then
  echo "ERROR: URG returned without creating dashboard.html:" >&2
  echo "       ${validation_report}" >&2
  exit 4
fi

echo "Validated exclusion file: ${output_el}"
echo "Waived coverage dashboard: ${validation_report}/dashboard.html"
echo "Open it with:"
echo "  firefox '${validation_report}/dashboard.html' &"
