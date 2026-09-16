# Power BI Dashboard — Visual Layout Specification (Phase 3)

7 pages, 1920×1080 canvas. Page navigation via a persistent left nav bar
(bookmark-driven buttons, not the default tab strip — see Bookmarks below).

---

## Field Parameters (built once, reused across pages)

**`Metric Selector`** — New parameter → Fields → add `[Total Revenue]`,
`[RevPAR]`, `[ADR]`, `[Avg Occupancy %]` as the 4 fields. Creates a table
with `Parameter` and `Order` columns and a `[Metric Selector]` measure.
Bind this measure into the Y-axis of any chart, paired with a slicer built
from the same parameter table, so the user picks which KPI drives the
chart without needing 4 separate visuals. Used on: **Executive, Revenue,
Neighborhood**.

**`Time Granularity`** — parameter over `DimDate[YearMonth]`,
`DimDate[Quarter]`, `DimDate[Year]` — drives the axis grouping of trend
charts. Used on: **Revenue, Reviews**.

---

## Page 1 — Executive Summary
*Audience: leadership, 10-second glance*

- **Top strip, 5 cards**: `Total Revenue`, `Total Listings`, `Avg Occupancy %`, `RevPAR`, `Pricing Opportunity Count` (Q20 from the SQL library maps directly onto this row)
- **Center-left, line chart**: Revenue by `YearMonth`, using the `Metric Selector` field parameter so leadership can toggle Revenue/RevPAR/ADR/Occupancy on the same chart. Includes `Revenue 3-Month Moving Avg` as a secondary line for trend-smoothing.
- **Center-right, map visual**: listings plotted by lat/long, bubble size = `Total Revenue`, color = `PriceCategory`
- **Bottom-left, bar chart**: Top 5 neighborhoods by `Total Revenue` (`Neighbourhood Revenue Rank` filtered ≤5)
- **Bottom-right, donut**: revenue split `IsSuperhost` (feeds `Superhost Revenue Share %`)
- **Drill-through**: clicking a neighborhood bar → **Page 3 (Neighborhood)** filtered to that neighborhood. Clicking a map bubble → **Page 5 (Host)** filtered to that listing's host.
- **Bookmark**: "This Month" vs "Year to Date" toggle button (top-right) swaps a hidden date-range slicer selection.

---

## Page 2 — Revenue Performance
*Audience: revenue/finance analysts*

- **Top**: line/column combo — `Total Revenue` (column) + `Revenue MoM Growth %` (line, secondary axis) by `Time Granularity` parameter
- **Left**: waterfall-style column chart — `Cumulative Revenue` by month (running total pattern)
- **Right**: matrix table — rows = `DimListing[RoomType]`, columns = `DimDate[Quarter]`, values = `Total Revenue`, with conditional-formatting data bars
- **Bottom**: scatter plot — `ADR` (x) vs `Avg Occupancy %` (y), bubble size = `Total Revenue`, colored by `PriceCategory` — visually answers "does higher price actually cost you occupancy"
- **Drill-through**: clicking any point on the scatter → **Page 4 (Pricing)** filtered to that listing
- **Bookmark**: "Show Superhosts Only" — applies a `DimHost[IsSuperhost] = TRUE` filter and swaps the page title subtitle

---

## Page 3 — Neighborhood Analysis
*Audience: market/expansion strategy*

- **Left, filled map**: neighborhoods shaded by `RevPAR` (matches SQL Q1's ranking logic)
- **Center, ranked bar chart**: `Neighbourhood Revenue Rank` — horizontal bars, one per neighborhood, using the `Metric Selector` parameter for the value axis
- **Right, small multiples**: one mini occupancy-trend line chart per neighborhood (seasonality — mirrors SQL Q12)
- **Bottom, table**: neighborhood-level summary — listing count, avg price, avg occupancy, total revenue, avg estimated ROI (clearly labeled "Estimated")
- **Drill-through**: clicking any neighborhood element → **Page 5 (Host)** filtered to hosts operating there
- **Bookmark**: none needed — this page is filter-driven via the map itself, which acts as the primary interaction surface

---

## Page 4 — Dynamic Pricing
*Audience: revenue management / pricing ops*

- **Top strip cards**: `Pricing Opportunity Count`, count "Possibly Overpriced", count "Possibly Underpriced"
- **Main, scatter plot**: `BasePrice` (x) vs `ADR` (y), diagonal reference line at x=y — points above the line are overpriced, below are underpriced, colored by `PricingSignal`. This is the single most useful visual on the page.
- **Right, ranked table**: listings sorted by `ABS(PricingGap)` descending (mirrors SQL Q6) — the "act on this first" list
- **Bottom, bar chart**: `Avg Occupancy %` by `PriceCategory` — price-elasticity view (mirrors SQL Q17)
- **Drill-through**: clicking a row in the ranked table → **Page 1 (Executive)** filtered to that single listing, to see its full context
- **Bookmark**: "Overpriced Only" / "Underpriced Only" / "All" — three bookmark buttons that swap the `PricingSignal` filter, wired to a button group at top-right

---

## Page 5 — Host Performance
*Audience: host success / community ops*

- **Top-left, scatter**: `Avg Occupancy %` (x) vs `avg review composite_score` (y), bubble size = `Total Revenue`, colored by `ExperienceTier` — visually clusters the Platinum/Gold/Silver/Needs-Improvement tiers from SQL Q3
- **Top-right, bar chart**: `Total Revenue` by `ExperienceTier` (mirrors SQL Q11)
- **Bottom-left, ranked table**: Top 10 hosts by `Total Revenue` (mirrors SQL Q2), with `Listing Revenue Rank` shown per listing on drill-down
- **Bottom-right, KPI comparison card pair**: Superhost vs non-superhost side-by-side (`Avg Occupancy %`, `RevPAR`, avg review score) — mirrors SQL Q8
- **Drill-through**: clicking a host → **Page 6 (Reviews)** filtered to that host's listings
- **Bookmark**: "New Hosts (<1yr)" spotlight — filters `ExperienceTier` and highlights coaching-relevant cards

---

## Page 6 — Reviews & Guest Sentiment
*Audience: quality/guest experience team*

- **Top**: line chart — review volume (`SUM(ReviewCount)`) by `Time Granularity` parameter — demand-proxy trend
- **Left, bar chart**: `Total Revenue` by review-score bucket (mirrors SQL Q13 bucketing logic — reuse the same bucket boundaries in a calculated column on `review_scores` rather than recomputing in DAX)
- **Right, card grid**: average of each of the 5 review sub-scores (cleanliness, check-in, communication, location, value) — a simple radar-style visual works well here if the org's Power BI has custom visuals enabled, otherwise 5 gauge cards
- **Bottom, table**: listings flagged `IsStaleListing = TRUE` (no review in 365+ days) — the at-risk list from SQL Q14
- **Drill-through**: none — this page is a terminus for investigation, not a routing hub
- **Bookmark**: "At Risk Listings" — jumps straight to the bottom table filter pre-applied, linked from a warning icon on Page 1

---

## Page 7 — Investment & ROI (⚠️ synthetic valuation data)
*Audience: prospective investors*

**Every visual on this page carries a persistent banner**: *"Property values
and ROI are illustrative estimates, not real appraisals — see Data
Dictionary."* This isn't optional styling; it's a factual disclosure and
should be a locked text box that can't be filtered or hidden.

- **Top, cards**: avg `EstimatedPropertyValue`, `Avg Estimated ROI %`, count of listings analyzed
- **Left, bar chart**: `Avg Estimated ROI %` by neighborhood, descending (mirrors SQL Q15)
- **Right, scatter**: `EstimatedPropertyValue` (x) vs `Total Revenue` (y) — visually separates "expensive but low-yield" from "affordable and high-yield" neighborhoods
- **Bottom, table**: neighborhood-level investment summary — avg property value, avg revenue, avg ROI, listing count
- **Drill-through**: clicking a neighborhood → **Page 3 (Neighborhood)** for full market context
- **Bookmark**: none — page is intentionally simple given the data-quality caveat; over-interactivity would invite over-trusting synthetic numbers

---

## Navigation & global elements

- **Left nav rail** (all pages): 7 icon buttons, each a bookmark that navigates to its page (Bookmarks pane → "Selected visuals" scoped so the nav rail itself never resets when a bookmark restores page-specific filters)
- **Global filter pane**: `DimDate[Date]` range slicer and `DimNeighbourhood[NeighbourhoodName]` slicer, synced (Sync Slicers) across all 7 pages so date/neighborhood selections persist as the user navigates
- **Page tooltips**: every card visual has a tooltip page (small 320×240 hidden page) showing the trend sparkline for that KPI — Format → Tooltip → set the tooltip page
