# RetailPulse Business Analyst Project

An end-to-end retail analytics case study built around a synthetic Superstore-style order dataset. It demonstrates the full workflow from raw order generation and quality checks to SQL analysis and a Power BI executive dashboard.

## Business brief

RetailPulse leadership wants to answer four questions:

1. Which products, categories, and regions create profitable growth?
2. Where are discounts destroying margin?
3. Which customers and segments should receive retention attention?
4. How much does shipping performance affect customer experience and profit?

## Project outputs

- `data/raw/orders.csv`: reproducible synthetic source data.
- `data/processed/orders_clean.csv`: validated, analysis-ready order-line data.
- `data/processed/monthly_kpis.csv`: monthly KPI table for quick reporting.
- `data/processed/customer_summary.csv`: customer-level RFM and profitability summary.
- `python/generate_data.py`: deterministic raw data generator.
- `python/analysis.py`: validation, feature engineering, KPI analysis, and chart export.
- `sql/01_schema.sql`: PostgreSQL-compatible warehouse schema and loading pattern.
- `sql/02_insight_queries.sql`: business questions expressed as SQL.
- `powerbi/README.md`: Power BI build instructions and page design.
- `powerbi/measures.dax`: dashboard measures and calculation logic.
- `powerbi/PowerBI_Data_Model.md`: relationships, grain, and modeling decisions.
- `reports/insights.md`: executive findings, recommendations, and limitations.
- `dashboard/app.py`: interactive Streamlit dashboard with filters and Plotly visuals.

## Quick start

### 1. Install dependencies

```bash
python -m venv .venv
.venv\\Scripts\\activate
pip install -r requirements.txt
```

### 2. Run the pipeline

```bash
python python/generate_data.py
python python/analysis.py
```

The scripts create the `data/raw`, `data/processed`, and `reports/charts` outputs. The generator uses a fixed seed, so the results are repeatable.

### 3. Run SQL

The SQL is written for PostgreSQL. Load `data/processed/orders_clean.csv` into `analytics.fact_orders` after creating the schema, then execute the queries in `sql/02_insight_queries.sql`.

### 4. Build the Power BI report

Open Power BI Desktop, load `data/processed/orders_clean.csv`, create the calendar and dimensions described in `powerbi/PowerBI_Data_Model.md`, add the measures in `powerbi/measures.dax`, and follow `powerbi/README.md` for the four report pages.

### 5. Run the interactive dashboard

```bash
python -m streamlit run dashboard/app.py
```

The dashboard provides shared date, region, segment, category, and delivery-status filters across executive, profitability, customer, and operations views. See `dashboard/README.md` for details.

## Metric definitions

- **Sales** = `sales_amount`
- **Cost** = `cost_amount`
- **Profit** = `sales_amount - cost_amount`
- **Profit margin** = `profit / sales`
- **Discount rate** = `discount_amount / gross_sales_amount`
- **Delivery days** = `ship_date - order_date`
- **Late delivery** = delivery days greater than the promised delivery days
- **Order-line grain** = one product on one customer order. An order can have multiple rows.

## Project assumptions

This is portfolio-safe synthetic data, not a representation of a real retailer. The business patterns are intentionally plausible so that the analysis demonstrates method without exposing private customer information.
