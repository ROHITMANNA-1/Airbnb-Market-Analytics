"""
03_export_for_mysql.py
------------------------
Airbnb Market Analytics & Investment Platform — Phase 2

Splits the Phase 1 output (master_analytics_table.csv, calendar_clean.csv,
reviews_clean.csv) into normalized CSVs matching sql/01_schema.sql, ready
for MySQL Workbench's Table Data Import Wizard (or LOAD DATA INFILE).

Run AFTER 01_data_cleaning.py and 02_feature_engineering.py:
    python scripts/03_export_for_mysql.py

Output: data/processed/mysql_load/*.csv  (one file per table, in FK-safe
load order: neighbourhoods, hosts, listings, listing_performance,
listing_valuation, calendar_daily, reviews, review_scores)
"""

import os
import pandas as pd

PROCESSED_DIR = os.path.join("data", "processed")
LOAD_DIR = os.path.join(PROCESSED_DIR, "mysql_load")
os.makedirs(LOAD_DIR, exist_ok=True)


def print_section(title: str) -> None:
    print("\n" + "=" * 70)
    print(title)
    print("=" * 70)


if __name__ == "__main__":
    master = pd.read_csv(os.path.join(PROCESSED_DIR, "master_analytics_table.csv"))
    calendar = pd.read_csv(
        os.path.join(PROCESSED_DIR, "calendar_clean.csv"), parse_dates=["date"]
    )
    reviews = pd.read_csv(
        os.path.join(PROCESSED_DIR, "reviews_clean.csv"), parse_dates=["date"]
    )

    # ------------------------------------------------------------------
    # 1. neighbourhoods — surrogate key generated here, mapped back onto listings
    # ------------------------------------------------------------------
    print_section("Building neighbourhoods.csv")
    neigh_col = "neighbourhood_cleansed"
    neigh_group_col = "neighbourhood_group_cleansed"
    neighbourhood_columns = [neigh_col]
    if neigh_group_col in master.columns:
        neighbourhood_columns.append(neigh_group_col)
    unique_neigh = master[neighbourhood_columns].drop_duplicates(subset=[neigh_col])
    unique_neigh = unique_neigh.sort_values(neigh_col).reset_index(drop=True)
    unique_neigh["neighbourhood_id"] = unique_neigh.index + 1
    if neigh_group_col in unique_neigh.columns:
        unique_neigh = unique_neigh.rename(columns={neigh_group_col: "neighbourhood_group"})
    else:
        unique_neigh["neighbourhood_group"] = None
    neighbourhoods_out = unique_neigh.rename(
        columns={neigh_col: "neighbourhood_name"}
    )[["neighbourhood_id", "neighbourhood_name", "neighbourhood_group"]]
    neighbourhoods_out.to_csv(os.path.join(LOAD_DIR, "neighbourhoods.csv"), index=False)
    print(f"{len(neighbourhoods_out)} neighbourhoods")

    master = master.merge(
        unique_neigh[[neigh_col, "neighbourhood_id"]], on=neigh_col, how="left"
    )

    # ------------------------------------------------------------------
    # 2. hosts
    # ------------------------------------------------------------------
    print_section("Building hosts.csv")
    host_cols = {
        "host_id": "host_id",
        "host_since": "host_since",
        "host_is_superhost": "is_superhost",
        "host_response_rate": "response_rate_pct",
        "host_response_time": "response_time",
        "host_identity_verified": "identity_verified",
        "host_total_listings_count": "total_listings_count",
        "host_experience_years": "experience_years",
        "host_experience_tier": "experience_tier",
    }
    present = {k: v for k, v in host_cols.items() if k in master.columns}
    hosts_out = master[list(present.keys())].rename(columns=present)
    hosts_out = hosts_out.drop_duplicates(subset=["host_id"])
    for bool_col in ["is_superhost", "identity_verified"]:
        if bool_col in hosts_out.columns:
            hosts_out[bool_col] = hosts_out[bool_col].fillna(False).astype(int)
    hosts_out.to_csv(os.path.join(LOAD_DIR, "hosts.csv"), index=False)
    print(f"{len(hosts_out)} hosts")

    # ------------------------------------------------------------------
    # 3. listings
    # ------------------------------------------------------------------
    print_section("Building listings.csv")
    listing_cols = {
        "id": "listing_id",
        "host_id": "host_id",
        "neighbourhood_id": "neighbourhood_id",
        "property_type": "property_type",
        "room_type": "room_type",
        "accommodates": "accommodates",
        "bedrooms": "bedrooms",
        "beds": "beds",
        "bathrooms": "bathrooms",
        "amenity_count": "amenity_count",
        "price": "base_price",
        "price_category": "price_category",
        "minimum_nights": "minimum_nights",
        "maximum_nights": "maximum_nights",
        "instant_bookable": "instant_bookable",
        "first_review": "first_review_date",
        "last_review": "last_review_date",
        "is_stale_listing": "is_stale_listing",
    }
    present = {k: v for k, v in listing_cols.items() if k in master.columns}
    listings_out = master[list(present.keys())].rename(columns=present)
    for bool_col in ["instant_bookable", "is_stale_listing"]:
        if bool_col in listings_out.columns:
            listings_out[bool_col] = (
                listings_out[bool_col].astype("boolean").fillna(False).astype(int)
            )
    listings_out.to_csv(os.path.join(LOAD_DIR, "listings.csv"), index=False)
    print(f"{len(listings_out)} listings")

    # ------------------------------------------------------------------
    # 4. listing_performance
    # ------------------------------------------------------------------
    print_section("Building listing_performance.csv")
    perf_cols = {
        "id": "listing_id",
        "total_nights_tracked": "total_nights_tracked",
        "booked_nights": "booked_nights",
        "occupancy_rate": "occupancy_rate",
        "revenue_estimate": "revenue_estimate",
        "adr": "adr",
        "revpar": "revpar",
        "avg_open_listing_price": "avg_open_listing_price",
        "pricing_gap": "pricing_gap",
        "pricing_signal": "pricing_signal",
    }
    present = {k: v for k, v in perf_cols.items() if k in master.columns}
    perf_out = master[list(present.keys())].rename(columns=present)
    perf_out = perf_out.dropna(subset=["total_nights_tracked"])
    perf_out.to_csv(os.path.join(LOAD_DIR, "listing_performance.csv"), index=False)
    print(f"{len(perf_out)} performance rows")

    # ------------------------------------------------------------------
    # 5. listing_valuation (synthetic)
    # ------------------------------------------------------------------
    print_section("Building listing_valuation.csv")
    val_cols = {
        "id": "listing_id",
        "estimated_property_value": "estimated_property_value",
        "estimated_annual_roi_pct": "estimated_annual_roi_pct",
        "is_synthetic_valuation": "is_synthetic_valuation",
    }
    present = {k: v for k, v in val_cols.items() if k in master.columns}
    val_out = master[list(present.keys())].rename(columns=present)
    val_out["valuation_multiplier"] = 250
    val_out["is_synthetic_valuation"] = val_out["is_synthetic_valuation"].fillna(True).astype(int)
    val_out.to_csv(os.path.join(LOAD_DIR, "listing_valuation.csv"), index=False)
    print(f"{len(val_out)} valuation rows")

    # ------------------------------------------------------------------
    # 6. calendar_daily
    # ------------------------------------------------------------------
    print_section("Building calendar_daily.csv")
    cal_out = calendar.rename(
        columns={"listing_id": "listing_id", "date": "calendar_date", "available": "is_available"}
    )[["listing_id", "calendar_date", "is_available", "price"]]
    cal_out["is_available"] = cal_out["is_available"].astype(int)
    cal_out.to_csv(os.path.join(LOAD_DIR, "calendar_daily.csv"), index=False)
    print(f"{len(cal_out):,} calendar rows")

    # ------------------------------------------------------------------
    # 7. reviews
    # ------------------------------------------------------------------
    print_section("Building reviews.csv")
    rev_out = reviews.rename(columns={"id": "review_id", "date": "review_date"})
    rev_cols = [c for c in ["review_id", "listing_id", "reviewer_id", "reviewer_name", "review_date", "comments"] if c in rev_out.columns]
    rev_out = rev_out[rev_cols]
    rev_out.to_csv(os.path.join(LOAD_DIR, "reviews.csv"), index=False)
    print(f"{len(rev_out)} reviews")

    # ------------------------------------------------------------------
    # 8. review_scores
    # ------------------------------------------------------------------
    print_section("Building review_scores.csv")
    score_cols = {
        "id": "listing_id",
        "review_scores_rating": "rating",
        "review_scores_cleanliness": "cleanliness",
        "review_scores_checkin": "checkin",
        "review_scores_communication": "communication",
        "review_scores_location": "location_score",
        "review_scores_value": "value_score",
        "review_score_composite": "composite_score",
    }
    present = {k: v for k, v in score_cols.items() if k in master.columns}
    scores_out = master[list(present.keys())].rename(columns=present)
    # Inside Airbnb's review_scores_rating is on a 0-100 scale; our schema
    # (and the other five sub-scores) use 0-5, so rescale rating to match.
    if "rating" in scores_out.columns:
        scores_out["rating"] = (scores_out["rating"] / 20).round(2)
    scores_out.to_csv(os.path.join(LOAD_DIR, "review_scores.csv"), index=False)
    print(f"{len(scores_out)} review_scores rows")

    print_section("DONE")
    print(f"All 8 load-ready CSVs written to {LOAD_DIR}/")
    print("Load order (respects foreign keys): neighbourhoods -> hosts -> listings ->")
    print("  listing_performance -> listing_valuation -> calendar_daily -> reviews -> review_scores")
    print("See sql/02_load_data_workbench.md for MySQL Workbench import instructions.")
