-- 02: Core KPIs on clean table `sales` (note: Dec-2011 is a partial month, data ends 9 Dec 2011)
-- Q1 Headline KPIs
SELECT ROUND(SUM(Revenue),2) AS total_revenue, COUNT(DISTINCT InvoiceNo) AS orders,
       COUNT(DISTINCT CustomerID) AS customers, SUM(Quantity) AS units,
       ROUND(SUM(Revenue)/COUNT(DISTINCT InvoiceNo),2) AS avg_order_value
FROM sales;
-- Q2 Monthly trend with MoM growth
WITH m AS (
  SELECT strftime('%Y-%m', InvoiceDate) AS month, ROUND(SUM(Revenue),2) AS revenue,
         COUNT(DISTINCT InvoiceNo) AS orders, COUNT(DISTINCT CustomerID) AS customers
  FROM sales GROUP BY 1)
SELECT month, revenue, orders, customers, ROUND(revenue/orders,2) AS aov,
       ROUND(100.0*(revenue - LAG(revenue) OVER (ORDER BY month))/LAG(revenue) OVER (ORDER BY month),1) AS mom_growth_pct
FROM m ORDER BY month;
-- Q3 Revenue by weekday
SELECT CASE strftime('%w',InvoiceDate) WHEN '0' THEN 'Sun' WHEN '1' THEN 'Mon' WHEN '2' THEN 'Tue' WHEN '3' THEN 'Wed'
       WHEN '4' THEN 'Thu' WHEN '5' THEN 'Fri' ELSE 'Sat' END AS weekday,
       ROUND(SUM(Revenue),2) AS revenue, COUNT(DISTINCT InvoiceNo) AS orders
FROM sales GROUP BY strftime('%w',InvoiceDate) ORDER BY strftime('%w',InvoiceDate);
-- Q4 Revenue by hour of day
SELECT CAST(strftime('%H',InvoiceDate) AS INTEGER) AS hour, ROUND(SUM(Revenue),2) AS revenue
FROM sales GROUP BY 1 ORDER BY 1;
