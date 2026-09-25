-- количество звонков 280000
SELECT COUNT(DISTINCT call_id)
FROM call_segments;

-- количество сегментов 920673
SELECT COUNT(*)
FROM call_segments;
