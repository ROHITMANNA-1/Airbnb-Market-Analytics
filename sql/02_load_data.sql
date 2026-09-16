-- ============================================================================
-- Airbnb Market Analytics & Investment Platform
-- Phase 2: Data Loading (MySQL LOAD DATA INFILE)
-- ============================================================================
-- Prereqs:
--   1. sql/01_schema.sql already executed
--   2. The 8 CSVs from data/processed/mysql_load/ copied into the directory
--      shown by: SHOW VARIABLES LIKE 'secure_file_priv';
--   3. Adjust the path below (currently set to a typical Linux default) to
--      match your machine.
--
-- See sql/02_load_data_workbench.md if you'd rather use the Table Data
-- Import Wizard GUI instead, or want the LOAD DATA LOCAL INFILE variant.
-- ============================================================================

USE airbnb_analytics;

SET FOREIGN_KEY_CHECKS = 0;

-- 1. neighbourhoods -----------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/neighbourhoods.csv'
INTO TABLE neighbourhoods
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(neighbourhood_id, neighbourhood_name, @neighbourhood_group)
SET neighbourhood_group = NULLIF(@neighbourhood_group, '');

-- 2. hosts ----------------------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/hosts.csv'
INTO TABLE hosts
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(host_id, @host_since, is_superhost, @response_rate_pct, response_time,
 identity_verified, total_listings_count, @experience_years, experience_tier)
SET
  host_since = NULLIF(@host_since, ''),
  response_rate_pct = NULLIF(@response_rate_pct, ''),
  experience_years = NULLIF(@experience_years, '');

-- 3. listings ---------------------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/listings.csv'
INTO TABLE listings
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(listing_id, host_id, neighbourhood_id, property_type, room_type,
 @accommodates, @bedrooms, @beds, @bathrooms, amenity_count, base_price,
 price_category, minimum_nights, maximum_nights, instant_bookable,
 @first_review_date, @last_review_date, is_stale_listing)
SET
  accommodates = NULLIF(@accommodates, ''),
  bedrooms = NULLIF(@bedrooms, ''),
  beds = NULLIF(@beds, ''),
  bathrooms = NULLIF(@bathrooms, ''),
  first_review_date = NULLIF(@first_review_date, ''),
  last_review_date = NULLIF(@last_review_date, '');

-- 4. listing_performance ------------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/listing_performance.csv'
INTO TABLE listing_performance
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(listing_id, total_nights_tracked, booked_nights, occupancy_rate,
 revenue_estimate, adr, revpar, @avg_open_listing_price, pricing_gap, pricing_signal)
SET avg_open_listing_price = NULLIF(@avg_open_listing_price, '');

-- 5. listing_valuation (synthetic) ---------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/listing_valuation.csv'
INTO TABLE listing_valuation
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(listing_id, estimated_property_value, @estimated_annual_roi_pct,
 is_synthetic_valuation, valuation_multiplier)
SET estimated_annual_roi_pct = NULLIF(@estimated_annual_roi_pct, '');

-- 6. calendar_daily (largest table) ----------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/calendar_daily.csv'
INTO TABLE calendar_daily
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(listing_id, calendar_date, is_available, @price)
SET price = NULLIF(@price, '');

-- 7. reviews ------------------------------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/reviews.csv'
INTO TABLE reviews
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(review_id, listing_id, @reviewer_id, reviewer_name, review_date, comments)
SET reviewer_id = NULLIF(@reviewer_id, '');

-- 8. review_scores --------------------------------------------------------------------
LOAD DATA INFILE '/var/lib/mysql-files/review_scores.csv'
INTO TABLE review_scores
FIELDS TERMINATED BY ',' OPTIONALLY ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(listing_id, @rating, @cleanliness, @checkin, @communication, @location_score,
 @value_score, @composite_score)
SET
  rating = NULLIF(@rating, ''),
  cleanliness = NULLIF(@cleanliness, ''),
  checkin = NULLIF(@checkin, ''),
  communication = NULLIF(@communication, ''),
  location_score = NULLIF(@location_score, ''),
  value_score = NULLIF(@value_score, ''),
  composite_score = NULLIF(@composite_score, '');

SET FOREIGN_KEY_CHECKS = 1;

-- Verify
SELECT
  (SELECT COUNT(*) FROM neighbourhoods)      AS neighbourhoods,
  (SELECT COUNT(*) FROM hosts)               AS hosts,
  (SELECT COUNT(*) FROM listings)            AS listings,
  (SELECT COUNT(*) FROM listing_performance) AS listing_performance,
  (SELECT COUNT(*) FROM listing_valuation)   AS listing_valuation,
  (SELECT COUNT(*) FROM calendar_daily)      AS calendar_daily,
  (SELECT COUNT(*) FROM reviews)             AS reviews,
  (SELECT COUNT(*) FROM review_scores)       AS review_scores;
