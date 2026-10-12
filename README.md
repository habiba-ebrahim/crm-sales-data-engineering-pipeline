# CRM Sales Opportunities – Data Engineering Pipeline

DEPI Data Engineering graduation project.
An end-to-end pipeline on the **Maven Analytics CRM Sales Opportunities** dataset:
raw CSV files are loaded into DuckDB, transformed into a dimensional model with dbt,
validated with dbt tests, and orchestrated by Apache Airflow through Astronomer Cosmos.

## Architecture

```
Raw CSV files (Raw Data/)
        |
        v
Python loader (load_Data.py)
        |
        v
DuckDB  (raw_* tables)
        |
        v
dbt staging models  ->  dbt dimensional models (dims + fact)
        |
        v
dbt data tests
        |
        v
Orchestrated by Airflow DAG `crm_sales_dbt_pipeline` (Astronomer Cosmos)
```

| Layer | Technology |
|---|---|
| Loading / automation | Python, DuckDB |
| Transformation, testing, docs | dbt (dbt-duckdb) |
| Orchestration | Apache Airflow on Astro Runtime 3.3 |
| dbt-in-Airflow integration | Astronomer Cosmos (`DbtTaskGroup`) |
| Local environment | Astro CLI + Docker |

## Dataset

Four CSV files in `Raw Data/` (a `data_dictionary.csv` is also included):

| File | Rows | Columns | Notes |
|---|---|---|---|
| `sales_pipeline.csv` | 8,800 | 8 | 6,103 missing cells; deal stages: Prospecting, Engaging, Won, Lost |
| `accounts.csv` | 85 | 7 | 70 missing cells |
| `products.csv` | 7 | 3 | no missing values |
| `sales_teams.csv` | 35 | 3 | no missing values |

None of the files contain duplicate rows. Detailed profiling reports (HTML) are in `docs/`,
and the profiling notebook is in `notebooks/data_profiling.ipynb`.

### Data-quality decisions

- **Product naming:** `sales_pipeline.csv` contains `GTXPro`, while `products.csv` uses `GTX Pro`.
  The raw CSV is left untouched; the value is standardized in the dbt model
  `stg_sales_pipeline` so every product in the fact table matches `dim_product`.
- **Missing values:** missing close dates, close values and accounts are legitimate for
  opportunities that have not closed (Prospecting deals have no engage date; Engaging deals have no
  close date), so they are never imputed. In the staging layer they stay `NULL`; in the dimensional model they
  point to a dedicated `Unknown` member (key `-1`), so every foreign key in the fact table is `NOT NULL`.
- **Whitespace:** text columns are trimmed in the staging layer.

## Data modeling

Conceptual, logical and physical schemas are in `docs/`:

- `Conceptual Schema.png`
- `Logical Schema.png`
- `Phsical Schema.png`

Dimensional model (star schema), implemented as in the physical schema diagram:

| Model | Type | Surrogate key | Notes |
|---|---|---|---|
| `dim_date` | dimension | `date_key` (`yyyymmdd`) | one row per day, 2016-01-01 to 2017-12-31 (732 rows incl. Unknown) |
| `dim_account` | dimension | `account_key` | `annual_revenue_musd`, `is_subsidiary`, self-reference `parent_account_key` |
| `dim_product` | dimension | `product_key` | `product_name`, `product_series`, `list_price` |
| `dim_sales_agent` | dimension | `sales_agent_key` | `sales_agent_name`, `manager_name`, `regional_office` |
| `fact_opportunity` | fact | `opportunity_id` | one row per opportunity (8,800); `engage_date_key`, `close_date_key`, `is_closed`, `is_won`, `close_value`, `sales_cycle_days` |

Staging models: `stg_accounts`, `stg_products`, `stg_sales_pipeline`, `stg_sales_teams` (trim, type casting and the
`GTXPro` fix). All models are materialized as views.

Design notes:

- **Surrogate keys** are integers assigned with `row_number()` ordered by the natural name, so they are deterministic
  for the current data; adding new members later can shift the numbering.
- **Unknown member (`-1`)** exists in every dimension. In the current data it is used by 1,425 opportunities without an
  account, 500 without an engage date and 2,089 without a close date.
- **Derived columns:** `is_closed` = stage is Won or Lost; `is_won` = stage is Won;
  `sales_cycle_days` = days between engage and close (`NULL` while the deal is open).

## Data quality (dbt tests)

32 data tests run on every pipeline execution:

- `unique` and `not_null` on every surrogate key and on `opportunity_id` (fact and `stg_sales_pipeline`);
  `unique` on the natural names of the dimensions
- `not_null` and `relationships` on all five foreign keys of `fact_opportunity`
  (`account_key`, `product_key`, `sales_agent_key`, `engage_date_key`, `close_date_key`), plus
  `relationships` for `dim_account.parent_account_key`
- `accepted_values` on `deal_stage` (Prospecting, Engaging, Won, Lost) and `not_null` on `is_closed` / `is_won`
- 2 reconciliation tests (`crm_dbt/tests/`): the fact has the same number of rows and the same total `close_value`
  as `stg_sales_pipeline`

## Orchestration

DAG: `crm_sales_dbt_pipeline` (`dags/crm_sales_pipeline.py`), manual trigger (`schedule=None`).

```
load_raw_data  >>  dbt_transform  >>  dbt_tests
```

1. **`load_raw_data`** – `BashOperator` running `load_Data.py` with the dbt virtualenv's Python;
   rebuilds the four `raw_*` tables (`CREATE OR REPLACE TABLE`).
2. **`dbt_transform`** – Cosmos `DbtTaskGroup`; renders each dbt model as its own Airflow task
   (9 tasks). Tests are excluded here (`TestBehavior.NONE`).
3. **`dbt_tests`** – `BashOperator` running `dbt test`.

### Verified run

A full manual run completed successfully in Airflow (11 task instances, all `Success`):

- `load_raw_data`: `raw_accounts` 85, `raw_products` 7, `raw_sales_pipeline` 8,800, `raw_sales_teams` 35 rows
- `dbt_transform`: all 9 models built
- `dbt_tests`: `PASS=32 WARN=0 ERROR=0 SKIP=0 TOTAL=32`

## Project structure

```
ETI Project/
├── dags/crm_sales_pipeline.py     # Airflow DAG
├── crm_dbt/                       # dbt project (models, tests, profiles.yml)
│   ├── models/staging/
│   └── models/marts/
├── Raw Data/                      # source CSV files
├── load_Data.py                   # CSV -> DuckDB loader
├── notebooks/                     # data profiling notebook
├── docs/                          # profiling reports and schema diagrams
├── Dockerfile                     # Astro Runtime image + isolated dbt venv
├── requirements.txt               # astronomer-cosmos
├── .dockerignore
└── airflow_settings.yaml
```

The `Dockerfile` installs `dbt-duckdb` into a separate virtualenv (`/usr/local/airflow/dbt_venv`)
so dbt dependencies do not conflict with Airflow's.

## How to run

Prerequisites: Docker Desktop and the Astro CLI.

```bash
# from the project root (the folder that contains .astro/)
astro dev start
```

1. Open http://localhost:8080.
2. Open `crm_sales_dbt_pipeline`, un-pause it, and press **Trigger**.
3. Wait for the three stages to finish; check the `dbt_tests` log for `PASS=32`.

Useful checks:

```bash
astro dev run dags list
astro dev run dags list-import-errors
astro dev run tasks test crm_sales_dbt_pipeline load_raw_data 2026-10-11
```

> Run all `astro` commands from the project root, not from inside `crm_dbt/`.

## dbt documentation

The dbt documentation site (model pages, column types, test coverage and the lineage graph) is generated
locally with a separate Windows profile, kept outside the project (for example `%USERPROFILE%\.dbt\profiles.yml`).
That profile must be named `crm_dbt`, use `type: duckdb`, and point `path` to a `crm_sales.duckdb` file on the host.

Run from `crm_dbt/`:

```powershell
dbt docs generate --profiles-dir "$HOME\.dbt"
dbt docs serve --profiles-dir "$HOME\.dbt" --port 8081
```

Then open http://localhost:8081 (port 8081 is used because Airflow occupies 8080) and use the
**Lineage Graph** button at the bottom right.

> The `profiles.yml` inside `crm_dbt/` points to `/usr/local/airflow/crm_sales.duckdb`, a path that
> exists only inside the Airflow container, and the DAG depends on it. Do not edit it for local use;
> `--profiles-dir` makes dbt use the external profile instead.

The site lists every model with its column types and test coverage, and the lineage graph shows the staging
models feeding the dimensions and the fact (the fact also depends on the dimensions through `ref()`).
Re-run `dbt docs generate` after any change to the models so the site reflects the current project.

> Model and column descriptions are not yet written in `schema.yml`, so the "Description" fields are empty.

![dbt lineage graph](docs/lineage_graph.png)

## Known issues and notes

- **Task logs permission error:** if a DAG run fails immediately and the UI shows
  `Could not read served logs`, the `logs` volume may be read-only for the `astro` user
  (`Permission denied` on `/usr/local/airflow/logs` in the scheduler log). Fix, from `astro dev bash --scheduler`:
  `chmod u+w /usr/local/airflow/logs`.
- **Database location:** the DAG writes `crm_sales.duckdb` inside the container. It is not synced back
  to the host copy and is rebuilt from the CSV files on every run of `load_raw_data`.
- **Deprecation warning:** `airflow.operators.bash.BashOperator` is deprecated in this Airflow version in favor of
  `airflow.providers.standard.operators.bash.BashOperator`. It does not affect execution.

## Author

Individual graduation project, DEPI Data Engineering track.

<!-- Add your name (and supervisor name, if required) here. -->
