# kube-airflow (Celery Executor)
[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://hub.docker.com/r/stibbons31/kube-airflow/)
[![Docker Pulls](https://img.shields.io/docker/pulls/stibbons31/kube-airflow.svg?maxAge=2592000)]()
[![Docker Stars](https://img.shields.io/docker/stars/stibbons31/kube-airflow.svg?maxAge=2592000)]()

kube-airflow provides a set of tools to run Airflow in a Kubernetes cluster.
This is useful when you'd want:

* Easy high availability of the Airflow scheduler
  * [Running multiple schedulers for high availability isn't safe](https://groups.google.com/forum/#!topic/airbnb_airflow/-1wKa3OcwME) so it isn't the way to go in the first place. [Someone in the internet tried to implement a wrapper](https://stackoverflow.com/a/39595535) to implement leader election on top of the scheduler so that only one scheduler executes the tasks at a time. It is possible but can't we just utilize a kind of cluster manager here? This is where Kubernetes comes into play.
* Easy parallelism of task executions
  * The common way to scale out workers in Airflow is to utilize Celery. However, managing a H/A backend database and Celery workers just for parallelising task executions sounds like a hassle. This is where Kubernetes comes into play, again. If you already had a K8S cluster, just let K8S manage them for you.
  * If you have ever considered to avoid Celery for task parallelism, yes, K8S can still help you for a while. Just keep using `LocalExecutor` instead of `CeleryExecutor` and delegate actual tasks to Kubernetes by calling e.g. `kubectl run --restart=Never ...` from your tasks. It will work until the concurrent `kubectl run` executions(up to the concurrency implied by scheduler's `max_threads` and LocalExecutor's `parallelism`. See [this SO question](https://stackoverflow.com/questions/38200666/airflow-parallelism) for gotchas) consumes all the resources a single airflow-scheduler pod provides, which will be after the pretty long time.

This repository contains:

* **Dockerfile(.template)** of [airflow](https://github.com/apache/incubator-airflow) for [Docker](https://www.docker.com/) images published to the public [Docker Hub Registry](https://registry.hub.docker.com/).
* **airflow.all.yaml** for manual creating Kubernetes services and deployments to run Airflow on Kubernetes
* **Helm Chart** in `./airflow` for deployments using Helm

## Informations

* Fork of [mumoshu/kube-airflow](https://github.com/mumoshu/kube-airflow)
* Highly inspired by the great work [puckel/docker-airflow](https://github.com/puckel/docker-airflow)
* Based on Debian Stretch official Image [debian:stretch](https://registry.hub.docker.com/_/debian/) and uses the official [Postgres](https://hub.docker.com/_/postgres/) as backend and [RabbitMQ](https://hub.docker.com/_/rabbitmq/) as queue
* Following the Airflow release from [Python Package Index](https://pypi.python.org/pypi/airflow)

## Manual Installation

Create all the deployments and services to run Airflow on Kubernetes:

    kubectl create -f airflow.all.yaml

It will create deployments for:

* postgres
* rabbitmq
* airflow-webserver
* airflow-scheduler
* airflow-flower
* airflow-worker

and services for:

* postgres
* rabbitmq
* airflow-webserver
* airflow-flower

## Helm Deployment (recommended)

Ensure your helm installation is done, you may need to have `TILLER_NAMESPACE` set as
environment variable.

Deploy to Kubernetes using:

    make helm-install NAMESPACE=yournamespace HELM_VALUES=/path/to/you/values.yaml

### Helm ingresses

The Chart provides ingress configuration to allow customization the installation by adapting
the `config.yaml` depending on your setup.

### Prefix

This Helm chart allows using a "prefix" string that will be added to every Kubernetes names.
That allows instantiating several, independent Airflow clusters in the same namespace.

Note:

    Do NOT use characters such as " (double quote), ' (simple quote), / (slash) or \ (backslash)
    in your passwords and prefix and keep it as small as possible.

### DAGs deployment: embedded DAGs or git-sync

This chart provide basically two way of deploying DAGs in your Airflow installation:

- embedded DAGs
- Git-Sync

This helm chart provide support for Persistant Storage but not for sidecar git-sync pod.
If you are willing to contribute, do not hesitate to do a Pull Request !

#### Using embedded Git-Sync

Git-sync is the easiest way to automatically update your DAGs. It simply checks periodically (by
default every minute) a Git project on a given branch and check this new version out when available.
Scheduler and worker see changes almost real-time. There is no need to other tool and complex
rolling-update procedure.

While it is extremely cool to see its DAG appears on Airflow 60s after merge on this project, you should be aware of some limitations Airflow has with dynamic DAG updates:

    If the scheduler reloads a dag in the middle of a dagrun then the dagrun will actually start
    using the new version of the dag in the middle of execution.

This is a known issue with airflow and it means it's unsafe in general to use a git-sync
like solution with airflow without:

 - using explicit locking, ie never pull down a new dag if a dagrun is in progress
 - make dags immutable, never modify your dag always make a new one

Also keep in mind using git-sync may not be scalable at all in production if you have lot of DAGs.
The best way to deploy you DAG is to build a new docker image containing all the DAG and their
dependencies. To do so, fork this project

#### Airflow.cfg as ConfigMap

By default, we use the configuration file `airflow.cfg` hardcoded in the docker image. This file
uses a custom templating system to apply some environmnet variable and feed the airflow processes
with (basically it is just some `sed`).

If you want to use your own `airflow.cfg` file without having to rebuild a complete docker image, for example when testing new settings, there is a way to define this file in a Kubernetes configuration
map:

- you need to define your own Value file you will feed to helm with `helm install -f myvalue.yaml`
- you need to enable init the node `airflow.airflow_cfg.enable: true`
- you need to store the content of your `airflow.cfg` in the node `airflow.airflow_cfg.data`
  You can see at `airflow/myvalue-with-airflowcfg-configmap.yaml` for an example on how to set it
  in your `config.yaml` file
- note it is important to keep the custom templating in your `airflow.cfg` (ex:
  `{{ POSTGRES_CREDS }}`) or at least keep it aligned with the configuration applyied in your
  Kubernetes Cluster.

#### Worker Statefulset

As you can see, Celery workers uses StatefulSet instead of deployment. It is used to freeze their
DNS using a Kubernetes Headless Service, and allow the webserver to requests the logs from each
workers individually. This requires to expose a port (8793) and ensure the pod DNS is accessible to
the web server pod, which is why StatefulSet is for.

#### Embedded DAGs

If you want more control on the way you deploy your DAGs, you can use embedded DAGs, where DAGs
are burned inside the Docker container deployed as Scheduler and Workers.

Be aware this requirement more heavy tooling than using git-sync, especially if you use CI/CD:

- your CI/CD should be able to build a new docker image each time your DAGs are updated.
- your CI/CD should be able to control the deployment of this new image in your kubernetes cluster

Example of procedure:
- Fork this project
- Place your DAG inside the `dags` folder of this project, update `requirements-dags.txt` to
  install new dependencies if needed (see bellow)
- Add build script connected to your CI that will build the new docker image
- Deploy on your Kubernetes cluster

You can avoid forking this project by:

- keep a git-project dedicated to storing only your DAGs + dedicated `requirements.txt`
- you can gate any change to DAGs in your CI (unittest, `pip install -r requirements-dags.txt`,.. )
- have your CI/CD makes a new docker image after each successful merge using

      DAG_PATH=$PWD
      cd /path/to/kube-aiflow
      make ENBEDDED_DAGS_LOCATION=$DAG_PATH

- trigger the deployment on this new image on your Kubernetes infrastructure

### Python dependencies

If you want to add specific python dependencies to use in your DAGs, you simply declare them inside
the `requirements/dags.txt` file. They will be automatically installed inside the container during
build, so you can directly use these library in your DAGs.

To use another file, call:

    make REQUIREMENTS_TXT_LOCATION=/path/to/you/dags/requirements.txt

Please note this requires you set up the same tooling environment in your CI/CD that when using
Embedded DAGs.

### Helm configuration customization

Helm allow to overload the configuration to adapt to your environment. You probably want to specify
your own ingress configuration for instance.


## Build Docker image

`git clone` this repository and then just run:

    make build

## Run with minikube

You can browse the Airflow dashboard via running:

    minikube start
    make browse-web

the Flower dashboard via running:

    make browse-flower

If you want to use Ad hoc query, make sure you've configured connections:
Go to Admin -> Connections and Edit "mysql_default" set this values (equivalent to values in `config/airflow.cfg`) :
- Host : mysql
- Schema : airflow
- Login : airflow
- Password : airflow

Check [Airflow Documentation](http://pythonhosted.org/airflow/)

## Run the test "tutorial"

        kubectl exec web-<id> --namespace airflow-dev airflow backfill tutorial -s 2015-05-01 -e 2015-06-01

## Scale the number of workers

For now, update the value for the `replicas` field of the deployment you want to scale and then:

        make apply


# Wanna help?

Fork, improve and PR. ;-)
