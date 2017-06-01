#!/bin/bash
set -euo pipefail

# This should get the 2nd most recent version of an image that we can then delete, assuming we always want the most recent image.
# If we didn't want the most recent it would probably be a rollback scenario.
# But we are not using `-f`, so if a container is running from the image, the image will not be removed.
docker images --format '{"repo": json .Repository, "tag": json .Tag, "createdAt": json .CreatedAt}' \
  | jq -sr 'group_by(.repo) | .[] | sort_by(.createdAt) | reverse | .1 | values | "(.repo):(.tag)"' \
  | xargs docker rmi
