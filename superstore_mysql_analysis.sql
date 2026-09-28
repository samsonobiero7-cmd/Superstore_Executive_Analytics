CREATE DATABASE  superstore_analytics;
USE superstore_analytics;

CREATE TABLE  sales (
    Row_ID INT NOT NULL,
    Order_ID VARCHAR(25) NOT NULL,
    Order_Date DATE NOT NULL,
    Ship_Date DATE NOT NULL,
    Ship_Mode VARCHAR(25) NOT NULL,
    Customer_ID VARCHAR(25) NOT NULL,
    Customer_Name VARCHAR(100) NOT NULL,
    Segment VARCHAR(50) NOT NULL,
    Country VARCHAR(100) NOT NULL,
    City VARCHAR(100) NOT NULL,
    State VARCHAR(100) NOT NULL,
    Postal_Code INT NULL,
    Region VARCHAR(50) NOT NULL,
    Product_ID VARCHAR(50) NOT NULL,
    Category VARCHAR(50) NOT NULL,
    Sub_Category VARCHAR(50) NOT NULL,
    Product_Name VARCHAR(255) NOT NULL,
    Sales DECIMAL(10, 2) NOT NULL,
    Quantity INT NOT NULL,
    Discount DECIMAL(4, 2) NOT NULL,
    Profit DECIMAL(10, 2) NOT NULL,
    PRIMARY KEY (Row_ID)
);

-- loading data and also converting date strings to real data system dates
USE superstore_analytics;
LOAD DATA INFILE 'C:/ProgramData/MySQL/MySQL Server 8.0/uploads/Sample-Superstore.csv'
INTO TABLE sales
CHARACTER SET latin1
FIELDS TERMINATED BY ','
ENCLOSED BY '"'
LINES TERMINATED BY '\n'
IGNORE 1 ROWS
(
    `Row ID`, `Order ID`, @raw_order_date, @raw_ship_date, `Ship Mode`,
    `Customer ID`, `Customer Name`, Segment, Country, City,
    State, `Postal Code`, Region, `Product ID`, Category,
    `Sub-Category`, `Product Name`, Sales, Quantity, Discount, Profit
)
SET 
    `Order Date` = STR_TO_DATE(TRIM(@raw_order_date), '%m/%d/%Y'),
    `Ship Date`  = STR_TO_DATE(TRIM(@raw_ship_date), '%m/%d/%Y');
    
    
    
UPDATE sales
-- 1.round financial metrics to standard 2 decimal places
SET sales  =ROUND(sales,2),
    profit =ROUND(profit,2),
    Discount =ROUND(Discount,2),
-- 2. Trim hidden spaces from EVERY text column
    `Order ID`      = TRIM(`Order ID`),
    `Customer ID`   = TRIM(`Customer ID`),
    `Customer Name` = TRIM(`Customer Name`),
    Segment       = TRIM(Segment),      -- Added
    Country       = TRIM(Country),
    City          = TRIM(City),
    State         = TRIM(State),
    Region        = TRIM(Region),       -- Added
    `Product ID`    = TRIM(`Product ID`),
    Category      = TRIM(Category),
    `Sub-Category`  = TRIM(`Sub-Category`),
    `Product Name`  = TRIM(`Product Name`),
    `Ship Mode`     = TRIM(`Ship Mode`);
    
    SELECT `order ID`,`product ID`,COUNT(*) as duplicate_count
FROM sales
GROUP BY `order ID`,`product ID`
HAVING COUNT(*)>1;

-- THIS COULD NOT DELETE THE DUPLICATES BECAUSE MYSQL SAW THE ROW NO AS IDENTICAL
CREATE TABLE sales_temp AS
SELECT DISTINCT*FROM sales;

TRUNCATE TABLE sales;

INSERT INTO sales
SELECT*FROM sales_temp;

SELECT*
FROM sales
WHERE `order ID`='CA-2016-129714'
AND`Product ID`='OFF-PA-10001970';

-- re-create the temp table ,keeping only
--  the first appearance(min row id)of every order item
USE superstore_analytics;
CREATE TABLE sales_temp
SELECT *
FROM sales
WHERE`Row ID`IN(
       SELECT MIN(`Row ID`)
       FROM sales
       GROUP BY`Order ID`,`Product ID`);
       
TRUNCATE TABLE sales;

       INSERT INTO sales
SELECT * FROM sales_temp;

SELECT*
FROM sales;

SELECT 
    -- 1. Check Row and Order Identity
    SUM(CASE WHEN `Row ID` IS NULL THEN 1 ELSE 0 END) AS RowID_Nulls,
    SUM(CASE WHEN `Order ID` IS NULL OR `Order ID` = '' THEN 1 ELSE 0 END) AS OrderID_Nulls,
    
    -- 2. Check Key Transaction Dates
    SUM(CASE WHEN `Order Date` IS NULL THEN 1 ELSE 0 END) AS OrderDate_Nulls,
    SUM(CASE WHEN `Ship Date` IS NULL THEN 1 ELSE 0 END) AS ShipDate_Nulls,
    
    -- 3. Check Customer Info
    SUM(CASE WHEN `Customer ID` IS NULL OR `Customer ID` = '' THEN 1 ELSE 0 END) AS CustomerID_Nulls,
    SUM(CASE WHEN `Customer Name` IS NULL OR `Customer Name` = '' THEN 1 ELSE 0 END) AS CustomerName_Nulls,
    
    -- 4. Check Geographic Info
    SUM(CASE WHEN `Country` IS NULL OR `Country` = '' THEN 1 ELSE 0 END) AS Country_Nulls,
    SUM(CASE WHEN `City` IS NULL OR `City` = '' THEN 1 ELSE 0 END) AS City_Nulls,
    SUM(CASE WHEN `State` IS NULL OR `State` = '' THEN 1 ELSE 0 END) AS State_Nulls,
    SUM(CASE WHEN `Postal Code` IS NULL OR `Postal Code` = '' THEN 1 ELSE 0 END) AS PostalCode_Nulls,
    
    -- 5. Check Product Info
    SUM(CASE WHEN `Product ID` IS NULL OR `Product ID` = '' THEN 1 ELSE 0 END) AS ProductID_Nulls,
    SUM(CASE WHEN `Category` IS NULL OR `Category` = '' THEN 1 ELSE 0 END) AS Category_Nulls,
    SUM(CASE WHEN `Sub-Category` IS NULL OR `Sub-Category` = '' THEN 1 ELSE 0 END) AS SubCategory_Nulls,
    SUM(CASE WHEN `Product Name` IS NULL OR `Product Name` = '' THEN 1 ELSE 0 END) AS ProductName_Nulls,
    
    -- 6. Check Financial Performance Metrics
    SUM(CASE WHEN Sales IS NULL THEN 1 ELSE 0 END) AS Sales_Nulls,
    SUM(CASE WHEN Quantity IS NULL THEN 1 ELSE 0 END) AS Quantity_Nulls,
    SUM(CASE WHEN Discount IS NULL THEN 1 ELSE 0 END) AS Discount_Nulls,
    SUM(CASE WHEN Profit IS NULL THEN 1 ELSE 0 END) AS Profit_Nulls
FROM sales;


-- to get your total revenue, total profit, total items sold,
-- and your overall profit margin percentage. 
SELECT 
    ROUND(SUM(Sales), 2) AS Total_Revenue,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    SUM(Quantity) AS Total_Items_Sold,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS Overall_Profit_Margin_PCT
FROM sales;

-- top 5 most profitable subcategories
-- These two queries help you understand what is driving 
-- the business forward—and what is dragging it down.
-- while phones generate the highest raw revenue, copiers are vastly more effecient
-- ,generating higher pure profit on less than half the sales volume marketing budgets
-- should be reaaligned to focus aggresively on promoting copiers and accessories to maximize
-- net cash flow
SELECT 
    `Sub-Category`,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit
FROM sales
GROUP BY `Sub-Category`
ORDER BY Total_Profit DESC
LIMIT 5;

-- top 5 most unprofitable subcategories/ bleeding products
-- Restructure the furniture pricing and shipping strategy
-- The problem ;the tables sub-category is actively draining cash from the business
-- The evidence ;tables lost massive_$17,725.57, making the worst-performing product group
-- The action ;increase retail prices for tables and bookcases. alternatively,charge separate
-- realistic shipping fees for large furniture items instead of eating the freight costs
SELECT 
        `sub-category`,
        ROUND(sum(sales),2) AS total_sales,
        ROUND(sum(profit),2) AS total_profit
FROM sales
GROUP BY `sub-category`
ORDER BY total_profit ASC
LIMIT 5;

SELECT 
    Segment,
    COUNT(DISTINCT `Order ID`) AS Total_Unique_Orders,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS Segment_Margin_PCT
FROM sales
GROUP BY Segment
ORDER BY Total_Sales DESC;

-- which US States are bringing in the highest revenue and profits.
SELECT 
    State,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit
FROM sales
GROUP BY State
ORDER BY Total_Sales DESC
LIMIT 5;


-- finding out what makes texas and pennsylvania profits low 
-- using the discount avg
-- the problem; high sales volumes in states like texas and illinois are a trap
-- The evidence; average discount of 37% to 39% are mathematically wiping out all revenue
-- The action;immediately cap maximum allowed promotional discounts at 15% in texas
-- ohio,pennsylivania and illinois to restore profitability
SELECT 
    State,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND(AVG(Discount) * 100, 1) AS Avg_Discount_Percentage
FROM sales
GROUP BY State
ORDER BY Total_Profit ASC
LIMIT 5;


-- low discounts percentage in different states 
SELECT 
    State,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND(AVG(Discount) * 100, 1) AS Avg_Discount_Percentage
FROM sales
GROUP BY State
ORDER BY Total_Profit DESC
LIMIT 5;


SELECT 
    YEAR(`Order Date`) AS Sales_Year,
    COUNT(DISTINCT `Order ID`) AS Total_Unique_Orders,
    ROUND(SUM(Sales), 2) AS Total_Revenue,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS Annual_Margin_PCT
FROM sales
GROUP BY YEAR(`Order Date`)
ORDER BY Sales_Year ASC;

USE superstore_analytics;
-- The Shipping & Logistics Check; This query calculates the average number of days 
-- it takes for orders to ship out based on your different
-- shipping methods. It uses DATEDIFF() to subtract the Order Date from the Ship Date.
SELECT 
    `Ship Mode`,
    COUNT(`Order ID`) AS Total_Shipments,
    ROUND(AVG(DATEDIFF(`Ship Date`, `Order Date`)), 1) AS Avg_Days_To_Ship
FROM sales
GROUP BY `Ship Mode`
ORDER BY Avg_Days_To_Ship ASC;


-- The VIP Customer Report ;This identifies your top 5 highest-spending customers across 
-- the entire dataset. It helps business managers figure out who their most
-- critical accounts are.
SELECT 
    `Customer ID`,
    `Customer Name`,
    Segment,
    ROUND(SUM(Sales), 2) AS Total_Spent,
    ROUND(SUM(Profit), 2) AS Total_Profit_Generated
FROM sales
GROUP BY `Customer ID`, `Customer Name`, Segment
ORDER BY Total_Spent DESC
LIMIT 5;

SELECT 
    `Ship Mode`,
    COUNT(DISTINCT `Order ID`) AS Total_Orders,
    ROUND(SUM(Sales), 2) AS Total_Sales,
    ROUND(SUM(Profit), 2) AS Total_Profit,
    ROUND((SUM(Profit) / SUM(Sales)) * 100, 2) AS Ship_Mode_Margin_PCT
FROM sales
GROUP BY `Ship Mode`
ORDER BY Total_Sales DESC;


