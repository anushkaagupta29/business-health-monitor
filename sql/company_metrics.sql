-- Business Health Monitor — SQL Diagnostics
-- Run after loading companies_clean.csv into SQLite via 02_analysis.ipynb

-- ─────────────────────────────────────────
-- 1. YoY Revenue Growth per company
-- ─────────────────────────────────────────
SELECT
    Company,
    Year,
    Sales,
    LAG(Sales) OVER (PARTITION BY Company ORDER BY Year) AS prev_sales,
    ROUND(
        100.0 * (Sales - LAG(Sales) OVER (PARTITION BY Company ORDER BY Year))
        / LAG(Sales) OVER (PARTITION BY Company ORDER BY Year), 1
    ) AS yoy_growth_pct
FROM financials
WHERE Sales IS NOT NULL
ORDER BY Company, Year;

-- ─────────────────────────────────────────
-- 2. Cost Efficiency Ratio
-- ─────────────────────────────────────────
SELECT
    Company,
    Year,
    Sales,
    Expenses,
    ROUND(100.0 * Expenses / Sales, 1) AS cost_ratio_pct
FROM financials
WHERE Sales IS NOT NULL
  AND Expenses IS NOT NULL
  AND Sales > 0
ORDER BY Company, Year;

-- ─────────────────────────────────────────
-- 3. Margin Risk Flags
-- Flags any year where OPM declined vs prior year
-- ─────────────────────────────────────────
SELECT
    Company,
    Year,
    OPM,
    LAG(OPM) OVER (PARTITION BY Company ORDER BY Year) AS prev_opm,
    CASE
        WHEN OPM < LAG(OPM) OVER (PARTITION BY Company ORDER BY Year)
        THEN 'RISK FLAG'
        ELSE 'OK'
    END AS margin_status
FROM financials
WHERE OPM IS NOT NULL
ORDER BY Company, Year;

-- ─────────────────────────────────────────
-- 4. Latest Year Company Rankings (FY25)
-- ─────────────────────────────────────────
SELECT
    Company,
    Year,
    Sales,
    [Net profit],
    OPM,
    RANK() OVER (ORDER BY OPM DESC)   AS opm_rank,
    RANK() OVER (ORDER BY Sales DESC) AS revenue_rank
FROM financials
WHERE Year = 'FY25'
ORDER BY opm_rank;

-- ─────────────────────────────────────────
-- 5. High Risk Segment
-- Companies with 3+ consecutive RISK FLAG years
-- ─────────────────────────────────────────
SELECT
    Company,
    COUNT(*) AS risk_flag_years
FROM (
    SELECT
        Company,
        Year,
        CASE
            WHEN OPM < LAG(OPM) OVER (PARTITION BY Company ORDER BY Year)
            THEN 'RISK FLAG'
            ELSE 'OK'
        END AS margin_status
    FROM financials
    WHERE OPM IS NOT NULL
)
WHERE margin_status = 'RISK FLAG'
GROUP BY Company
ORDER BY risk_flag_years DESC;