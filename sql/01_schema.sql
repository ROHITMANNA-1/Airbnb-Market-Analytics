-- ============================================================================
-- Airbnb Market Analytics & Investment Platform
-- Phase 2: Database Schema (MySQL 8.0 / MySQL Workbench)
-- ============================================================================
-- Design notes:
--   * Schema is in 3NF for the transactional/analytical SQL layer. Phase 3
--     will build a separate STAR schema on top of this for Power BI.
--   * listing_performance and listing_valuation are split out from listings
--     even though it's a 1:1 relationship, because they have a different
--     "nature" and refresh cadence: listings = descriptive attributes
--     (rarely change), listing_performance = recalculated metrics (refreshed
--     whenever the calendar pipeline reruns), listing_valuation = clearly
--     flagged SYNTHETIC estimates (see docs/DATA_DICTIONARY.md). Keeping
--     synthetic data structurally isolated from real data is a deliberate
--     data-governance choice, not just normalization for its own sake.
--   * calendar_daily is the largest table (listings × ~365 days) and is the
--     source of truth Revenue/Occupancy are derived from.
-- ============================================================================

CREATE DATABASE IF NOT EXISTS airbnb_analytics
    CHARACTER SET utf8mb4 COLLATE utf8mb4_unicode_ci;

USE airbnb_analytics;

SET FOREIGN_KEY_CHECKS = 0;

DROP TABLE IF EXISTS review_scores;
DROP TABLE IF EXISTS reviews;
DROP TABLE IF EXISTS calendar_daily;
DROP TABLE IF EXISTS listing_valuation;
DROP TABLE IF EXISTS listing_performance;
DROP TABLE IF EXISTS listings;
DROP TABLE IF EXISTS hosts;
DROP TABLE IF EXISTS neighbourhoods;

SET FOREIGN_KEY_CHECKS = 1;

-- ----------------------------------------------------------------------------
-- 1. neighbourhoods  (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE neighbourhoods (
    neighbourhood_id     INT AUTO_INCREMENT PRIMARY KEY,
    neighbourhood_name   VARCHAR(100) NOT NULL,
    neighbourhood_group  VARCHAR(100),
    CONSTRAINT uq_neighbourhood_name UNIQUE (neighbourhood_name)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 2. hosts  (dimension)
-- ----------------------------------------------------------------------------
CREATE TABLE hosts (
    host_id                    BIGINT PRIMARY KEY,
    host_since                 DATE,
    is_superhost                BOOLEAN DEFAULT FALSE,
    response_rate_pct          DECIMAL(5,2) CHECK (response_rate_pct BETWEEN 0 AND 100),
    response_time               VARCHAR(50),
    identity_verified           BOOLEAN DEFAULT FALSE,
    total_listings_count        INT DEFAULT 0 CHECK (total_listings_count >= 0),
    experience_years            DECIMAL(4,1) CHECK (experience_years >= 0),
    experience_tier             VARCHAR(30)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 3. listings  (dimension / core entity)
-- ----------------------------------------------------------------------------
CREATE TABLE listings (
    listing_id            BIGINT PRIMARY KEY,
    host_id                BIGINT NOT NULL,
    neighbourhood_id       INT NOT NULL,
    property_type           VARCHAR(50),
    room_type                VARCHAR(50) NOT NULL,
    accommodates             SMALLINT CHECK (accommodates > 0),
    bedrooms                  DECIMAL(3,1) CHECK (bedrooms >= 0),
    beds                       DECIMAL(3,1) CHECK (beds >= 0),
    bathrooms                  DECIMAL(3,1) CHECK (bathrooms >= 0),
    amenity_count               SMALLINT DEFAULT 0 CHECK (amenity_count >= 0),
    base_price                   DECIMAL(10,2) NOT NULL CHECK (base_price >= 0),
    price_category                 VARCHAR(20),
    minimum_nights                  SMALLINT CHECK (minimum_nights >= 1),
    maximum_nights                   SMALLINT,
    instant_bookable                  BOOLEAN DEFAULT FALSE,
    first_review_date                  DATE,
    last_review_date                    DATE,
    is_stale_listing                     BOOLEAN DEFAULT FALSE,
    CONSTRAINT fk_listings_host
        FOREIGN KEY (host_id) REFERENCES hosts(host_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    CONSTRAINT fk_listings_neighbourhood
        FOREIGN KEY (neighbourhood_id) REFERENCES neighbourhoods(neighbourhood_id)
        ON UPDATE CASCADE ON DELETE RESTRICT,
    INDEX idx_listings_host (host_id),
    INDEX idx_listings_neighbourhood (neighbourhood_id),
    INDEX idx_listings_room_type (room_type),
    INDEX idx_listings_price_category (price_category)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 4. listing_performance  (derived KPIs — Revenue/Occupancy/ADR/RevPAR)
--    1:1 with listings. This is the table Phase 1's calendar-derived
--    metrics land in.
-- ----------------------------------------------------------------------------
CREATE TABLE listing_performance (
    listing_id                BIGINT PRIMARY KEY,
    total_nights_tracked        SMALLINT NOT NULL CHECK (total_nights_tracked > 0),
    booked_nights                 SMALLINT NOT NULL CHECK (booked_nights >= 0),
    occupancy_rate                  DECIMAL(5,4) CHECK (occupancy_rate BETWEEN 0 AND 1),
    revenue_estimate                  DECIMAL(12,2) DEFAULT 0 CHECK (revenue_estimate >= 0),
    adr                                DECIMAL(10,2) DEFAULT 0,
    revpar                               DECIMAL(10,2) DEFAULT 0,
    avg_open_listing_price                 DECIMAL(10,2),
    pricing_gap                              DECIMAL(10,2),
    pricing_signal                             VARCHAR(30),
    CONSTRAINT fk_perf_listing
        FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT chk_booked_le_tracked CHECK (booked_nights <= total_nights_tracked)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 5. listing_valuation  (⚠️ SYNTHETIC — isolated on purpose, see data dictionary)
-- ----------------------------------------------------------------------------
CREATE TABLE listing_valuation (
    listing_id                    BIGINT PRIMARY KEY,
    estimated_property_value        DECIMAL(12,2) CHECK (estimated_property_value >= 0),
    estimated_annual_roi_pct          DECIMAL(6,2),
    is_synthetic_valuation              BOOLEAN NOT NULL DEFAULT TRUE,
    valuation_multiplier                  SMALLINT DEFAULT 250,
    CONSTRAINT fk_val_listing
        FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 6. calendar_daily  (fact table — grain: 1 row per listing per date)
--    Source of truth for Revenue & Occupancy derivation.
-- ----------------------------------------------------------------------------
CREATE TABLE calendar_daily (
    calendar_id     BIGINT AUTO_INCREMENT PRIMARY KEY,
    listing_id       BIGINT NOT NULL,
    calendar_date      DATE NOT NULL,
    is_available          BOOLEAN NOT NULL,
    price                    DECIMAL(10,2),
    CONSTRAINT fk_cal_listing
        FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    CONSTRAINT uq_listing_date UNIQUE (listing_id, calendar_date),
    INDEX idx_cal_date (calendar_date),
    INDEX idx_cal_listing_date (listing_id, calendar_date)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 7. reviews  (fact table)
-- ----------------------------------------------------------------------------
CREATE TABLE reviews (
    review_id       BIGINT PRIMARY KEY,
    listing_id        BIGINT NOT NULL,
    reviewer_id          BIGINT,
    reviewer_name           VARCHAR(100),
    review_date                DATE NOT NULL,
    comments                     TEXT,
    CONSTRAINT fk_review_listing
        FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
        ON UPDATE CASCADE ON DELETE CASCADE,
    INDEX idx_reviews_listing (listing_id),
    INDEX idx_reviews_date (review_date)
) ENGINE = InnoDB;

-- ----------------------------------------------------------------------------
-- 8. review_scores  (1:1 with listings — sub-scores are a distinct concern
--    from listing attributes, and are frequently NULL for new listings)
-- ----------------------------------------------------------------------------
CREATE TABLE review_scores (
    listing_id             BIGINT PRIMARY KEY,
    rating                    DECIMAL(3,2) CHECK (rating BETWEEN 0 AND 5),
    cleanliness                 DECIMAL(3,2) CHECK (cleanliness BETWEEN 0 AND 5),
    checkin                        DECIMAL(3,2) CHECK (checkin BETWEEN 0 AND 5),
    communication                     DECIMAL(3,2) CHECK (communication BETWEEN 0 AND 5),
    location_score                       DECIMAL(3,2) CHECK (location_score BETWEEN 0 AND 5),
    value_score                             DECIMAL(3,2) CHECK (value_score BETWEEN 0 AND 5),
    composite_score                            DECIMAL(3,2),
    CONSTRAINT fk_scores_listing
        FOREIGN KEY (listing_id) REFERENCES listings(listing_id)
        ON UPDATE CASCADE ON DELETE CASCADE
) ENGINE = InnoDB;
