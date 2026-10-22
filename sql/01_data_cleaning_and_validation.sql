-- 01: Data validation & cleaning (SQLite). Source table: raw_sales (loaded by scripts/analysis.py)
-- Q1 Row count
SELECT COUNT(*) AS total_rows FROM raw_sales;
-- Q2 Null / blank checks per column
SELECT SUM(CustomerID IS NULL OR CustomerID='') AS null_customer_id,
       SUM(Description IS NULL OR TRIM(Description)='') AS null_description,
       SUM(InvoiceNo IS NULL) AS null_invoice, SUM(InvoiceDate IS NULL) AS null_date,
       SUM(UnitPrice IS NULL) AS null_price, SUM(Quantity IS NULL) AS null_qty
FROM raw_sales;
-- Q3 Exact duplicate rows (extra copies)
SELECT COUNT(*) - (SELECT COUNT(*) FROM (SELECT DISTINCT * FROM raw_sales)) AS duplicate_rows FROM raw_sales;
-- Q4 Cancellations / returns (InvoiceNo starts with 'C') and negative quantities
SELECT SUM(InvoiceNo LIKE 'C%') AS cancellation_lines,
       SUM(Quantity <= 0) AS non_positive_qty_lines,
       SUM(Quantity <= 0 AND InvoiceNo NOT LIKE 'C%') AS neg_qty_not_cancelled
FROM raw_sales;
-- Q5 Price checks
SELECT SUM(UnitPrice = 0) AS zero_price_lines, SUM(UnitPrice < 0) AS negative_price_lines FROM raw_sales;
-- Q6 Type / format checks: dates parse, quantity is integer, non-product stock codes
SELECT SUM(datetime(InvoiceDate) IS NULL) AS unparseable_dates,
       SUM(typeof(Quantity) <> 'integer') AS non_integer_qty,
       SUM(StockCode IN ('POST','DOT','M','BANK CHARGES','AMAZONFEE','D','CRUK','S','PADS','B','C2','m')) AS non_product_lines,
       MIN(InvoiceDate) AS first_date, MAX(InvoiceDate) AS last_date
FROM raw_sales;
-- Q7 Reconciliation: value of cancellations vs gross sales
SELECT ROUND(SUM(CASE WHEN InvoiceNo NOT LIKE 'C%' AND Quantity>0 THEN Quantity*UnitPrice END),2) AS gross_sales,
       ROUND(SUM(CASE WHEN InvoiceNo LIKE 'C%' THEN Quantity*UnitPrice END),2) AS cancelled_value
FROM raw_sales;
-- Q8 Reconciliation: original sale lines fully reversed by a later cancellation (same customer, product, quantity)
SELECT COUNT(*) AS reversed_sale_lines, ROUND(SUM(o.Quantity*o.UnitPrice),2) AS reversed_value
FROM raw_sales o
WHERE o.InvoiceNo NOT LIKE 'C%' AND o.Quantity > 0 AND EXISTS (
  SELECT 1 FROM raw_sales c WHERE c.InvoiceNo LIKE 'C%' AND c.CustomerID = o.CustomerID
    AND c.StockCode = o.StockCode AND c.Quantity = -o.Quantity AND c.InvoiceDate >= o.InvoiceDate);
-- Q9 Build clean table: dedupe, drop cancellations AND the sales they reversed, non-positive qty/price, missing customer, non-product codes
DROP TABLE IF EXISTS sales;
CREATE TABLE sales AS
SELECT DISTINCT InvoiceNo, StockCode, TRIM(Description) AS Description, Quantity,
       datetime(InvoiceDate) AS InvoiceDate, UnitPrice, CAST(CAST(CustomerID AS REAL) AS INTEGER) AS CustomerID, Country,
       ROUND(Quantity*UnitPrice,2) AS Revenue
FROM raw_sales
WHERE InvoiceNo NOT LIKE 'C%' AND Quantity > 0 AND UnitPrice > 0
  AND CustomerID IS NOT NULL AND CustomerID <> ''
  AND StockCode NOT IN ('POST','DOT','M','BANK CHARGES','AMAZONFEE','D','CRUK','S','PADS','B','C2','m')
  AND NOT EXISTS (SELECT 1 FROM raw_sales c WHERE c.InvoiceNo LIKE 'C%' AND c.CustomerID = raw_sales.CustomerID
    AND c.StockCode = raw_sales.StockCode AND c.Quantity = -raw_sales.Quantity AND c.InvoiceDate >= raw_sales.InvoiceDate);
-- Q10 Post-clean reconciliation
SELECT (SELECT COUNT(*) FROM raw_sales) AS raw_rows, COUNT(*) AS clean_rows,
       (SELECT COUNT(*) FROM raw_sales) - COUNT(*) AS rows_removed,
       ROUND(100.0*COUNT(*)/(SELECT COUNT(*) FROM raw_sales),1) AS pct_retained
FROM sales;
