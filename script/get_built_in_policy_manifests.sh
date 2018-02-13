#!/bin/bash

# This script is only used in Test::Nginx tests.
# It prints a JSON array that includes all the manifests of the built-in
# policies plus the ones specified in the directories received in the
# arguments.

built_in_dir=$(pwd)/gateway/src/apicast/policy
manifest_files=$(find "$built_in_dir" "$@" -name apicast-policy.json)

manifests='['

for manifest_file in ${manifest_files}
do
    manifests+=$(cat "$manifest_file"),
done

manifests=${manifests::-1}] # Replace last ',' with ']'

manifests="{\"policies\":$manifests}"

echo ${manifests}
