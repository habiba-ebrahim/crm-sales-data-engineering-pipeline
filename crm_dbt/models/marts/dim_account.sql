-- Surrogate keys are assigned deterministically by account name.
-- -1 is the "Unknown" member for opportunities with no account yet.
with keyed as (

    select
        cast(row_number() over (order by account) as integer) as account_key,
        *
    from {{ ref('stg_accounts') }}

)

select
    child.account_key,
    child.account as account_name,
    child.sector,
    cast(child.year_established as smallint) as year_established,
    cast(child.revenue as decimal(12, 2)) as annual_revenue_musd,
    cast(child.employees as integer) as employee_count,
    child.office_location,
    child.subsidiary_of is not null as is_subsidiary,
    parent.account_key as parent_account_key
from keyed as child
left join keyed as parent
    on child.subsidiary_of = parent.account

union all

select
    -1,
    'Unknown',
    'Unknown',
    cast(null as smallint),
    cast(null as decimal(12, 2)),
    cast(null as integer),
    cast(null as varchar),
    false,
    cast(null as integer)
