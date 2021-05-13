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
  --arg actor "$GITHUB_ACTOR" \
  --arg branch "${GITHUB_HEAD_REF:-${GITHUB_REF##*/}}" \
  --arg commit_sha "${INPUT_COMMIT_SHA}" \
  --arg commit "${GITHUB_SERVER_URL}/${GITHUB_REPOSITORY}/commit/${INPUT_COMMIT_SHA}" \
  --arg request_link "${INPUT_PULL_REQUEST:-$INPUT_COMPARE}" \
  --arg migration_envs "$INPUT_MIGRATION_ENVS" \
  --arg observation_interval "$INPUT_OBSERVATION_INTERVAL" \
  --arg max_lock_duration "$INPUT_MAX_LOCK_DURATION" \
  --arg max_duration "$INPUT_MAX_DURATION" \
  --argjson keep_clone $KEEP_CLONE \
  '{source: {owner: $owner, repo: $repo, ref: $ref, branch: $branch, commit_sha: $commit_sha, commit: $commit, request_link: $request_link}, actor: $actor, db_name: $db_name, commands: $commands | rtrimstr("\n") | split("\n"), migration_envs: $migration_envs | rtrimstr("\n") | split("\n"), observation_config: { observation_interval: $observation_interval|tonumber, max_lock_duration: $max_lock_duration|tonumber, max_duration: $max_duration|tonumber}, keep_clone: $keep_clone}')

echo $JSON_DATA

response_code=$(curl --show-error --silent --location --request POST "${CI_ENDPOINT}/migration/run" --write-out "%{http_code}" \
--header "Verification-Token: ${SECRET_TOKEN}" \
--header 'Content-Type: application/json' \
--output response.json \
--data "${JSON_DATA}")

jq . response.json

if [[ $response_code -ne 200 ]]; then
  echo "Invalid status code given: ${response_code}"
  exit 1
fi

status=$(jq -r '.session.result.status' response.json)

if [[ $status != "passed" ]]; then
  echo "Invalid status given: ${status}"
  exit 1
fi

echo "::set-output name=response::$(cat response.json)"

clone_id=$(jq -r '.clone_id' response.json)
session_id=$(jq -r '.session.session_id' response.json)

if [[ ! $KEEP_CLONE ]]; then
  exit 0
fi

# Download artifacts
mkdir artifacts

download_artifacts() {
    artifact_code=$(curl --show-error --silent "${CI_ENDPOINT}/artifact/download?artifact_type=$1&session_id=$2&clone_id=$3" --write-out "%{http_code}" \
         --header "Verification-Token: ${SECRET_TOKEN}" \
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

# Stop the running clone
response_code=$(curl --show-error --silent "${CI_ENDPOINT}/artifact/stop?clone_id=${clone_id}" --write-out "%{http_code}" \
     --header "Verification-Token: ${SECRET_TOKEN}" \
     --header 'Content-Type: application/json')

if [[ $response_code -ne 200 ]]; then
  echo "Invalid status code given on destroy clone: ${artifact_code}"
fi
