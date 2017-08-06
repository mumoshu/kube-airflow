#!/usr/bin/env bash

CMD="airflow"
TRY_LOOP="10"
POSTGRES_HOST="postgres"
POSTGRES_PORT="5432"
FERNET_KEY=$(python -c "from cryptography.fernet import Fernet; FERNET_KEY = Fernet.generate_key().decode(); print FERNET_KEY")

# Generate Fernet key
sed -i "s/{FERNET_KEY}/${FERNET_KEY}/" $AIRFLOW_HOME/airflow.cfg

# wait for DB
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
  if [ "$1" = "webserver" ]; then
    echo "Initialize database..."
    $CMD initdb
  fi
  sleep 5
fi

run_scheduler() {
  while echo "Running scheduler, all args ignored"; do
    $CMD "scheduler" "-n" "5"
    exitcode=$?
    if [ $exitcode -ne 0 ]; then
      echo "ERROR: Scheduler exited with exit code $?."
      echo $(date)
      exit $exitcode 
    fi
    sleep 30
  done
}

if [ "$1" = "scheduler" ] ; then
  run_scheduler
else
  nohup $CMD "$@" &
  run_scheduler
fi