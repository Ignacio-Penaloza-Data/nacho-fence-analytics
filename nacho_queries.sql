-- ============================================================
-- Nacho Fence Analysis (SAMPLE DATA) - SQL practice in DuckDB
-- Purpose: cross-check the Power BI dashboard numbers with SQL
-- Data: synthetic sample data, not real business results
-- Run from the folder containing the five CSV files:
--   duckdb  then  .read nacho_queries.sql
-- ============================================================

-- 0. LOAD: read each CSV into a table
CREATE OR REPLACE TABLE customers AS SELECT * FROM read_csv_auto('customers.csv');
CREATE OR REPLACE TABLE leads     AS SELECT * FROM read_csv_auto('leads.csv');
CREATE OR REPLACE TABLE jobs      AS SELECT * FROM read_csv_auto('jobs.csv');
CREATE OR REPLACE TABLE invoices  AS SELECT * FROM read_csv_auto('invoices.csv');
CREATE OR REPLACE TABLE reviews   AS SELECT * FROM read_csv_auto('reviews.csv');

-- 1. HEADLINE KPIs (matches Power BI cards: 272365 | 76308 | 28.02 | 70)
--    Margin divides totals (weighted), not the average of job margins.
SELECT SUM(revenue) AS total_revenue,
       SUM(profit)  AS total_profit,
       ROUND(100.0 * SUM(profit) / SUM(revenue), 2) AS margin_pct,
       COUNT(*)     AS total_jobs
FROM jobs;

-- 2. MARGIN BY FENCE TYPE (GROUP BY) - repairs have the best margin, lowest volume
SELECT fence_type,
       COUNT(*) AS jobs,
       SUM(revenue) AS revenue,
       ROUND(100.0 * SUM(profit) / SUM(revenue), 1) AS margin_pct
FROM jobs
GROUP BY fence_type
ORDER BY margin_pct DESC;

-- 3. LEAD CONVERSION BY SOURCE (JOIN + CASE WHEN)
--    Quoted (open) leads count as not won, so overall rate is 67/126 = 53.17%.
SELECT c.lead_source,
       COUNT(*) AS total_leads,
       SUM(CASE WHEN l.status = 'Won' THEN 1 ELSE 0 END) AS won_leads,
       ROUND(100.0 * SUM(CASE WHEN l.status = 'Won' THEN 1 ELSE 0 END) / COUNT(*), 2) AS conversion_pct
FROM leads l
JOIN customers c ON l.customer_id = c.customer_id
GROUP BY c.lead_source
ORDER BY conversion_pct DESC;

-- 4. REVENUE BY MONTH + RUNNING TOTAL (CTE + window function)
--    Last running_revenue should equal 272365.
WITH monthly AS (
    SELECT strftime(job_date, '%Y-%m') AS month,
           SUM(revenue) AS revenue,
           SUM(profit)  AS profit,
           COUNT(*)     AS jobs
    FROM jobs
    GROUP BY 1
)
SELECT month,
       revenue,
       jobs,
       ROUND(100.0 * profit / revenue, 1) AS margin_pct,
       SUM(revenue) OVER (ORDER BY month) AS running_revenue
FROM monthly
ORDER BY month;

-- 5a. PAYMENT SPEED BY PAYMENT METHOD
SELECT i.payment_method,
       COUNT(*) AS invoices,
       ROUND(AVG(i.days_to_pay), 2) AS avg_days_to_pay
FROM invoices i
JOIN jobs j ON i.job_id = j.job_id
GROUP BY i.payment_method
ORDER BY avg_days_to_pay;

-- 5b. PAYMENT SPEED BY CITY (3-table JOIN + HAVING)
--     WHERE filters rows before grouping; HAVING filters groups after.
SELECT c.city,
       COUNT(*) AS jobs,
       ROUND(AVG(i.days_to_pay), 1) AS avg_days_to_pay,
       SUM(j.revenue) AS revenue
FROM jobs j
JOIN customers c ON j.customer_id = c.customer_id
JOIN invoices i  ON j.job_id = i.job_id
GROUP BY c.city
HAVING COUNT(*) >= 3
ORDER BY avg_days_to_pay DESC;

-- 6. TOP 2 JOBS BY REVENUE WITHIN EACH FENCE TYPE (window function + QUALIFY)
--    RANK ties: 1,1,3 | DENSE_RANK ties: 1,1,2 | ROW_NUMBER: 1,2,3
--    QUALIFY is DuckDB/Snowflake; elsewhere wrap in a CTE and use WHERE.
SELECT fence_type, job_id, revenue,
       RANK() OVER (PARTITION BY fence_type ORDER BY revenue DESC) AS rank_in_type
FROM jobs
QUALIFY rank_in_type <= 2
ORDER BY fence_type, rank_in_type;

-- 7a. DATA QUALITY: list distinct values to spot inconsistent labels
--     Finding: leads uses 'Wood privacy' / 'Vinyl privacy'; jobs uses 'Wood' / 'Vinyl'.
SELECT fence_type, COUNT(*) AS leads
FROM leads
GROUP BY fence_type
ORDER BY leads DESC;

-- 7b. DATA QUALITY: orphan check (jobs with no invoice). Expected 0.
SELECT COUNT(*) AS jobs_without_invoice
FROM jobs j
LEFT JOIN invoices i ON j.job_id = i.job_id
WHERE i.job_id IS NULL;

-- 7c. CLEANING: standardize leads.fence_type (SQL version of Power Query Replace Values)
SELECT CASE WHEN fence_type LIKE '% privacy' THEN REPLACE(fence_type, ' privacy', '')
            ELSE fence_type END AS fence_type_clean,
       COUNT(*) AS leads
FROM leads
GROUP BY 1
ORDER BY leads DESC;
