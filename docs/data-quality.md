# Data Quality

## Overview

Data quality profiling was performed before building the Silver and Gold layers.

The objective was to validate:

- row completeness
- key completeness
- numeric validity
- financial consistency
- categorical consistency
- dimensional business-key assumptions
- foreign-key completeness

The profiling process directly influenced the final dimensional model.

---

## Dataset Baseline

Bronze table:

`dbo.bronze_ecommerce_sales`

Baseline:

| Metric | Result |
|---|---:|
| Total rows | 20,000 |
| Distinct orders | 20,000 |
| Minimum order date | 2025-01-01 |
| Maximum order date | 2025-12-31 |

Observed grain:

> One row represents one order.

---

## Schema Validation

The source contains 16 attributes.

Important data types include:

| Column | Type |
|---|---|
| order_id | varchar |
| order_date | date |
| customer_id | varchar |
| product_id | varchar |
| quantity | int |
| unit_price | decimal |
| discount_pct | decimal |
| gross_sales | decimal |
| discount_amount | decimal |
| net_sales | decimal |

All columns are technically nullable in the Lakehouse schema, so data-level validation was required.

---

## Completeness Checks

The following checks returned zero invalid rows:

| Rule | Invalid rows |
|---|---:|
| Missing order_id | 0 |
| Missing order_date | 0 |
| Missing customer_id | 0 |
| Missing product_id | 0 |
| Missing product_name | 0 |

---

## Numeric and Business Rules

The following business rules were validated:

| Rule | Invalid rows |
|---|---:|
| quantity <= 0 | 0 |
| unit_price < 0 | 0 |
| discount_pct outside 0-100 | 0 |
| gross_sales < 0 | 0 |
| discount_amount < 0 | 0 |
| net_sales < 0 | 0 |

Cancelled and returned orders were not treated as invalid records.

They represent valid business states and are preserved through the Silver and Gold layers.

---

## Financial Formula Validation

The following formulas were validated:

```text
gross_sales
= quantity * unit_price

discount_amount
= gross_sales * discount_pct / 100

net_sales
= gross_sales - discount_amount

Results:

Validation	Mismatches
gross_sales formula	0
discount_amount formula	0
net_sales formula	0
Categorical Profiling
Order Status
Status	Rows
Completed	13,356
Cancelled	3,366
Returned	3,278
Category
Category	Rows
Sports	3,395
Home & Kitchen	3,388
Electronics	3,349
Beauty	3,339
Books	3,313
Fashion	3,216
Region
Region	Rows
South	8,080
North	6,973
Central	4,947
Sales Channel
Channel	Rows
Website	10,045
Mobile App	5,954
Marketplace	4,001
Payment Method
Method	Rows
Cash on Delivery	5,079
E-Wallet	5,027
Credit Card	4,982
Bank Transfer	4,912
Business-Key Profiling

Initial dimensional modeling assumed that product_id could uniquely identify a product.

Profiling disproved that assumption.

Observed results:

Metric	Result
Distinct product IDs	899
Distinct product names	30
Distinct categories	6
Distinct product_id/product_name/category combinations	14,134

A single product_id could be associated with multiple product names and categories.

However:

product_name -> category

was stable in the observed dataset.

Therefore, the Gold product dimension uses the stable product-name/category relationship rather than blindly treating product_id as the dimensional business key.

Customer and Region Profiling

Profiling also showed that one customer_id could appear in multiple regions.

Therefore:

customer_id -> region

was not treated as a fixed dependency.

The final Gold model separates:

dim_customer
dim_region

This avoids incorrectly storing Region as a permanent Customer attribute.

Silver Validation

After Bronze-to-Silver processing:

Metric	Result
Silver rows	20,000
Distinct orders	20,000
Minimum order date	2025-01-01
Maximum order date	2025-12-31

No records were lost during Silver transformation.

Gold Referential Integrity

Final Gold validation:

Check	Result
fact_sales rows	20,000
distinct orders	20,000
missing date_key	0
missing customer_key	0
missing product_key	0
missing region_key	0
missing channel_key	0
missing payment_key	0

This confirms that the dimensional joins neither duplicated nor lost source orders.

Engineering Outcome

Data profiling was performed before dimensional modeling.

The most important result was that profiling invalidated two initial modeling assumptions:

product_id was not a reliable product business key.
customer_id did not uniquely determine Region.

The dimensional model was changed based on observed data relationships rather than forcing the source data into an assumed star schema.


---

