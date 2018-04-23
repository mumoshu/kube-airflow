# Airflow DAGs

Place your DAGs in this folder if you choose to deploy your DAGS inside the Docker image.

This allows to enforce consistency between all the containers, and have the following advantages:
- force restart of the scheduler on DAG update, avoiding inconsistency issue in case of DAG update
  while it is running
- allow installation of dependencies

It is also possible to actually keep your DAGs in an external git-project, combining it with
DAG requirements declaration, and call the kube-airflow's Makefile accordingly. For example, you can:

- gate every DAGs changes by a mergerequest mecanism: unittest, pip install,
- make a new docker image using

      DAG_PATH=$PWD
      cd /path/to/kube-aiflow
      make ENBEDDED_DAGS_LOCATION=$DAG_PATH REQUIREMENTS_TXT_LOCATION=$DAG_PATH/requirements.txt

- trigger the deployment on this new image on your Kubernetes infrastructure
