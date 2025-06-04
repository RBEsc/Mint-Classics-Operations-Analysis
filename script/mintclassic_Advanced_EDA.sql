/*
-----------------------------------------------------------------------------------------
Exploratory Data Analysis
-----------------------------------------------------------------------------------------
Purpose: 
	Understand supplementary data to properly address the objective and business quiestions
    Reviewing the Objective and Business questions:
		OBJECTIVE:
        - Explore products currently in inventory.
		- Determine important factors that may influence inventory reorganization/reduction.
		- Provide analytic insights and data-driven recommendations.
        
		BUSINESS QUESTIONS:
		- Where are items stored and if they were rearranged, could a warehouse be eliminated?
		- How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?
		- Are we storing items that are not moving? Are any items candidates for being dropped from the product line?
*/

-- Create Order Summary View for simplfied query of repetitive table JOIN
CREATE OR REPLACE VIEW Order_Summary AS (
SELECT 
	O.orderNumber,
    orderDate,
    requiredDate,
    shippedDate,
    status,
    OD.productCode,
    quantityOrdered,
    priceEach,
    productName,
    warehouseName,
    buyPrice,
    productLine
    FROM orders AS O
LEFT JOIN orderdetails AS OD ON O.orderNumber = OD.orderNumber
LEFT JOIN products AS P ON OD.productCode = P.productCode
LEFT JOIN warehouses AS W ON P.warehouseCode = W.warehouseCode
);

-- Get Business Dates
SELECT 
	MIN(orderDate),
    MAX(orderDate)
FROM Order_Summary;

-- Identify Year-over-Year (YoY) percent change thru monthly average sales 
WITH Yearly_Sales AS (
	SELECT 
		YEAR(orderDate) AS Year,
        COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM orderDate)) AS Months_Year,
		SUM(priceEach * quantityOrdered) AS Sales,
        SUM(priceEach * quantityOrdered) / COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM orderDate)) AS Ave_Sales
	FROM Order_Summary
	GROUP BY Year)
    
SELECT
Year,
Ave_Sales,
LAG(Ave_Sales) OVER() AS PY_Sales,
(Ave_Sales / LAG(Ave_Sales) OVER()) AS `%Change`
FROM Yearly_Sales;

-- Identify Month-over-Month Sales Trend and percent Change
WITH Monthly_Sales AS (
	SELECT 
		MONTH(orderDate) AS Month,
        SUM(priceEach * quantityOrdered) / COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM orderDate)) AS Ave_Sales
	FROM Order_Summary
	GROUP BY Month
)
SELECT
	Month,
	Ave_Sales,
	COALESCE(
		LAG(Ave_Sales) OVER (ORDER BY Month),
		LAST_VALUE(Ave_Sales) OVER ()
	) AS prev_month_sales,
	ROUND(((Ave_Sales / 
		COALESCE(
			LAG(Ave_Sales) OVER (ORDER BY Month),
			LAST_VALUE(Ave_Sales) OVER ()
		)) - 1) * 100, 2) AS `%_Change`
FROM Monthly_Sales;

-- What is the sales contribution of each warehouse
SELECT 
	warehouseName,
    SUM(priceEach * quantityOrdered) AS Sales,
    SUM(priceEach * quantityOrdered) / 
    (SELECT SUM(priceEach * quantityOrdered) FROM order_summary) * 100 AS `%_Sales`
from order_summary
GROUP BY warehouseName;

-- Profit Analysis per individual product
SELECT
productName,
SUM(buyPrice * quantityOrdered) AS Cost,
SUM(priceEach * quantityOrdered) AS Sales,
SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered) AS Profit,
(SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered)) /
SUM(priceEach * quantityOrdered)*100 AS `%_Profit`
FROM order_summary
GROUP BY productName
ORDER BY `%_Profit`;

-- Profit Analysis per product line
SELECT
productLine,
warehouseName,
SUM(buyPrice * quantityOrdered) AS Cost,
SUM(priceEach * quantityOrdered) AS Sales,
SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered) AS Profit,
(SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered)) /
SUM(priceEach * quantityOrdered)*100 AS `%_Profit`
FROM order_summary
GROUP BY productLine, warehouseName
ORDER BY `%_Profit`;
