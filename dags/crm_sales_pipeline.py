from datetime import datetime

from airflow import DAG
from airflow.operators.bash import BashOperator

from cosmos import (
    DbtTaskGroup,
    ProjectConfig,
    ProfileConfig,
    ExecutionConfig,
    RenderConfig,
)
from cosmos.constants import TestBehavior


# Project paths inside the Airflow Docker container
BASE_PATH = "/usr/local/airflow"

DBT_PROJECT_PATH = f"{BASE_PATH}/crm_dbt"
DBT_EXECUTABLE_PATH = "/usr/local/airflow/dbt_venv/bin/dbt"
PYTHON_EXECUTABLE_PATH = "/usr/local/airflow/dbt_venv/bin/python"

PROFILES_FILE = f"{DBT_PROJECT_PATH}/profiles.yml"

with DAG(
    dag_id="crm_sales_dbt_pipeline",
    start_date=datetime(2026, 10, 1),
    schedule=None,
    catchup=False,
    max_active_tasks=1,
    max_active_runs=1,
    tags=["CRM", "ETL", "dbt", "Cosmos"],
) as dag:

    # Step 1: Load raw CSV files into DuckDB
    load_raw_data = BashOperator(
        task_id="load_raw_data",
        bash_command=(
            f"{PYTHON_EXECUTABLE_PATH} "
            f"{BASE_PATH}/load_Data.py"
        ),
    )

    # Step 2: Execute dbt models through Cosmos
    dbt_transform = DbtTaskGroup(
        group_id="dbt_transform",
        project_config=ProjectConfig(
            dbt_project_path=DBT_PROJECT_PATH,
        ),
        profile_config=ProfileConfig(
            profile_name="crm_dbt",
            target_name="dev",
            profiles_yml_filepath=PROFILES_FILE,
        ),
        execution_config=ExecutionConfig(
            dbt_executable_path=DBT_EXECUTABLE_PATH,
        ),
        render_config=RenderConfig(
            test_behavior=TestBehavior.NONE,
        ),
    )

    # Step 3: Run dbt tests after the models are built
    dbt_tests = BashOperator(
        task_id="dbt_tests",
        bash_command=(
            f"{DBT_EXECUTABLE_PATH} test "
            f"--project-dir {DBT_PROJECT_PATH} "
            f"--profiles-dir {DBT_PROJECT_PATH}"
        ),
    )

    # Define execution order
    load_raw_data >> dbt_transform >> dbt_tests