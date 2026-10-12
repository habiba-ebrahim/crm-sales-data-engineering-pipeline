FROM astrocrpublic.azurecr.io/runtime:3.3-8
# Create a separate virtual environment for dbt
RUN python -m venv dbt_venv && \
    dbt_venv/bin/pip install --no-cache-dir dbt-duckdb