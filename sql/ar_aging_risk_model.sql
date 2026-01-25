WITH AR_Customer_Summary AS (
  SELECT arc.CustomerID, arc.CustomerName AS CustomerName, ROUND(AVG(ari.InvoiceAmount),2) AS avg_InvoiceSize, ROUND(SUM(CASE WHEN ari.status = 'Unpaid' THEN ari.InvoiceAmount ELSE 0 END),2) AS total_due, ROUND(100 * AVG( CASE WHEN ari.status = 'Paid' THEN 1 ELSE 0  END),2) AS percent_invoices_paid
  FROM AR_Invoices AS ari
  INNER JOIN AR_Customers AS arc
  USING (CustomerID)
  GROUP BY arc.CustomerID, arc.CustomerName),

 day_ovrdue_buckets AS (
  SELECT CustomerID,InvoiceAmount, CASE WHEN status = 'Unpaid' and DueDate <  '2025-12-31'
  THEN DATEDIFF('2025-12-31',DueDate) ELSE 0 END AS days_overdue
  FROM AR_Invoices
  WHERE Status = 'Unpaid')
 
SELECT CustomerName AS Customer , total_due , percent_invoices_paid AS invoices_paid_percent ,SUM(CASE WHEN dob.days_overdue = 0 THEN 1 ELSE 0 END) AS current, SUM(CASE WHEN dob.days_overdue BETWEEN 1 and 30 THEN 1 ELSE 0 END) AS cnt_1_30,
 SUM(CASE WHEN dob.days_overdue BETWEEN 31 and 60 THEN 1 ELSE 0 END) AS cnt_31_60,
  SUM(CASE WHEN dob.days_overdue BETWEEN 61 and 90 THEN 1 ELSE 0 END) AS cnt_61_90,
   SUM(CASE WHEN dob.days_overdue BETWEEN 91 and 120 THEN 1 ELSE 0 END) AS cnt_91_120,
    SUM(CASE WHEN dob.days_overdue BETWEEN 121 and 180 THEN 1 ELSE 0 END) AS cnt_121_180,
     SUM(CASE WHEN dob.days_overdue BETWEEN 181 and 365 THEN 1 ELSE 0 END) AS cnt_181_365,
      SUM(CASE WHEN dob.days_overdue > 365 THEN 1 ELSE 0 END) AS cnt_365_higher,
      CASE 
      	WHEN SUM(CASE WHEN dob.days_overdue > 365 THEN dob.InvoiceAmount ELSE 0 END) > 75000
      	 OR SUM(CASE WHEN dob.days_overdue between 181 AND 365 THEN dob.InvoiceAmount ELSE 0 END) >= 60000
      	 OR (total_due / avg_InvoiceSize) >= 8 THEN 'High' 
       WHEN (SUM(CASE WHEN dob.days_overdue BETWEEN 121 AND 180 THEN dob.InvoiceAmount ELSE 0 END) + SUM(CASE WHEN dob.days_overdue BETWEEN 91 AND 120 THEN dob.InvoiceAmount ELSE 0 END)) >= 35000
      	 OR ((SUM(CASE WHEN dob.days_overdue BETWEEN 121 AND 180 THEN 1 ELSE 0 END) + SUM(CASE WHEN dob.days_overdue BETWEEN 91 AND 120 THEN 1 ELSE 0 END) + SUM(CASE WHEN dob.days_overdue BETWEEN 61 AND 90 THEN 1 ELSE 0 END) + SUM(CASE WHEN dob.days_overdue BETWEEN 31 AND 60 THEN 1 ELSE 0 END)) >= 4)
      	 OR (total_due / avg_InvoiceSize) >= 5 THEN 'Medium' 
       ELSE 'low' END AS risk_level
FROM AR_Customer_Summary AS acs
LEFT JOIN day_ovrdue_buckets AS dob
USING (CustomerID)
GROUP BY acs.CustomerName, acs.total_due, acs.percent_invoices_paid, acs.avg_InvoiceSize
ORDER BY acs.total_due DESC;
