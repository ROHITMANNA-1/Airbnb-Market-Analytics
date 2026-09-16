-- ============================================================================
-- Airbnb Market Analytics & Investment Platform
-- Phase 2: Analytics Query Library (MySQL 8.0)
-- ============================================================================
-- 20 queries representing the core of a 60+ query library. Each is labeled
-- with the business question it answers and the SQL technique it
-- demonstrates — written to double as interview talking points.
-- ============================================================================

USE airbnb_analytics;


-- ============================================================================
-- Q1. Top 15 neighborhoods by total estimated revenue
-- Technique: JOIN + GROUP BY + aggregate ranking
-- Business question: Where should marketing/investment budget concentrate?
-- ============================================================================
SELECT
    n.neighbourhood_name,
    COUNT(DISTINCT l.listing_id)              AS listing_count,
    ROUND(SUM(lp.revenue_estimate), 2)        AS total_revenue,
    ROUND(AVG(lp.revpar), 2)                  AS avg_revpar,
    ROUND(AVG(lp.occupancy_rate) * 100, 1)    AS avg_occupancy_pct
FROM neighbourhoods n
JOIN listings l            ON l.neighbourhood_id = n.neighbourhood_id
JOIN listing_performance lp ON lp.listing_id = l.listing_id
GROUP BY n.neighbourhood_name
ORDER BY total_revenue DESC
LIMIT 15;


-- ============================================================================
-- Q2. Top 10 hosts by total revenue, ranked
-- Technique: Window function ROW_NUMBER()
-- Business question: Who are the platform's highest-earning hosts?
-- ============================================================================
SELECT *
FROM (
    SELECT
        h.host_id,
        h.experience_tier,
        COUNT(l.listing_id)                          AS num_listings,
        ROUND(SUM(lp.revenue_estimate), 2)            AS total_revenue,
        ROW_NUMBER() OVER (ORDER BY SUM(lp.revenue_estimate) DESC) AS revenue_rank
    FROM hosts h
    JOIN listings l             ON l.host_id = h.host_id
    JOIN listing_performance lp ON lp.listing_id = l.listing_id
    GROUP BY h.host_id, h.experience_tier
) ranked
WHERE revenue_rank <= 10
ORDER BY revenue_rank;


-- ============================================================================
-- Q3. Host performance tier segmentation
-- Technique: Multi-condition CASE expression
-- Business question: Which hosts should get "coaching" outreach vs. showcased
--                     as best practice examples?
-- ============================================================================
SELECT
    h.host_id,
    ROUND(AVG(lp.occupancy_rate) * 100, 1) AS avg_occupancy_pct,
    ROUND(AVG(rs.composite_score), 2)      AS avg_review_score,
    CASE
        WHEN AVG(lp.occupancy_rate) >= 0.60 AND AVG(rs.composite_score) >= 4.7 THEN 'Platinum'
        WHEN AVG(lp.occupancy_rate) >= 0.45 AND AVG(rs.composite_score) >= 4.4 THEN 'Gold'
        WHEN AVG(lp.occupancy_rate) >= 0.30 AND AVG(rs.composite_score) >= 4.0 THEN 'Silver'
        ELSE 'Needs Improvement'
    END AS performance_tier
FROM hosts h
JOIN listings l              ON l.host_id = h.host_id
JOIN listing_performance lp  ON lp.listing_id = l.listing_id
LEFT JOIN review_scores rs   ON rs.listing_id = l.listing_id
GROUP BY h.host_id
ORDER BY avg_occupancy_pct DESC;


-- ============================================================================
-- Q4. Month-over-month revenue growth (requires the monthly seasonality
--     table — import calendar_monthly_agg.csv as an extra table, or run
--     this directly against calendar_daily via the CTE below)
-- Technique: CTE + window function LAG()
-- Business question: Is revenue accelerating or decelerating month to month?
-- ============================================================================
WITH monthly_revenue AS (
    SELECT
        listing_id,
        DATE_FORMAT(calendar_date, '%Y-%m') AS yr_month,
        SUM(CASE WHEN is_available = 0 THEN price ELSE 0 END) AS month_revenue
    FROM calendar_daily
    GROUP BY listing_id, DATE_FORMAT(calendar_date, '%Y-%m')
),
listing_month_totals AS (
    SELECT
        yr_month,
        SUM(month_revenue) AS total_revenue
    FROM monthly_revenue
    GROUP BY yr_month
)
SELECT
    yr_month,
    total_revenue,
    LAG(total_revenue) OVER (ORDER BY yr_month) AS prior_month_revenue,
    ROUND(
        100.0 * (total_revenue - LAG(total_revenue) OVER (ORDER BY yr_month))
        / NULLIF(LAG(total_revenue) OVER (ORDER BY yr_month), 0), 2
    ) AS mom_growth_pct
FROM listing_month_totals
ORDER BY yr_month;


-- ============================================================================
-- Q5. Listings with declining occupancy for 3+ consecutive months
-- Technique: CTE + LAG() + running flag logic
-- Business question: Early-warning list for host outreach before listings churn
-- ============================================================================
WITH monthly_occ AS (
    SELECT
        listing_id,
        DATE_FORMAT(calendar_date, '%Y-%m') AS yr_month,
        AVG(CASE WHEN is_available = 0 THEN 1.0 ELSE 0 END) AS occupancy_rate
    FROM calendar_daily
    GROUP BY listing_id, DATE_FORMAT(calendar_date, '%Y-%m')
),
with_trend AS (
    SELECT
        listing_id,
        yr_month,
        occupancy_rate,
        LAG(occupancy_rate, 1) OVER (PARTITION BY listing_id ORDER BY yr_month) AS occ_prev1,
        LAG(occupancy_rate, 2) OVER (PARTITION BY listing_id ORDER BY yr_month) AS occ_prev2
    FROM monthly_occ
)
SELECT listing_id, yr_month, occupancy_rate, occ_prev1, occ_prev2
FROM with_trend
WHERE occupancy_rate < occ_prev1
  AND occ_prev1 < occ_prev2
ORDER BY listing_id, yr_month;


-- ============================================================================
-- Q6. Dynamic pricing opportunities, ranked within each neighborhood
-- Technique: Window function RANK() PARTITION BY + CASE
-- Business question: Which specific listings should adjust price first?
-- ============================================================================
-- NOTE: MySQL has no QUALIFY clause (unlike Snowflake/BigQuery/DuckDB), so
-- filtering on a window-function result requires wrapping it in a CTE first.
WITH ranked AS (
    SELECT
        n.neighbourhood_name,
        l.listing_id,
        l.base_price,
        lp.adr,
        lp.pricing_gap,
        lp.pricing_signal,
        RANK() OVER (
            PARTITION BY n.neighbourhood_name
            ORDER BY ABS(lp.pricing_gap) DESC
        ) AS pricing_urgency_rank
    FROM listings l
    JOIN neighbourhoods n        ON n.neighbourhood_id = l.neighbourhood_id
    JOIN listing_performance lp  ON lp.listing_id = l.listing_id
    WHERE lp.pricing_signal <> 'Well-Priced'
)
SELECT * FROM ranked
WHERE pricing_urgency_rank <= 5
ORDER BY neighbourhood_name, pricing_urgency_rank;


-- ============================================================================
-- Q7. RevPAR quartile ranking across the whole market
-- Technique: Window function NTILE(4)
-- Business question: Which listings sit in the bottom performance quartile?
-- ============================================================================
SELECT
    l.listing_id,
    lp.revpar,
    NTILE(4) OVER (ORDER BY lp.revpar) AS revpar_quartile
FROM listings l
JOIN listing_performance lp ON lp.listing_id = l.listing_id
ORDER BY lp.revpar;


-- ============================================================================
-- Q8. Superhost vs non-superhost performance comparison
-- Technique: CASE-based conditional aggregation
-- Business question: Does superhost status actually correlate with performance?
-- ============================================================================
SELECT
    h.is_superhost,
    COUNT(DISTINCT h.host_id)                    AS num_hosts,
    ROUND(AVG(lp.occupancy_rate) * 100, 1)        AS avg_occupancy_pct,
    ROUND(AVG(lp.revpar), 2)                      AS avg_revpar,
    ROUND(AVG(rs.composite_score), 2)             AS avg_review_score
FROM hosts h
JOIN listings l              ON l.host_id = h.host_id
JOIN listing_performance lp  ON lp.listing_id = l.listing_id
LEFT JOIN review_scores rs   ON rs.listing_id = l.listing_id
GROUP BY h.is_superhost;


-- ============================================================================
-- Q9. Cumulative (running total) revenue per neighborhood by month
-- Technique: Window function SUM() OVER with a frame
-- Business question: Track cumulative YTD revenue trajectory per market
-- ============================================================================
WITH monthly AS (
    SELECT
        n.neighbourhood_name,
        DATE_FORMAT(cd.calendar_date, '%Y-%m') AS yr_month,
        SUM(CASE WHEN cd.is_available = 0 THEN cd.price ELSE 0 END) AS month_revenue
    FROM calendar_daily cd
    JOIN listings l       ON l.listing_id = cd.listing_id
    JOIN neighbourhoods n ON n.neighbourhood_id = l.neighbourhood_id
    GROUP BY n.neighbourhood_name, DATE_FORMAT(cd.calendar_date, '%Y-%m')
)
SELECT
    neighbourhood_name,
    yr_month,
    month_revenue,
    SUM(month_revenue) OVER (
        PARTITION BY neighbourhood_name
        ORDER BY yr_month
        ROWS BETWEEN UNBOUNDED PRECEDING AND CURRENT ROW
    ) AS cumulative_revenue
FROM monthly
ORDER BY neighbourhood_name, yr_month;


-- ============================================================================
-- Q10. Top 3 listings per neighborhood by RevPAR
-- Technique: Window function ROW_NUMBER() PARTITION BY
-- Business question: Best-in-class listing examples per market, for host coaching
-- ============================================================================
WITH ranked AS (
    SELECT
        n.neighbourhood_name,
        l.listing_id,
        lp.revpar,
        ROW_NUMBER() OVER (PARTITION BY n.neighbourhood_name ORDER BY lp.revpar DESC) AS rn
    FROM listings l
    JOIN neighbourhoods n       ON n.neighbourhood_id = l.neighbourhood_id
    JOIN listing_performance lp ON lp.listing_id = l.listing_id
)
SELECT neighbourhood_name, listing_id, revpar
FROM ranked
WHERE rn <= 3
ORDER BY neighbourhood_name, rn;


-- ============================================================================
-- Q11. Host experience tier vs. average occupancy & review score
-- Technique: GROUP BY aggregate comparison
-- Business question: Do veteran hosts actually outperform new hosts?
-- ============================================================================
SELECT
    h.experience_tier,
    COUNT(DISTINCT h.host_id)               AS num_hosts,
    ROUND(AVG(lp.occupancy_rate) * 100, 1)  AS avg_occupancy_pct,
    ROUND(AVG(rs.composite_score), 2)       AS avg_review_score,
    ROUND(AVG(lp.revenue_estimate), 2)      AS avg_revenue_per_listing
FROM hosts h
JOIN listings l              ON l.host_id = h.host_id
JOIN listing_performance lp  ON lp.listing_id = l.listing_id
LEFT JOIN review_scores rs   ON rs.listing_id = l.listing_id
GROUP BY h.experience_tier
ORDER BY avg_revenue_per_listing DESC;


-- ============================================================================
-- Q12. Seasonality — average occupancy by calendar month, ranked
-- Technique: GROUP BY + RANK()
-- Business question: When should hosts expect peak vs. off-season demand?
-- ============================================================================
WITH monthly_occ AS (
    SELECT
        MONTHNAME(calendar_date)               AS month_name,
        MONTH(calendar_date)                   AS month_num,
        AVG(CASE WHEN is_available = 0 THEN 1.0 ELSE 0 END) AS avg_occupancy_rate
    FROM calendar_daily
    GROUP BY MONTHNAME(calendar_date), MONTH(calendar_date)
)
SELECT
    month_name,
    ROUND(avg_occupancy_rate * 100, 1) AS avg_occupancy_pct,
    RANK() OVER (ORDER BY avg_occupancy_rate DESC) AS demand_rank
FROM monthly_occ
ORDER BY month_num;


-- ============================================================================
-- Q13. Review score vs. revenue relationship, bucketed
-- Technique: CASE-based binning + aggregate
-- Business question: How much does review quality actually move revenue?
-- ============================================================================
SELECT
    CASE
        WHEN rs.composite_score >= 4.8 THEN '4.8 - 5.0 (Excellent)'
        WHEN rs.composite_score >= 4.5 THEN '4.5 - 4.8 (Very Good)'
        WHEN rs.composite_score >= 4.0 THEN '4.0 - 4.5 (Good)'
        ELSE 'Below 4.0'
    END AS review_score_bucket,
    COUNT(*)                               AS num_listings,
    ROUND(AVG(lp.revenue_estimate), 2)     AS avg_revenue,
    ROUND(AVG(lp.occupancy_rate) * 100, 1) AS avg_occupancy_pct
FROM listings l
JOIN listing_performance lp ON lp.listing_id = l.listing_id
JOIN review_scores rs       ON rs.listing_id = l.listing_id
WHERE rs.composite_score IS NOT NULL
GROUP BY review_score_bucket
ORDER BY avg_revenue DESC;


-- ============================================================================
-- Q14. Listings "at risk" — stale AND underperforming
-- Technique: CTE + compound CASE flag
-- Business question: Which listings need urgent host intervention?
-- ============================================================================
WITH risk_flags AS (
    SELECT
        l.listing_id,
        l.is_stale_listing,
        lp.occupancy_rate,
        CASE
            WHEN l.is_stale_listing = 1 AND lp.occupancy_rate < 0.30 THEN 'High Risk'
            WHEN l.is_stale_listing = 1 OR lp.occupancy_rate < 0.30 THEN 'Moderate Risk'
            ELSE 'Healthy'
        END AS risk_level
    FROM listings l
    JOIN listing_performance lp ON lp.listing_id = l.listing_id
)
SELECT risk_level, COUNT(*) AS num_listings
FROM risk_flags
GROUP BY risk_level
ORDER BY FIELD(risk_level, 'High Risk', 'Moderate Risk', 'Healthy');


-- ============================================================================
-- Q15. Neighborhood investment ranking by estimated ROI
-- Technique: CTE + JOIN across performance and (synthetic) valuation tables
-- Business question: Where should a new investor buy, by yield?
-- NOTE: ROI figures are built on estimated_property_value, which is
--       SYNTHETIC (see docs/DATA_DICTIONARY.md) — label accordingly in any
--       report or dashboard.
-- ============================================================================
SELECT
    n.neighbourhood_name,
    COUNT(l.listing_id)                             AS listing_count,
    ROUND(AVG(lv.estimated_property_value), 0)      AS avg_estimated_property_value,
    ROUND(AVG(lp.revenue_estimate), 2)              AS avg_annual_revenue,
    ROUND(AVG(lv.estimated_annual_roi_pct), 2)       AS avg_estimated_roi_pct
FROM neighbourhoods n
JOIN listings l              ON l.neighbourhood_id = n.neighbourhood_id
JOIN listing_performance lp  ON lp.listing_id = l.listing_id
JOIN listing_valuation lv    ON lv.listing_id = l.listing_id
GROUP BY n.neighbourhood_name
ORDER BY avg_estimated_roi_pct DESC;


-- ============================================================================
-- Q16. Data completeness check — find calendar months with missing data
-- Technique: RECURSIVE CTE (generates a full month spine to diff against)
-- Business question: Are there gaps in our calendar coverage that would
--                     bias occupancy/revenue calculations?
-- ============================================================================
WITH RECURSIVE month_spine AS (
    SELECT DATE_FORMAT(MIN(calendar_date), '%Y-%m-01') AS month_start
    FROM calendar_daily
    UNION ALL
    SELECT DATE_ADD(month_start, INTERVAL 1 MONTH)
    FROM month_spine
    WHERE month_start < (SELECT DATE_FORMAT(MAX(calendar_date), '%Y-%m-01') FROM calendar_daily)
),
actual_months AS (
    SELECT DISTINCT DATE_FORMAT(calendar_date, '%Y-%m-01') AS month_start
    FROM calendar_daily
)
SELECT
    DATE_FORMAT(ms.month_start, '%Y-%m') AS expected_month,
    CASE WHEN am.month_start IS NULL THEN 'MISSING' ELSE 'Present' END AS coverage_status
FROM month_spine ms
LEFT JOIN actual_months am ON am.month_start = ms.month_start
ORDER BY ms.month_start;


-- ============================================================================
-- Q17. Price elasticity — occupancy rate by price category
-- Technique: JOIN + GROUP BY aggregate comparison
-- Business question: Does raising price meaningfully hurt occupancy?
-- ============================================================================
SELECT
    l.price_category,
    COUNT(*)                                AS num_listings,
    ROUND(AVG(l.base_price), 2)             AS avg_price,
    ROUND(AVG(lp.occupancy_rate) * 100, 1)  AS avg_occupancy_pct,
    ROUND(AVG(lp.revpar), 2)                AS avg_revpar
FROM listings l
JOIN listing_performance lp ON lp.listing_id = l.listing_id
GROUP BY l.price_category
ORDER BY FIELD(l.price_category, 'Budget', 'Mid-Range', 'Premium', 'Luxury');


-- ============================================================================
-- Q18. Amenity count impact on price and revenue
-- Technique: CASE-based binning + aggregate
-- Business question: Do more amenities justify higher prices / drive revenue?
-- ============================================================================
SELECT
    CASE
        WHEN l.amenity_count >= 20 THEN '20+ amenities'
        WHEN l.amenity_count >= 10 THEN '10-19 amenities'
        ELSE 'Under 10 amenities'
    END AS amenity_tier,
    COUNT(*)                            AS num_listings,
    ROUND(AVG(l.base_price), 2)         AS avg_price,
    ROUND(AVG(lp.revenue_estimate), 2)  AS avg_revenue
FROM listings l
JOIN listing_performance lp ON lp.listing_id = l.listing_id
GROUP BY amenity_tier
ORDER BY avg_price DESC;


-- ============================================================================
-- Q19. New vs. veteran host benchmark — how far behind is a new host?
-- Technique: Window function AVG() OVER (whole-table baseline comparison)
-- Business question: Set realistic first-90-day performance expectations
-- ============================================================================
SELECT DISTINCT
    h.experience_tier,
    ROUND(AVG(lp.revpar) OVER (PARTITION BY h.experience_tier), 2) AS tier_avg_revpar,
    ROUND(AVG(lp.revpar) OVER (), 2)                               AS market_avg_revpar,
    ROUND(
        AVG(lp.revpar) OVER (PARTITION BY h.experience_tier) - AVG(lp.revpar) OVER (),
        2
    ) AS gap_vs_market
FROM hosts h
JOIN listings l              ON l.host_id = h.host_id
JOIN listing_performance lp  ON lp.listing_id = l.listing_id
ORDER BY tier_avg_revpar DESC;


-- ============================================================================
-- Q20. Executive summary — single-query KPI snapshot for dashboard cards
-- Technique: Scalar subqueries assembled into one summary row
-- Business question: The 6 numbers a VP wants to see before anything else
-- ============================================================================
SELECT
    (SELECT COUNT(*) FROM listings)                                   AS total_listings,
    (SELECT COUNT(DISTINCT host_id) FROM hosts)                       AS total_hosts,
    (SELECT ROUND(SUM(revenue_estimate), 0) FROM listing_performance) AS total_estimated_revenue,
    (SELECT ROUND(AVG(occupancy_rate) * 100, 1) FROM listing_performance) AS avg_occupancy_pct,
    (SELECT ROUND(AVG(revpar), 2) FROM listing_performance)           AS avg_revpar,
    (
        SELECT n.neighbourhood_name
        FROM neighbourhoods n
        JOIN listings l ON l.neighbourhood_id = n.neighbourhood_id
        JOIN listing_performance lp ON lp.listing_id = l.listing_id
        GROUP BY n.neighbourhood_name
        ORDER BY SUM(lp.revenue_estimate) DESC
        LIMIT 1
    ) AS top_neighbourhood_by_revenue;
