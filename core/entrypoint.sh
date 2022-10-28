#!/bin/sh -l

KEEP_CLONE=false

if [[ "${INPUT_DOWNLOAD_ARTIFACTS}" == "true" ]]; then
  KEEP_CLONE=true
fi

JSON_DATA=$(jq -n -c \
  --arg owner "$INPUT_OWNER" \
  --arg repo "$INPUT_REPO" \
  --arg ref "$INPUT_REF" \
  --arg commands "$INPUT_COMMANDS" \
  --arg db_name "$INPUT_DBNAME" \
  --arg username "$GITHUB_ACTOR" \
  --arg username_full "$INPUT_AUTHOR_NAME" \
  --arg username_link "${GITHUB_SERVER_URL}/$GITHUB_ACTOR" \
  --arg branch "${GITHUB_HEAD_REF:-${GITHUB_REF##*/}}" \
  --arg branch_link "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/tree/${GITHUB_HEAD_REF:-${GITHUB_REF##*/}}" \
  --arg commit "${INPUT_COMMIT_SHA}" \
  --arg commit_link "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${INPUT_COMMIT_SHA}" \
  --arg request_link "${INPUT_PULL_REQUEST}" \
  --arg diff_link "${INPUT_COMPARE}" \
  --arg migration_envs "$INPUT_MIGRATION_ENVS" \
  --arg observation_interval "$INPUT_OBSERVATION_INTERVAL" \
  --arg max_lock_duration "$INPUT_MAX_LOCK_DURATION" \
  --arg max_duration "$INPUT_MAX_DURATION" \
  --argjson keep_clone "$KEEP_CLONE" \
  '{source: {owner: $owner, repo: $repo, ref: $ref, branch: $branch, branch_link: $branch_link, commit: $commit, commit_link: $commit_link, request_link: $request_link, diff_link: $diff_link}, username: $username, username_full: $username_full, username_link: $username_link, db_name: $db_name, commands: $commands | rtrimstr("\n") | split("\n"), migration_envs: $migration_envs | rtrimstr("\n") | split("\n"), observation_config: { observation_interval: $observation_interval|tonumber, max_lock_duration: $max_lock_duration|tonumber, max_duration: $max_duration|tonumber}, keep_clone: $keep_clone}')

echo $JSON_DATA

response_code=$(curl --show-error --silent --location --request POST "${DLMC_CI_ENDPOINT}/migration/run" --write-out "%{http_code}" \
--header "Verification-Token: ${DLMC_VERIFICATION_TOKEN}" \
--header 'Content-Type: application/json' \
--output response.json \
--data "${JSON_DATA}")

jq . response.json

if [[ $response_code -ne 200 ]]; then
  echo "Migration status code: ${response_code}"
  exit 1
fi

clone_id=$(jq -r '.clone_id' response.json)
session_id=$(jq -r '.session.session_id' response.json)

if [[ ! $KEEP_CLONE ]]; then
  exit 0
fi

# Download artifacts
mkdir artifacts

download_artifacts() {
    artifact_code=$(curl --show-error --silent "${DLMC_CI_ENDPOINT}/artifact/download?artifact_type=$1&session_id=$2&clone_id=$3" --write-out "%{http_code}" \
         --header "Verification-Token: ${DLMC_VERIFICATION_TOKEN}" \
         --header 'Content-Type: application/json' \
         --output artifacts/$1)

    if [[ $artifact_code -ne 200 ]]; then
      echo "Downloading $1, invalid status code given: ${artifact_code}"
      return
    fi

    echo "Artifact \"$1\" has been downloaded to the artifacts directory"
}

cat response.json | jq -c -r '.session.artifacts[]' | while read artifact; do
    download_artifacts $artifact $session_id $clone_id
done

# Download report
download_artifacts 'report.md' $session_id $clone_id

# Stop the running clone
response_code=$(curl --show-error --silent "${DLMC_CI_ENDPOINT}/artifact/stop?clone_id=${clone_id}" --write-out "%{http_code}" \
     --header "Verification-Token: ${DLMC_VERIFICATION_TOKEN}" \
     --header 'Content-Type: application/json')

if [[ $response_code -ne 200 ]]; then
  echo "Invalid status code given on destroy clone: ${response_code}"
fi

status=$(jq -r '.session.result.status' response.json)

if [[ $status != "passed" ]]; then
  echo "Migration status: ${status}"
  exit 1
fi
