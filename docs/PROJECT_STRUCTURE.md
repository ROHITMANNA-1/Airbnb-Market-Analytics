# Project Folder Structure

```
airbnb-market-analytics/
├── data/
│   ├── raw/                    # Untouched Inside Airbnb downloads go here
│   │   ├── listings.csv
│   │   ├── calendar.csv
│   │   └── reviews.csv
│   └── processed/              # Output of scripts/ — clean, analysis-ready tables
│       ├── listings_clean.csv
│       ├── calendar_clean.csv
│       ├── reviews_clean.csv
│       └── master_analytics_table.csv   # Final table -> loaded into SQL / Power BI
├── scripts/
│   ├── 01_data_cleaning.py     # Raw -> clean (types, nulls, outliers)
│   └── 02_feature_engineering.py  # Clean -> Revenue, Occupancy, KPIs, master table
├── sql/                        # Phase 2: DDL + query library
├── powerbi/                    # Phase 3: .pbix file + DAX documentation
├── docs/
│   ├── PROJECT_STRUCTURE.md
│   └── DATA_DICTIONARY.md      # Every derived/synthetic field documented here
├── notebooks/                  # Optional exploratory analysis (not required for pipeline)
├── requirements.txt
├── .gitignore
└── README.md                   # Full project write-up (built in Phase 4)
```

## Setup instructions

1. Go to https://insideairbnb.com/get-the-data/ and download, for one city
   (recommend **London** or **New York City** — both have rich, well-maintained data):
   - `listings.csv.gz`
   - `calendar.csv.gz`
   - `reviews.csv.gz`
2. Unzip and place all three into `data/raw/`.
3. `pip install -r requirements.txt`
4. Run in order:
   ```bash
   python scripts/01_data_cleaning.py
   python scripts/02_feature_engineering.py
   ```
5. Output lands in `data/processed/master_analytics_table.csv` — this is what
   Phase 2 (SQL) will load.
