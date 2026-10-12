-- Fails if total close_value in the fact differs from the staging layer.
select 1
where (select coalesce(sum(close_value), 0) from {{ ref('fact_opportunity') }})
   <> (select coalesce(sum(close_value), 0) from {{ ref('stg_sales_pipeline') }})
