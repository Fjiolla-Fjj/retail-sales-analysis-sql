-- 03: Customer & product analysis on `sales`
-- Q1 Top 10 products by revenue
SELECT StockCode, MAX(Description) AS product, SUM(Quantity) AS units, ROUND(SUM(Revenue),2) AS revenue
FROM sales GROUP BY StockCode ORDER BY revenue DESC LIMIT 10;
-- Q2 Top 10 customers by revenue
SELECT CustomerID, MAX(Country) AS country, COUNT(DISTINCT InvoiceNo) AS orders, ROUND(SUM(Revenue),2) AS revenue
FROM sales GROUP BY CustomerID ORDER BY revenue DESC LIMIT 10;
-- Q3 Country split (top 10) with share of revenue
SELECT Country, COUNT(DISTINCT CustomerID) AS customers, ROUND(SUM(Revenue),2) AS revenue,
       ROUND(100.0*SUM(Revenue)/(SELECT SUM(Revenue) FROM sales),1) AS revenue_share_pct
FROM sales GROUP BY Country ORDER BY revenue DESC LIMIT 10;
-- Q4 RFM segmentation (snapshot = day after last invoice), quintile scores via NTILE
WITH base AS (
  SELECT CustomerID,
         julianday((SELECT date(MAX(InvoiceDate),'+1 day') FROM sales)) - julianday(MAX(date(InvoiceDate))) AS recency_days,
         COUNT(DISTINCT InvoiceNo) AS frequency, SUM(Revenue) AS monetary
  FROM sales GROUP BY CustomerID),
scored AS (
  SELECT *, NTILE(5) OVER (ORDER BY recency_days DESC) AS r, NTILE(5) OVER (ORDER BY frequency) AS f,
         NTILE(5) OVER (ORDER BY monetary) AS m FROM base),
seg AS (
  SELECT *, CASE WHEN r>=4 AND f>=4 THEN 'Champions'
                 WHEN r>=3 AND f>=3 THEN 'Loyal'
                 WHEN r>=4 AND f<=2 THEN 'New / Promising'
                 WHEN r<=2 AND f>=3 THEN 'At Risk'
                 WHEN r<=2 AND f<=2 THEN 'Lost / Hibernating'
                 ELSE 'Needs Attention' END AS segment FROM scored)
SELECT segment, COUNT(*) AS customers, ROUND(AVG(recency_days),0) AS avg_recency_days,
       ROUND(AVG(frequency),1) AS avg_orders, ROUND(SUM(monetary),2) AS revenue,
       ROUND(100.0*SUM(monetary)/(SELECT SUM(monetary) FROM base),1) AS revenue_share_pct
FROM seg GROUP BY segment ORDER BY revenue DESC;
-- Q5 Repeat-customer rate
SELECT ROUND(100.0*SUM(n>1)/COUNT(*),1) AS repeat_customer_pct, COUNT(*) AS customers
FROM (SELECT CustomerID, COUNT(DISTINCT InvoiceNo) n FROM sales GROUP BY CustomerID);
-- Q6 Revenue concentration: share from top 10% of customers
WITH c AS (SELECT CustomerID, SUM(Revenue) rev, NTILE(10) OVER (ORDER BY SUM(Revenue) DESC) d FROM sales GROUP BY CustomerID)
SELECT ROUND(100.0*SUM(CASE WHEN d=1 THEN rev END)/SUM(rev),1) AS top10pct_customer_rev_share FROM c;
