# kube-airflow
[![Docker Hub](https://img.shields.io/badge/docker-ready-blue.svg)](https://hub.docker.com/r/mumoshu/kube-airflow/)
[![Docker Pulls](https://img.shields.io/docker/pulls/mumoshu/kube-airflow.svg?maxAge=2592000)]()
[![Docker Stars](https://img.shields.io/docker/stars/mumoshu/kube-airflow.svg?maxAge=2592000)]()

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
