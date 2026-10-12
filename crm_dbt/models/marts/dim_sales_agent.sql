select
    cast(row_number() over (order by sales_agent) as integer) as sales_agent_key,
    sales_agent as sales_agent_name,
    manager as manager_name,
    regional_office
from {{ ref('stg_sales_teams') }}

union all

select
    -1,
    'Unknown',
    'Unknown',
    'Unknown'
