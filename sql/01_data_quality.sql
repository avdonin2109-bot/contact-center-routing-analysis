-- количество звонков 280000
SELECT COUNT(DISTINCT call_id)
FROM call_segments;

-- количество сегментов 920673
SELECT COUNT(*)
FROM call_segments;


SELECT
    segment_count,
    COUNT(*) AS calls,
    ROUND(
        COUNT(*) * 100.0 / SUM(COUNT(*)) OVER (),
        2
    ) AS share_percent
FROM (
    SELECT
        call_id,
        COUNT(*) AS segment_count
    FROM call_segments
    GROUP BY call_id
)
GROUP BY segment_count
ORDER BY segment_count;

| segment_count | calls | share_percent |
|---|---|---|
| 1 | 11 355 | 4,06 |
| 2 | 83 998 | 30 |
| 3 | 83 932 | 29,98 |
| 4 | 42 122 | 15,04 |
| 5 | 41 729 | 14,9 |
| 6 | 8 452 | 3,02 |
| 7 | 5 615 | 2,01 |
| 8 | 2 797 | 1 |
