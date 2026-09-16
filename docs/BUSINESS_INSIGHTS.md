# Business Insights & Executive Reporting

**How to use this document:** every finding below follows the standard
BI narrative structure — **Finding → Root Cause Analysis → Recommendation**
— written as a fully-formed template against the actual dashboard
structure from Phase 3. Bracketed values like `[XX%]` are placeholders:
run the pipeline against real Inside Airbnb data (Phase 1 → 2 → 3), pull
the actual numbers from your Power BI report, and replace them. Keep this
structure — it's the format a hiring manager expects in a portfolio
write-up and the format you'll be asked to produce in an actual BI role.
The *shape* of each finding (what to compare, what to attribute it to,
what to recommend) is realistic to how this analysis typically plays out
on Inside Airbnb data — only the specific figures need replacing.

---

## Page 1 — Executive Summary

**Finding:** Total estimated revenue across the market is `[$X.XM]`,
concentrated in the top `[X]` neighborhoods, which together account for
`[XX%]` of platform-wide revenue despite holding only `[XX%]` of listings.

**Root Cause:** Revenue concentration this steep almost always traces to
a mix of tourist-corridor proximity (transit access, landmark density) and
room-type mix — neighborhoods skewed toward "Entire home/apt" out-earn
"Private room"-heavy areas at 2-4x the RevPAR, independent of location quality.

**Recommendation:** Prioritize host-acquisition and listing-quality
investment in the top revenue neighborhoods first (highest ROI on
marketing spend), but flag the 2nd-tier neighborhoods with strong RevPAR
but low listing count as underserved expansion targets — a market where
demand outstrips supply is worth more per new listing than a saturated one.

---

## Page 2 — Revenue Performance

**Finding:** Month-over-month revenue growth (`Revenue MoM Growth %`)
shows `[X]` months of acceleration followed by a `[XX%]` dip in `[month]`
— seasonality, not demand collapse.

**Root Cause:** Cross-referencing against the occupancy scatter (ADR vs.
Occupancy), the dip coincides with a period where average occupancy fell
faster than price adjusted down — hosts weren't repricing to match
seasonal demand shifts.

**Recommendation:** Build a seasonal pricing calendar recommendation
(this is exactly what Phase 6's ML model should ultimately automate) —
hosts who fail to reduce price in shoulder-season months are leaving
occupancy on the table rather than protecting margin, since Airbnb demand
at this end of the market is price-elastic below a certain threshold.

---

## Page 3 — Neighborhood Analysis

**Finding:** `[Neighborhood A]` has the highest RevPAR market-wide
(`[$XX]`) but the lowest average review composite score (`[X.X]`) among
top-10 neighborhoods by revenue.

**Root Cause:** High RevPAR with mediocre reviews typically signals a
market where demand is driven by something other than guest satisfaction
— usually location scarcity (proximity to a single major venue/transit
hub) letting hosts under-invest in guest experience without losing bookings.

**Recommendation:** This is a fragile revenue base — a single new
competitor listing or a review-score-weighted change to Airbnb's own
search ranking algorithm would expose it. Recommend host-quality
coaching outreach here specifically, framed as "protect your current
advantage" rather than "you're underperforming."

---

## Page 4 — Dynamic Pricing

**Finding:** `[XX]` listings (`Pricing Opportunity Count`) are flagged
Over- or Underpriced; of these, `[XX%]` are "Possibly Underpriced" —
meaning more listings are leaving money on the table than are pricing
themselves out of bookings.

**Root Cause:** New and Growing-tier hosts (`ExperienceTier`) are
disproportionately represented in the underpriced group — consistent
with new hosts anchoring price to competitor listings rather than to
their own realized ADR, and never revisiting the number once bookings start.

**Recommendation:** A one-time "your listing is underpriced by
`[pricing_gap]`" nudge notification for new hosts in their first 90 days
would likely be the single highest-ROI product intervention available —
it's a data-driven number the host can act on immediately, unlike generic
pricing tips.

---

## Page 5 — Host Performance

**Finding:** Superhosts show `[XX%]` higher average occupancy and
`[XX%]` higher RevPAR than non-superhosts (`Superhost Revenue Share %`),
but the gap in average review score between the two groups is only
`[X.X]` points.

**Root Cause:** The performance gap is larger than the quality gap —
suggesting superhost status itself (via Airbnb's search-ranking boost)
is driving a meaningful share of the revenue difference, not just that
superhosts are meaningfully better hosts.

**Recommendation:** For hosts close to the superhost threshold
(`response_rate`, `occupancy`, `review_score` cutoffs), a targeted
"you're `[X]` bookings away from Superhost" campaign converts marginal
hosts with a clear, achievable goal — likely higher ROI than broad
quality-coaching content.

---

## Page 6 — Reviews & Guest Sentiment

**Finding:** `[XX]` listings are flagged `is_stale_listing` (no review in
365+ days), representing `[XX%]` of total inventory.

**Root Cause:** Cross-referencing stale listings against
`host_experience_tier` shows they skew heavily toward "New" and
"Growing" hosts — consistent with early hosts listing once, getting
discouraged by slow initial bookings, and never re-engaging rather than
these being deliberately delisted properties.

**Recommendation:** These are not "bad" listings to deprioritize — they're
a recoverable-revenue opportunity. A win-back campaign (relist prompts,
temporary search-ranking boost to jump-start bookings) targeting stale
listings under 2 years old is likely more cost-effective than acquiring
new hosts from scratch.

---

## Page 7 — Investment & ROI ⚠️

**Finding:** `[Neighborhood B]` shows the highest `Avg Estimated ROI %`
(`[XX%]`) among all neighborhoods analyzed.

**Root Cause:** *(This finding rests entirely on the synthetic
`estimated_property_value` field — see docs/DATA_DICTIONARY.md. The
"root cause" here is methodological, not market-driven: neighborhoods
with a high price-per-bedroom-to-revenue ratio will always rank well
under this valuation model, regardless of actual real-estate market
conditions, because the model derives value from the platform's own
pricing data rather than independent comps.)*

**Recommendation:** Do not present this page's numbers as investment
advice. The honest recommendation is methodological: a production version
of this platform needs a real property-valuation data source (e.g.
Zillow/Redfin API, county assessor records, or MLS comps) before the ROI
page has any real-world decision value. Frame this page in interviews as
"I identified the data gap and built a transparent, clearly-labeled
placeholder rather than presenting a black-box number" — that's the
actual signal of seniority here, not the ROI figure itself.

---

## Presenting this in an interview

If asked "walk me through a finding," Page 4 (Pricing) or Page 6
(Reviews) are the strongest to lead with — both have a clear, actionable,
low-cost recommendation with a plausible mechanism, not just "revenue
went up/down." Page 7 is worth bringing up specifically to demonstrate
data-skepticism and honest handling of a data gap, which is a stronger
signal than any single insight.
