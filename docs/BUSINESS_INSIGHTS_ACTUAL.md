# Business Insights from Current Data

This report is generated from the current processed Airbnb snapshot. Refresh it with `python scripts/05_generate_business_insights.py` after rerunning the pipeline.

## EXEC-01 - Executive
**Finding:** The market contains 458 priced listings and generates $8,665,719 in estimated revenue at 30.7% weighted occupancy.

**Recommendation:** Use the top-revenue neighborhoods as the acquisition baseline, but evaluate RevPAR and inventory depth before adding supply.

**Caveat:** Revenue and occupancy are estimates from availability flags, not verified reservations.

## EXEC-02 - Revenue concentration
**Finding:** The top three neighborhoods contribute 44.8% of estimated revenue; SIXTH WARD is the largest revenue market.

**Recommendation:** Protect the core market while testing expansion in smaller areas with strong RevPAR and occupancy.

**Caveat:** Neighborhood performance is sensitive to the current listing mix.

## SEAS-01 - Seasonality
**Finding:** Estimated revenue peaks in 2026-07 and bottoms in 2026-11; monthly occupancy should drive seasonal pricing rules.

**Recommendation:** Create a seasonal pricing calendar and review it monthly against occupancy and RevPAR.

**Caveat:** This dataset is a single forward-looking calendar window, not a multi-year trend.

## HOST-01 - Host performance
**Finding:** Superhost RevPAR is 35.3% above non-superhost RevPAR in the tracked window.

**Recommendation:** Prioritize coaching and Superhost-readiness campaigns for hosts close to the quality threshold.

**Caveat:** The comparison is observational and does not prove that status alone causes the revenue gap.

## QUALITY-01 - Guest experience
**Finding:** 55 listings are stale under the 365-day review rule, creating a recoverable reactivation audience.

**Recommendation:** Launch a win-back workflow with listing refresh prompts and a short-term booking incentive.

**Caveat:** No recent review can mean inactivity, not necessarily poor guest experience.

## PRICING-01 - Pricing
**Finding:** 14 listings are flagged by the pricing-gap rule; this export has no calendar price column, so most listings cannot show a meaningful realized-ADR gap.

**Recommendation:** Treat pricing signals as provisional and refresh with nightly calendar prices before automating host recommendations.

**Caveat:** Calendar prices were backfilled from listings.csv base price for this source export.

## INVEST-01 - Investment
**Finding:** THIRTEENTH WARD ranks highest on estimated ROI under the current valuation proxy.

**Recommendation:** Use this page to prioritize diligence, not as an investment recommendation; replace the proxy with independent property-value data.

**Caveat:** Property values and ROI are synthetic estimates derived from Airbnb pricing data.

## Dashboard KPI snapshot

- Listings analyzed: 458
- Estimated revenue: $8,665,719
- Weighted occupancy: 30.7%
- RevPAR: $52
