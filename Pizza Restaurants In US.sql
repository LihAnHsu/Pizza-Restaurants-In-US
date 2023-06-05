-- Pizza restaurants and Pizzas on their Menus
-- license: CC BY-NC-SA

-- What are the least and most expensive cities for pizza?
-- What are the most popular in category?
-- Most/Least Expensive Pizza selling restaurant with their menu
-- Restaurant with maximum price difference in their menu
-- What is the number of restaurants serving pizza per city across the U.S.?
-- Pizza demand with respect to days of the week

SELECT *

FROM pizza AS p 

-- Copy table
CREATE TABLE Pizza_1 AS 

SELECT * FROM pizza;

-------------------------------------Cleaning data--------------------------------------- 
--drop cols that are not related to analysis
ALTER TABLE Pizza_1  

DROP COLUMN address;

ALTER TABLE Pizza_1 

DROP COLUMN keys;

ALTER TABLE Pizza_1 

DROP COLUMN menuPageURL;

ALTER TABLE Pizza_1 

DROP COLUMN 'menus.description';


-- Rename cols 
-- categories -> restaurant_category
ALTER TABLE Pizza_1 

RENAME COLUMN categories TO restaurant_category; 

-- only one country, drop this col
SELECT COUNT (DISTINCT p1.country) 

FROM Pizza_1 AS p1;


ALTER TABLE Pizza_1 

DROP COLUMN country;

-- menus.amountMax -> max_price_item
ALTER TABLE Pizza_1 

RENAME COLUMN 'menus.amountMax' TO max_price_item ; 

-- menus.amountMin -> min_price_item
ALTER TABLE Pizza_1 

RENAME COLUMN 'menus.amountMin' TO min_price_item;

--menus.currency, only USD, so drop col to simplify table
SELECT COUNT (DISTINCT p1.'menus.currency')

FROM Pizza_1 AS p1; 


ALTER TABLE Pizza_1 

DROP COLUMN 'menus.currency';

--so does pricecurrency, drop col
ALTER TABLE Pizza_1 

DROP COLUMN priceRangeCurrency;

-- menus.dateseen -> clicking_menu_date
ALTER TABLE Pizza_1 

RENAME COLUMN 'menus.dateSeen' TO clicking_menu_date;

-- menus.name -> menu_item
ALTER TABLE Pizza_1 

RENAME COLUMN 'menus.name' TO menu_item;

-- name -> restaurant_name
ALTER TABLE Pizza_1 

RENAME COLUMN name TO restaurant_name;

-- count null of each col and drop null
--First, count rows of total: 3,510 rows
SELECT 
		COUNT(*) AS row_num
FROM Pizza_1;


SELECT COUNT(*)

FROM Pizza_1 AS p1 

WHERE p1.max_price_item IS NULL; --562 nulls

SELECT COUNT(*)

FROM Pizza_1 AS p1 

WHERE p1.min_price_item IS NULL; --562 nulls

SELECT COUNT(*)

FROM Pizza_1 AS p1 

WHERE p1.postalCode IS NULL;     -- 26 NULLS

SELECT COUNT(*)

FROM Pizza_1 AS p1 

WHERE p1.priceRangeMin IS NULL;-- 1,953 NULLS

SELECT COUNT(*)

FROM Pizza_1 AS p1 

WHERE p1.priceRangeMax IS NULL;-- 1,953 NULLS

--drop pricerange cols(>50% are nulls) and row that has nulls
ALTER TABLE Pizza_1 

DROP COLUMN priceRangeMin;

ALTER TABLE Pizza_1 

DROP COLUMN priceRangeMax;

--DELETE statement will then remove the null rows where the CASE expression equals 1.
DELETE FROM Pizza_1 

WHERE CASE 
	WHEN max_price_item IS NULL THEN 1
	WHEN min_price_item IS NULL THEN 1
	WHEN postalCode IS NULL THEN 1
	ELSE 0
END
-- now 2922 cols remained
SELECT 
		COUNT(*) AS row_num
FROM Pizza_1;

-- drop duplicate by sub query: MIN(id), GROUP BY all cols
DELETE FROM Pizza_1 AS p1 

WHERE p1.id NOT IN (
				SELECT MIN(p1.id)
				
				FROM Pizza_1 AS p1
				
				GROUP BY p1.id,
						p1.restaurant_category,
						p1.city, 
						p1.latitude,
						p1.longitude,
						p1.max_price_item,
						p1.clicking_menu_date,
						p1.menu_item,
						p1.restaurant_name,
						p1.postalCode,
						p1.province)
						
-- after droping duplicate, 2922 cols remained

-- change dtype, seperate double info at clicking_menu_date col into 2 rows 
-- (similar to .explode() in Python or CROSS APPLY in SQL but not sqlite) 
----------------------------------------------method 1-----------------								
-- Create a temporary table to hold the split rows
CREATE TEMPORARY TABLE temp_split AS

SELECT
    id,
    restaurant_category,
    city,
    latitude,
    longitude,
    max_price_item,
    min_price_item,
    SUBSTR(clicking_menu_date, 1, INSTR(clicking_menu_date, ',') - 1) AS clicking_menu_date,--HOLD value BEFORE comma
    menu_item,
    restaurant_name,
    postalCode,
    province
FROM Pizza_1

WHERE clicking_menu_date LIKE '%,%'

UNION ALL

SELECT
    id,
    restaurant_category,
    city,
    latitude,
    longitude,
    max_price_item,
    min_price_item,
    SUBSTR(clicking_menu_date, INSTR(clicking_menu_date, ',') + 1) AS clicking_menu_date,--HOLD value after comma
    menu_item,
    restaurant_name,
    postalCode,
    province
FROM Pizza_1

WHERE clicking_menu_date LIKE '%,%';

-- Insert the original rows without splitting
INSERT INTO Pizza_1

SELECT *

FROM Pizza_1

WHERE clicking_menu_date NOT LIKE '%,%';

-- Update the original rows with the first part of the split values
UPDATE Pizza_1

SET clicking_menu_date = (
    SELECT clicking_menu_date
    FROM temp_split
    WHERE Pizza_1.id = temp_split.id
)

WHERE EXISTS (
    SELECT 1
    FROM temp_split
    WHERE Pizza_1.id = temp_split.id
);

-- Insert the split rows into the original table
INSERT INTO Pizza_1

SELECT *

FROM temp_split;

-- Drop the temporary table
DROP TABLE temp_split;
						
--check if turn comma delimited col into rows works						
SELECT* 

FROM Pizza_1 

WHERE city = 'Provo'  	--3 rows for 2016-3-31, 2016-3-31, 2016-6-08, means it successfully works															

--Drop duplicate after this
DELETE FROM Pizza_1 AS p1 

WHERE p1.id NOT IN (
				SELECT MIN(p1.id)
				
				FROM Pizza_1 AS p1
				
				GROUP BY p1.id,
						p1.restaurant_category,
						p1.city, 
						p1.latitude,
						p1.longitude,
						p1.max_price_item,
						p1.clicking_menu_date,
						p1.menu_item,
						p1.restaurant_name,
						p1.postalCode,
						p1.province);  --6433 ROWS now AFTER droping duplicate
						
--convert dtype of p1.clicking_menu_date into datetime
ALTER TABLE Pizza_1 

ADD COLUMN clicking_menu_datetime DATETIME;

UPDATE Pizza_1

SET clicking_menu_datetime = DATETIME(clicking_menu_date);

--drop clicking_menu_date since it already has datetime dtype col
ALTER TABLE Pizza_1 

DROP COLUMN clicking_menu_date;

--drop nulls too
DELETE FROM Pizza_1 

WHERE CASE 
	WHEN clicking_menu_datetime IS NULL THEN 1
	ELSE 0
END;

--------------------------------EDA & Answer For Questions--------------------------------------
-- Question 1: What are the least and most expensive cities for pizza?
----Marina Del Rey in CA has the most expensive average pizza $ 163.3
----Jamaica, Philadelphia in Queens, Wm Penn Anx W respectively have the cheapst average pizza $ 1 
----(Chatswoth is excluded since showing the result as 0 dollar)
SELECT 
	p1.province, 
	p1.city, 
	ROUND (AVG(p1.max_price_item),1) AS average_pizza_$

FROM Pizza_1 AS p1 

GROUP BY p1.province, p1.city

ORDER BY average_pizza_$ DESC; 

SELECT 
	   p1.province,
	   p1.city,
	   ROUND (AVG(p1.max_price_item),1) AS average_pizza_$

FROM Pizza_1 AS p1 

GROUP BY p1.province, p1.city

ORDER BY average_pizza_$ ASC; 

-- Question 2: What are the most popular in category?
----Pizza Place is the most popular restaurant_category, which got viewed by 1,010 times
SELECT 
	p1.restaurant_category, 
	COUNT(p1.clicking_menu_datetime) AS viewed_count 

FROM Pizza_1 AS p1 

GROUP BY p1.restaurant_category

ORDER BY viewed_count DESC;

-- Question 3: Most/Least Expensive Pizza selling restaurant with their menu item
----Eddie's Italian Restaurant sells the most expensive item: Pizza Claudia for $313
----Crown Fried Chicken sells the cheapest item: Pizza Role for $1
SELECT 
	p1.restaurant_name, 
	p1.menu_item, 
	ROUND(MAX(p1.max_price_item),1) AS most_expensive_price

FROM Pizza_1 AS p1 

GROUP BY p1.restaurant_name

ORDER BY most_expensive_price DESC;

SELECT 
	p1.restaurant_name, 
	p1.menu_item, 
	ROUND(MAX(p1.min_price_item),1) AS least_expensive_price

FROM Pizza_1 AS p1 

GROUP BY p1.restaurant_name

ORDER BY least_expensive_price ASC;

-- Question 4: Restaurant with maximum price difference in their menu
----Eddie's Italian Restaurant has the maximum price difference $ 302
SELECT 
	p1.restaurant_name, 
	MAX(p1.max_price_item - p1.min_price_item) AS max_price_diff  

FROM Pizza_1 AS p1; 

-- Question 5: What is the number of restaurants serving pizza per city across the U.S.?
----The top 3 cities owning most pizza restaurant are: Philadelphia, NY, East Granby
SELECT 
	p1.city,
	COUNT(p1.restaurant_name) AS restaurant_num

FROM Pizza_1 AS p1

GROUP BY p1.city

ORDER BY restaurant_num DESC; 

-- Question 6: Pizza demand with respect to days of the week
--use strftime to get the day of the week,the %w represents the day of the week as a decimal number, where Sunday is 0 and Saturday is 6
----Monday serves the most pizza amount (1417 times of menu being viewed)
SELECT 
	CASE strftime('%w', p1.clicking_menu_datetime)
    	WHEN '0' THEN 'Sunday'
    	WHEN '1' THEN 'Monday'
    	WHEN '2' THEN 'Tuesday'
    	WHEN '3' THEN 'Wednesday'
    	WHEN '4' THEN 'Thursday'
    	WHEN '5' THEN 'Friday'
    	WHEN '6' THEN 'Saturday'
    END AS day_of_week,
    COUNT(p1.clicking_menu_datetime) AS menu_reviewed_num    
 
FROM Pizza_1 AS p1

GROUP BY day_of_week

ORDER BY menu_reviewed_num DESC;











