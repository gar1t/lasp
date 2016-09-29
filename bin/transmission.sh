#!/usr/bin/env bash

source helpers.sh

ENV_VARS=(
  LASP_BRANCH
  DCOS
  TOKEN
  EVALUATION_PASSPHRASE
  ELB_HOST
  AWS_ACCESS_KEY_ID
  AWS_SECRET_ACCESS_KEY
  SIMULATION
  CLIENT_NUMBER
  PARTITION_PROBABILITY
  EVENT_VELOCITY
)

for ENV_VAR in "${ENV_VARS[@]}"
do
  if [ -z "${!ENV_VAR}" ]; then
    echo ">>> ${ENV_VAR} is not configured; please export it."
    exit 1
  fi
done

EVAL_NUMBER=1
AAE_INTERVAL=5000
DELTA_INTERVAL=5000
INSTRUMENTATION=true
LOGS="s3"
EXTENDED_LOGGING=true
MAILBOX_LOGGING=false

declare -A EVALUATIONS

EVALUATIONS["client_server_state_based_with_aae"]="partisan_client_server_peer_service_manager state_based false false false"
EVALUATIONS["reactive_client_server_state_based_with_aae"]="partisan_client_server_peer_service_manager state_based false false true"
##EVALUATIONS["peer_to_peer_state_based_with_aae"]="partisan_hyparview_peer_service_manager state_based false false false"

for i in $(seq 1 $EVAL_NUMBER)
do
  echo "[$(date +%T)] Running evaluation $i of $EVAL_NUMBER"

  for EVAL_ID in "${!EVALUATIONS[@]}"
  do
    STR=${EVALUATIONS["$EVAL_ID"]}
    IFS=' ' read -a CONFIG <<< "$STR"
    PEER_SERVICE=${CONFIG[0]}
    MODE=${CONFIG[1]}
    BROADCAST=${CONFIG[2]}
    HEAVY_CLIENTS=${CONFIG[3]}
    REACTIVE_SERVER=${CONFIG[4]}
    TIMESTAMP=$(date +%s)
    REAL_EVAL_ID=$EVAL_ID"_"$CLIENT_NUMBER"_"$PARTITION_PROBABILITY"_"$EVENT_VELOCITY

    if [ "$PEER_SERVICE" == "partisan_client_server_peer_service_manager" ] && [ "$CLIENT_NUMBER" -gt "128" ]; then
      echo "[$(date +%T)] Client-Server topology with $CLIENT_NUMBER clients is not supported"
    else
      PEER_SERVICE=$PEER_SERVICE MODE=$MODE BROADCAST=$BROADCAST SIMULATION=$SIMULATION EVAL_ID=$REAL_EVAL_ID EVAL_TIMESTAMP=$TIMESTAMP HEAVY_CLIENTS=$HEAVY_CLIENTS REACTIVE_SERVER=$REACTIVE_SERVER AAE_INTERVAL=$AAE_INTERVAL DELTA_INTERVAL=$DELTA_INTERVAL INSTRUMENTATION=$INSTRUMENTATION LOGS=$LOGS EXTENDED_LOGGING=$EXTENDED_LOGGING MAILBOX_LOGGING=$MAILBOX_LOGGING ./dcos-deploy.sh

      echo "[$(date +%T)] Running $EVAL_ID with $CLIENT_NUMBER clients; $PARTITION_PROBABILITY % partitions; $EVENT_VELOCITY velocity; with configuration $STR"

      wait_for_completion $TIMESTAMP
    fi
  done

  echo "[$(date +%T)] Evaluation $i of $EVAL_NUMBER completed!"
done
