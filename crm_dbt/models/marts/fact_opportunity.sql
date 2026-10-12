-- One row per opportunity. Missing dimension references (e.g. no account yet,
-- no close date for open deals) point to the -1 "Unknown" member.
select
    p.opportunity_id,
    coalesce(a.account_key, -1) as account_key,
    coalesce(pr.product_key, -1) as product_key,
    coalesce(s.sales_agent_key, -1) as sales_agent_key,
    coalesce(cast(strftime(p.engage_date, '%Y%m%d') as integer), -1) as engage_date_key,
    coalesce(cast(strftime(p.close_date, '%Y%m%d') as integer), -1) as close_date_key,
    p.deal_stage,
    p.deal_stage in ('Won', 'Lost') as is_closed,
    p.deal_stage = 'Won' as is_won,
    cast(p.close_value as decimal(12, 2)) as close_value,
    cast(date_diff('day', p.engage_date, p.close_date) as integer) as sales_cycle_days
from {{ ref('stg_sales_pipeline') }} as p
left join {{ ref('dim_account') }} as a on p.account = a.account_name
left join {{ ref('dim_product') }} as pr on p.product = pr.product_name
left join {{ ref('dim_sales_agent') }} as s on p.sales_agent = s.sales_agent_name
