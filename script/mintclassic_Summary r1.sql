/*
-----------------------------------------------------------------------------------------
Summary of Analysis
-----------------------------------------------------------------------------------------
Purpose: 
	Below scripts are going to generate data from stakeholder's database and are intended to
	answer business questions.
*/

-- Question 1: Where are items stored and if they were rearranged, could a warehouse be eliminated?
-- Q1 Code Output 1: Data of each warehouses showing its capacity, current stock and max capacity.
SELECT
    W.warehouseName AS Warehouse_Name,
    CONCAT(W.warehousePctCap, '%') AS Warehouse_Capacity,
    SUM(P.quantityInStock) AS Current_Stock,
    SUM(P.quantityInStock) / (W.warehousePctCap / 100.0) AS Warehouse_Max_Capacity
FROM products AS P
LEFT JOIN warehouses AS W 
	   ON W.warehouseCode = P.warehouseCode
GROUP BY 
	W.warehouseName, 
    W.warehousePctCap
ORDER BY
    Current_Stock DESC;
    
-- Q1 Code Output 2: Show the invetory of warehouse per product line
SELECT
	productLine,
    SUM(CASE WHEN W.warehouseName = 'North' THEN P.quantityInStock ELSE 0 END) AS North_Stock,
    SUM(CASE WHEN W.warehouseName = 'East' THEN P.quantityInStock ELSE 0 END) AS East_Stock,
	SUM(CASE WHEN W.warehouseName = 'South' THEN P.quantityInStock ELSE 0 END) AS South_Stock,
    SUM(CASE WHEN W.warehouseName = 'West' THEN P.quantityInStock ELSE 0 END) AS West_Stock
FROM products AS P
LEFT JOIN warehouses AS W ON P.warehouseCode = W.warehouseCode
GROUP BY productLine;

-- Q1 Code Output 3: Profit Analysis per warehouse
SELECT
warehouseName,
SUM(buyPrice * quantityOrdered) AS Cost,
SUM(priceEach * quantityOrdered) AS Sales,
SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered) AS Profit,
(SUM(priceEach * quantityOrdered) - SUM(buyPrice * quantityOrdered)) /
SUM(priceEach * quantityOrdered)*100 AS `%_Profit`
FROM order_summary
GROUP BY warehouseName
ORDER BY Profit;
    
-- Question 2: How are inventory numbers related to sales figures? Do the inventory counts seem appropriate for each item?
-- Q2 Code Output 1: Gather data of Annual Sales, IOH in $ and get their ratio per PRODUCT LINE
WITH Product_Inventory AS (
    SELECT
        productLine,
        SUM(MSRP * quantityInStock) AS IOH_$
    FROM products
    GROUP BY productLine
)
SELECT
    P.productLine,
    SUM(P.MSRP * OD.quantityOrdered) / COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM O.orderDate)) * 12 AS Annual_Sales,
    PI.IOH_$,
    PI.IOH_$ / (SUM(P.MSRP * OD.quantityOrdered) / 
    COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM O.orderDate)) * 12)  AS Sales_to_IOH_Ratio
FROM products AS P
LEFT JOIN orderdetails AS OD ON P.productCode = OD.productCode
LEFT JOIN orders AS O ON OD.orderNumber = O.orderNumber
LEFT JOIN Product_Inventory AS PI ON P.productLine = PI.productLine
GROUP BY P.productLine, PI.IOH_$
ORDER BY Annual_Sales DESC;


-- Question 3: Are we storing items that are not moving? Are any items candidates for being dropped from the product line?
-- Q3 Code Output 1: Gather data of Annual Sales, IOH in $ and get their ratio per INDIVIDUAL PRODUCT
WITH Product_Inventory AS (
    SELECT
        productName,
        SUM(MSRP * quantityInStock) AS IOH_$
    FROM products
    GROUP BY productName
)
SELECT
    P.productName,
    SUM(P.MSRP * OD.quantityOrdered) / COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM O.orderDate)) AS Annual_Sales,
    PI.IOH_$,
    PI.IOH_$ / (SUM(P.MSRP * OD.quantityOrdered) / 
    COUNT(DISTINCT EXTRACT(YEAR_MONTH FROM O.orderDate)) * 12)  AS Sales_to_IOH_Ratio
FROM products AS P
LEFT JOIN orderdetails AS OD ON P.productCode = OD.productCode
LEFT JOIN orders AS O ON OD.orderNumber = O.orderNumber
LEFT JOIN Product_Inventory AS PI ON P.productName = PI.productName
GROUP BY P.productName, PI.IOH_$
HAVING Sales_to_IOH_Ratio < 1 OR Sales_to_IOH_Ratio IS NULL
ORDER BY Sales_to_IOH_Ratio;


-- Supplementary Queries:
-- Pareto Chart per product line; to idetify the top product composing 80% of total sales.
WITH Product_Sales AS (
    SELECT
        productLine AS Product,
        SUM(MSRP * quantityOrdered) AS Sales
    FROM products AS P
    INNER JOIN orderdetails AS OD ON P.productCode = OD.productCode
    GROUP BY productLine
)
SELECT
    Product,
    Sales,
    (SUM(Sales) OVER (ORDER BY Sales DESC) / 
		(SELECT SUM(Sales) FROM Product_Sales) * 100) AS Percent_Running_Sales
FROM Product_Sales
ORDER BY Sales DESC;

-- Pareto Chart per individual product; Identify the sales distribution per product
WITH Product_Sales AS (
    SELECT
        productName AS Product,
        SUM(MSRP * quantityOrdered) AS Sales
    FROM products AS P
    INNER JOIN orderdetails AS OD ON P.productCode = OD.productCode
    GROUP BY productName
)
SELECT
    Product,
    Sales,
    (SUM(Sales) OVER (ORDER BY Sales DESC) / 
		(SELECT SUM(Sales) FROM Product_Sales) * 100) AS Percent_Running_Sales
FROM Product_Sales
ORDER BY Sales DESC;