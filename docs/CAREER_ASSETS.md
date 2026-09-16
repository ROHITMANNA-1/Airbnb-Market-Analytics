# Career Assets — Resume, LinkedIn & Portfolio Copy

**Note on metrics:** bullets below use the XYZ formula (Accomplished [X] as
measured by [Y], by doing [Z]) with placeholder metrics in brackets.
Replace these once you've run the pipeline against real Inside Airbnb data
— e.g. actual listing count, actual $ pricing-opportunity total from SQL
Q6, actual RMSE from Phase 6's model. Never leave bracketed placeholders on
a submitted resume; an unfilled placeholder reads worse than a modest real
number.

---

## Resume bullets (4, XYZ formula)

**1. Pipeline & data engineering**
> Engineered an end-to-end analytics pipeline processing **[50,000+]**
> Airbnb listings across London/NYC, cutting manual KPI reporting time by
> an estimated **[70%]**, by building a Python-based ETL process that
> derives revenue and occupancy metrics from 18M+ raw calendar records and
> loads them into a normalized MySQL database.

**2. SQL & pricing analytics**
> Identified **[$XX,XXX]** in estimated annual pricing-optimization
> opportunity, as measured by a dynamic pricing-gap model comparing listed
> vs. realized rates, by developing a 20-query SQL library using window
> functions, CTEs, and a recursive CTE for data-completeness validation
> against an 8-table normalized schema.

**3. Power BI & dashboard delivery**
> Delivered a 7-page Power BI dashboard covering Executive, Revenue,
> Pricing, Host, and Investment KPIs, enabling self-service analysis for
> **[non-technical stakeholders]**, by designing a galaxy-schema data model
> (2 fact / 4 dimension tables) with 15 DAX measures supporting time
> intelligence, dynamic ranking, and moving averages.

**4. Machine learning**
> Improved nightly price-recommendation accuracy to within **[$XX]** RMSE
> of actual market rates, as measured against a held-out test set, by
> training and evaluating a scikit-learn regression model on 20+
> engineered listing, host, and location features.

---

## LinkedIn "Featured" / Projects section

> **Airbnb Market Analytics & Investment Platform**
> End-to-end BI project turning raw Inside Airbnb data into an
> investor-and-host-facing analytics platform. Built a Python pipeline
> deriving revenue and occupancy from calendar availability data (Inside
> Airbnb doesn't publish these directly), a normalized MySQL warehouse with
> a 20-query analytics library, and a 7-page Power BI dashboard on a
> galaxy-schema model with 15 custom DAX measures. Includes a scikit-learn
> pricing model and a fully documented data dictionary distinguishing raw,
> derived, and synthetic fields — because knowing exactly how confident to
> be in a number is as important as the number itself.
> `Python · pandas · MySQL · Power BI · DAX · scikit-learn`
> [GitHub link] · [Dashboard screenshot/demo link]

## Portfolio site — one-paragraph summary

> I built a full-stack analytics platform on Inside Airbnb data to answer
> the questions a real property management company or investor would
> actually ask: which listings earn the most, which are mispriced, and
> where's the best (estimated) ROI for new investment. The project spans
> the full analytics stack — Python for cleaning and feature engineering,
> MySQL for a normalized warehouse and a 20-query interview-grade SQL
> library, and Power BI for an interactive 7-page dashboard on a
> purpose-built star schema. I was deliberate about data honesty
> throughout: every derived and synthetic field is documented, and the
> investment/ROI page carries an explicit disclosure that its valuations
> are illustrative, not real appraisals.

## Portfolio site — project card (short version, for a grid/list view)

> **Airbnb Market Analytics Platform** — Python · MySQL · Power BI
> End-to-end BI pipeline deriving revenue/occupancy from raw booking-
> calendar data, a 20-query SQL analytics library, and a 7-page
> interactive dashboard with 15 custom DAX measures.
