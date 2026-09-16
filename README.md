# Airbnb Market Analytics & Investment Platform

An end-to-end BI platform answering the questions a real Airbnb management
company or investor actually asks: which listings/neighborhoods earn the
most, which hosts perform best, which listings are mispriced, how seasonal
trends move demand, and where new investment has the best (estimated) yield.

Built on real Inside Airbnb data, with every derived and synthetic field
explicitly documented — no black-box numbers.

---

## Architecture

```
Inside Airbnb (listings.csv, calendar.csv, reviews.csv)
        │
        ▼
┌───────────────────────┐
│  Python (pandas)       │  scripts/01_data_cleaning.py
│  Phase 1               │  scripts/02_feature_engineering.py
│  Clean → Derive KPIs   │  → derives Revenue & Occupancy from calendar.csv
└───────────┬────────────┘
            ▼
┌───────────────────────┐
│  MySQL 8.0             │  sql/01_schema.sql        (8-table 3NF schema)
│  Phase 2               │  sql/02_load_data.sql     (data load)
│  Normalized storage +  │  sql/03_analytics_queries.sql (20 queries: CTEs,
│  analytics query layer │   window functions, recursive CTE, business KPIs)
└───────────┬────────────┘
            ▼
┌───────────────────────┐
│  Power BI               │  powerbi/power_query_m_scripts.pq
│  Phase 3                │  powerbi/dax_measures.dax (15 measures)
│  Star schema (galaxy:   │  docs/DASHBOARD_LAYOUT.md (7-page spec)
│  2 fact + 4 dim tables) │
└───────────┬────────────┘
            ▼
   7-page interactive dashboard
   (Executive, Revenue, Neighborhood, Pricing, Host, Reviews, Investment)
```

**Why this shape:** each layer does the job it's best at — Python for
messy real-world cleaning and feature derivation, SQL for a normalized
source of truth and a reusable query library, Power BI for a model
optimized for interactive slicing rather than transactional integrity.
This mirrors how analytics teams actually structure a pipeline, rather
than doing everything in one notebook.

---

## The core data logic

Inside Airbnb does not publish revenue or occupancy directly. Both are
**derived** from `calendar.csv`, where each row is one (listing, date)
with an `available` flag:

- `available = 'f'` (blocked) → treated as a **booked night**
- `occupancy_rate = booked_nights / total_nights_tracked`
- `revenue_estimate = SUM(price)` on booked nights

This is the standard convention used across Inside Airbnb analytics —
an estimate, not verified reservation data, since hosts occasionally
block dates for personal reasons. Every derived and synthetic field
(including the investment/ROI figures, which are built on an illustrative
property-valuation model, not real appraisals) is fully documented in
**[`docs/DATA_DICTIONARY.md`](docs/DATA_DICTIONARY.md)**.

---

## Tech stack

| Layer | Tools |
|---|---|
| Data source | [Inside Airbnb](https://insideairbnb.com) |
| Processing | Python 3.10+, pandas, numpy |
| Database | MySQL 8.0 (MySQL Workbench) |
| BI / Visualization | Power BI Desktop |
| ML (Phase 6) | scikit-learn |

---

## Repository structure

```
├── data/
│   ├── raw/                    # Inside Airbnb downloads (gitignored — see Setup)
│   └── processed/               # Pipeline output (gitignored)
├── scripts/
│   ├── 01_data_cleaning.py      # Types, nulls, outliers
│   ├── 02_feature_engineering.py # Revenue/Occupancy derivation + KPIs
│   ├── 03_export_for_mysql.py   # Splits output into the 8 normalized load CSVs
│   └── 04_ml_price_prediction.py # Bonus: scikit-learn price prediction model
├── sql/
│   ├── 01_schema.sql            # 3NF schema: 8 tables, PKs/FKs/constraints
│   ├── 02_load_data.sql         # LOAD DATA INFILE
│   ├── 02_load_data_workbench.md # MySQL Workbench import guide
│   └── 03_analytics_queries.sql # 20 queries — CTEs, window functions, recursive CTE
├── powerbi/
│   ├── power_query_m_scripts.pq # Star-schema build from MySQL source
│   └── dax_measures.dax         # KPI, time intelligence, ranking, and support measures
├── docs/
│   ├── DATA_DICTIONARY.md       # Every field: RAW / DERIVED / SYNTHETIC
│   ├── POWERBI_DATA_MODEL.md    # Star (galaxy) schema design
│   ├── DASHBOARD_LAYOUT.md      # 7-page visual spec, drill-through, bookmarks
│   ├── BUSINESS_INSIGHTS.md     # Finding → Root Cause → Recommendation, per page
│   ├── CAREER_ASSETS.md         # Resume bullets, LinkedIn/portfolio copy
│   ├── INTERVIEW_PREP.md        # 30 Q&A across SQL, Power BI, Python, business case
│   └── PROJECT_STRUCTURE.md     # Folder layout reference
└── requirements.txt
```

---

## Setup

### 1. Get the data
Download from [insideairbnb.com/get-the-data](https://insideairbnb.com/get-the-data/)
for one city (London or NYC recommended — richest, best-maintained exports):
`listings.csv.gz`, `calendar.csv.gz`, `reviews.csv.gz`. Unzip into `data/raw/`.

### 2. Run the Python pipeline
```bash
pip install -r requirements.txt
python scripts/01_data_cleaning.py
python scripts/02_feature_engineering.py
python scripts/03_export_for_mysql.py
python scripts/05_generate_business_insights.py
```
Output: `data/processed/master_analytics_table.csv`, 8 normalized CSVs in
`data/processed/mysql_load/`, and the current evidence-based insight pack in
`data/processed/business_insights.csv` plus `docs/BUSINESS_INSIGHTS_ACTUAL.md`.

### 3. Build the MySQL database
```bash
mysql -u root < sql/01_schema.sql
```
Then load data — see `sql/02_load_data_workbench.md` for both the GUI
(Table Data Import Wizard) and `LOAD DATA INFILE` options.

Run the query library:
```bash
mysql -u root airbnb_analytics < sql/03_analytics_queries.sql
```

### 4. Build the Power BI report
1. Power BI Desktop → **Get Data → MySQL database** → `localhost` / `airbnb_analytics`
2. Paste each query from `powerbi/power_query_m_scripts.pq` as a new blank query
3. Mark `DimDate` as the official date table (Modeling → Mark as Date Table)
4. Build the relationships per `docs/POWERBI_DATA_MODEL.md`
5. Create a `_Measures` table, add the measures from `powerbi/dax_measures.dax`
6. Build the 7 pages per `docs/DASHBOARD_LAYOUT.md`

### 5. (Bonus) Train the price prediction model
```bash
python scripts/04_ml_price_prediction.py
```
Trains and evaluates a Random Forest price model (RMSE/MAE/R² + feature
importance printed to console). Explicitly excludes every column
mathematically derived from `price` itself — see the leakage-avoidance
note at the top of the script.

### Refresh the dashboard inputs
After replacing the raw CSVs, rerun the pipeline and refresh the Power BI
queries. Review `docs/BUSINESS_INSIGHTS_ACTUAL.md` alongside the report; it
is generated from the same processed snapshot and keeps synthetic ROI clearly
separate from verified business metrics.

### Open the interactive website
The `dashboard/` folder contains a browser-based companion to the Power BI
report. From the project root, run:
```bash
python -m http.server 8000
```
Then open `http://localhost:8000/dashboard/`. The site reads the processed CSV
outputs directly and includes overview, market mix, pricing watch, filters,
and business-insight views.

---

## Known limitations

- **Revenue/Occupancy are estimates**, not verified bookings (see "core data logic" above)
- **Investment/ROI figures are synthetic** — built on an illustrative property-valuation
  formula, not real appraisal data. See `docs/DATA_DICTIONARY.md` and Page 7 of
  `docs/BUSINESS_INSIGHTS.md` for full disclosure and what a production fix would require.
- **YoY analysis** requires multiple dated Inside Airbnb snapshots — a single
  `calendar.csv` download is typically one forward-looking year, not multi-year history.

---

## License

MIT — data © Inside Airbnb, used under their terms.
