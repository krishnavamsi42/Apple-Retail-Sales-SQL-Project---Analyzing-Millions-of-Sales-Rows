-- Apple Sales Project - 1M rows sales datasets

SELECT * FROM category;
SELECT * FROM products;
SELECT * FROM stores;
SELECT * FROM sales;
SELECT * FROM warranty;

-- EDA
SELECT DISTINCT repair_status from warranty;
SELECT COUNT(*) FROM sales;

-- Improving Query Performance 

-- et - 64.ms
-- pt - 0.15ms
-- et after index 5-10 ms

EXPLAIN ANALYZE
SELECT * FROM sales
WHERE product_id ='P-44'

CREATE INDEX sales_product_id ON sales(product_id);
CREATE INDEX sales_store_id ON sales(store_id);
CREATE INDEX sales_sale_date ON sales(sale_date);

-- et - 58.ms
-- pt - 0.069
-- et after index 2 ms
EXPLAIN ANALYZE
SELECT * FROM sales
WHERE store_id ='ST-31'

----------------------------------------------------------------------------------------------------------------------------------------

-- Business Problems
-- 1. Find the number of stores in each country.
SELECT 
      country,
	  count(store_id) as total_stores
FROM stores
GROUP BY country;


-- Q.2 Calculate the total number of units sold by each store.
SELECT 
      s.store_id,
	  st.store_name,
	  SUM(s.quantity) as total_units_sold
FROM sales AS s 
JOIN 
stores AS st
ON s.store_id = st.store_id
GROUP BY 1,2
ORDER BY 3 DESC;


-- Q.3 Identify how many sales occurred in December 2023.
SELECT 
      COUNT(*) AS total_sales
FROM sales
WHERE TO_CHAR(sale_date,'MM-YYYY') = '12-2023';


-- Q.4 Determine how many stores have never had a warranty claim filed.
SELECT  COUNT(*) AS total_stores
FROM stores 
WHERE store_id NOT IN (
	SELECT DISTINCT s.store_id
	FROM sales s 
	RIGHT JOIN warranty w
	ON w.sale_id = s.sale_id)


-- Q.5. Calculate the percentage of warranty claims marked as "Warranty Void". 
-- no of wv claims / total claims * 100
SELECT 
      ROUND
            (count(*) / (SELECT COUNT(*) FROM warranty)::NUMERIC 
			*100,
			2) AS warranty_void_percentage
FROM warranty
WHERE repair_status='Warranty Void';


-- Q.6. Identify which store had the highest total units sold in the last year.
SELECT 
      s.store_id,
	  st.store_name,
	  SUM(s.quantity) AS total_units
FROM sales s           
JOIN stores as st
ON st.store_id = s.store_id
WHERE sale_date>= (CURRENT_DATE - INTERVAL '1 YEAR')
GROUP BY s.store_id,st.store_name
ORDER BY 3 DESC
LIMIT 1


-- Q.7. Count the number of unique products sold in the last year.
SELECT 
      COUNT(DISTINCT product_id) AS total_unique_roducts
FROM sales 
WHERE sale_date >= (CURRENT_DATE - INTERVAL '1 YEAR')



-- Q.8. Find the average price of products in each category.
SELECT category_id,
       AVG(price) AS Avg_price
FROM products
GROUP BY 1


-- Q.9. How many warranty claims were filed in 2020?
SELECT 
      COUNT(*) AS Total_claims
FROM warranty
WHERE EXTRACT (YEAR FROM claim_date)=2020;


-- Q.10. For each store, identify the best-selling day based on highest quantity sold.
WITH cte AS(
SELECT 
     store_id,
	 TO_CHAR(sale_date,'DAY') as day_name,
	 SUM(quantity) as Total_quantity_sold,
	 RANK()OVER(PARTITION BY store_id ORDER BY SUM(quantity) DESC) AS Rank
FROM sales 
GROUP BY 1,2
ORDER BY 1,3 DESC)

SELECT * FROM cte
WHERE rank=1


-- Q.11. Identify the least selling product in each country for each year based on total units sold.
WITH cte AS (
SELECT
      st.country,
	  p.product_name,
	  EXTRACT(YEAR FROM s.sale_date) as year,
	  SUM(s.quantity) AS total_qty_sold,
	  DENSE_RANK() OVER(PARTITION BY country,EXTRACT(YEAR FROM s.sale_date) ORDER BY SUM(s.quantity)) AS RANK
FROM sales AS s
JOIN
stores as st
ON s.store_id=st.store_id
JOIN
products as p
ON p.product_id=s.product_id
GROUP BY 1,2,3
ORDER BY 1,3,4
)

SELECT year,
       country,
	   product_name,
	   total_qty_sold 
FROM cte 
where rank=1


-- Q.12. Calculate how many warranty claims were filed within 180 days of a product sale.
SELECT 
      COUNT(*) AS total_warranty_claims
FROM warranty AS w
LEFT JOIN 
sales AS s 
ON s.sale_id=w.sale_id
WHERE (w.claim_date - s.sale_date) <= 180;


-- Q.13. Determine how many warranty claims were filed for products launched in the last two years.
SELECT 
      p.product_name,
	  COUNT(w.claim_id) as NO_Total_claims
FROM warranty AS w
JOIN
sales AS s
ON s.sale_id = w.sale_id
JOIN
products AS p
ON p.product_id = s.product_id
WHERE p.launch_date >= (CURRENT_DATE - INTERVAL '2 YEARS')
GROUP BY 1


-- Q.14. List the months in the last three years where sales exceeded 5,000 units in the USA.
SELECT 
      TO_CHAR(sale_date,'MM-YYYY') AS month,
	  SUM(s.quantity) AS total_units_sold
FROM sales AS s
JOIN
stores AS st
ON s.store_id = st.store_id
WHERE 
    st.country = 'USA'
	AND
	s.sale_date >= CURRENT_DATE - INTERVAL '3 YEAR'
GROUP BY 1
HAVING SUM(s.quantity)>= 5000;


-- Q.15. Identify the product category with the most warranty claims filed in the last two years.
SELECT 
      c.category_name,
	  COUNT(w.claim_id) AS total_claims
FROM warranty as w
JOIN sales AS s
ON s.sale_id = w.sale_id
JOIN products AS p
ON p.product_id = s.product_id
JOIN category AS c
ON c.category_id = p.category_id
WHERE 
     w.claim_date >= CURRENT_DATE - INTERVAL '2 YEAR'
GROUP BY 1
ORDER BY 2 DESC;



-- Q.16. Determine the percentage chance of receiving warranty claims after each purchase for each country.
SELECT
      country,
	  total_quantity_sold,
	  total_claim,
	  COALESCE(total_claim::NUMERIC/ total_quantity_sold::NUMERIC *100,0) AS risk
FROM 
(SELECT 
      st.country,
	  SUM(s.quantity) AS total_quantity_sold,
	  COUNT(w.claim_id) AS total_claim
FROM sales AS s
JOIN stores AS st
ON st.store_id = s.store_id
LEFT JOIN warranty AS w
ON w.sale_id = s.sale_id
GROUP BY 1) AS t1
ORDER BY 4 DESC;


-- Q.17. Analyze the year-by-year growth ratio for each store.
-- each store and their yearly sale 
WITH yearly_sales
AS
(
	SELECT 
		s.store_id,
		st.store_name,
		EXTRACT(YEAR FROM sale_date) as year,
		SUM(s.quantity * p.price) as total_sale
	FROM sales as s
	JOIN
	products as p
	ON s.product_id = p.product_id
	JOIN stores as st
	ON st.store_id = s.store_id
	GROUP BY 1, 2, 3
	ORDER BY 2, 3 
),
growth_ratio
AS
(
SELECT 
	store_name,
	year,
	LAG(total_sale, 1) OVER(PARTITION BY store_name ORDER BY year) as last_year_sale,
	total_sale as current_year_sale
FROM yearly_sales
)

SELECT 
	store_name,
	year,
	last_year_sale,
	current_year_sale,
	ROUND(
			(current_year_sale - last_year_sale)::numeric/
							last_year_sale::numeric * 100
	,3) as growth_ratio
FROM growth_ratio
WHERE 
	last_year_sale IS NOT NULL
	AND 
	YEAR <> EXTRACT(YEAR FROM CURRENT_DATE)



-- Q.18. Calculate the correlation between product price and warranty claims for products sold in the last five years,
-- segmented by price range.
SELECT 
      CASE 
	      WHEN p.price < 500 THEN 'Less Expensive Product'
		  WHEN p.price BETWEEN 500 AND 1000 THEN 'MID Range Product'
		  ELSE 'Expensive Product' 
	  END AS price_segment,
	  COUNT(w.claim_id) AS total_claims
FROM warranty AS w
JOIN
sales AS s 
ON w.sale_id=s.sale_id
JOIN
products AS p
ON p.product_id=s.product_id
WHERE w.claim_date >= CURRENT_DATE - INTERVAL ' 5 YEAR'
GROUP BY 1


-- Q.19. Identify the store with the highest percentage of "Paid Repaired" claims relative to total claims filed.
WITH paid_repair
AS
(SELECT 
	s.store_id,
	COUNT(w.claim_id) as paid_repaired
FROM sales as s
RIGHT JOIN warranty as w
ON w.sale_id = s.sale_id
WHERE w.repair_status = 'Paid Repaired'
GROUP BY 1
),

total_repaired
AS
(SELECT 
	s.store_id,
	COUNT(w.claim_id) as total_repaired
FROM sales as s
RIGHT JOIN warranty as w
ON w.sale_id = s.sale_id
GROUP BY 1)

SELECT 
	tr.store_id,
	st.store_name,
	pr.paid_repaired,
	tr.total_repaired,
	ROUND(pr.paid_repaired::numeric/
			tr.total_repaired::numeric * 100
		,2) as percentage_paid_repaired
FROM paid_repair as pr
JOIN 
total_repaired tr
ON pr.store_id = tr.store_id
JOIN stores as st
ON tr.store_id = st.store_id



-- Q.20. Write a query to calculate the monthly running total of sales for each store over the past four years 
--and compare trends during this period.
WITH monthly_sales
AS
(SELECT 
	store_id,
	EXTRACT(YEAR FROM sale_date) as year,
	EXTRACT(MONTH FROM sale_date) as month,
	SUM(p.price * s.quantity) as total_revenue
FROM sales as s
JOIN 
products as p
ON s.product_id = p.product_id
GROUP BY 1, 2, 3
ORDER BY 1, 2,3
)
SELECT 
	store_id,
	month,
	year,
	total_revenue,
	SUM(total_revenue) OVER(PARTITION BY store_id ORDER BY year, month) as running_total
FROM monthly_sales



-- Q.21. Analyze product sales trends over time, segmented into key periods: from launch to 6 months, 
--       6-12 months, 12-18 months, and beyond 18 months.
SELECT 
	p.product_name,
	CASE 
		WHEN s.sale_date BETWEEN p.launch_date AND p.launch_date + INTERVAL '6 month' THEN '0-6 month'
		WHEN s.sale_date BETWEEN  p.launch_date + INTERVAL '6 month'  AND p.launch_date + INTERVAL '12 month' THEN '6-12' 
		WHEN s.sale_date BETWEEN  p.launch_date + INTERVAL '12 month'  AND p.launch_date + INTERVAL '18 month' THEN '6-12'
		ELSE '18+'
	END as plc,
	SUM(s.quantity) as total_qty_sale
	
FROM sales as s
JOIN products as p
ON s.product_id = p.product_id
GROUP BY 1, 2
ORDER BY 1, 3 DESC




