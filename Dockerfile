FROM quay.io/coffeepac/kube-airflow:1.8.1-db2

COPY script/entrypoint.sh ${AIRFLOW_HOME}/entrypoint.sh
COPY script/dag_from_s3.py ${AIRFLOW_HOME}/dags
COPY config/airflow.cfg ${AIRFLOW_HOME}/airflow.cfg

RUN mkdir ${AIRFLOW_HOME}/scripts/
RUN chmod 777 ${AIRFLOW_HOME}/scripts/
COPY helper_class/  ${AIRFLOW_HOME}/scripts/ 
RUN cd ${AIRFLOW_HOME}/scripts/ \
    && python setup.py install

RUN cd ${AIRFLOW_HOME}/scripts/ \
    && python setup.py install

USER root
WORKDIR ${AIRFLOW_HOME}
ENTRYPOINT ["./entrypoint.sh"]