// ============================================================================
// Airbnb Market Analytics & Investment Platform
// Phase 3: Power Query M — builds the star schema from the Phase 2 MySQL DB
// ============================================================================
// In Power BI Desktop: Get Data -> MySQL database -> Server: localhost,
// Database: airbnb_analytics. Then Transform Data to open Power Query Editor,
// and paste each query below as a New Blank Query (Home -> New Source ->
// Blank Query -> Advanced Editor -> paste).
//
// Load order doesn't matter to Power BI (it resolves dependencies), but is
// listed in dependency order below for readability:
//   DimDate, DimNeighbourhood, DimHost, DimListing  (dimensions first)
//   FactListingPerformance, FactCalendarDaily, FactReviews, FactReviewScores
//   (facts reference dims)
// ============================================================================


// ----------------------------------------------------------------------------
// DimDate — generated in M rather than loaded from SQL, spanning the full
// range actually present in calendar_daily (with a little padding either
// side so relative-date slicers don't clip at the edges).
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    CalendarTable = Source{[Schema="airbnb_analytics", Item="calendar_daily"]}[Data],
    MinDate = Date.AddDays(List.Min(CalendarTable[calendar_date]), -7),
    MaxDate = Date.AddDays(List.Max(CalendarTable[calendar_date]), 7),
    DateList = List.Dates(MinDate, Duration.Days(MaxDate - MinDate) + 1, #duration(1,0,0,0)),
    ToTable = Table.FromList(DateList, Splitter.SplitByNothing(), {"Date"}),
    ChangedType = Table.TransformColumnTypes(ToTable, {{"Date", type date}}),
    AddDateKey = Table.AddColumn(ChangedType, "DateKey", each Date.ToText([Date], "yyyyMMdd"), type text),
    AddYear = Table.AddColumn(AddDateKey, "Year", each Date.Year([Date]), Int64.Type),
    AddQuarter = Table.AddColumn(AddYear, "Quarter", each Date.QuarterOfYear([Date]), Int64.Type),
    AddMonthNum = Table.AddColumn(AddQuarter, "MonthNum", each Date.Month([Date]), Int64.Type),
    AddMonthName = Table.AddColumn(AddMonthNum, "MonthName", each Date.ToText([Date], "MMMM"), type text),
    AddYearMonth = Table.AddColumn(AddMonthName, "YearMonth", each Date.ToText([Date], "yyyy-MM"), type text),
    AddDayName = Table.AddColumn(AddYearMonth, "DayName", each Date.ToText([Date], "dddd"), type text),
    AddIsWeekend = Table.AddColumn(AddDayName, "IsWeekend", each Date.DayOfWeek([Date], Day.Monday) >= 5, type logical),
    Reordered = Table.ReorderColumns(AddIsWeekend,
        {"DateKey","Date","Year","Quarter","MonthNum","MonthName","YearMonth","DayName","IsWeekend"})
in
    Reordered


// ----------------------------------------------------------------------------
// DimNeighbourhood — thin passthrough, renamed to model conventions
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    NeighTable = Source{[Schema="airbnb_analytics", Item="neighbourhoods"]}[Data],
    Renamed = Table.RenameColumns(NeighTable, {
        {"neighbourhood_id", "NeighbourhoodKey"},
        {"neighbourhood_name", "NeighbourhoodName"},
        {"neighbourhood_group", "NeighbourhoodGroup"}
    })
in
    Renamed


// ----------------------------------------------------------------------------
// DimHost
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    HostTable = Source{[Schema="airbnb_analytics", Item="hosts"]}[Data],
    Renamed = Table.RenameColumns(HostTable, {
        {"host_id", "HostKey"},
        {"host_since", "HostSince"},
        {"is_superhost", "IsSuperhost"},
        {"response_rate_pct", "ResponseRatePct"},
        {"total_listings_count", "TotalListingsCount"},
        {"experience_years", "ExperienceYears"},
        {"experience_tier", "ExperienceTier"}
    }),
    Removed = Table.RemoveColumns(Renamed, {"response_time", "identity_verified"})
in
    Removed


// ----------------------------------------------------------------------------
// DimListing — includes a PriceCategorySort helper column so "Budget < Mid-
// Range < Premium < Luxury" sorts correctly in visuals instead of
// alphabetically (this is what "Sort by Column" in Power BI points at).
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    ListingsTable = Source{[Schema="airbnb_analytics", Item="listings"]}[Data],
    Renamed = Table.RenameColumns(ListingsTable, {
        {"listing_id", "ListingKey"},
        {"property_type", "PropertyType"},
        {"room_type", "RoomType"},
        {"accommodates", "Accommodates"},
        {"bedrooms", "Bedrooms"},
        {"beds", "Beds"},
        {"bathrooms", "Bathrooms"},
        {"amenity_count", "AmenityCount"},
        {"base_price", "BasePrice"},
        {"price_category", "PriceCategory"},
        {"minimum_nights", "MinimumNights"},
        {"maximum_nights", "MaximumNights"},
        {"instant_bookable", "InstantBookable"},
        {"first_review_date", "FirstReviewDate"},
        {"last_review_date", "LastReviewDate"},
        {"is_stale_listing", "IsStaleListing"}
    }),
    AddSort = Table.AddColumn(Renamed, "PriceCategorySort", each
        if [PriceCategory] = "Budget" then 1
        else if [PriceCategory] = "Mid-Range" then 2
        else if [PriceCategory] = "Premium" then 3
        else if [PriceCategory] = "Luxury" then 4
        else 0, Int64.Type),
    // host_id / neighbourhood_id are dropped here — DimListing doesn't need
    // them once loaded, since the FACT tables carry their own HostKey /
    // NeighbourhoodKey (denormalized below), keeping this a pure star.
    Removed = Table.RemoveColumns(AddSort, {"host_id", "neighbourhood_id"})
in
    Removed


// ----------------------------------------------------------------------------
// FactListingPerformance — merges listing_performance + listing_valuation,
// and denormalizes host_id / neighbourhood_id from listings so this fact
// connects directly to DimHost / DimNeighbourhood (no snowflake through
// DimListing).
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    Perf = Source{[Schema="airbnb_analytics", Item="listing_performance"]}[Data],
    Valuation = Source{[Schema="airbnb_analytics", Item="listing_valuation"]}[Data],
    Listings = Source{[Schema="airbnb_analytics", Item="listings"]}[Data],

    MergeValuation = Table.NestedJoin(Perf, {"listing_id"}, Valuation, {"listing_id"}, "val", JoinKind.LeftOuter),
    ExpandValuation = Table.ExpandTableColumn(MergeValuation, "val",
        {"estimated_property_value", "estimated_annual_roi_pct", "is_synthetic_valuation"},
        {"EstimatedPropertyValue", "EstimatedAnnualROIPct", "IsSyntheticValuation"}),

    MergeListings = Table.NestedJoin(ExpandValuation, {"listing_id"}, Listings, {"listing_id"}, "lst", JoinKind.LeftOuter),
    ExpandListings = Table.ExpandTableColumn(MergeListings, "lst", {"host_id", "neighbourhood_id"}, {"HostKey", "NeighbourhoodKey"}),

    Renamed = Table.RenameColumns(ExpandListings, {
        {"listing_id", "ListingKey"},
        {"total_nights_tracked", "TotalNightsTracked"},
        {"booked_nights", "BookedNights"},
        {"occupancy_rate", "OccupancyRate"},
        {"revenue_estimate", "RevenueEstimate"},
        {"adr", "ADR"},
        {"revpar", "RevPAR"},
        {"avg_open_listing_price", "AvgOpenListingPrice"},
        {"pricing_gap", "PricingGap"},
        {"pricing_signal", "PricingSignal"}
    })
in
    Renamed


// ----------------------------------------------------------------------------
// FactCalendarDaily — the largest table (listings x days). Adds DateKey to
// match DimDate's text key format, denormalizes HostKey/NeighbourhoodKey,
// and computes BookedRevenue / IsBooked once here rather than in DAX so
// every downstream measure is a simple SUM (cheaper than an IF at query time).
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    Calendar = Source{[Schema="airbnb_analytics", Item="calendar_daily"]}[Data],
    Listings = Source{[Schema="airbnb_analytics", Item="listings"]}[Data],

    MergeListings = Table.NestedJoin(Calendar, {"listing_id"}, Listings, {"listing_id"}, "lst", JoinKind.LeftOuter),
    ExpandListings = Table.ExpandTableColumn(MergeListings, "lst", {"host_id", "neighbourhood_id"}, {"HostKey", "NeighbourhoodKey"}),

    AddDateKey = Table.AddColumn(ExpandListings, "DateKey", each Date.ToText([calendar_date], "yyyyMMdd"), type text),
    AddIsBooked = Table.AddColumn(AddDateKey, "IsBooked", each if [is_available] = false then 1 else 0, Int64.Type),
    AddBookedRevenue = Table.AddColumn(AddIsBooked, "BookedRevenue", each if [is_available] = false then [price] else 0, type number),

    Renamed = Table.RenameColumns(AddBookedRevenue, {
        {"listing_id", "ListingKey"},
        {"calendar_date", "Date"},
        {"is_available", "IsAvailable"},
        {"price", "Price"}
    }),
    Removed = Table.RemoveColumns(Renamed, {"calendar_id"})
in
    Removed


// ----------------------------------------------------------------------------
// FactReviews
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    Reviews = Source{[Schema="airbnb_analytics", Item="reviews"]}[Data],
    Listings = Source{[Schema="airbnb_analytics", Item="listings"]}[Data],

    MergeListings = Table.NestedJoin(Reviews, {"listing_id"}, Listings, {"listing_id"}, "lst", JoinKind.LeftOuter),
    ExpandListings = Table.ExpandTableColumn(MergeListings, "lst", {"host_id", "neighbourhood_id"}, {"HostKey", "NeighbourhoodKey"}),

    AddDateKey = Table.AddColumn(ExpandListings, "ReviewDateKey", each Date.ToText([review_date], "yyyyMMdd"), type text),
    AddReviewCount = Table.AddColumn(AddDateKey, "ReviewCount", each 1, Int64.Type),

    Renamed = Table.RenameColumns(AddReviewCount, {
        {"review_id", "ReviewKey"},
        {"listing_id", "ListingKey"},
        {"review_date", "ReviewDate"}
    }),
    Removed = Table.RemoveColumns(Renamed, {"reviewer_id", "reviewer_name", "comments"})
    // comments dropped from the model deliberately — free text has no place
    // in a star schema fact table and bloats the .pbix; keep it in the SQL
    // layer for anyone who needs to read individual reviews.
in
    Removed


// ----------------------------------------------------------------------------
// FactReviewScores — one row per listing, kept separate from performance so
// review-quality visuals remain at listing grain and do not duplicate daily rows.
// ----------------------------------------------------------------------------
let
    Source = MySQL.Database("localhost", "airbnb_analytics"),
    Scores = Source{[Schema="airbnb_analytics", Item="review_scores"]}[Data],
    Listings = Source{[Schema="airbnb_analytics", Item="listings"]}[Data],
    MergeListings = Table.NestedJoin(Scores, {"listing_id"}, Listings, {"listing_id"}, "lst", JoinKind.LeftOuter),
    ExpandListings = Table.ExpandTableColumn(MergeListings, "lst", {"host_id", "neighbourhood_id"}, {"HostKey", "NeighbourhoodKey"}),
    Renamed = Table.RenameColumns(ExpandListings, {
        {"listing_id", "ListingKey"},
        {"rating", "Rating"},
        {"cleanliness", "Cleanliness"},
        {"checkin", "Checkin"},
        {"communication", "Communication"},
        {"location_score", "LocationScore"},
        {"value_score", "ValueScore"},
        {"composite_score", "CompositeScore"}
    })
in
    Renamed
