/*
 * AR Aging Risk Analysis Query
 *
 * Purpose: Customer-level accounts receivable aging report with risk classification
 *
 * Business Rules: See docs/assumptions.md for detailed threshold definitions
 *
 * Output Columns:
 *   - Customer: Customer name
 *   - total_due: Total unpaid balance
 *   - invoices_paid_percent: Percentage of invoices paid
 *   - current: Count of unpaid invoices not yet overdue
 *   - cnt_1_30 through cnt_365_higher: Invoice counts per aging bucket
 *   - risk_level: High/Medium/Low based on thresholds in assumptions.md
 *
 * Usage:
 *   -- Optional: Set custom as-of date (defaults to 2025-12-31)
 *   SET @AsOfDate = '2026-01-31';
 *   SOURCE sql/ar_aging_risk_model.sql;
 *
 * Performance: Optimized to scan AR_Invoices table once (previously scanned twice)
 */

-- ============================================================================
-- PARAMETER: As-of date for aging calculation
-- ============================================================================
SET @AsOfDate = COALESCE(@AsOfDate, '2025-12-31');

-- ============================================================================
-- CTE: Unified customer aging analysis
-- Combines customer summary and aging buckets in single table scan
-- ============================================================================
WITH customer_aging_analysis AS (
  SELECT
    -- Customer identification
    arc.CustomerID,
    arc.CustomerName,

    -- Customer-level metrics (calculated from all invoices)
    ROUND(AVG(ari.InvoiceAmount), 2) AS avg_InvoiceSize,
    ROUND(SUM(CASE WHEN ari.Status = 'Unpaid'
      THEN ari.InvoiceAmount ELSE 0 END), 2) AS total_due,
    ROUND(100 * AVG(CASE WHEN ari.Status = 'Paid'
      THEN 1 ELSE 0 END), 2) AS percent_invoices_paid,

    -- Current (unpaid but not yet overdue)
    SUM(CASE
      WHEN ari.Status = 'Unpaid' AND ari.DueDate >= @AsOfDate THEN 1
      ELSE 0
    END) AS cnt_current,

    -- Aging bucket counts (unpaid and overdue)
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 1 AND 30 THEN 1
      ELSE 0
    END) AS cnt_1_30,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 31 AND 60 THEN 1
      ELSE 0
    END) AS cnt_31_60,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 61 AND 90 THEN 1
      ELSE 0
    END) AS cnt_61_90,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 91 AND 120 THEN 1
      ELSE 0
    END) AS cnt_91_120,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 121 AND 180 THEN 1
      ELSE 0
    END) AS cnt_121_180,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 181 AND 365 THEN 1
      ELSE 0
    END) AS cnt_181_365,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) > 365 THEN 1
      ELSE 0
    END) AS cnt_365_higher,

    -- Aging bucket amounts (for risk assessment)
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 31 AND 60
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_31_60,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 61 AND 90
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_61_90,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 91 AND 120
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_91_120,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 121 AND 180
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_121_180,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) BETWEEN 181 AND 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_181_365,

    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF(@AsOfDate, ari.DueDate) > 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_365_higher

  FROM AR_Invoices AS ari
  INNER JOIN AR_Customers AS arc USING (CustomerID)
  GROUP BY arc.CustomerID, arc.CustomerName
)

-- ============================================================================
-- FINAL SELECT: Customer aging report with risk classification
-- ============================================================================
SELECT
  CustomerName AS Customer,
  total_due,
  percent_invoices_paid AS invoices_paid_percent,
  cnt_current AS current,
  cnt_1_30,
  cnt_31_60,
  cnt_61_90,
  cnt_91_120,
  cnt_121_180,
  cnt_181_365,
  cnt_365_higher,

  -- Risk classification based on thresholds in docs/assumptions.md
  CASE
    -- HIGH RISK: Any of these conditions trigger high risk

    -- 365+ days overdue >= $400,000 (assumptions.md line 62)
    WHEN amt_365_higher >= 400000 THEN 'High'

    -- 181-365 days overdue >= $300,000 (assumptions.md line 63)
    WHEN amt_181_365 >= 300000 THEN 'High'

    -- Total exposure >= 35 invoice-equivalents (assumptions.md line 64)
    WHEN (total_due / NULLIF(avg_InvoiceSize, 0)) >= 35 THEN 'High'

    -- MEDIUM RISK: Any of these conditions trigger medium risk

    -- 91-180 days overdue >= $200,000 (assumptions.md line 69)
    WHEN (amt_91_120 + amt_121_180) >= 200000 THEN 'Medium'

    -- 31-180 days invoice count >= 9 (assumptions.md line 70)
    WHEN (cnt_31_60 + cnt_61_90 + cnt_91_120 + cnt_121_180) >= 9 THEN 'Medium'

    -- Total exposure >= 22 invoice-equivalents (assumptions.md line 71)
    WHEN (total_due / NULLIF(avg_InvoiceSize, 0)) >= 22 THEN 'Medium'

    -- LOW RISK: Default for all other cases
    ELSE 'Low'
  END AS risk_level

FROM customer_aging_analysis
ORDER BY total_due DESC;
