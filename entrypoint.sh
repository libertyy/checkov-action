#!/bin/bash
# Actions pass inputs as $INPUT_<input name> environmet variables
#
[[ ! -z "$INPUT_CHECK" ]] && CHECK_FLAG="--check $INPUT_CHECK"
[[ ! -z "$INPUT_SKIP_CHECK" ]] && SKIP_CHECK_FLAG="--skip-check $INPUT_SKIP_CHECK"
[[ ! -z "$INPUT_FRAMEWORK" ]] && FRAMEWORK_FLAG="--framework $INPUT_FRAMEWORK"
[[ ! -z "$INPUT_OUTPUT_FORMAT" ]] && OUTPUT_FLAG="--output $INPUT_OUTPUT_FORMAT"

if [ ! -z "$INPUT_QUIET" ] && [ "$INPUT_QUIET" = "true" ]; then
  QUIET_FLAG="--quiet"
fi

if [ ! -z "$INPUT_SOFT_FAIL" ] && [ "$INPUT_SOFT_FAIL" =  "true" ]; then
  SOFT_FAIL_FLAG="--soft-fail"
fi

RC=0 #return code

CHECKOV_REPORT=${INPUT_CHECKOV_REPORT:-"$HOME/report.out"}

EXTCHECK_DIRS_FLAG=""
if [ ! -z "$INPUT_EXTERNAL_CHECKS_DIRS" ]; then
  IFS=', ' read -r -a extchecks_dir <<< "$INPUT_EXTERNAL_CHECKS_DIRS"
  for d in "${extchecks_dir[@]}"
  do
    EXTCHECK_DIRS_FLAG="$EXTCHECK_DIRS_FLAG --external-checks-dir $d"
  done
fi

EXTCHECK_REPOS_FLAG=""
if [ ! -z "$INPUT_EXTERNAL_CHECKS_REPOS" ]; then
  IFS=', ' read -r -a extchecks_git <<< "$INPUT_EXTERNAL_CHECKS_REPOS"
  for repo in "${extchecks_git[@]}"
  do
    EXTCHECK_REPOS_FLAG="$EXTCHECK_REPOS_FLAG --external-checks-git $repo"
  done
fi

echo "input_soft_fail:$INPUT_SOFT_FAIL"
matcher_path=`pwd`/checkov-problem-matcher.json
if [ ! -z "$INPUT_SOFT_FAIL" ]; then
    cp /usr/local/lib/checkov-problem-matcher.json "$matcher_path"
    else
    cp /usr/local/lib/checkov-problem-matcher-softfail.json "$matcher_path"
fi

echo "::add-matcher::checkov-problem-matcher.json"

echo $(checkov --version )

if [ -z "$GITHUB_HEAD_REF" ]; then
  # No different commits, not a PR
  # Check everything, not just a PR diff (there is no PR diff in this context).
  # NOTE: this file scope may need to be expanded or refined further.
  echo "running checkov on directory: $1"
  checkov -d $INPUT_DIRECTORY $CHECK_FLAG $SKIP_CHECK_FLAG $QUIET_FLAG $SOFT_FAIL_FLAG $FRAMEWORK_FLAG $EXTCHECK_DIRS_FLAG $EXTCHECK_REPOS_FLAG $OUTPUT_FLAG
  RC=$?
else
  pushd $GITHUB_WORKSPACE/$INPUT_DIRECTORY #&>/dev/null

  git fetch ${GITHUB_BASE_REF/#/'origin '} #&>/dev/null
  git fetch ${GITHUB_HEAD_REF/#/'origin '} #&>/dev/null
  BASE_REF=$(git rev-parse ${GITHUB_BASE_REF/#/'origin/'})
  HEAD_REF=$(git rev-parse ${GITHUB_HEAD_REF/#/'origin/'})
  DIFF_FILES=$(git diff --diff-filter=d --name-only $BASE_REF $HEAD_REF | tr '\n' ' ')

  IFS=' ' read -r -a files2scan <<< "$DIFF_FILES"

  SCAN_FILES_FLAG=""
  if [ -z "$DIFF_FILES" ]; then
    echo "No files to scan"
    RC=0
  else
    echo "running checkov on files: $DIFF_FILES"
    for f in "${files2scan[@]}"
    do
      SCAN_FILES_FLAG="$SCAN_FILES_FLAG -f $f"
    done
    checkov $SCAN_FILES_FLAG  $CHECK_FLAG $SKIP_CHECK_FLAG $QUIET_FLAG $SOFT_FAIL_FLAG $FRAMEWORK_FLAG $EXTCHECK_DIRS_FLAG $EXTCHECK_REPOS_FLAG $OUTPUT_FLAG
    RC=$?
  fi

fi

echo "exiting script: $RC"
exit $RC

