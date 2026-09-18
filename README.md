# E-commerce Analytics Platform with Microsoft Fabric

## Overview

This project implements an end-to-end data engineering and analytics pipeline using Microsoft Fabric.

E-commerce transactional data is ingested from a local PostgreSQL database through an on-premises data gateway and Dataflow Gen2, processed through Bronze, Silver, and Gold layers in a Fabric Lakehouse, modeled as a dimensional star schema, and served to Power BI through Direct Lake on OneLake.

The complete workflow is orchestrated using a Microsoft Fabric Data Pipeline.

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
Microsoft Fabric Lakehouse
        |
        v
Bronze
bronze_ecommerce_sales
        |
        v
Fabric Notebook
nb_bronze_to_silver
        |
        v
Silver
silver_ecommerce_sales
        |
        v
Fabric Notebook
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