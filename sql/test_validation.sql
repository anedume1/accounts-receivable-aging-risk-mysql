/*
 * Validation Tests for AR Aging Risk Query
 *
 * Run these tests to verify query correctness after improvements
 *
 * Usage:
 *   SOURCE sql/test_validation.sql;
 *
 * Expected Results:
 *   All tests should return 'PASS' in the result column
 *
 * Note: These tests assume the improved query has been run and
 *       results are available in a temporary table or view
 */

-- ============================================================================
-- Setup: Create temporary table with query results for testing
-- ============================================================================
SET @AsOfDate = '2025-12-31';

DROP TEMPORARY TABLE IF EXISTS test_query_results;
CREATE TEMPORARY TABLE test_query_results AS
  SOURCE sql/ar_aging_risk_model.sql;

-- Note: If the above doesn't work, run the query manually and create the temp table:
-- CREATE TEMPORARY TABLE test_query_results AS SELECT * FROM (<paste query here>);

-- ============================================================================
-- Test 1: Verify no duplicate CustomerIDs in output
-- ============================================================================
SELECT
  'Test 1: No Duplicate Customers' AS test_name,
  COUNT(*) AS total_rows,
  COUNT(DISTINCT Customer) AS unique_customers,
  CASE
    WHEN COUNT(*) = COUNT(DISTINCT Customer) THEN 'PASS'
    ELSE 'FAIL - Duplicates found!'
  END AS result
FROM test_query_results;

-- ============================================================================
-- Test 2: Verify total_due matches sum of unpaid invoices
-- ============================================================================
SELECT
  'Test 2: Total Due Accuracy' AS test_name,
  c.Customer,
  c.calculated_total,
  q.total_due AS query_total,
  ABS(c.calculated_total - q.total_due) AS difference,
  CASE
    WHEN ABS(c.calculated_total - q.total_due) < 0.01 THEN 'PASS'
    ELSE 'FAIL - Amounts do not match!'
  END AS result
FROM (
  SELECT
    arc.CustomerName AS Customer,
    ROUND(SUM(CASE WHEN ari.Status = 'Unpaid'
      THEN ari.InvoiceAmount ELSE 0 END), 2) AS calculated_total
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS c
JOIN test_query_results AS q USING (Customer);

-- ============================================================================
-- Test 3: Verify percent_invoices_paid calculation
-- ============================================================================
SELECT
  'Test 3: Payment Percentage Accuracy' AS test_name,
  c.Customer,
  c.calculated_percent,
  q.invoices_paid_percent AS query_percent,
  ABS(c.calculated_percent - q.invoices_paid_percent) AS difference,
  CASE
    WHEN ABS(c.calculated_percent - q.invoices_paid_percent) < 0.01 THEN 'PASS'
    ELSE 'FAIL - Percentages do not match!'
  END AS result
FROM (
  SELECT
    arc.CustomerName AS Customer,
    ROUND(100 * AVG(CASE WHEN ari.Status = 'Paid'
      THEN 1 ELSE 0 END), 2) AS calculated_percent
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS c
JOIN test_query_results AS q USING (Customer);

-- ============================================================================
-- Test 4: Verify high risk thresholds (400k, 300k, 35)
-- ============================================================================
SELECT
  'Test 4: High Risk Threshold Validation' AS test_name,
  q.Customer,
  q.risk_level,
  q.total_due,
  m.avg_InvoiceSize,
  m.amt_365_higher,
  m.amt_181_365,
  (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) AS exposure_ratio,
  CASE
    -- If marked as High risk, verify it meets at least one high threshold
    WHEN q.risk_level = 'High' AND (
      m.amt_365_higher >= 400000 OR
      m.amt_181_365 >= 300000 OR
      (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) >= 35
    ) THEN 'PASS'
    WHEN q.risk_level = 'High' THEN 'FAIL - High risk but no threshold met!'
    ELSE 'N/A - Not High risk'
  END AS result
FROM test_query_results q
JOIN (
  SELECT
    arc.CustomerName AS Customer,
    ROUND(AVG(ari.InvoiceAmount), 2) AS avg_InvoiceSize,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) > 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_365_higher,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 181 AND 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_181_365
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS m USING (Customer);

-- ============================================================================
-- Test 5: Verify medium risk thresholds (200k, 9, 22)
-- ============================================================================
SELECT
  'Test 5: Medium Risk Threshold Validation' AS test_name,
  q.Customer,
  q.risk_level,
  q.total_due,
  m.avg_InvoiceSize,
  m.amt_91_180,
  m.cnt_31_180,
  (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) AS exposure_ratio,
  CASE
    -- If marked as Medium risk, verify it meets at least one medium threshold
    WHEN q.risk_level = 'Medium' AND (
      m.amt_91_180 >= 200000 OR
      m.cnt_31_180 >= 9 OR
      (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) >= 22
    ) THEN 'PASS'
    WHEN q.risk_level = 'Medium' THEN 'FAIL - Medium risk but no threshold met!'
    ELSE 'N/A - Not Medium risk'
  END AS result
FROM test_query_results q
JOIN (
  SELECT
    arc.CustomerName AS Customer,
    ROUND(AVG(ari.InvoiceAmount), 2) AS avg_InvoiceSize,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 91 AND 180
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_91_180,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 31 AND 180
        THEN 1
      ELSE 0
    END) AS cnt_31_180
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS m USING (Customer);

-- ============================================================================
-- Test 6: Verify aging bucket counts for 365+ days
-- ============================================================================
SELECT
  'Test 6: Aging Bucket Count (365+)' AS test_name,
  c.Customer,
  c.calculated_cnt_365_higher,
  q.cnt_365_higher AS query_cnt_365_higher,
  CASE
    WHEN c.calculated_cnt_365_higher = q.cnt_365_higher THEN 'PASS'
    ELSE 'FAIL - Count mismatch!'
  END AS result
FROM (
  SELECT
    arc.CustomerName AS Customer,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) > 365 THEN 1
      ELSE 0
    END) AS calculated_cnt_365_higher
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS c
JOIN test_query_results AS q USING (Customer);

-- ============================================================================
-- Test 7: Verify no Low risk customers meet High or Medium thresholds
-- ============================================================================
SELECT
  'Test 7: Low Risk Validation' AS test_name,
  q.Customer,
  q.risk_level,
  m.amt_365_higher,
  m.amt_181_365,
  m.amt_91_180,
  m.cnt_31_180,
  (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) AS exposure_ratio,
  CASE
    -- If marked as Low risk, verify it doesn't meet any high/medium thresholds
    WHEN q.risk_level = 'Low' AND (
      m.amt_365_higher < 400000 AND
      m.amt_181_365 < 300000 AND
      (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) < 35 AND
      m.amt_91_180 < 200000 AND
      m.cnt_31_180 < 9 AND
      (q.total_due / NULLIF(m.avg_InvoiceSize, 0)) < 22
    ) THEN 'PASS'
    WHEN q.risk_level = 'Low' THEN 'FAIL - Low risk but threshold exceeded!'
    ELSE 'N/A - Not Low risk'
  END AS result
FROM test_query_results q
JOIN (
  SELECT
    arc.CustomerName AS Customer,
    ROUND(AVG(ari.InvoiceAmount), 2) AS avg_InvoiceSize,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) > 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_365_higher,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 181 AND 365
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_181_365,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 91 AND 180
        THEN ari.InvoiceAmount
      ELSE 0
    END) AS amt_91_180,
    SUM(CASE
      WHEN ari.Status = 'Unpaid'
        AND DATEDIFF('2025-12-31', ari.DueDate) BETWEEN 31 AND 180
        THEN 1
      ELSE 0
    END) AS cnt_31_180
  FROM AR_Invoices ari
  JOIN AR_Customers arc USING (CustomerID)
  GROUP BY arc.CustomerName
) AS m USING (Customer);

-- ============================================================================
-- Test 8: Verify all customers are present
-- ============================================================================
SELECT
  'Test 8: All Customers Present' AS test_name,
  expected.customer_count AS expected_customers,
  actual.result_count AS actual_customers,
  CASE
    WHEN expected.customer_count = actual.result_count THEN 'PASS'
    ELSE 'FAIL - Missing customers!'
  END AS result
FROM
  (SELECT COUNT(DISTINCT CustomerName) AS customer_count
   FROM AR_Customers) AS expected,
  (SELECT COUNT(*) AS result_count
   FROM test_query_results) AS actual;

-- ============================================================================
-- Test Summary: Count passing vs failing tests
-- ============================================================================
-- Note: This requires running all tests above and aggregating results
-- For now, manually review each test result

-- ============================================================================
-- Cleanup
-- ============================================================================
DROP TEMPORARY TABLE IF EXISTS test_query_results;
