-- ============================================================
-- E-commerce Fabric Data Platform
-- Data Quality Validation Queries
-- ============================================================


-- ------------------------------------------------------------
-- 1. Bronze baseline
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    MIN(order_date) AS min_order_date,
    MAX(order_date) AS max_order_date
FROM dbo.bronze_ecommerce_sales;


-- ------------------------------------------------------------
-- 2. Schema inspection
-- ------------------------------------------------------------

SELECT
    ORDINAL_POSITION,
    COLUMN_NAME,
    DATA_TYPE,
    IS_NULLABLE
FROM INFORMATION_SCHEMA.COLUMNS
WHERE TABLE_SCHEMA = 'dbo'
  AND TABLE_NAME = 'bronze_ecommerce_sales'
ORDER BY ORDINAL_POSITION;


-- ------------------------------------------------------------
-- 3. Completeness and numeric validation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS total_rows,

    SUM(
        CASE
            WHEN order_id IS NULL OR TRIM(order_id) = ''
            THEN 1 ELSE 0
        END
    ) AS bad_order_id,

    SUM(
        CASE
            WHEN order_date IS NULL
            THEN 1 ELSE 0
        END
    ) AS bad_order_date,

    SUM(
        CASE
            WHEN customer_id IS NULL OR TRIM(customer_id) = ''
            THEN 1 ELSE 0
        END
    ) AS bad_customer_id,

    SUM(
        CASE
            WHEN product_id IS NULL OR TRIM(product_id) = ''
            THEN 1 ELSE 0
        END
    ) AS bad_product_id,

    SUM(
        CASE
            WHEN quantity IS NULL OR quantity <= 0
            THEN 1 ELSE 0
        END
    ) AS invalid_quantity,

    SUM(
        CASE
            WHEN unit_price IS NULL OR unit_price < 0
            THEN 1 ELSE 0
        END
    ) AS invalid_unit_price,

    SUM(
        CASE
            WHEN discount_pct IS NULL
              OR discount_pct < 0
              OR discount_pct > 100
            THEN 1 ELSE 0
        END
    ) AS invalid_discount_pct,

    SUM(
        CASE
            WHEN gross_sales IS NULL OR gross_sales < 0
            THEN 1 ELSE 0
        END
    ) AS invalid_gross_sales,

    SUM(
        CASE
            WHEN discount_amount IS NULL OR discount_amount < 0
            THEN 1 ELSE 0
        END
    ) AS invalid_discount_amount,

    SUM(
        CASE
            WHEN net_sales IS NULL OR net_sales < 0
            THEN 1 ELSE 0
        END
    ) AS invalid_net_sales

FROM dbo.bronze_ecommerce_sales;


-- ------------------------------------------------------------
-- 4. Financial formula validation
-- ------------------------------------------------------------

SELECT
    SUM(
        CASE
            WHEN ABS(
                gross_sales - (quantity * unit_price)
            ) > 0.01
            THEN 1 ELSE 0
        END
    ) AS gross_sales_mismatch,

    SUM(
        CASE
            WHEN ABS(
                discount_amount
                - (gross_sales * discount_pct / 100.0)
            ) > 0.01
            THEN 1 ELSE 0
        END
    ) AS discount_amount_mismatch,

    SUM(
        CASE
            WHEN ABS(
                net_sales
                - (gross_sales - discount_amount)
            ) > 0.01
            THEN 1 ELSE 0
        END
    ) AS net_sales_mismatch

FROM dbo.bronze_ecommerce_sales;


-- ------------------------------------------------------------
-- 5. Product business-key consistency
-- ------------------------------------------------------------

SELECT
    product_id,
    COUNT(DISTINCT product_name) AS product_names,
    COUNT(DISTINCT category) AS categories
FROM dbo.silver_ecommerce_sales
GROUP BY product_id
HAVING COUNT(DISTINCT product_name) > 1
    OR COUNT(DISTINCT category) > 1;


-- ------------------------------------------------------------
-- 6. Customer-region consistency
-- ------------------------------------------------------------

SELECT
    customer_id,
    COUNT(DISTINCT region) AS regions
FROM dbo.silver_ecommerce_sales
GROUP BY customer_id
HAVING COUNT(DISTINCT region) > 1;


-- ------------------------------------------------------------
-- 7. Product profiling summary
-- ------------------------------------------------------------

SELECT
    COUNT(DISTINCT product_id) AS product_ids,
    COUNT(DISTINCT product_name) AS product_names,
    COUNT(DISTINCT category) AS categories,
    COUNT(
        DISTINCT CONCAT(
            product_id,
            '||',
            product_name,
            '||',
            category
        )
    ) AS product_combinations
FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 8. Product-name consistency
-- ------------------------------------------------------------

SELECT
    product_name,
    COUNT(DISTINCT category) AS categories,
    COUNT(DISTINCT product_id) AS product_ids
FROM dbo.silver_ecommerce_sales
GROUP BY product_name
ORDER BY categories DESC, product_ids DESC;


-- ------------------------------------------------------------
-- 9. Silver reconciliation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS silver_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,
    MIN(order_date) AS min_order_date,
    MAX(order_date) AS max_order_date
FROM dbo.silver_ecommerce_sales;


-- ------------------------------------------------------------
-- 10. Gold referential-integrity validation
-- ------------------------------------------------------------

SELECT
    COUNT(*) AS fact_rows,
    COUNT(DISTINCT order_id) AS distinct_orders,

    SUM(CASE WHEN date_key IS NULL THEN 1 ELSE 0 END)
        AS missing_date_key,

    SUM(CASE WHEN customer_key IS NULL THEN 1 ELSE 0 END)
        AS missing_customer_key,

    SUM(CASE WHEN product_key IS NULL THEN 1 ELSE 0 END)
        AS missing_product_key,

    SUM(CASE WHEN region_key IS NULL THEN 1 ELSE 0 END)
        AS missing_region_key,

    SUM(CASE WHEN channel_key IS NULL THEN 1 ELSE 0 END)
        AS missing_channel_key,

    SUM(CASE WHEN payment_key IS NULL THEN 1 ELSE 0 END)
        AS missing_payment_key

FROM dbo.fact_sales;


-- ------------------------------------------------------------
-- 11. Dimension row counts
-- ------------------------------------------------------------

SELECT 'dim_product' AS table_name, COUNT(*) AS row_count
FROM dbo.dim_product

UNION ALL

SELECT 'dim_customer', COUNT(*)
FROM dbo.dim_customer

UNION ALL

SELECT 'dim_region', COUNT(*)
FROM dbo.dim_region

UNION ALL

SELECT 'dim_channel', COUNT(*)
FROM dbo.dim_channel

UNION ALL

SELECT 'dim_payment', COUNT(*)
FROM dbo.dim_payment

UNION ALL

SELECT 'dim_date', COUNT(*)
FROM dbo.dim_date;