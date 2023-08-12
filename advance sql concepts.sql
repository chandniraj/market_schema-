-- Rank Demo

USE market_star_schema;

SELECT  customer_name,
		ord_id,
		ROUND(sales) AS rounded_sales,
        RANK() OVER (ORDER BY sales DESC) AS sales_rank
FROM market_fact_full as m
INNER JOIN
cust_dimen as c
ON m.cust_id = c.cust_id
WHERE customer_name= 'RICK WILSON';

-- Top 10 sales orders from a customer

WITH rank_info AS
(
SELECT  customer_name,
		ord_id,
		ROUND(sales) AS rounded_sales,
        RANK() OVER (ORDER BY sales DESC) AS sales_rank
FROM market_fact_full as m
INNER JOIN
cust_dimen as c
ON m.cust_id = c.cust_id
WHERE customer_name= 'RICK WILSON'
)
SELECT *
FROM rank_info
WHERE sales_rank<=10;

-- Example for Dense Rank
SELECT ord_id,
		discount,
        customer_name,
        RANK() OVER (ORDER BY discount DESC) AS disc_rank,
        DENSE_RANK() OVER (ORDER BY discount DESC) AS disc_dense_rank        
FROM market_fact_full as m
INNER JOIN cust_dimen as c
ON m.cust_id=c.cust_id
WHERE customer_name= 'RICK WILSON';

-- Number of orders each customer has placed

SELECT customer_name,
		COUNT(DISTINCT ord_id) AS order_count,
        RANK() OVER (ORDER BY COUNT(DISTINCT ord_id) DESC) AS order_rank,
        DENSE_RANK() OVER (ORDER BY COUNT(DISTINCT ord_id) DESC) AS order_dense_rank,
        ROW_NUMBER() OVER (ORDER BY COUNT(DISTINCT ord_id) DESC) AS order_row_num
FROM market_fact_full AS m
INNER JOIN
cust_dimen AS c
ON m.cust_id=c.cust_id
GROUP BY customer_name;

-- Partitioning example
WITH shipping_summary AS
(
SELECT ship_mode,
		MONTH(ship_date) AS shipping_month,
        COUNT(*) as shipments
FROM 
shipping_dimen
GROUP BY ship_mode,
		 

-- Frames example
WITH daily_shipping_summary AS
(
SELECT ship_date,
		SUM(shipping_cost) AS daily_total
FROM
market_fact_full AS m
INNER JOIN
shipping_dimen AS s
ON m.ship_id=s.ship_id
GROUP BY ship_date
)
SELECT *,
		SUM(daily_total) OVER w1 AS running_total,
        AVG(daily_total) OVER w2 AS moving_avg
FROM daily_shipping_summary
WINDOW w1 as (ORDER BY ship_date ROWS UNBOUNDED PRECEDING),
w2 AS (ORDER BY ship_date ROWS 6 PRECEDING);

-- Lead and Lag example
WITH cust_order as
(
	SELECT c.customer_name,
			m.ord_id,
			o.order_date
	FROM
	market_fact_full as m
	LEFT JOIN
	orders_dimen as o
	ON m.ord_id=o.ord_id
	LEFT JOIN
	cust_dimen as c
	ON m.cust_id=c.cust_id
	WHERE customer_name='RICK WILSON'
	GROUP BY 
			c.customer_name,
			m.ord_id,
			o.order_date
),
next_date_summary AS 
(
SELECT *,
		LEAD(order_date,1,'2015-01-01') OVER (ORDER BY order_date, ord_id) AS next_order_date
FROM cust_order
ORDER BY customer_name,
		 order_date,
         ord_id
)
SELECT *, DATEDIFF(next_order_date, order_date) as days_diff
FROM next_date_summary; 


-- Case when example
/*  profit < -500 -> huge loss
	profit -500 to 0 ->bearable loss
    profit 0 to 500 -> decent profit
    profit >500 -> great profit
*/
SELECT 
	market_fact_id,
    profit,
	CASE
		WHEN profit <-500 THEN 'Huge Loss'
        WHEN profit BETWEEN -500 AND 0 THEN 'Bearable Loss'
        WHEN profit BETWEEN 0 AND 500 THEN 'Decent Profit'
		ELSE 'Great Profit'
    END AS Profit_type
FROM
    market_fact_full;
-- Classify customers on the following criteria
-- Top 10 % of customers as Gold
-- Next 40% of customers as Silver
-- Rest 50% of customers as Bronze
WITH cust_summary AS
(
	SELECT m.cust_id, 
			c.customer_name, 
			ROUND(SUM(m.sales)) as total_sales,
			PERCENT_RANK() OVER( ORDER BY ROUND(SUM(m.sales)) DESC) as perc_rank
	FROM
		market_fact_full as m
		LEFT JOIN 
		cust_dimen as c
	ON
		m.cust_id=c.cust_id
	GROUP BY cust_id
)
SELECT *,
		CASE 
			WHEN perc_rank<0.1 THEN 'Gold'
            WHEN perc_rank<0.5 THEN 'Silver'
            ELSE 'Bronze'
		END AS customer_category
FROM cust_summary;

-- UDFs
DELIMITER $$

CREATE FUNCTION profitType(profit int)
RETURNS VARCHAR(30) DETERMINISTIC

BEGIN

DECLARE message VARCHAR(30);
IF profit<-500 THEN
	SET message = 'Huge Loss';
ELSEIF profit BETWEEN -500 AND 0 THEN 
	SET message = 'Bearable Loss';
ELSEIF profit BETWEEN 0 AND 500 THEN
	SET message = 'Decent Profit';
ELSE
	SET message = 'Great Profit';
END IF;

RETURN message;

END;
$$
DELIMITER ;

SELECT profitType(-20) as Function_output;



-- Stored Procedures

DELIMITER $$

CREATE PROCEDURE get_sales_customers (sales_input INT)
BEGIN
	SELECT DISTINCT cust_id,
					ROUND(sales) AS sales_amount
	FROM
		market_fact_full
	WHERE ROUND(sales)>sales_input
    ORDER BY sales;
    
END $$

DELIMITER ;

CALL get_sales_customers(300);

DROP PROCEDURE get_sales_customers;


-- Query best practices 

-- Comment Section

/*
Comment Section with
multiple lines
*/

SELECT fact.ord_id, order_date
FROM market_fact_full AS fact INNER JOIN orders_dimen AS ord ON fact.ord_id = ord.ord_id
ORDER BY fact.ord_id , order_date;


SELECT fact.ord_id,
       order_date
FROM   market_fact_full AS fact
       INNER JOIN orders_dimen AS ord
               ON fact.ord_id = ord.ord_id
ORDER  BY fact.ord_id,
          order_date;  

-- Index Demo
CREATE TABLE market_fact_temp AS
SELECT * 
FROM
	market_fact_full;

CREATE INDEX filter_index ON market_fact_temp (cust_id, ship_id, prod_id);

ALTER TABLE market_fact_temp DROP INDEX filter_index;


-- Types of Indexes
SELECT * FROM market_fact_full;

-- Query Optimisation with understanding of Order of Query execution
-- Problem: Top 10 order ids and the customers who did them

SELECT ord_id,
		customer_name 
FROM
(
SELECT  m.*,c.customer_name,
        RANK() OVER (ORDER BY sales DESC) AS sales_rank,
        DENSE_RANK() OVER (ORDER BY sales DESC) AS sales_dense_rank,
        ROW_NUMBER() OVER (ORDER BY sales DESC) AS sales_row_num
FROM 
market_fact_full as m
LEFT JOIN
cust_dimen as c
ON m.cust_id = c.cust_id
ORDER BY sales desc
) as a
LIMIT 10;



SELECT ord_id,
		customer_name 
FROM
(
SELECT  ord_id,c.customer_name,
        ROW_NUMBER() OVER (ORDER BY sales DESC) AS sales_row_num
FROM 
market_fact_full as m
INNER JOIN
cust_dimen as c
ON m.cust_id = c.cust_id
) as a
WHERE sales_row_num<=10;











