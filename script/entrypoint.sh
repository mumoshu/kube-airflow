#!/usr/bin/env bash

CMD="airflow"
TRY_LOOP="${TRY_LOOP:-10}"
POSTGRES_HOST="${POSTGRES_HOST:-postgres}"
POSTGRES_PORT=5432
POSTGRES_CREDS="${POSTGRES_CREDS:-airflow:airflow}"
RABBITMQ_HOST="${RABBITMQ_HOST:-rabbitmq}"
RABBITMQ_CREDS="${RABBITMQ_CREDS:-airflow:airflow}"
RABBITMQ_MANAGEMENT_PORT=15672
FLOWER_URL_PREFIX="${FLOWER_URL_PREFIX:-}"
AIRFLOW_URL_PREFIX="${AIRFLOW_URL_PREFIX:-}"
LOAD_DAGS_EXAMPLES="${LOAD_DAGS_EXAMPLES:-true}"
GIT_SYNC_REPO="${GIT_SYNC_REPO:-}"

if [ -z $FERNET_KEY ]; then
    FERNET_KEY=$(python3 -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print(FERNET_KEY)")
fi

echo "Postgres host: $POSTGRES_HOST"
echo "RabbitMQ host: $RABBITMQ_HOST"
echo "Load DAG examples: $LOAD_DAGS_EXAMPLES"
echo "Git sync repository: $GIT_SYNC_REPO"
echo

# Generate Fernet key
sed -i "s/{{ FERNET_KEY }}/${FERNET_KEY}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s/{{ POSTGRES_HOST }}/${POSTGRES_HOST}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s/{{ POSTGRES_CREDS }}/${POSTGRES_CREDS}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s/{{ RABBITMQ_HOST }}/${RABBITMQ_HOST}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s/{{ RABBITMQ_CREDS }}/${RABBITMQ_CREDS}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s/{{ LOAD_DAGS_EXAMPLES }}/${LOAD_DAGS_EXAMPLES}/" $AIRFLOW_HOME/airflow.cfg
sed -i "s#{{ FLOWER_URL_PREFIX }}#${FLOWER_URL_PREFIX}#" $AIRFLOW_HOME/airflow.cfg
sed -i "s#{{ AIRFLOW_URL_PREFIX }}#${AIRFLOW_URL_PREFIX}#" $AIRFLOW_HOME/airflow.cfg

# wait for rabbitmq
if [ "$1" = "webserver" ] || [ "$1" = "worker" ] || [ "$1" = "scheduler" ] || [ "$1" = "flower" ] ; then
  j=0
  while ! curl -sI -u $RABBITMQ_CREDS http://$RABBITMQ_HOST:$RABBITMQ_MANAGEMENT_PORT/api/whoami |grep '200 OK'; do
    j=`expr $j + 1`
    if [ $j -ge $TRY_LOOP ]; then
      echo "$(date) - $RABBITMQ_HOST still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for RabbitMQ... $j/$TRY_LOOP"
    sleep 5
  done
fi

# wait for postgres
if [ "$1" = "webserver" ] || [ "$1" = "worker" ] || [ "$1" = "scheduler" ] ; then
  i=0
  while ! nc $POSTGRES_HOST $POSTGRES_PORT >/dev/null 2>&1 < /dev/null; do
    i=`expr $i + 1`
    if [ $i -ge $TRY_LOOP ]; then
      echo "$(date) - ${POSTGRES_HOST}:${POSTGRES_PORT} still not reachable, giving up"
      exit 1
    fi
    echo "$(date) - waiting for ${POSTGRES_HOST}:${POSTGRES_PORT}... $i/$TRY_LOOP"
    sleep 5
  done
  # TODO: move to a Helm hook
  #   https://github.com/kubernetes/helm/blob/master/docs/charts_hooks.md
  if [ "$1" = "webserver" ]; then
    echo "Initialize database..."
    $CMD initdb
  fi
fi

if [ ! -z $GIT_SYNC_REPO ]; then
    mkdir -p $AIRFLOW_HOME/dags
    # remove possible embedded dags to avoid conflicts
    rm -rf $AIRFLOW_HOME/dags/*
    echo "Executing background task git-sync on repo $GIT_SYNC_REPO"
    $AIRFLOW_HOME/git-sync --dest $AIRFLOW_HOME/dags --force &
fi

$CMD "$@"
