-- ============================================================
-- E-commerce Fabric Data Platform
-- Bronze -> Silver Transformation
--
-- Fabric notebook:
--   nb_bronze_to_silver
--
-- Source:
--   dbo.bronze_ecommerce_sales
--
-- Target:
--   dbo.silver_ecommerce_sales
--
-- Grain:
--   One row represents one order
--
-- Processing mode:
--   Full refresh
-- ============================================================


-- ------------------------------------------------------------
-- 1. Build Silver table
-- ------------------------------------------------------------
--
-- Silver responsibilities:
--   - normalize string attributes
--   - enforce analytical data types
--   - validate required business fields
--   - validate numeric ranges
--   - retain valid business states
--   - derive analytical date attributes
--
-- Cancelled and Returned orders are intentionally preserved.
-- They are valid business states, not invalid records.
-- ------------------------------------------------------------

CREATE OR REPLACE TABLE dbo.silver_ecommerce_sales
USING DELTA
AS

SELECT
    TRIM(order_id) AS order_id,

    CAST(order_date AS DATE) AS order_date,

    TRIM(customer_id) AS customer_id,

    TRIM(product_id) AS product_id,

    TRIM(product_name) AS product_name,

    TRIM(category) AS category,

    TRIM(region) AS region,

    TRIM(sales_channel) AS sales_channel,

    TRIM(payment_method) AS payment_method,

    CAST(quantity AS INT) AS quantity,

    CAST(unit_price AS DECIMAL(18, 2)) AS unit_price,

    CAST(discount_pct AS DECIMAL(5, 2)) AS discount_pct,

    TRIM(order_status) AS order_status,

    CAST(gross_sales AS DECIMAL(18, 2)) AS gross_sales,

    CAST(discount_amount AS DECIMAL(18, 2)) AS discount_amount,

    CAST(net_sales AS DECIMAL(18, 2)) AS net_sales,

    YEAR(order_date) AS order_year,

    MONTH(order_date) AS order_month,

    CASE
        WHEN TRIM(order_status) = 'Completed'
            THEN TRUE
        ELSE FALSE
    END AS is_completed_order

FROM dbo.bronze_ecommerce_sales

WHERE
    -- Required identifiers
    order_id IS NOT NULL
    AND TRIM(order_id) <> ''

    AND order_date IS NOT NULL

    AND customer_id IS NOT NULL
    AND TRIM(customer_id) <> ''

    AND product_id IS NOT NULL
    AND TRIM(product_id) <> ''

    -- Numeric business rules
    AND quantity > 0

    AND unit_price >= 0

    AND discount_pct BETWEEN 0 AND 100

    -- Monetary rules
    AND gross_sales >= 0

    AND discount_amount >= 0

    AND net_sales >= 0;


-- ------------------------------------------------------------
-- 2. Row-count and grain validation
-- ------------------------------------------------------------
--
-- Expected:
--   silver_rows      = 20000
--   distinct_orders  = 20000
--   min_order_date   = 2025-01-01
--   max_order_date   = 2025-12-31
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS silver_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    MIN(order_date) AS min_order_date,
    MAX(order_date) AS max_order_date
FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 3. Order-status validation
-- ------------------------------------------------------------
--
-- Expected:
--
-- Completed   true     13356
-- Cancelled   false     3366
-- Returned    false     3278
-- ------------------------------------------------------------

SELECT
    order_status,
    is_completed_order,
    COUNT(*) AS row_count
FROM dbo.silver_ecommerce_sales
GROUP BY
    order_status,
    is_completed_order
ORDER BY
    row_count DESC;


-- ------------------------------------------------------------
-- 4. Required-field validation
-- ------------------------------------------------------------
--
-- Expected:
--   all invalid counts = 0
-- ------------------------------------------------------------

SELECT
    SUM(
        CASE
            WHEN order_id IS NULL
                OR TRIM(order_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS invalid_order_id,

    SUM(
        CASE
            WHEN order_date IS NULL
            THEN 1
            ELSE 0
        END
    ) AS invalid_order_date,

    SUM(
        CASE
            WHEN customer_id IS NULL
                OR TRIM(customer_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS invalid_customer_id,

    SUM(
        CASE
            WHEN product_id IS NULL
                OR TRIM(product_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS invalid_product_id,

    SUM(
        CASE
            WHEN product_name IS NULL
                OR TRIM(product_name) = ''
            THEN 1
            ELSE 0
        END
    ) AS invalid_product_name

FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 5. Numeric validation
-- ------------------------------------------------------------
--
-- Expected:
--   all invalid counts = 0
-- ------------------------------------------------------------

SELECT
    SUM(
        CASE
            WHEN quantity <= 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_quantity,

    SUM(
        CASE
            WHEN unit_price < 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_unit_price,

    SUM(
        CASE
            WHEN discount_pct < 0
                OR discount_pct > 100
            THEN 1
            ELSE 0
        END
    ) AS invalid_discount_pct,

    SUM(
        CASE
            WHEN gross_sales < 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_gross_sales,

    SUM(
        CASE
            WHEN discount_amount < 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_discount_amount,

    SUM(
        CASE
            WHEN net_sales < 0
            THEN 1
            ELSE 0
        END
    ) AS invalid_net_sales

FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 6. Financial formula validation
-- ------------------------------------------------------------
--
-- Expected:
--   gross_sales_mismatch       = 0
--   discount_amount_mismatch   = 0
--   net_sales_mismatch         = 0
-- ------------------------------------------------------------

SELECT
    SUM(
        CASE
            WHEN ABS(
                gross_sales
                - (quantity * unit_price)
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS gross_sales_mismatch,

    SUM(
        CASE
            WHEN ABS(
                discount_amount
                - (gross_sales * discount_pct / 100.0)
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS discount_amount_mismatch,

    SUM(
        CASE
            WHEN ABS(
                net_sales
                - (gross_sales - discount_amount)
            ) > 0.01
            THEN 1
            ELSE 0
        END
    ) AS net_sales_mismatch

FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 7. Sample inspection
-- ------------------------------------------------------------

SELECT *
FROM dbo.silver_ecommerce_sales
LIMIT 20;