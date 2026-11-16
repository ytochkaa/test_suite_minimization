SELECT x, y, expected_accept,
       ((x > 0 AND y > 0) IS NOT FALSE) AS actual_accept
FROM (VALUES
    (NULL::integer, -1, FALSE),
    (NULL::integer,  1, TRUE),
    (-1, NULL::integer, FALSE),
    (1, NULL::integer, TRUE),
    (NULL::integer, NULL::integer, TRUE),
    (1, 1, TRUE),
    (-1, 1, FALSE)
) AS cases(x, y, expected_accept);
