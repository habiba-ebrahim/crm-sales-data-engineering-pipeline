SELECT
    TRIM(opportunity_id) AS opportunity_id,
    TRIM(sales_agent) AS sales_agent,
    CASE
    WHEN TRIM(product) = 'GTXPro' THEN 'GTX Pro'
    ELSE TRIM(product)
END AS product,
    TRIM(account) AS account,
    TRIM(deal_stage) AS deal_stage,
    CAST(engage_date AS DATE) AS engage_date,
    CAST(close_date AS DATE) AS close_date,
    close_value
FROM raw_sales_pipeline