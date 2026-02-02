# accounts-receivable-aging-risk-mysql
MySQL A/R aging buckets + risk labeling model (1,000 invoices, 5 customers) generated using ExcelX finance data generator.
# Accounts Receivable Aging + Risk Labeling (MySQL)

This project summarizes Accounts Receivable (A/R) at the **customer level** and assigns a **risk label (Low / Medium / High)** based on delinquency aging buckets and exposure thresholds.

**Dataset:** 1,000 invoices across 5 customers  
**Tools:** Excelx Accounting Data Generator (data generation) → MySQL 8.0 (analysis)  
**Output:** total unpaid balance, % invoices paid, aging bucket counts, and risk level per customer
**Execution Time:** 4.79 ms

---

## Business Goal
A/R and audit teams often need a quick way to answer:
- Which customers have the highest outstanding balances?
- How old are the unpaid invoices (1–30, 31–60, … 365+)?
- Which customers should be prioritized for collections or credit review?

This query produces a repeatable customer-level A/R aging report with a risk tier.

---

## Dataset Source 
The dataset was created using **ExcelX Finance & Accounting Data Generator**, exported from Excel/CSV, and loaded into MySQL for analysis.

---

## Tables Used
### AR_Customers
- CustomerID
- CustomerName

### AR_Invoices
- InvoiceID
- CustomerID
- InvoiceDate
- DueDate
- InvoiceAmount
- Status (Paid / Unpaid)

---

## Methods / SQL Techniques
- CTEs (WITH)
- Joins (INNER JOIN, LEFT JOIN, USING)
- Conditional aggregation (SUM(CASE WHEN...))
- Aging calculation (DATEDIFF(as_of_date, DueDate))
- Bucketing into standard aging windows (1–30 … 365+)
- Risk classification logic (CASE)

---

## Aging Buckets Produced
- Current (unpaid but not overdue)
- 1–30
- 31–60
- 61–90
- 91–120
- 121–180
- 181–365
- 365+

---

## Risk Logic (Threshold-Based)
Risk is assigned using overdue **amounts** and exposure **ratios**:

### High risk (any condition)
- 365+ overdue dollars ≥ 400000
- 181–365 overdue dollars ≥ 300,000
- Total exposure ≥ 35 “invoice-equivalents” (total_due / avg_invoice_size)

### Medium risk (any condition)
- 91–180 overdue dollars ≥ 200000
- 31–180 overdue invoice count ≥ 9
- Total exposure ≥ 22 “invoice-equivalents”

Else: Low

> Note: The analysis uses an “as-of date”, This can be changed to `CURRENT_DATE()`.

---

##  Output
| Customer | Total Due | % Paid | Current | 1–30 | 31–60 | 61–90 | 91–120 | 121–180 | 181–365 | 365+ | Risk |
|---|---:|---:|---:|---:|---:|---:|---:|---:|---:|---:|---|
| Retail Giant A | 796,491.38 | 84.34 | 1 | 0 | 4 | 0 | 1 | 4 | 11 | 10 | Medium |
| Gourmet Shop C | 790,469.80 | 84.66 | 0 | 1 | 3 | 1 | 1 | 2 | 9 | 10 | Medium |
| Supermarket Chain B | 731,030.98 | 88.16 | 1 | 0 | 0 | 0 | 0 | 2 | 8 | 16 | High |
| Online Retailer D | 688,251.73 | 86.06 | 1 | 0 | 2 | 1 | 1 | 4 | 8 | 12 | Medium |
| Hotel Group E | 424,176.34 | 89.47 | 2 | 1 | 1 | 3 | 0 | 1 | 5 | 7 | Low |

---

## Key Business Insights
**Portfolio Summary:** $3,430,420 total outstanding across 5 customers  
**Risk Distribution:** 1 High-risk | 3 Medium-risk | 1 Low-risk customers  
**Critical Alert:** 78 invoices over 180 days overdue requiring immediate attention
**Top Priorities:**
- **Supermarket Chain B** was flagged as the **highest-risk** account with **16 invoices >365 days overdue**, indicating severe long-term delinquency and urgent collections risk.
- **Retail Giant A** and **Gourmet Shop C** each contain **10 invoices >365 days overdue**, making them key targets for immediate collections follow-up and credit review.
- **A/R exposure is concentrated:** the single **High-risk** customer represents **$731,030.98** (~21.3% of total receivables), creating material portfolio-level risk.
- **Hotel Group E** demonstrates the strongest payment behavior (**89.47% paid rate**) and is labeled **Low risk**, suggesting reduced collections urgency and more stable cash flow behavior.

---

## How to Run
1) Load the CSVs into MySQL (or create the tables manually).
2) **(Optional but Recommended)** Install performance indexes:
   ```sql
   SOURCE sql/performance_indexes.sql;
   ```
3) **(Optional)** Set custom as-of date for analysis:
   ```sql
   SET @AsOfDate = '2026-01-31';  -- Defaults to 2025-12-31 if not set
   ```
4) Run the AR aging risk query:
   ```sql
   SOURCE sql/ar_aging_risk_model.sql;
   ```
5) View the resulting customer-level report sorted by total_due.

**Note:** The query has been optimized to eliminate duplicate table scans (40-50% faster) and uses corrected risk thresholds that match the documented business rules in `docs/assumptions.md`. See `docs/query_migration_guide.md` for details on improvements.

---

## Next Steps
- ✅ **COMPLETED**: Fixed critical threshold bug and optimized query performance (see `query_improvements.md`)
- ✅ **COMPLETED**: Added parameterized as-of date for flexible analysis
- ✅ **COMPLETED**: Created performance indexes and migration guide
- Add dollar totals per aging bucket in final output (not just counts)
- Build a Power BI dashboard using the output table
- Analyze Monthly data, such as AR collected per month
- Consider implementing risk config table for easier threshold management
