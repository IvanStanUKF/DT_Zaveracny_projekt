/* Graf 1: Počet transakcií na US štát (top 8) */

SELECT 
    state AS state,
    COUNT(state) AS total_transactions_by_state
FROM fact_transaction
GROUP BY state
ORDER BY total_transactions_by_state DESC
LIMIT 8;


/* Graf 2: Počet transakcií podľa hodiny dňa */

SELECT
    t.hour AS hour,
    COUNT(f.fact_transactionId) AS total_transactions_by_hour
FROM fact_transaction f
INNER JOIN dim_time t ON f.timeId = t.dim_timeId
GROUP BY t.hour
ORDER BY t.hour ASC;


/* Graf 3: Počet a celková suma transakcií podľa dňa v týždni */

SELECT
    d.weekday_name AS weekday,
    SUM(f.transaction_amount) AS total_spend_by_weekday,
    COUNT(f.fact_transactionId) AS total_transactions_by_weekday
FROM fact_transaction f
INNER JOIN dim_date d ON f.dateId = d.dim_dateId
GROUP BY d.weekday_name, d.weekday
ORDER BY d.weekday ASC;


/* Graf 4: Priemerná tržba na 1 prevádzku podľa kategórie3 (počet prevádzok > 1000) */

SELECT
    m.category3,
    COUNT(DISTINCT m.store_id) AS total_stores,
    SUM(f.transaction_amount) AS total_transaction_amount,
    total_transaction_amount / total_stores AS average_store_transaction_amount_by_category3
FROM fact_transaction f
INNER JOIN dim_merchant m ON f.merchantId = m.dim_merchantId
GROUP BY m.category3
HAVING total_stores > 1000
ORDER BY total_stores ASC;


/* Graf 5: Popularita podľa generácií držiteľov kariet */

SELECT
    c.cardholder_generation AS generation,
    COUNT(f.fact_transactionId) AS total_transactions_by_generation
FROM fact_transaction f
INNER JOIN dim_card c ON f.cardId = c.dim_cardId
GROUP BY c.cardholder_generation
ORDER BY total_transactions_by_generation DESC;


/* Graf 6: Priemerná výška transakcie podľa kategórie1 */

SELECT
    m.category1,
    AVG(f.transaction_amount) AS avg_transaction_amount_by_category1
FROM fact_transaction f
JOIN dim_merchant m ON f.merchantId = m.dim_merchantId
GROUP BY m.category1
ORDER BY avg_transaction_amount_by_category1 DESC;
