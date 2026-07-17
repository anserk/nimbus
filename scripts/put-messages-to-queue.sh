#!/bin/bash
# This sripts adds message to a given queue that triggers KEDA
# for weather and traffic processing.
#
# Requires jq.
#
# Produces a message with the following format: {"city":"Chicago","lat":41.85,"lon":-87.65}.
#
# Usage: ./scripts/put-messages-to-queue.sh <limit> <account-name> <queue-name>


LIMIT=$1
ACCOUNT_NAME=$2
QUEUE_NAME=$3

echo $LIMIT

if [ -z "$LIMIT" ] || [ -z "$ACCOUNT_NAME" ] || [ -z "$QUEUE_NAME" ]; then
  echo "Usage: ./scripts/put-messages-to-queue.sh <limit> <account-name> <queue-name>"
  exit 1
fi

FILE=$(dirname "$0")/../cities.json

if [ -f "$FILE" ]; then

    jq -c --argjson n "$LIMIT" 'limit($n; to_entries[])
        | {city: .key, lat: .value[0], lon: .value[1]}' "$FILE" |
    while read -r entry; do
        echo "$entry"

        az storage message put \
            --auth-mode login \
            --account-name  "$ACCOUNT_NAME" \
            --queue-name "$QUEUE_NAME" \
            --content "$entry"
    done

else
    echo "cities file does not exist."
fi
