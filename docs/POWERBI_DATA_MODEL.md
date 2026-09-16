# Power BI Data Model — Star Schema (Phase 3)

## Design approach

The Phase 2 MySQL schema is 3NF (correct for a transactional/analytical SQL
layer, wrong for Power BI). For Power BI we reshape it into a **galaxy
schema**: three conformed dimensions shared by two fact tables, each
dimension connecting *directly* to each fact table (no snowflaking) so every
slicer and every visual filters correctly without ambiguous relationship
paths.

`host_id` and `neighbourhood_id` are denormalized onto both fact tables
during the Power Query load (a merge against `listings`), specifically so
`DimHost` and `DimNeighbourhood` don't have to relate through `DimListing` —
that would be a snowflake, and snowflaking creates multi-hop filter paths
that are slower and harder to reason about in DAX.

## Tables

### Dimensions

| Table | Grain | Key columns |
|---|---|---|
| `DimDate` | 1 row per calendar date | `DateKey` (PK), `Date`, `Year`, `Quarter`, `MonthNum`, `MonthName`, `YearMonth`, `DayName`, `IsWeekend` — marked as the official Date Table in Power BI (Modeling → Mark as Date Table) so time-intelligence DAX functions work |
| `DimListing` | 1 row per listing | `ListingKey` = `listing_id` (PK), `RoomType`, `PropertyType`, `PriceCategory`, `PriceCategorySort` (1-4, for correct visual ordering), `Accommodates`, `Bedrooms`, `Beds`, `Bathrooms`, `AmenityCount`, `InstantBookable`, `IsStaleListing` |
| `DimHost` | 1 row per host | `HostKey` = `host_id` (PK), `IsSuperhost`, `ResponseRatePct`, `ExperienceYears`, `ExperienceTier`, `TotalListingsCount`, `HostSince` |
| `DimNeighbourhood` | 1 row per neighbourhood | `NeighbourhoodKey` (PK), `NeighbourhoodName`, `NeighbourhoodGroup` |

### Facts

| Table | Grain | Key measures it enables |
|---|---|---|
| `FactCalendarDaily` | 1 row per listing × date | `IsBooked` (0/1), `Price`, `BookedRevenue` (`= IF IsBooked THEN Price ELSE 0`) — **the fact table that powers every time-intelligence measure** (MoM, YoY, moving averages) because it's the only one that carries a real date |
| `FactListingPerformance` | 1 row per listing (snapshot over the tracked window) | `OccupancyRate`, `RevenueEstimate`, `ADR`, `RevPAR`, `PricingGap`, `PricingSignal`, `EstimatedPropertyValue` (⚠️ synthetic), `EstimatedAnnualROIPct` (⚠️ synthetic) — powers ranking, pricing-opportunity, and investment measures that don't need a date axis |
| `FactReviews` | 1 row per review | `ReviewCount` (always 1, for `SUM`-based counting), used for review-volume trend and recency measures |
| `FactReviewScores` | 1 row per listing | `Rating`, `Cleanliness`, `Checkin`, `Communication`, `LocationScore`, `ValueScore`, `CompositeScore` for quality visuals |

Every fact table carries `ListingKey`, `HostKey`, `NeighbourhoodKey` as
foreign keys. `FactCalendarDaily` and `FactReviews` also carry `DateKey`.

## Relationships (all Many-to-One, single direction, active)

```
DimDate          (1) ── (*) FactCalendarDaily.DateKey
DimDate          (1) ── (*) FactReviews.ReviewDateKey
DimListing       (1) ── (*) FactCalendarDaily.ListingKey
DimListing       (1) ── (*) FactListingPerformance.ListingKey
DimListing       (1) ── (*) FactReviews.ListingKey
DimHost          (1) ── (*) FactCalendarDaily.HostKey
DimHost          (1) ── (*) FactListingPerformance.HostKey
DimHost          (1) ── (*) FactReviews.HostKey
DimNeighbourhood (1) ── (*) FactCalendarDaily.NeighbourhoodKey
DimNeighbourhood (1) ── (*) FactListingPerformance.NeighbourhoodKey
DimNeighbourhood (1) ── (*) FactReviews.NeighbourhoodKey
DimListing       (1) ── (*) FactReviewScores.ListingKey
DimHost          (1) ── (*) FactReviewScores.HostKey
DimNeighbourhood (1) ── (*) FactReviewScores.NeighbourhoodKey
```

All 11 relationships are single-direction (filter flows dimension → fact
only) — no bidirectional cross-filtering, to keep the model predictable and
avoid ambiguous many-many paths as the model grows.

## Why two fact tables instead of one

A common beginner mistake is cramming `FactCalendarDaily` (18,000+ rows for
just 50 listings over a year) and `FactListingPerformance` (1 row per
listing) into a single table — that forces every snapshot metric
(RevPAR, pricing signal, ROI) to either repeat 365× per listing or collapse
the daily grain. Keeping them separate, both anchored to the same conformed
dimensions, is the standard fix — it's exactly the same reasoning that
separates fact tables by grain in any real analytics warehouse.

## Load source

Power BI connects to the MySQL database built in Phase 2 (`Get Data → MySQL
database`, pointing at `airbnb_analytics`) rather than re-reading the raw
CSVs — this keeps the transformation logic in one place and means the
Power BI model always reflects whatever's currently in the SQL layer.
