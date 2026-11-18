# Nacho Fence Analytics (Sample Data)

A Power BI dashboard and SQL analysis for a small fence installation and repair business.

> **All data in this repository is synthetic sample data.** It is modeled on how a small fence business operates, contains no real customers, and none of the results here describe a real business.
>
> **Why synthetic?** This repository documents the method I used to analyze my own fence business's data: the data model, DAX measures, SQL cross-checks, and data quality checks. The real data contains customer information, so it is kept private. I rebuilt the same workflow on synthetic data so the work can be shown and reproduced without exposing anyone's information. The numbers below come from the synthetic dataset only.

## What this project covers

- **Power BI dashboard (2 pages):** Overview (revenue, profit, margin, days to pay, ratings) and Sales & Leads (funnel, lead sources, lost reasons, leads by month)
- **Data model:** 5 tables plus a date table, one-to-many relationships, shared date dimension
- **DAX measures:** conversion rate, profit margin, revenue per foot, average days to pay, and more
- **SQL (DuckDB):** 7 queries used to cross-check every dashboard KPI and to run data quality checks

## Data model

| Table | Rows | Description |
|---|---|---|
| `customers` | 45 | One row per customer: city and lead source |
| `leads` | 126 | Quote requests with outcome (Won, Lost, Quoted) |
| `jobs` | 70 | Completed jobs with revenue, costs, and profit |
| `invoices` | 70 | One invoice per job, with days to pay |
| `reviews` | 47 | Customer ratings by platform |
| `Calendar` | n/a | Date table, shared by `jobs` and `leads` |

**Relationships:** `jobs` → `customers` (many-to-one), `leads` → `customers` (many-to-one), `jobs` ↔ `invoices` (one-to-one), `jobs` ↔ `reviews` (one-to-one), `Calendar` → `jobs[job_date]` and `Calendar` → `leads[requested_date]` (one-to-many).

## Data dictionary

**customers**
| Column | Description |
|---|---|
| `customer_id` | Unique customer key |
| `first_name`, `last_name` | Synthetic names |
| `city` | Customer's city |
| `lead_source` | How the customer found the business (Referral, Google, and so on) |
| `notes` | Free text, mostly empty |

**leads**
| Column | Description |
|---|---|
| `lead_id` | Unique lead key |
| `customer_id` | Links to `customers` |
| `requested_date` | Date the quote was requested |
| `fence_type` | Fence type requested (uses labels such as "Wood privacy" that differ from `jobs`) |
| `status` | Won, Lost, or Quoted (open) |
| `lost_reason` | Reason for a lost lead (Price, Timing, and so on) |

**jobs**
| Column | Description |
|---|---|
| `job_id` | Unique job key |
| `customer_id` | Links to `customers` |
| `job_date` | Date of the job |
| `job_type` | Repair or Replacement |
| `fence_type` | Fence type installed or repaired |
| `linear_feet` | Length of fence (empty for repairs) |
| `crew_days`, `helpers`, `hours` | Labor inputs |
| `material_cost`, `helper_pay`, `gas_cost` | Cost components |
| `revenue` | Amount billed |
| `profit` | `revenue - material_cost - helper_pay - gas_cost` |
| `margin` | `profit / revenue` for the job |

**invoices**
| Column | Description |
|---|---|
| `invoice_id` | Unique invoice key |
| `job_id` | Links to `jobs` |
| `invoice_date`, `paid_date` | Issue and payment dates |
| `amount` | Invoice amount |
| `days_to_pay` | Days between invoice and payment |
| `payment_method` | Cash, Card, and so on |

**reviews**
| Column | Description |
|---|---|
| `review_id` | Unique review key |
| `job_id` | Links to `jobs` |
| `review_date` | Date of the review |
| `rating` | 1 to 5 |
| `platform` | Where the review was posted |

## DAX measures

```dax
Total Leads = COUNTROWS(leads)
Won Leads = CALCULATE([Total Leads], leads[status] = "Won")
Lead Conversion Rate = DIVIDE([Won Leads], [Total Leads])
Total Jobs = COUNTROWS(jobs)
Total Revenue = SUM(jobs[revenue])
Total Profit = SUM(jobs[profit])
Profit Margin % = DIVIDE([Total Profit], [Total Revenue])
Avg Days to Pay = AVERAGE(invoices[days_to_pay])
Avg Rating = AVERAGE(reviews[rating])
Revenue per Job = DIVIDE([Total Revenue], [Total Jobs])
Revenue per Foot =
    DIVIDE(
        CALCULATE(SUM(jobs[revenue]), NOT(ISBLANK(jobs[linear_feet]))),
        SUM(jobs[linear_feet])
    )
```

Margin is calculated as total profit divided by total revenue (a weighted figure), not as the average of each job's margin.

## SQL validation

`nacho_queries.sql` loads the CSVs into DuckDB and reproduces the dashboard numbers:

| Query | Technique | Purpose |
|---|---|---|
| 1 | Aggregates | Headline KPIs |
| 2 | `GROUP BY` | Margin by fence type |
| 3 | `JOIN`, `CASE WHEN` | Lead conversion by source |
| 4 | CTE, window function | Monthly revenue with running total |
| 5 | Multi-table `JOIN`, `HAVING` | Payment speed by method and city |
| 6 | `RANK`, `QUALIFY` | Top jobs within each fence type |
| 7 | Distinct values, `LEFT JOIN` | Data quality checks and label cleaning |

## Sample findings

Results from the synthetic dataset, shown to demonstrate the analysis:

- 126 leads, 67 won (53.2% conversion; 63.2% counting only closed leads)
- $272,365 revenue and $76,308 profit across 70 jobs (28.0% margin)
- Repairs have the highest margin (48.9%) but only about 9% of revenue
- Referral leads convert best (70.6%); Facebook converts worst (33.3% on only 6 leads)
- The largest city by revenue (Douglasville) is also the slowest to pay (21.5 days vs. 13.6 average)
- Data quality: `leads.fence_type` uses "Wood privacy" and "Vinyl privacy" where `jobs.fence_type` uses "Wood" and "Vinyl"

## Limitations

- The data is synthetic, so findings reflect how the sample was built, not real business performance.
- 20 leads are still open (Quoted) and are counted as not won.
- Revenue per foot excludes repairs, which have no linear footage.
- Average rating covers only the 47 of 70 jobs that have a review.

## How to run

1. Install DuckDB (`brew install duckdb` on macOS).
2. Put the five CSV files and `nacho_queries.sql` in one folder.
3. In that folder, run `duckdb`, then `.read nacho_queries.sql`.

## Tools

Power BI Desktop, DAX, DuckDB (SQL), Excel
