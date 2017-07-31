"""
Download DAGs from S3 staging bucket
"""

from airflow import DAG
from airflow.operators import SimpleHttpOperator, HttpSensor,   BashOperator, EmailOperator, S3KeySensor
from datetime import datetime, timedelta

default_args = {
    'owner': 'airflow',
    'depends_on_past': False,
    'start_date': datetime(2017, 1, 1),
    'email': ['bradford@roboticprofit.com'],
    'email_on_failure': False,
    'email_on_retry': False,
    'retries': 5,
    'retry_delay': timedelta(minutes=5)
}


dag = DAG('dag_from_s3', default_args=default_args, schedule_interval= '* * * * *')

t1 = BashOperator(
    task_id='copy_dags',
    bash_command='aws s3 sync --region=us-east-2  s3://test-deployment-staging-airflow-dags /usr/local/airflow/dags',
    dag=dag)


    