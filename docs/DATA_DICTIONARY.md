# Data Dictionary — Airbnb Market Analytics & Investment Platform

Every field in `master_analytics_table.csv` is labeled below as:
- **RAW** — comes straight from Inside Airbnb, cleaned only (types/nulls/outliers)
- **DERIVED** — calculated from raw fields using real, documented logic
- **SYNTHETIC** — does not exist in Inside Airbnb at all; generated with a
  transparent rule because the business question requires it. Always
  labeled "estimated" in dashboards — never presented as fact.

## Core identifiers (RAW)
| Field | Description |
|---|---|
| `id` | Unique listing ID |
| `host_id` | Unique host ID |
| `neighbourhood_cleansed` | Standardized neighborhood name |
| `latitude` / `longitude` | Listing coordinates |
| `property_type` / `room_type` | Property classification |

## Revenue & Occupancy (DERIVED — the heart of this project)
Source: `calendar.csv`, where each row is one (listing, date) with an
`available` flag. **`available = 'f'` (false/blocked) is treated as a
booked night.** This is the standard Inside Airbnb analytics convention,
not ground-truth reservation data — a small share of blocked nights are
hosts blocking dates for personal reasons rather than actual bookings.

| Field | Formula | Description |
|---|---|---|
| `total_nights_tracked` | count of calendar rows per listing | Size of the observation window (usually ~365 days) |
| `booked_nights` | count where `available = false` | Nights treated as booked |
| `occupancy_rate` | `booked_nights / total_nights_tracked` | % of tracked nights booked |
| `revenue_estimate` | `SUM(price)` where `available = false` | Estimated gross revenue over the window |
| `adr` | `revenue_estimate / booked_nights` | Average Daily Rate — industry-standard KPI, price per *booked* night |
| `revpar` | `revenue_estimate / total_nights_tracked` | Revenue Per Available night — the standard metric for comparing performance across listings of different price points |
| `avg_open_listing_price` | mean `price` where `available = true` | The host's "asking price" on open nights, for comparison against ADR |

## Pricing signals (DERIVED)
| Field | Formula | Description |
|---|---|---|
| `pricing_gap` | `price - adr` | Positive = asking more than the listing actually earns per booked night (possibly overpriced). Negative = booking below its own asking price (possibly underpriced / leaving money on the table). |
| `pricing_signal` | thresholded on `pricing_gap` (±$20) | Categorical: Possibly Overpriced / Possibly Underpriced / Well-Priced |

## Host & listing features (DERIVED)
| Field | Formula | Description |
|---|---|---|
| `host_experience_years` | `(today − host_since) / 365.25` | How long the host has been on Airbnb |
| `host_experience_tier` | binned `host_experience_years` | New / Growing / Established / Veteran |
| `price_category` | quartile bins of `price` | Budget / Mid-Range / Premium / Luxury |
| `listing_age_days` | `today − first_review` | Days since the listing's first booking/review |
| `days_since_last_review` | `today − last_review` | Recency signal |
| `is_stale_listing` | `days_since_last_review > 365` | Flag for listings that may be inactive/delisted |
| `review_score_composite` | mean of 5 review sub-scores | Single blended quality score |
| `amenity_count` | count of items in `amenities` list | Proxy for investment/quality level of the unit |

## Seasonality table (`calendar_monthly_agg.csv`, DERIVED)
Same revenue/occupancy logic as above, aggregated to listing × calendar
month, to support MoM/seasonal trend analysis in SQL and Power BI.

## Investment / ROI fields (⚠️ SYNTHETIC — clearly flagged)
Inside Airbnb has **no property value or acquisition cost data**. The
business problem explicitly asks about investor ROI, which is impossible
without an estimated asset value, so we generate one transparently:

| Field | Formula | Description |
|---|---|---|
| `neighbourhood_median_price_per_bedroom` | median(`price / bedrooms`) per neighborhood | Intermediate calc |
| `estimated_property_value` | `neighbourhood_median_price_per_bedroom × bedrooms × 250` | **Illustrative only.** The multiplier (250) approximates a rough nightly-rate-to-asset-value ratio (~10–15% annual gross yield), it is **not** a real appraisal or market comp |
| `is_synthetic_valuation` | always `true` | Explicit flag carried through to SQL/Power BI so this can never silently be mistaken for real data |
| `estimated_annual_roi_pct` | `revenue_estimate / estimated_property_value × 100` | Illustrative gross yield estimate |

**Every dashboard and report using these two ROI fields must visibly label
them "Estimated" — this is a portfolio-project simplification, disclosed
here and repeated in the README and on the Investment dashboard page.**

## Reviews table fields (RAW, from `reviews.csv`)
| Field | Description |
|---|---|
| `id` | Unique review ID |
| `listing_id` | FK to listings |
| `date` | Review date |
| `reviewer_id` / `reviewer_name` | Reviewer info |
| `comments` | Review text (HTML artifacts stripped) |
