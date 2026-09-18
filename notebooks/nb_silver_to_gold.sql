-- ============================================================
-- E-commerce Fabric Data Platform
-- Silver -> Gold Transformation
--
-- Fabric notebook:
--   nb_silver_to_gold
--
-- Source:
--   dbo.silver_ecommerce_sales
--
-- Targets:
--   dbo.dim_date
--   dbo.dim_product
--   dbo.dim_customer
--   dbo.dim_region
--   dbo.dim_channel
--   dbo.dim_payment
--   dbo.fact_sales
--
-- Fact grain:
--   One row represents one order
--
-- Processing mode:
--   Full refresh
-- ============================================================


-- ------------------------------------------------------------
-- 1. Product business-key profiling
-- ------------------------------------------------------------
--
-- product_id is NOT a reliable dimensional business key.
--
-- Observed profiling:
--   product IDs:            899
--   product names:           30
--   categories:               6
--   source combinations: 14,134
--
-- product_name -> category is stable in the observed dataset.
-- ------------------------------------------------------------

SELECT
    product_id,
    COUNT(DISTINCT product_name) AS product_names,
    COUNT(DISTINCT category) AS categories
FROM dbo.silver_ecommerce_sales
GROUP BY product_id
HAVING
       COUNT(DISTINCT product_name) > 1
    OR COUNT(DISTINCT category) > 1;


-- ------------------------------------------------------------
-- 2. Customer-region profiling
-- ------------------------------------------------------------
--
-- customer_id does NOT uniquely determine region.
-- Region is therefore modeled as a separate dimension.
-- ------------------------------------------------------------

SELECT
    customer_id,
    COUNT(DISTINCT region) AS regions
FROM dbo.silver_ecommerce_sales
GROUP BY customer_id
HAVING COUNT(DISTINCT region) > 1;


-- ------------------------------------------------------------
-- 3. Create dim_product
-- ------------------------------------------------------------
--
-- Grain:
--   One row per logical product_name/category combination
--
-- Expected rows:
--   30
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_product
USING DELTA
AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY product_name
    ) AS product_key,

    product_name,
    category

FROM (
    SELECT DISTINCT
        product_name,
        category
    FROM dbo.silver_ecommerce_sales
);


-- ------------------------------------------------------------
-- 4. Create dim_customer
-- ------------------------------------------------------------
--
-- Grain:
--   One row per customer_id
--
-- Expected rows:
--   7,324
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_customer
USING DELTA
AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY customer_id
    ) AS customer_key,

    customer_id

FROM (
    SELECT DISTINCT
        customer_id
    FROM dbo.silver_ecommerce_sales
);


-- ------------------------------------------------------------
-- 5. Create dim_region
-- ------------------------------------------------------------
--
-- Grain:
--   One row per region
--
-- Expected rows:
--   3
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_region
USING DELTA
AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY region
    ) AS region_key,

    region

FROM (
    SELECT DISTINCT
        region
    FROM dbo.silver_ecommerce_sales
);


-- ------------------------------------------------------------
-- 6. Create dim_channel
-- ------------------------------------------------------------
--
-- Grain:
--   One row per sales channel
--
-- Expected rows:
--   3
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_channel
USING DELTA
AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY sales_channel
    ) AS channel_key,

    sales_channel

FROM (
    SELECT DISTINCT
        sales_channel
    FROM dbo.silver_ecommerce_sales
);


-- ------------------------------------------------------------
-- 7. Create dim_payment
-- ------------------------------------------------------------
--
-- Grain:
--   One row per payment method
--
-- Expected rows:
--   4
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_payment
USING DELTA
AS

SELECT
    ROW_NUMBER() OVER (
        ORDER BY payment_method
    ) AS payment_key,

    payment_method

FROM (
    SELECT DISTINCT
        payment_method
    FROM dbo.silver_ecommerce_sales
);


-- ------------------------------------------------------------
-- 8. Create dim_date
-- ------------------------------------------------------------
--
-- Grain:
--   One row per calendar date
--
-- Expected date range:
--   2025-01-01 -> 2025-12-31
--
-- Expected rows:
--   365
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.dim_date
USING DELTA
AS

WITH date_bounds AS (

    SELECT
        MIN(order_date) AS min_date,
        MAX(order_date) AS max_date
    FROM dbo.silver_ecommerce_sales

),

calendar AS (

    SELECT
        EXPLODE(
            SEQUENCE(
                min_date,
                max_date,
                INTERVAL 1 DAY
            )
        ) AS full_date

    FROM date_bounds

)

SELECT
    CAST(
        DATE_FORMAT(full_date, 'yyyyMMdd')
        AS INT
    ) AS date_key,

    full_date,

    YEAR(full_date) AS year,

    QUARTER(full_date) AS quarter,

    MONTH(full_date) AS month_number,

    DATE_FORMAT(
        full_date,
        'MMMM'
    ) AS month_name,

    DAY(full_date) AS day_of_month,

    DATE_FORMAT(
        full_date,
        'EEEE'
    ) AS day_name

FROM calendar;


-- ------------------------------------------------------------
-- 9. Create fact_sales
-- ------------------------------------------------------------
--
-- Grain:
--   One row per order
--
-- product_name is used to resolve product_key because source
-- product_id was shown by profiling to be unstable.
--
-- source_product_id is retained for traceability.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.fact_sales
USING DELTA
AS

SELECT
    s.order_id,

    d.date_key,
    c.customer_key,
    p.product_key,
    r.region_key,
    ch.channel_key,
    pm.payment_key,

    s.product_id AS source_product_id,

    s.quantity,
    s.unit_price,
    s.discount_pct,

    s.gross_sales,
    s.discount_amount,
    s.net_sales,

    s.order_status,
    s.is_completed_order

FROM dbo.silver_ecommerce_sales AS s

LEFT JOIN dbo.dim_date AS d
    ON s.order_date = d.full_date

LEFT JOIN dbo.dim_customer AS c
    ON s.customer_id = c.customer_id

LEFT JOIN dbo.dim_product AS p
    ON s.product_name = p.product_name

LEFT JOIN dbo.dim_region AS r
    ON s.region = r.region

LEFT JOIN dbo.dim_channel AS ch
    ON s.sales_channel = ch.sales_channel

LEFT JOIN dbo.dim_payment AS pm
    ON s.payment_method = pm.payment_method;


-- ------------------------------------------------------------
-- 10. Fact grain and referential-integrity validation
-- ------------------------------------------------------------
--
-- Expected:
--
-- fact_rows            = 20000
-- distinct_orders      = 20000
--
-- all missing keys     = 0
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS fact_rows,

    COUNT(
        DISTINCT order_id
    ) AS distinct_orders,

    SUM(
        CASE
            WHEN date_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_date_key,

    SUM(
        CASE
            WHEN customer_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_customer_key,

    SUM(
        CASE
            WHEN product_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_product_key,

    SUM(
        CASE
            WHEN region_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_region_key,

    SUM(
        CASE
            WHEN channel_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_channel_key,

    SUM(
        CASE
            WHEN payment_key IS NULL
            THEN 1
            ELSE 0
        END
    ) AS missing_payment_key

FROM dbo.fact_sales;


-- ------------------------------------------------------------
-- 11. Dimension row-count validation
-- ------------------------------------------------------------

SELECT
    'dim_product' AS table_name,
    COUNT(*) AS row_count
FROM dbo.dim_product

UNION ALL

SELECT
    'dim_customer',
    COUNT(*)
FROM dbo.dim_customer

UNION ALL

SELECT
    'dim_region',
    COUNT(*)
FROM dbo.dim_region

UNION ALL

SELECT
    'dim_channel',
    COUNT(*)
FROM dbo.dim_channel

UNION ALL

SELECT
    'dim_payment',
    COUNT(*)
FROM dbo.dim_payment

UNION ALL

SELECT
    'dim_date',
    COUNT(*)
FROM dbo.dim_date;


-- ------------------------------------------------------------
-- 12. Fact sample inspection
-- ------------------------------------------------------------

SELECT *
FROM dbo.fact_sales
LIMIT 20;