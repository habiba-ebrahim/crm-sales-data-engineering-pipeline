SELECT
    TRIM(account) AS account,
    TRIM(sector) AS sector,
    year_established,
    revenue,
    employees,
    TRIM(office_location) AS office_location,
    TRIM(subsidiary_of) AS subsidiary_of
FROM raw_accounts