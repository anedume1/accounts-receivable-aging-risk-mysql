# accounts-receivable-aging-risk-mysql
MySQL A/R aging buckets + risk labeling model (1,000 invoices, 5 customers) generated using ExcelX finance data generator.
# Accounts Receivable Aging + Risk Labeling (MySQL)

This project summarizes Accounts Receivable (A/R) at the **customer level** and assigns a **risk label (Low / Medium / High)** based on delinquency aging buckets and exposure thresholds.

**Dataset:** 1,000 invoices across 5 customers  
**Tools:** Excelx Accounting Data Generator (data generation) → MySQL 8.0 (analysis)  
**Output:** total unpaid balance, % invoices paid, aging bucket counts, and risk level per customer
**Execution Time:** 1.69 ms

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
- 365+ overdue dollars ≥ 75,000
- 181–365 overdue dollars ≥ 60,000
- Total exposure ≥ 8 “invoice-equivalents” (total_due / avg_invoice_size)

### Medium risk (any condition)
- 91–180 overdue dollars ≥ 35,000
- 31–180 overdue invoice count ≥ 4
- Total exposure ≥ 5 “invoice-equivalents”

Else: Low

> Note: The analysis uses an “as-of date”, This can be changed to `CURRENT_DATE()`.

---

##  Output
| Customer | total_due | invoices_paid_percent | cnt_181_365 | cnt_365_higher | risk_level |
|---|---:|---:|---:|---:|---|
| Retail Giant A | 245,847.04 | 77.50 | 3 | 6 | High |
| Gourmet Shop C | 187,274.82 | 79.41 | 0 | 6 | High |
| Supermarket Chain B | 142,222.42 | 84.31 | 2 | 2 | Medium |
| Online Retailer D | 110,838.95 | 89.19 | 2 | 0 | High |
| Hotel Group E | 55,622.10 | 92.11 | 3 | 0 | Low |

---

## Key Business Insights
**Portfolio Summary:** $741,805 total outstanding across 5 customers  
**Risk Distribution:** 3 High-risk | 1 Medium-risk | 1 Low-risk customers  
**Critical Alert:** 14 invoices over 180 days overdue requiring immediate attention
**Top Priorities:**
- **Retail Giant A** and **Gourmet Shop C** each have 6 invoices >365 days overdue
- **High-risk customers** represent 69% of total receivables ($544,961)
- **Hotel Group E** shows best payment behavior (92% paid rate) - potential model customer

---

## How to Run
1) Load the CSVs into MySQL (or create the tables manually).
2) Run `sql/ar_aging_risk_model.sql`
3) View the resulting customer-level report sorted by total_due.

---

## Next Steps (Optional Enhancements)
- Add dollar totals per aging bucket (not just counts)
- Build a Power BI dashboard using the output table
- Analyze Monthly data, such as AR collected per month
