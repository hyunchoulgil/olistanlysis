# Weekday vs Weekend Payment Ratio

SELECT 
    kpi1.day_end,
    CONCAT(
        ROUND(
            kpi1.total_payment / (
                SELECT SUM(payment_value) 
                FROM order_payments
            ) * 100, 
            2
        ),
        '%'
    ) AS percentage_payment_values
FROM (
    SELECT 
        ord.day_end,
        SUM(pmt.payment_value) AS total_payment
    FROM order_payments AS pmt
    JOIN (
        SELECT DISTINCT 
            order_id,
            CASE 
                WHEN WEEKDAY(order_purchase_timestamp) IN (5, 6) THEN 'Weekend'
                ELSE 'Weekday'
            END AS day_end
        FROM orders
    ) AS ord
        ON ord.order_id = pmt.order_id
    GROUP BY ord.day_end
) AS kpi1;


# Credit Card Usage among 5-Star Reviews

SELECT 
    COUNT(pmt.order_id) AS total_orders
FROM order_payments pmt
JOIN order_reviews rev 
    ON pmt.order_id = rev.order_id
WHERE 
    rev.review_score = 5
    AND pmt.payment_type = 'credit_card';


# Average Delivery Days for Pet Shop

SELECT 
    prod.product_category_name,
    ROUND(
        AVG(
            DATEDIFF(
                ord.order_delivered_customer_date,
                ord.order_purchase_timestamp
            )
        ), 
        0
    ) AS avg_delivery_days
FROM orders ord
JOIN (
    SELECT 
        product_id, 
        order_id, 
        product_category_name
    FROM products
    JOIN orders_items USING(product_id)
) AS prod
    ON ord.order_id = prod.order_id
WHERE prod.product_category_name = 'Pet_shop'
GROUP BY prod.product_category_name;


# Avg Order Item Price vs Payment (Sao Paulo)

WITH order_items_avg AS (
    SELECT 
        ROUND(AVG(item.price)) AS avg_order_item_price
    FROM orders_items item
    JOIN orders ord 
        ON item.order_id = ord.order_id
    JOIN customers cust 
        ON ord.customer_id = cust.customer_id
    WHERE cust.customer_city = 'Sao Paulo'
)

SELECT 
    (
        SELECT avg_order_item_price 
        FROM order_items_avg
    ) AS avg_order_item_price,
    ROUND(AVG(pmt.payment_value)) AS avg_payment_value
FROM order_payments pmt
JOIN orders ord 
    ON pmt.order_id = ord.order_id
JOIN customers cust 
    ON ord.customer_id = cust.customer_id
WHERE cust.customer_city = 'Sao Paulo';


# Relationship: Shipping Days vs Review Score

SELECT 
    rew.review_score,
    ROUND(
        AVG(
            DATEDIFF(
                ord.order_delivered_customer_date,
                ord.order_purchase_timestamp
            )
        ),
        0
    ) AS avg_shipping_days
FROM orders ord
JOIN order_reviews rew 
    ON rew.order_id = ord.order_id
GROUP BY rew.review_score
ORDER BY rew.review_score;


# Installment Behavior (Before / BF / After)

SELECT
    period,
    COUNT(*) AS orders,
    ROUND(AVG(payment_installments), 2) AS avg_installments,
    ROUND(
        SUM(
            CASE 
                WHEN payment_installments > 1 THEN 1 
                ELSE 0 
            END
        ) / COUNT(*) * 100, 
        2
    ) AS installment_rate
FROM (
    SELECT
        o.order_id,
        CASE
            WHEN DATE(o.order_purchase_timestamp) BETWEEN '2017-11-10' AND '2017-11-23' THEN 'Before'
            WHEN DATE(o.order_purchase_timestamp) = '2017-11-24' THEN 'Black Friday'
            WHEN DATE(o.order_purchase_timestamp) BETWEEN '2017-11-25' AND '2017-12-08' THEN 'After'
        END AS period,
        op.payment_installments
    FROM orders o
    JOIN order_payments op 
        ON o.order_id = op.order_id
    WHERE 
        o.order_status = 'delivered'
        AND DATE(o.order_purchase_timestamp) BETWEEN '2017-11-10' AND '2017-12-08'
) t
GROUP BY period;


# Delay Rate Around Black Friday

SELECT
    period,
    ROUND(AVG(is_delayed) * 100, 2) AS delay_rate
FROM (
    SELECT
        CASE
            WHEN DATE(order_purchase_timestamp) BETWEEN '2017-11-10' AND '2017-11-23' THEN 'Before'
            WHEN DATE(order_purchase_timestamp) = '2017-11-24' THEN 'Black Friday'
            WHEN DATE(order_purchase_timestamp) BETWEEN '2017-11-25' AND '2017-12-08' THEN 'After'
        END AS period,
        is_delayed
    FROM delivery_review_dm
    WHERE DATE(order_purchase_timestamp) BETWEEN '2017-11-10' AND '2017-12-08'
) t
GROUP BY period;


# Daily Order Count

SELECT
    DATE(order_purchase_timestamp) AS order_date,
    COUNT(*) AS daily_orders
FROM orders
WHERE 
    order_status = 'delivered'
    AND order_purchase_timestamp IS NOT NULL
GROUP BY order_date
ORDER BY order_date;


# Category-wise Sales (Black Friday)

SELECT 
    p.product_category_name AS category,
    COUNT(*) AS items_sold
FROM orders o
JOIN orders_items oi 
    ON o.order_id = oi.order_id
JOIN products p 
    ON oi.product_id = p.product_id
WHERE 
    o.order_status = 'delivered'
    AND DATE(o.order_purchase_timestamp) = '2017-11-24'
GROUP BY p.product_category_name
ORDER BY items_sold DESC;


# Avg Order Value by Category (Black Friday)

SELECT
    category,
    AVG(order_value) AS avg_order_value
FROM (
    SELECT
        o.order_id,
        p.product_category_name AS category,
        SUM(oi.price + oi.freight_value) AS order_value
    FROM orders o
    JOIN orders_items oi 
        ON o.order_id = oi.order_id
    JOIN products p 
        ON oi.product_id = p.product_id
    WHERE 
        o.order_status = 'delivered'
        AND DATE(o.order_purchase_timestamp) = '2017-11-24'
    GROUP BY 
        o.order_id, 
        p.product_category_name
) t
GROUP BY category
ORDER BY avg_order_value DESC;


# Weekly Payment per Capita by State

SELECT
    YEARWEEK(o.order_purchase_timestamp, 1) AS year_week,
    c.customer_state,
    SUM(op.payment_value) AS total_payments,
    COUNT(DISTINCT o.customer_id) AS customers,
    ROUND(
        SUM(op.payment_value) / COUNT(DISTINCT o.customer_id), 
        2
    ) AS avg_payment_per_capita
FROM orders o
JOIN order_payments op 
    ON o.order_id = op.order_id
JOIN customers c 
    ON o.customer_id = c.customer_id
WHERE o.order_status = 'delivered'
GROUP BY 
    year_week, 
    c.customer_state
ORDER BY 
    year_week, 
    c.customer_state;


# Review Score by Product Category

SELECT
    COALESCE(
        t.product_category_name_english,
        p.product_category_name
    ) AS category,
    COUNT(*) AS review_cnt,
    ROUND(AVG(r.review_score), 3) AS avg_review_score
FROM order_reviews r
JOIN orders_items oi 
    ON r.order_id = oi.order_id
JOIN products p 
    ON oi.product_id = p.product_id
LEFT JOIN product_category_name_translation t 
    ON p.product_category_name = t.product_category_name
WHERE r.review_score IS NOT NULL
GROUP BY category
ORDER BY avg_review_score DESC;


# Customer RFM + Behavior Metrics

WITH pay AS (
    SELECT
        order_id,
        SUM(payment_value) AS order_payment
    FROM order_payments
    GROUP BY order_id
),

delivery AS (
    SELECT
        order_id,
        order_delivered_customer_date,
        order_estimated_delivery_date,
        DATEDIFF(
            order_delivered_customer_date,
            order_purchase_timestamp
        ) AS delivery_days
    FROM orders
    WHERE order_status = 'delivered'
),

base AS (
    SELECT
        c.customer_unique_id,
        o.order_id,
        o.order_purchase_timestamp,
        pay.order_payment,
        d.delivery_days,
        d.order_delivered_customer_date,
        d.order_estimated_delivery_date,
        r.review_score
    FROM orders o
    JOIN customers c 
        ON o.customer_id = c.customer_id
    JOIN pay 
        ON o.order_id = pay.order_id
    JOIN delivery d 
        ON o.order_id = d.order_id
    LEFT JOIN order_reviews r 
        ON o.order_id = r.order_id
    WHERE o.order_status = 'delivered'
),

snapshot AS (
    SELECT 
        MAX(order_purchase_timestamp) AS snap_dt
    FROM orders
    WHERE order_status = 'delivered'
)

SELECT
    b.customer_unique_id,

    -- RFM
    DATEDIFF(MAX(s.snap_dt), MAX(b.order_purchase_timestamp)) AS recency,
    COUNT(DISTINCT b.order_id) AS frequency,
    SUM(b.order_payment) AS monetary,

    -- Delivery & Review
    AVG(b.delivery_days) AS avg_delivery_days,
    AVG(b.review_score) AS avg_review,

    -- Delay Rate
    AVG(
        CASE
            WHEN b.order_delivered_customer_date > b.order_estimated_delivery_date THEN 1
            ELSE 0
        END
    ) AS delay_rate

FROM base b
CROSS JOIN snapshot s
GROUP BY b.customer_unique_id;