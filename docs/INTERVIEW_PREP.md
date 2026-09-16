# Interview Preparation — 30 Questions & Answer Keys

Organized by category to mirror how a real loop is usually structured.
Answers are brief talking points, not scripts — say them in your own words.

---

## SQL (8 questions)

**1. Walk me through your schema design. Why 8 tables instead of one flat table?**
> 3NF normalization: `listings` (rarely-changing attributes) is separated
> from `listing_performance` (recalculated metrics, different refresh
> cadence) and `listing_valuation` (synthetic data, deliberately isolated
> so it can never be mistaken for real data). `calendar_daily` is kept at
> its natural daily grain rather than pre-aggregated, so it can support
> both revenue derivation and time-series analysis.

**2. Why did you split `listing_performance` and `listing_valuation` from `listings` even though they're 1:1?**
> Different data governance concerns: `listings` is descriptive, `listing_performance`
> is recalculated on each pipeline run, `listing_valuation` is synthetic
> and must stay structurally flagged as such. Normalizing by "reason to
> change together" is as valid a rule as normalizing by functional dependency.

**3. Explain how you derived revenue and occupancy — Inside Airbnb doesn't provide them directly.**
> From `calendar.csv`: `available='f'` (blocked) is treated as booked.
> `occupancy_rate = booked_nights / total_nights`, `revenue = SUM(price)`
> on booked nights. It's an industry-standard proxy, not verified booking
> data — a small share of blocked nights are hosts blocking for personal
> reasons, and I documented that caveat rather than presenting it as ground truth.

**4. What's the difference between `RANK()`, `DENSE_RANK()`, and `ROW_NUMBER()`? Where did you use them?**
> `ROW_NUMBER()` gives unique sequential numbers even on ties;
> `RANK()` leaves gaps after ties (1,1,3); `DENSE_RANK()` doesn't (1,1,2).
> I used `ROW_NUMBER()` for top-N-per-group (top 3 listings per
> neighborhood — needs exactly 3, no ties ambiguity) and `DENSE_RANK`-style
> ranking for pricing-urgency ranks where ties are meaningful and shouldn't skip numbers.

**5. Walk me through your recursive CTE. What problem does it solve?**
> Generates a full month spine between the min and max calendar dates,
> then LEFT JOINs against actual months present to surface any missing
> month — a data-completeness check that would be tedious to hardcode
> since the date range varies per dataset.

**6. Why MySQL doesn't support `QUALIFY` (unlike Snowflake/BigQuery) — how do you filter on a window function result instead?**
> Wrap the windowed SELECT in a CTE, then filter in an outer SELECT against
> the CTE's computed rank/row-number column. Window functions can't be
> referenced in the same-level WHERE clause because WHERE is logically
> evaluated before window functions in query processing order.

**7. How would you calculate month-over-month growth in SQL without window functions?**
> Self-join the aggregated monthly table to itself, joining current month
> to `month - 1` via a date function, or use a correlated subquery — both
> work but are less readable and often slower than `LAG()`.

**8. Your `pricing_gap` logic uses a flat ±$20 threshold. What's the limitation, and how would you improve it?**
> A flat threshold treats a $20 gap on a $50/night listing the same as on
> a $500/night listing — the former is a 40% miss, the latter is 4%. A
> percentage-based threshold (`ABS(gap)/base_price`) would be more
> defensible, and I'd validate the exact cutoff against actual booking-
> conversion data if I had it.

---

## Power BI / DAX (7 questions)

**9. Why did you build two fact tables instead of one?**
> Different grains: `FactCalendarDaily` is listing×date (needed for any
> time-axis measure), `FactListingPerformance` is listing-only (a
> snapshot). Forcing snapshot metrics like RevPAR into the daily table
> would mean repeating the same value 365 times per listing — wasteful
> and semantically wrong (RevPAR isn't a daily fact).

**10. What is a "galaxy schema" and why did you use one here?**
> Multiple fact tables sharing conformed dimensions. I denormalized
> `host_id`/`neighbourhood_id` onto both fact tables in Power Query so
> `DimHost` and `DimNeighbourhood` connect directly to each fact — avoids
> snowflaking through `DimListing`, which would create longer, more
> fragile filter paths.

**11. Why mark `DimDate` as the official date table?**
> Time-intelligence functions (`DATEADD`, `SAMEPERIODLASTYEAR`,
> `DATESINPERIOD`) require a table Power BI recognizes as a proper,
> contiguous date table — without marking it, these functions error or
> silently misbehave.

**12. Explain your MoM growth measure line by line.**
> `[Total Revenue]` in current context, then `CALCULATE([Total Revenue], DATEADD(DimDate[Date], -1, MONTH))`
> shifts the filter context back one month, then `DIVIDE` computes the
> percentage change with a safe divide-by-zero guard.

**13. Why `ALLSELECTED` instead of `ALL` in your ranking measures?**
> `ALL` strips every filter, always ranking against the entire
> unfiltered market. `ALLSELECTED` respects slicer/visual-level filters
> but ignores the row context of the current visual — so a rank
> recalculates correctly within a user's slicer selection (e.g. "rank
> within this neighborhood") rather than always ranking market-wide.

**14. Why is `RevPAR` calculated the same way as `ADR` conceptually but with a different denominator?**
> ADR = revenue ÷ booked nights (rate when actually rented). RevPAR =
> revenue ÷ total available nights (blends rate and occupancy into one
> number) — RevPAR is the standard metric for comparing listings of
> different sizes/occupancy patterns because it can't be inflated by a
> high price with low occupancy the way ADR alone can.

**15. How would you handle a 10x larger dataset (500K listings) in this model?**
> Aggregate `FactCalendarDaily` to a coarser grain (weekly instead of
> daily) if daily granularity isn't actually used in any visual,
> consider incremental refresh on the date dimension, and push
> heavier aggregations back into MySQL views rather than computing them
> in DAX at query time.

---

## Python (7 questions)

**16. Walk me through a bug you actually hit building this and how you found it.**
> pandas 3.0 changed the default string dtype, so my `series.dtype == object`
> check silently skipped price-cleaning and every price became NaN. I
> caught it by smoke-testing the script against synthetic data before
> trusting it on real data, then fixed it by checking `is_numeric_dtype`
> instead of the specific dtype name — a more version-robust check.

**17. Why cap outliers with IQR instead of dropping them?**
> For a BI platform, investors and hosts want visibility into extreme
> listings too — dropping a $2,000/night penthouse loses real information.
> Capping (clipping to the IQR bounds) prevents a data-entry typo from
> distorting aggregate KPIs while still keeping every listing in the dataset.

**18. How did you handle missing `host_response_rate` values?**
> Filled with 0 but added a separate `host_response_rate_missing` boolean
> flag rather than silently treating "never responded" the same as "no
> data available" — those are different situations and collapsing them
> loses information a model or analyst might need.

**19. Explain the difference between your `revenue_estimate` calculation and a naive `SUM(price)`.**
> Naive `SUM(price)` across all calendar rows would count blocked AND open
> nights — wildly overstating revenue. I filtered specifically to
> `available == False` rows before summing, since only blocked nights are
> our booked-night proxy.

**20. Why did you separate `01_data_cleaning.py` from `02_feature_engineering.py` instead of one script?**
> Single responsibility — cleaning handles types/nulls/outliers (would
> change if the raw schema changes), feature engineering handles business
> logic (would change if KPI definitions change). Keeping them separate
> means a schema change doesn't force you to re-review derivation logic, and vice versa.

**21. How would you unit test `02_feature_engineering.py`?**
> Build a small synthetic calendar DataFrame with known booked/open nights
> and prices, assert the resulting `occupancy_rate` and `revenue_estimate`
> match hand-calculated expected values — exactly what I did informally
> when smoke-testing, just formalized into `pytest` assertions.

**22. What would you change if this needed to run daily in production instead of once?**
> Move from CSV-to-CSV batch scripts to an orchestrated pipeline (Airflow/
> Dagster), add incremental loading instead of full reprocessing, and add
> data-quality checks (e.g. the recursive-CTE completeness check from
> Phase 2) as automated gates before loading into MySQL.

---

## Business Case (8 questions)

**23. A host asks "why is my listing underpriced?" How do you answer using this platform?**
> Pull their `pricing_gap` (asking price minus realized ADR) and
> `pricing_signal` — if negative and flagged "Possibly Underpriced," their
> realized bookings are coming in below their own listed price, meaning
> demand likely supports a higher price without hurting occupancy.

**24. Walk me through how you'd validate the synthetic ROI model before anyone actually used it for investment decisions.**
> I wouldn't let anyone use it as-is — I'd flag it needs a real property-
> valuation data source (Zillow/Redfin API, county assessor data) before
> the ROI numbers have real decision value. The current model derives
> "value" from the platform's own pricing data, which is circular for
> investment purposes even though it's a reasonable placeholder for a portfolio project.

**25. Superhosts outperform non-superhosts on revenue — does that mean superhost status *causes* higher revenue?**
> Not necessarily — correlation, not causation. Superhost status could
> cause it (search-ranking boost), or better hosts naturally earn both
> superhost status and higher revenue (confounding), or some of both. I'd
> want a natural experiment (hosts who just crossed the threshold) to separate these.

**26. How would you prioritize which neighborhoods to expand host-acquisition efforts in?**
> Not pure top-revenue — I'd look for high RevPAR with relatively low
> listing count (undersupplied demand), since a new listing there
> captures more incremental value than one in an already-saturated top-revenue market.

**27. The stale-listing flag uses a 365-day no-review cutoff. Why that number, and what's the tradeoff?**
> Roughly one full seasonal cycle — a listing with zero reviews across an
> entire year has very likely stopped being actively managed rather than
> just having a slow quarter. Shorter cutoffs would falsely flag seasonal
> listings (e.g. beach properties with a winter-only gap).

**28. If revenue is trending down market-wide, how would you use this dashboard to figure out why?**
> Start on the Revenue page's MoM trend to confirm it's broad-based vs. a
> few large listings, then check the Neighborhood page to see if it's
> geographically concentrated, then Pricing to see if occupancy or price
> is the driver — that ordering isolates the "where" before guessing "why."

**29. What's the single biggest data-quality limitation of this entire project, and how would you disclose it to a stakeholder?**
> Revenue/occupancy are both derived proxies, not verified bookings — I'd
> state that plainly on any dashboard using them and in any executive
> summary, the same way I documented it in the data dictionary here,
> rather than letting the specificity of a number imply more certainty than it has.

**30. Why does this project matter for a Data Analyst role specifically, versus a Data Scientist role?**
> The core value here is the full analytics-engineering stack — data
> derivation logic, normalized schema design, a reusable SQL query
> library, and a stakeholder-facing dashboard with disclosed data
> limitations. That's the day-to-day of an analyst role; the ML piece
> (Phase 6) is a bonus showing I can go further, not the center of gravity.
