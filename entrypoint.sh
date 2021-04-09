#!/bin/sh -l

JSON_DATA=$(jq -n -c \
  --arg owner "$INPUT_OWNER" \
  --arg repo "$INPUT_REPO" \
  --arg ref "$INPUT_REF" \
  --arg commands "$INPUT_COMMANDS" \
  --arg db_name "$INPUT_DBNAME" \
  --arg actor "$GITHUB_ACTOR" \
  --arg migration_envs "$INPUT_MIGRATION_ENVS" \
  '{source: {owner: $owner, repo: $repo, ref: $ref}, actor: $actor, db_name: $db_name, commands: $commands | rtrimstr("\n") | split("\n"), migration_envs: $migration_envs | rtrimstr("\n") | split("\n")}')

echo $JSON_DATA

response=$(curl -s --location --request POST "${CI_ENDPOINT}" \
--header "Verification-Token: ${SECRET_TOKEN}" \
--header 'Content-Type: application/json' \
--data "${JSON_DATA}")

echo "::set-output name=response::$response"
