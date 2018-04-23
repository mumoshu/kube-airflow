# VERSION 1.8.0.0
# AUTHOR: Yusuke KUOKA
# DESCRIPTION: Docker image to run Airflow on Kubernetes which is capable of creating Kubernetes jobs
# BUILD: docker build --rm -t mumoshu/kube-airflow
# SOURCE: https://github.com/mumoshu/kube-airflow

FROM    debian:stretch
MAINTAINER Yusuke KUOKA <ykuoka@gmail.com>

# Never prompts the user for choices on installation/configuration of packages
ENV     DEBIAN_FRONTEND noninteractive
ENV     TERM linux

# Airflow
ARG     AIRFLOW_VERSION=%%AIRFLOW_VERSION%%
ENV     AIRFLOW_HOME /usr/local/airflow
ENV     EMBEDDED_DAGS_LOCATION=%%EMBEDDED_DAGS_LOCATION%%
ENV     REQUIREMENTS_TXT_LOCATION=%%REQUIREMENTS_TXT_LOCATION%%

# Define en_US.
ENV     LANGUAGE en_US.UTF-8
ENV     LANG en_US.UTF-8
ENV     LC_ALL en_US.UTF-8
ENV     LC_CTYPE en_US.UTF-8
ENV     LC_MESSAGES en_US.UTF-8
ENV     LC_ALL en_US.UTF-8

WORKDIR /requirements
# Only copy needed files
COPY    requirements/airflow.txt /requirements/airflow.txt
COPY    ${REQUIREMENTS_TXT_LOCATION} /requirements/dags.txt


RUN         set -ex \
        &&  buildDeps=' \
                build-essential \
                libblas-dev \
                libffi-dev \
                libkrb5-dev \
                liblapack-dev \
                libpq-dev \
                libsasl2-dev \
                libssl-dev \
                libxml2-dev \
                libxslt1-dev \
                python3-dev \
                python3-pip \
                zlib1g-dev \
            ' \
        &&  apt-get update -yqq \
        &&  apt-get install -yqq --no-install-recommends \
                $buildDeps \
                apt-utils \
                curl \
                git \
                locales \
                netcat \
        &&      sed -i 's/^# en_US.UTF-8 UTF-8$/en_US.UTF-8 UTF-8/g' /etc/locale.gen \
        &&  locale-gen \
        &&  update-locale LANG=en_US.UTF-8 LC_ALL=en_US.UTF-8 \
        &&  useradd -ms /bin/bash -d ${AIRFLOW_HOME} airflow \
        &&  pip3 install --upgrade pip 'setuptools!=36.0.0' \
        &&  if [ ! -e /usr/bin/pip ]; then ln -s /usr/bin/pip3 /usr/bin/pip ; fi \
        &&  if [ ! -e /usr/bin/python ]; then ln -sf /usr/bin/python3 /usr/bin/python; fi \
        &&  pip3 install -r /requirements/airflow.txt \
        &&  pip3 install -r /requirements/dags.txt \
        &&  apt-get remove --purge -yqq $buildDeps libpq-dev \
        &&  apt-get clean \
        &&  rm -rf \
                /var/lib/apt/lists/* \
                /tmp/* \
                /var/tmp/* \
                /usr/share/man \
                /usr/share/doc \
                /usr/share/doc-base

ENV         KUBECTL_VERSION %%KUBECTL_VERSION%%

RUN         curl -L -o /usr/local/bin/kubectl \
                https://storage.googleapis.com/kubernetes-release/release/v${KUBECTL_VERSION}/bin/linux/amd64/kubectl \
        &&  chmod +x /usr/local/bin/kubectl

COPY        script/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
COPY        config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg
COPY        script/git-sync ${AIRFLOW_HOME}/git-sync
COPY        ${EMBEDDED_DAGS_LOCATION} ${AIRFLOW_HOME}/dags
COPY        script/git-sync ${AIRFLOW_HOME}/git-sync

RUN         chown -R airflow: ${AIRFLOW_HOME} \
        &&  chmod +x ${AIRFLOW_HOME}/entrypoint.sh \
        &&  chmod +x ${AIRFLOW_HOME}/git-sync

EXPOSE  8080 5555 8793

USER        airflow
WORKDIR     ${AIRFLOW_HOME}
ENTRYPOINT  ["./entrypoint.sh"]
