-- Date dimension covering every full calendar year found in the pipeline data.
-- date_key uses the yyyymmdd convention; -1 is the "Unknown" member used for
-- opportunities that have no engage date or no close date yet.
with bounds as (

    select
        make_date(year(least(min(engage_date), min(close_date))), 1, 1) as start_date,
        make_date(year(greatest(max(engage_date), max(close_date))), 12, 31) as end_date
    from {{ ref('stg_sales_pipeline') }}

),

calendar as (

    select cast(d as date) as full_date
    from bounds,
         generate_series(bounds.start_date, bounds.end_date, interval 1 day) as t(d)

)

select
    cast(strftime(full_date, '%Y%m%d') as integer) as date_key,
    full_date,
    cast(year(full_date) as smallint) as calendar_year,
    cast(quarter(full_date) as smallint) as calendar_quarter,
    cast(month(full_date) as smallint) as calendar_month,
    cast(monthname(full_date) as varchar) as month_name,
    strftime(full_date, '%Y-%m') as year_month,
    cast(weekofyear(full_date) as smallint) as week_of_year,
    cast(isodow(full_date) as smallint) as day_of_week,
    cast(dayname(full_date) as varchar) as day_name,
    isodow(full_date) >= 6 as is_weekend
from calendar

union all

select
    -1,
    cast(null as date),
    cast(null as smallint),
    cast(null as smallint),
    cast(null as smallint),
    'Unknown',
    'Unknown',
    cast(null as smallint),
    cast(null as smallint),
    'Unknown',
    cast(null as boolean)
