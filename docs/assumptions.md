# Assumptions & Methodology

This document explains the assumptions used to build the Accounts Receivable (A/R) aging and risk labeling model.

---

## 1) Dataset Origin
- The invoice and customer data used in this project is a **synthetic accounting dataset** generated using the **ExcelX Finance & Accounting Data Generator**.
- The dataset contains **1,000 invoices across 5 customers**.
- Because the data is synthetic, customer names and invoice behavior are simulated and do not represent a real company.

---

## 2) Invoice Status Logic
- Invoices are labeled as either:
  - **Paid**: invoice has been fully settled
  - **Unpaid**: invoice remains open and contributes to A/R exposure
- Only **Unpaid** invoices contribute to `total_due`.

---

## 3) As-Of Date for Aging
- A/R aging is calculated relative to an "as-of date" set to:

  **`2025-12-31`**

- Days overdue is calculated as:

  `DATEDIFF('2025-12-31', DueDate)`

- If an invoice is unpaid but not past due as of the as-of date, it is treated as **current**.

---

## 4) Days Overdue Rules
- `days_overdue = 0` means either:
  - the invoice is unpaid but not overdue yet (current), OR
  - the invoice is outside the overdue condition
- Only invoices with:
  - `Status = 'Unpaid'`
  - `DueDate < '2025-12-31'`
  are counted as overdue invoices.

---

## 5) A/R Aging Buckets
Overdue invoices are grouped into standard aging buckets:
- 1–30 days
- 31–60 days
- 61–90 days
- 91–120 days
- 121–180 days
- 181–365 days
- 365+ days

---

## 6) Risk Label Logic (Threshold Based)
Customer risk is assigned using threshold rules (not machine learning).

### High Risk triggers (any one):
- Total overdue amount for invoices **365+ days** past due ≥ **$75,000**, OR
- Total overdue amount for invoices **181–365 days** past due ≥ **$60,000**, OR
- Customer exposure ≥ **8 invoice-equivalents**, calculated as:

  `total_due / avg_invoice_size`

### Medium Risk triggers (any one):
- Total overdue amount across **91–180 days** ≥ **$35,000**, OR
- Total overdue invoice count across **31–180 days** ≥ **4 invoices**, OR
- Customer exposure ≥ **5 invoice-equivalents**

### Low Risk:
- Customers not meeting High or Medium thresholds are labeled Low risk.

---

## 7) Materiality Assumption
Thresholds are intended to represent **material delinquency exposure** where:
- older delinquency (181+ and 365+) is treated as higher priority,
- larger overdue balances indicate higher credit and collection risk.
