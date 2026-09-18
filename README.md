# E-commerce Analytics Platform with Microsoft Fabric

An end-to-end data engineering and analytics platform built with Microsoft Fabric.

The project ingests e-commerce transactional data from a local PostgreSQL database,
processes it through a Bronze-Silver-Gold Lakehouse architecture, builds a dimensional
star schema, serves analytics through Direct Lake on OneLake, and visualizes business
metrics in Power BI.

The complete workflow is orchestrated with Microsoft Fabric Data Pipeline.

---

## Architecture

```text
Local PostgreSQL
        |
        v
On-premises Data Gateway
        |
        v
Dataflow Gen2
        |
        v
Fabric Lakehouse / OneLake
        |
        v
Bronze
bronze_ecommerce_sales
        |
        v
nb_bronze_to_silver
        |
        v
Silver
silver_ecommerce_sales
        |
        v
nb_silver_to_gold
        |
        v
Gold Star Schema
        |
        v
Direct Lake on OneLake
        |
        v
Semantic Model
        |
        v
Power BI
```

The ingestion, transformation, and semantic-model refresh steps are orchestrated
through a Fabric Data Pipeline.

Detailed architecture documentation:

[Architecture Documentation](docs/architecture.md)

---

## Technology Stack

| Layer | Technology |
|---|---|
| Source | PostgreSQL |
| Local-to-cloud connectivity | On-premises Data Gateway |
| Ingestion | Dataflow Gen2 |
| Storage | Microsoft Fabric Lakehouse / OneLake |
| Processing | Apache Spark / Fabric Notebooks |
| Table format | Delta Lake |
| Data architecture | Bronze / Silver / Gold |
| Dimensional modeling | Star Schema |
| Semantic layer | Direct Lake on OneLake |
| Visualization | Power BI |
| Orchestration | Microsoft Fabric Data Pipeline |

---

## Dataset

The source contains:

| Metric | Value |
|---|---:|
| Orders | 20,000 |
| Source attributes | 16 |
| Minimum order date | 2025-01-01 |
| Maximum order date | 2025-12-31 |

Dataset grain:

> One row represents one order.

---

## Medallion Architecture

### Bronze

Source data is ingested from PostgreSQL into:

```text
dbo.bronze_ecommerce_sales
```

Validation:

```text
Rows             20,000
Distinct orders  20,000
```

The Bronze layer remains close to the source for traceability.

### Silver

Transformation:

```text
nb_bronze_to_silver
```

Output:

```text
dbo.silver_ecommerce_sales
```

Processing includes:

- string normalization
- explicit data-type enforcement
- required-field validation
- numeric and monetary validation
- business-rule validation
- date-derived attributes
- completed-order indicator

Validation:

```text
Rows             20,000
Distinct orders  20,000
```

### Gold

Gold contains one fact table and six dimensions:

```text
fact_sales

dim_date
dim_product
dim_customer
dim_region
dim_channel
dim_payment
```

Dimension counts:

| Table | Rows |
|---|---:|
| dim_product | 30 |
| dim_customer | 7,324 |
| dim_region | 3 |
| dim_channel | 3 |
| dim_payment | 4 |
| dim_date | 365 |

Fact validation:

```text
fact_sales rows       20,000
distinct orders       20,000

missing date_key           0
missing customer_key       0
missing product_key        0
missing region_key         0
missing channel_key        0
missing payment_key        0
```

---

## Data Quality Engineering

Profiling was performed before dimensional modeling.

The following validations returned zero invalid records:

- missing required identifiers
- invalid quantities
- invalid prices
- invalid discount percentages
- negative sales values
- financial formula mismatches
- missing Gold dimension keys

Financial rules:

```text
gross_sales
= quantity * unit_price

discount_amount
= gross_sales * discount_pct / 100

net_sales
= gross_sales - discount_amount
```

Full documentation:

[Data Quality Documentation](docs/data-quality.md)

Reusable validation SQL:

[Validation Queries](sql/validation_queries.sql)

---

## Profiling-Driven Modeling Decisions

Data profiling showed that the initial source assumptions could not safely be
used for dimensional modeling.

### Product

The source contained:

```text
899 distinct product IDs
30 distinct product names
6 categories
14,134 product_id/product_name/category combinations
```

A single `product_id` could map to multiple product names and categories.

However:

```text
product_name -> category
```

was stable in the observed dataset.

The Gold product dimension therefore uses the stable product-name/category
relationship instead of blindly treating `product_id` as the business key.

### Customer

One `customer_id` could appear in multiple regions.

Region was therefore modeled separately:

```text
dim_customer
dim_region
```

instead of treating region as a permanent customer attribute.

Detailed model documentation:

[Dimensional Model](docs/dimensional-model.md)

---

## Gold Star Schema

![Semantic Model](docs/screenshots/02_semantic_model_star_schema.png)

Relationships follow:

```text
Dimension 1 ---- * fact_sales
```

with single-direction filtering from dimensions toward the fact table.

---

## Semantic Model

The Gold layer is exposed through:

```text
sm_ecommerce_sales
```

using:

```text
Direct Lake on OneLake
```

Business measures include:

- Completed Revenue
- Total Orders
- Completed Orders
- Cancelled Orders
- Returned Orders
- Average Order Value
- Completed Quantity
- Return Rate
- Cancellation Rate

Completed Revenue uses completed orders rather than treating cancelled or
returned orders as realized revenue.

---

## Power BI Report

### Executive Overview

![Executive Overview](docs/screenshots/03_executive_overview.png)

Provides high-level revenue and operational KPIs.

### Sales Analysis

![Sales Analysis](docs/screenshots/04_sales_analysis.png)

Interactive analysis by:

- month
- category
- region
- sales channel
- payment method

### Product Analysis

![Product Analysis](docs/screenshots/05_product_analysis.png)

Includes:

- Top products by Completed Revenue
- Revenue by Category
- Completed Quantity by Product
- Average Order Value by Product
- Product Performance Matrix

---

## Pipeline Orchestration

The full workflow is orchestrated with:

```text
pl_ecommerce_end_to_end
```

Execution order:

```text
01_ingest_postgresql_to_bronze
                |
                v
02_bronze_to_silver
                |
                v
03_silver_to_gold
                |
                v
04_refresh_semantic_model
```

![Fabric Pipeline](docs/screenshots/01_pipeline_success.png)

End-to-end validation after a successful pipeline run:

```text
Bronze   20,000
Silver   20,000
Gold     20,000
```

---

## Repository Structure

```text
ecommerce-fabric-data-platform/
|
├── README.md
├── CHANGELOG.md
├── docs/
│   ├── architecture.md
│   ├── data-quality.md
│   ├── dimensional-model.md
│   └── screenshots/
│
├── notebooks/
│   ├── nb_bronze_to_silver.sql
│   └── nb_silver_to_gold.sql
│
└── sql/
    └── validation_queries.sql
```

---

## Transformation Source

Bronze to Silver:

[nb_bronze_to_silver.sql](notebooks/nb_bronze_to_silver.sql)

Silver to Gold:

[nb_silver_to_gold.sql](notebooks/nb_silver_to_gold.sql)

---

## Engineering Highlights

This project demonstrates:

- PostgreSQL-to-Fabric ingestion
- hybrid local/cloud connectivity
- Medallion Architecture
- Delta Lake
- Spark SQL transformations
- data-quality profiling
- business-key validation
- star-schema design
- surrogate-key modeling
- Direct Lake semantic modeling
- Power BI analytics
- Fabric Pipeline orchestration
- Git/GitHub feature-branch and pull-request workflow

---

## Current Scope and Limitations

The project is intentionally portfolio-scale.

Current implementation uses:

```text
20,000 source orders
Full-refresh transformations
ROW_NUMBER-based surrogate keys
Single development environment
```

It does not claim a production SLA.

---

## Future Improvements

Potential production enhancements include:

- incremental ingestion
- watermark-based processing
- MERGE-based Silver and Gold loads
- stable persistent surrogate keys
- Slowly Changing Dimensions
- rejected-record quarantine
- automated data-quality alerts
- dev/test/prod environments
- CI/CD deployment
- pipeline observability
- secrets management

---

## Outcome

The final platform implements the complete analytical flow:

```text
Operational Source
        ↓
Cloud Ingestion
        ↓
Lakehouse
        ↓
Data Quality
        ↓
Dimensional Modeling
        ↓
Semantic Layer
        ↓
Business Intelligence
        ↓
Pipeline Orchestration
```

The final end-to-end pipeline successfully processes all 20,000 source orders
through Bronze, Silver, Gold, Direct Lake, and Power BI.