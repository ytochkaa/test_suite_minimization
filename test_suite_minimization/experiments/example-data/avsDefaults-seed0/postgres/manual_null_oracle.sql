-- CHECK admits UNKNOWN; NOT NULL is verified separately by the table inserts.
SELECT quantity_of_goods, stock_capacity, expected_accept,
       (
           quantity_of_goods >= 0
           AND stock_capacity > 0
           AND quantity_of_goods <= stock_capacity
       ) IS NOT FALSE AS actual_accept
FROM (VALUES
    (NULL::integer, NULL::integer, TRUE),
    (NULL::integer, 1, TRUE),
    (1, NULL::integer, TRUE),
    (-1, NULL::integer, FALSE),
    (NULL::integer, -1, FALSE),
    (-1, 1, FALSE),
    (0, 1, TRUE),
    (1, 1, TRUE),
    (2, 1, FALSE),
    (1, 0, FALSE)
) AS cases(quantity_of_goods, stock_capacity, expected_accept);
