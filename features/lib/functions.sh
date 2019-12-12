#!/usr/bin/env bash

die() {
    # Print in RED
    printf "\e[31m==> [ERROR] %s \e[0m\n" "${1:-'unknown'}"
    exit 1
}

success() {
    # Print in GREEN
    printf "\e[32m==> [SUCCESS] %s\e[0m\n" "${1:-'unknown'}"
    exit 0
}

warn() {
    # Print in ORANGE
    printf "\e[33m==> [WARN] %s\e[0m\n" "${1:-'unknown'}"
}

info() {
    # Print in BLUE
    printf "\e[96m==> [INFO] %s\e[0m\n" "${1:-'unknown'}"
}

ocp_sanity_check() {
    if [ ! -x $(command -v oc) ]; then
        die "Could not find the executable oc in the current PATH"
    fi

    whoami=$(oc whoami 2> /dev/null)
    if [ -z "${whoami}" ]; then
        die "oc whoami returned empty ID, please run oc login"
    fi
}

# sync_repo_and_patch repo-name url branch pull_request_id1 pull_request_id2 ...
sync_repo_and_patch(){
  REPO_PATH=${REPO_PATH:-$HOME}
  DEST="${REPO_PATH}/$1"
  URL="${2}"
  echo "Syncing $1"

  if [ ! -d "${DEST}" ]; then
    mkdir -p "${DEST}"
    git clone "${URL}" "${DEST}"
  fi

  pushd "${DEST}" || die "pushd to ${DEST} failed"

  git am --abort || true
  git checkout master
  git fetch origin
  git rebase origin/master
  if [ "$#" -gt "2" ]; then
    git branch -D "${3}" || true
    git checkout -b "${3}"
    shift; shift; shift;
    for arg in "$@"; do
      curl -L "${URL%.*}/pull/$arg.patch" | git am
    done
  fi
  popd || die "popd failed"
}

random_master(){
  # Get all the masters
  MASTERS=$(oc get node -L "node-role.kubernetes.io/master" -o custom-columns=NAME:.metadata.name --no-headers | tr '\n' ',' | sed 's/.$//')
  # Convert them into an array
  IFS=',' read -r -a MARRAY <<< "$MASTERS"
  # Label a random master as 'grandmaster'
  echo "${MARRAY[$((RANDOM % ${#MARRAY[@]}))]}"
}

wait_mcp(){
  mcp=${1:-worker}
  paused=$(oc get mcp $mcp -o jsonpath='{.spec.paused}')
  if [ "$paused" == "true" ] ; then
    info "Mcp $mcp is paused, skipping wait"
    exit 0
  fi
  until oc wait mcp/$mcp --for condition=updated --timeout 600s ; do sleep 1 ; done
}

##  E2E
# Validates every tests inside of CHECKS variable
# Should be passed like:
# CHECKS=( 
#     "KERNEL_PREEMPTION:$(oc debug node/${worker} -- chroot /host uname -v | grep -c PREEMPT)"
#     "KERNEL_REAL_TIME:$(oc debug node/${worker} -- chroot /host uname -v | grep -c RT)"
# )

# set -x

function reverse() {
    # Workaround to match when the expected result is 0 to be compliant with others tests
    if [ $1 -eq 0 ];then
        echo '1'
    else
        echo '0'
    fi
}

function validate_function() {
    if [ -z "${CHECKS}" ];then
        die "There is not checks general to go through"
    fi

    for check in "${CHECKS[@]}"
    do
        CHECK_NAME="${check%%:*}"
        CHECK_RESULT=${check##*:}
        test_results+=("${CHECK_RESULT}")
        if [ ${CHECK_RESULT} -ge 1 ];then
            test_ok+=("${CHECK_RESULT}")
        else
            test_nok+=("${CHECK_RESULT}")
            test_failed+=("${CHECK_NAME}: Test Failed!")
            #if [ ! -z "${worker}" ];then
            #    echo "${worker} - ${CHECK_NAME}: ${CHECK_RESULT}"
            #fi
        fi
    done
}


function resume() {
    if [[ ${#test_nok[@]} -ge 1 ]]; then
        die "$1 results: ${#test_ok[@]} Passed | ${#test_nok[@]} Failed | ${#test_results[@]} Total"
        for failed in "${test_failed[@]}"
        do
            echo "${failed}"
        done
		exit 1
	else
        info "$1 results: ${#test_ok[@]} Passed | ${#test_nok[@]} Failed | ${#test_results[@]} Total"
	fi
}
