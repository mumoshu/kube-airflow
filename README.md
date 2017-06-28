# kube-airflow
[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://hub.docker.com/r/mumoshu/kube-airflow/)
[![Docker Pulls](https://img.shields.io/docker/pulls/mumoshu/kube-airflow.svg?maxAge=2592000)]()
[![Docker Stars](https://img.shields.io/docker/stars/mumoshu/kube-airflow.svg?maxAge=2592000)]()

kube-airflow provides a set of tools to run Airflow in a Kubernetes cluster.
This is useful when you'd want:

* Easy high availability of the Airflow scheduler
  * [Running multiple schedulers for high availability isn't safe](https://groups.google.com/forum/#!topic/airbnb_airflow/-1wKa3OcwME) so it isn't the way to go in the first place. [Someone in the internet tried to implement a wrapper](https://stackoverflow.com/a/39595535) to implement leader election on top of the scheduler so that only one scheduler executes the tasks at a time. It is possbile but can't we just utilize a kind of cluster manager here? This is where Kubernetes comes into play.
* Easy parallelism of task executions
  * The common way to scale out workers in Airflow is to utilize Celery. However, managing a H/A backend database and Celery workers just for parallelising task executions sounds like a hassle. This is where Kubernetes comes into play, again. If you already had a K8S cluster, just let K8S manage them for you.
  * If you have ever considered to avoid Celery for task parallelism, yes, K8S can still help you for a while. Just keep using `LocalExecutor` instead of `CeleryExecutor` and delegate actual tasks to Kubernetes by calling e.g. `kubectl run --restart=Never ...` from your tasks. It will work until the concurrent `kubectl run` executions(up to the concurrency implied by scheduler's `max_threads` and LocalExecutor's `parallelism`) consumes all the resources a single airflow-scheduler pod provides, which will be after the pretty long time.

This repository contains:

* **Dockerfile(.template)** of [airflow](https://github.com/apache/incubator-airflow) for [Docker](https://www.docker.com/) images published to the public [Docker Hub Registry](https://registry.hub.docker.com/).
* **airflow.all.yaml** for creating Kubernetes services and deployments to run Airflow on Kubernetes

## Informations

* Highly inspired by the great work [puckel/docker-airflow](https://github.com/puckel/docker-airflow)
* Based on Debian Jessie official Image [debian:jessie](https://registry.hub.docker.com/_/debian/) and uses the official [Postgres](https://hub.docker.com/_/postgres/) as backend and [RabbitMQ](https://hub.docker.com/_/rabbitmq/) as queue
* Following the Airflow release from [Python Package Index](https://pypi.python.org/pypi/airflow)

## Installation

Create all the deployments and services for Airflow:

        kubectl create -f airflow.all.yaml

## Build

`git clone` this repository and then just run:

        make build

## Usage

Create all the deployments and services to run Airflow on Kubernetse:

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

You can browse the Airflow dashboard via running:

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
