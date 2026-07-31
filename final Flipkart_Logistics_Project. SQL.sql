-- =======================================================
-- PROJECT: FLIPKART LOGISTICS PERFORMANCE ANALYSIS
-- STUDENT NAME: SAKSHI DUBEY

-- TASK 1: DATA CLEANING & PREPARATION 
-- =======================================================

-- Step 1: Initialize Database and Disable Safe Updates
USE flipkart_logistics;
SET SQL_SAFE_UPDATES = 0;

-- Step 2: Identify Duplicate Order_ID Records
-- This ensures each order is unique for accurate analysis.
SELECT Order_ID, COUNT(*) 
FROM Orders 
GROUP BY Order_ID 
HAVING COUNT(*) > 1;

-- 3: Route-specific null handling
UPDATE routes r
JOIN (
    SELECT Route_ID, AVG(Traffic_Delay_Min) AS avg_route_delay
    FROM routes
    WHERE Traffic_Delay_Min IS NOT NULL
    GROUP BY Route_ID
) AS route_avgs
ON r.Route_ID = route_avgs.Route_ID
SET r.Traffic_Delay_Min = route_avgs.avg_route_delay
WHERE r.Traffic_Delay_Min IS NULL;

-- Step 4: Logic Validation and Flagging
-- Identifying records where Delivery Date is logically impossible (before Order Date).
SELECT 
    Order_ID,
    Order_Date,
    Actual_Delivery_Date,
    CASE 
        WHEN Actual_Delivery_Date < Order_Date THEN 'Error'
        ELSE 'Valid'
    END AS Validation_Flag
FROM Orders;

-- Step 5: Final Clean Data Preview
SELECT * FROM Orders LIMIT 10;

-- ==========================================================
-- TASK 2: DELIVERY DELAY ANALYSIS (10 MARKS)
-- ==========================================================

-- Point 1: Calculate delivery delay (in days) for each order
-- We use DATEDIFF to subtract the expected date from the actual date.
SELECT Order_ID, Route_ID, 
       DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days
FROM Orders;

-- Point 2: Find Top 10 delayed routes based on average delay days
-- This helps Flipkart identify which paths are causing the most trouble.
SELECT Route_ID, 
AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Route_Delay
FROM Orders
GROUP BY Route_ID
ORDER BY Avg_Route_Delay DESC
LIMIT 10;

-- Point 3: Use Window Functions to rank orders by delay within each warehouse
-- This uses RANK() to see which specific orders are the most delayed at each location.
SELECT 
    Order_ID,
    Warehouse_ID,
    DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date) AS Delay_Days
FROM Orders
ORDER BY Warehouse_ID, Delay_Days DESC;

-- ==========================================================
-- TASK 3: WAREHOUSE PERFORMANCE & AGENT EFFICIENCY 
-- ==========================================================

-- Point 1: Total Orders per Warehouse
SELECT Warehouse_ID, COUNT(Order_ID) AS Total_Orders
FROM Orders
GROUP BY Warehouse_ID;

-- Point 2: Delivery Agent Success Rate
-- We calculate the percentage of orders delivered on or before the expected date.
SELECT Agent_ID, 
       COUNT(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 END) * 100.0 / COUNT(*) AS Success_Rate_Percentage
FROM orders
 GROUP BY Agent_ID;
 
 -- point 3.
 SELECT 
    Route_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Route_Delay
FROM Orders
GROUP BY Route_ID
ORDER BY Avg_Route_Delay DESC
LIMIT 3;
 
-- 4: Dynamic Categorization
SELECT Warehouse_ID, COUNT(Order_ID) AS Order_Count,
CASE 
    WHEN COUNT(Order_ID) > (SELECT AVG(order_vol) FROM (SELECT COUNT(Order_ID) as order_vol FROM Orders GROUP BY Warehouse_ID) as sub) THEN 'High Volume'
    ELSE 'Low Volume'
END AS Volume_Category
FROM Orders
GROUP BY Warehouse_ID;

-- ==========================================================
-- Task 4: WAREHOUSE OPERATIONAL PERFORMANCE ANALYSIS
-- ==========================================================

-- 1. Top 3 Hubs with Highest Average Processing Time
SELECT Warehouse_ID, 
       AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Processing_Days
FROM Orders
GROUP BY Warehouse_ID
ORDER BY Avg_Processing_Days DESC
LIMIT 3;

-- 2. Total Shipments vs. Delayed Shipments per Facility
SELECT Warehouse_ID, 
       COUNT(*) AS Total_Shipments,
       COUNT(CASE WHEN Actual_Delivery_Date > Expected_Delivery_Date THEN 1 END) AS Delayed_Shipments
FROM Orders
GROUP BY Warehouse_ID;

-- 3: Identify Warehouses 20% slower than average
SELECT Warehouse_ID, AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Processing_Days
FROM Orders
GROUP BY Warehouse_ID
HAVING Avg_Processing_Days > (SELECT AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) * 1.2 FROM Orders);

-- 4. Facility Performance Leaderboard (On-Time Delivery Rank)
SELECT 
    Warehouse_ID,
    (COUNT(CASE 
        WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 
    END) * 100.0 / COUNT(*)) AS OnTime_Percentage
FROM Orders
GROUP BY Warehouse_ID
ORDER BY OnTime_Percentage DESC;

-- TASK 4: Warehouse Operational Performance Analysis
-- This query identifies the most efficient warehouses by calculating 
-- the average processing time from order placement to actual delivery.

SELECT 
    Warehouse_ID,
    AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Processing_Days
FROM Orders
WHERE Actual_Delivery_Date IS NOT NULL 
AND Order_Date IS NOT NULL
GROUP BY Warehouse_ID
ORDER BY Avg_Processing_Days ASC;

-- ==========================================================
-- Task 5: DELIVERY AGENT PERFORMANCE & RANKING
-- ==========================================================

-- 1. Rank agents (per route) by on-time delivery percentage
SELECT 
    Route_ID,
    Agent_ID,
    COUNT(CASE 
        WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 
    END) * 100.0 / COUNT(*) AS OnTime_Percentage
FROM Orders
GROUP BY Route_ID, Agent_ID
ORDER BY Route_ID, OnTime_Percentage DESC;

-- 2. Find agents with on-time % < 80% (High-Priority for Training)
SELECT Agent_ID, 
       (COUNT(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 END) * 100.0 / COUNT(*)) AS Success_Rate
FROM Orders
GROUP BY Agent_ID
HAVING Success_Rate < 80;

-- 3. Compare Avg Speed: Top 5 vs Bottom 5 Agents (Using Subqueries)
-- We use Delivery_Time as a proxy for speed (Lower is faster)
(SELECT 'Top 5 Agents' AS Category, AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Days
 FROM (SELECT Agent_ID FROM Orders GROUP BY Agent_ID ORDER BY (COUNT(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 END) * 100.0 / COUNT(*)) DESC LIMIT 5) AS TopAgents
 JOIN Orders O ON TopAgents.Agent_ID = O.Agent_ID)
UNION ALL
(SELECT 'Bottom 5 Agents' AS Category, AVG(DATEDIFF(Actual_Delivery_Date, Order_Date)) AS Avg_Days
 FROM (SELECT Agent_ID FROM Orders GROUP BY Agent_ID ORDER BY (COUNT(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 END) * 100.0 / COUNT(*)) ASC LIMIT 5) AS BottomAgents
 JOIN Orders O ON BottomAgents.Agent_ID = O.Agent_ID);
 
-- ==========================================================
-- TASK 6: SHIPMENT TRACKING ANALYTICS
-- ==========================================================

-- 1. For each order, list the last checkpoint and time
SELECT st.Order_ID, 
       st.Checkpoint, 
       st.Checkpoint_Time
FROM ShipmentTracking st
JOIN (
    SELECT Order_ID, MAX(Checkpoint_Time) AS Latest_Time
    FROM ShipmentTracking
    GROUP BY Order_ID
) latest
ON st.Order_ID = latest.Order_ID 
AND st.Checkpoint_Time = latest.Latest_Time;


-- 2. Find the most common delay reasons (excluding None)
SELECT Delay_Reason, COUNT(*) AS Frequency
FROM ShipmentTracking
WHERE Delay_Reason IS NOT NULL 
  AND Delay_Reason <> 'None'
GROUP BY Delay_Reason
ORDER BY Frequency DESC;


-- 3. Identify orders with more than 2 delayed checkpoints
-- Logic: We count rows for an Order_ID where a delay reason exists
SELECT Order_ID, COUNT(*) AS Delayed_Checkpoints_Count
FROM ShipmentTracking
WHERE Delay_Reason IS NOT NULL 
  AND Delay_Reason <> 'None'
GROUP BY Order_ID
HAVING COUNT(*) > 2;

-- Point 4 .
-- :Objective Identify high-priority orders that have experienced 
-- more than 2 delays across different checkpoints.

SELECT 
    Order_ID,
    COUNT(*) AS Delayed_Count
FROM ShipmentTracking
WHERE Delay_Reason IS NOT NULL
AND Delay_Reason <> 'None'
GROUP BY Order_ID
HAVING COUNT(*) > 2
ORDER BY Delayed_Count DESC
LIMIT 10;
-- ==========================================================
-- TASK 7: ADVANCED KPI REPORTING
-- ==========================================================

-- 1. Average Delivery Delay per Region (Warehouse_ID)
SELECT Warehouse_ID, 
       AVG(DATEDIFF(Actual_Delivery_Date, Expected_Delivery_Date)) AS Avg_Delay_Days
FROM orders
GROUP BY Warehouse_ID;


-- 2. On-Time Delivery % (OTD)
SELECT 
    (COUNT(CASE WHEN Actual_Delivery_Date <= Expected_Delivery_Date THEN 1 END) * 100.0 / COUNT(*)) AS On_Time_Delivery_Percentage
FROM orders;


-- 3. Average Traffic Delay per Route
-- Logic: Route_ID is in 'orders', Delay_Minutes is in 'shipmenttracking'
SELECT o.Route_ID, 
       AVG(st.Delay_Minutes) AS Avg_Traffic_Delay_Minutes
FROM orders o
JOIN shipmenttracking st ON o.Order_ID = st.Order_ID
WHERE st.Delay_Reason = 'Traffic'
GROUP BY o.Route_ID
ORDER BY Avg_Traffic_Delay_Minutes DESC;






    




     

 



