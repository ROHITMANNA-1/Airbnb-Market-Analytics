# Loading Data — MySQL Workbench

You have two options. **Option A (Import Wizard)** is the friendlier,
click-through option and is what most people mean by "using MySQL
Workbench." **Option B (LOAD DATA)** is faster for large files like
`calendar_daily.csv` and is what a data analyst would actually use in
practice — worth knowing for interviews.

## Before either option
Run the schema script first:
```sql
-- In Workbench: File -> Open SQL Script -> sql/01_schema.sql -> Execute (⚡ icon)
```
This creates the `airbnb_analytics` database and all 8 tables.

Then generate the load-ready CSVs (if you haven't already):
```bash
python scripts/03_export_for_mysql.py
```
This writes 8 files to `data/processed/mysql_load/`.

## Option A — Table Data Import Wizard (GUI)

Load in this exact order (respects foreign keys):
`neighbourhoods → hosts → listings → listing_performance → listing_valuation → calendar_daily → reviews → review_scores`

For each file:
1. Right-click the target schema (`airbnb_analytics`) in the Navigator → **Table Data Import Wizard**
2. Browse to the corresponding CSV in `data/processed/mysql_load/`
3. Choose **"Use existing table"** and select the matching table name
4. Confirm the column mapping (should auto-match since CSV headers = column names)
5. Run

## Option B — LOAD DATA INFILE (SQL script)

MySQL restricts `LOAD DATA INFILE` to a secure directory by default. Check yours:
```sql
SHOW VARIABLES LIKE 'secure_file_priv';
```
Copy the 8 CSVs into that directory, then run `sql/02_load_data.sql`
(adjust the file paths at the top if your `secure_file_priv` differs).

If you'd rather not move files, enable local infile instead:
```sql
SET GLOBAL local_infile = 1;
```
and connect with `mysql --local-infile=1 ...`, then use `LOAD DATA LOCAL INFILE`
instead of `LOAD DATA INFILE` in the script.

## Verifying the load
```sql
SELECT
  (SELECT COUNT(*) FROM neighbourhoods)      AS neighbourhoods,
  (SELECT COUNT(*) FROM hosts)               AS hosts,
  (SELECT COUNT(*) FROM listings)            AS listings,
  (SELECT COUNT(*) FROM listing_performance) AS listing_performance,
  (SELECT COUNT(*) FROM listing_valuation)   AS listing_valuation,
  (SELECT COUNT(*) FROM calendar_daily)      AS calendar_daily,
  (SELECT COUNT(*) FROM reviews)             AS reviews,
  (SELECT COUNT(*) FROM review_scores)       AS review_scores;
```
Row counts should match the console output from `03_export_for_mysql.py`.
