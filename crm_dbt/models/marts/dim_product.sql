select
    cast(row_number() over (order by product) as integer) as product_key,
    product as product_name,
    series as product_series,
    cast(sales_price as decimal(10, 2)) as list_price
from {{ ref('stg_products') }}

union all

select
    -1,
    'Unknown',
    'Unknown',
    cast(0 as decimal(10, 2))
