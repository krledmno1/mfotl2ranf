function run() {
  if [[ "${skip}" == "1" ]]
  then
    echo -n "TO"
    return 0
  fi

  local cmd="${1}"

  local ts1="$(date +%s%N)"
  timeout ${to} script /dev/null </dev/null -eqc "${cmd}" &> /dev/null
  local status="${?}"

  local ts2="$(date +%s%N)"
  local delta="$((ts2 - ts1))"

  local t="$(echo "scale=1; ${delta}/1000000000" | bc -l)"
  if [[ "${status}" == "0" && "$(echo "${t} < ${to}" | bc -l)" == "1" ]]; then
    printf "%.2f s" "${t}"
    ts+=("${t}")
  elif [[ "${status}" == "124" || "$(echo "${t} >= ${to}" | bc -l)" == "1" ]]; then
    echo -n "TO"
    skip=1
  else
    echo -n "RE"
  fi
}

function runNoTO() {
  local cmd="${1}"

  local ts1="$(date +%s%N)"
  bash -c "${cmd}" &> /dev/null
  local status="${?}"

  local ts2="$(date +%s%N)"
  local delta="$((ts2 - ts1))"

  local t="$(echo "scale=1; ${delta}/1000000000" | bc -l)"
  if [[ "${status}" == "0" ]]; then
    printf "%.2f s" "${t}"
  else
    echo -n "RE"
  fi
}

function run01A() {
  run "./monpoly/monpoly -formula z_${i}.smfotl -log z_${i}.log -sig z_${i}.sig -no_rw -nofilterrel -nofilteremptytp -verified"
}
function run01B() {
  run "./monpoly/monpoly -formula z_${i}.smfotl -log z_${i}.log -sig z_${i}.sig -no_rw -nofilterrel -nofilteremptytp"
}
function run01C() {
  run "./staticmon/z_${i} --log z_${i}.xlog"
}

function run02() {
  if [[ "${skip}" == "1" ]]
  then
    echo -n "TO"
    return 0
  fi
  if [[ -f "z_${i}.timed.csv" ]]
  then
    cmd="./dejavu/dejavu z_${i}.${1} z_${i}.timed.csv \"$(cat z_${i}.bits)\""
  else
    cmd="./dejavu/dejavu z_${i}.${1} z_${i}.csv \"$(cat z_${i}.bits)\""
  fi
  out=$(timeout ${to} script /dev/null </dev/null 2>/dev/null -eqc "${cmd}")
  local status="${?}"
  if [[ "${status}" == "0" ]]; then
    t=$(echo -n "${out}" | grep -o "Elapsed analysis time: [0-9.]*" | sed "s/.*: \(.*\)/\1/")
    ts+=("${t}")
    printf "%.2f s" "${t}"
  elif [[ "${status}" == "124" ]]; then
    echo -n "TO"
    skip=1
  else
    echo -n "RE"
  fi
}
function run02A() {
  run02 "qtl"
}
function run02B() {
  run02 "permqtl"
}
function run03() {
  run "./monpoly-reg-1.0/monpoly-reg -mona_dir /home/mfotlranf/monpoly-reg-1.0/monaaut -formula z_${i}.mrfotl -log z_${i}.log -sig z_${i}.sig"
}

function lineskip() {
  echo -n "${1}"
  skip=0
  ts=()
  for i in ${seeds}
  do
    echo -n "&"
    ${2} ${i}
  done
  echo "\\\\"

  if [[ "${3}" == "ratios" ]]
  then
    echo -n "\\trat"
    prev=""
    for t in "${ts[@]}"
    do
      if [[ "${t}" == "TO" || "${t}" == "RE" ]]
      then
        break
      fi
      echo -n "&"
      if [[ "${prev}" != "" && "$(echo "${prev} != 0.0" | bc -l)" == "1" ]]
      then
        rat="$(echo "(${t}) / (${prev})" | bc -l)"
        printf "{\\\\tratsize $%.2f \\\\times$}" "${rat}"
      fi
      prev="${t}"
    done
    echo "\\\\"
  fi
}
