-- Fails (returns a row) if the fact table lost or duplicated opportunities.
select 1
where (select count(*) from {{ ref('fact_opportunity') }})
   <> (select count(*) from {{ ref('stg_sales_pipeline') }})
