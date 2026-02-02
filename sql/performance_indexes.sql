/*
 * Performance Index Recommendations for AR Aging Analysis
 *
 * These indexes optimize the ar_aging_risk_model.sql query performance
 *
 * Impact Analysis:
 *   - idx_ar_invoices_status_duedate: Supports WHERE Status = 'Unpaid' filter
 *     and DueDate comparisons for aging bucket calculations
 *   - idx_ar_invoices_customer_status: Speeds up JOIN and GROUP BY operations
 *     when filtering by customer and status
 *   - idx_ar_customers_id_name: Covers CustomerID and CustomerName for JOIN,
 *     avoiding table lookups
 *
 * Installation:
 *   SOURCE sql/performance_indexes.sql;
 *
 * Note: Run EXPLAIN on ar_aging_risk_model.sql before and after creating
 *       indexes to verify performance improvement
 *
 * Estimated Impact:
 *   - Single table scan (vs double scan): ~40-50% query time reduction
 *   - With indexes: Additional 20-30% improvement on large datasets
 */

-- ============================================================================
-- Index 1: Status + DueDate composite
-- Supports: WHERE Status = 'Unpaid' AND DueDate comparisons in aging logic
-- ============================================================================
CREATE INDEX idx_ar_invoices_status_duedate
ON AR_Invoices(Status, DueDate);

-- ============================================================================
-- Index 2: CustomerID + Status composite
-- Supports: JOIN operations and Status filtering
-- ============================================================================
CREATE INDEX idx_ar_invoices_customer_status
ON AR_Invoices(CustomerID, Status);

-- ============================================================================
-- Index 3: Cover index for customers
-- Supports: JOIN covering CustomerID and CustomerName
-- ============================================================================
CREATE INDEX idx_ar_customers_id_name
ON AR_Customers(CustomerID, CustomerName);

-- ============================================================================
-- Optional: Add InvoiceAmount to composite for covering index
-- Only use if query performance testing shows significant benefit
-- Trade-off: Larger index size vs. avoiding table lookups
-- Uncomment the following line if needed:
-- ============================================================================
-- CREATE INDEX idx_ar_invoices_status_duedate_amount
-- ON AR_Invoices(Status, DueDate, InvoiceAmount);
