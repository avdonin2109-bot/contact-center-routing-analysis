/* ============================================================
   01_data_quality.sql
   Контроль качества исходных данных call_segments
   ============================================================ */


/* ------------------------------------------------------------
   1. Общая статистика данных
   Количество строк, звонков и период
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS [Количество сегментов],
    COUNT(DISTINCT call_id) AS [Количество звонков],
    MIN(call_date) AS [Минимальная дата],
    MAX(call_date) AS [Максимальная дата]
FROM call_segments;


/* ------------------------------------------------------------
   2. Распределение звонков по количеству сегментов
   Показывает структуру звонков от 1 до 8 сегментов.
   ------------------------------------------------------------ */

WITH seg_counts AS (
    SELECT
        call_id,
        COUNT(*) AS seg_cnt
    FROM call_segments
    GROUP BY call_id
),
total_calls AS (
    SELECT
        COUNT(*) AS total_cnt
    FROM seg_counts
),
dist AS (
    SELECT
        CASE
            WHEN seg_cnt > 8 THEN '9+'
            ELSE CAST(seg_cnt AS TEXT)
        END AS seg_group,
        CASE
            WHEN seg_cnt > 8 THEN 99
            ELSE seg_cnt
        END AS sort_key,
        COUNT(*) AS call_cnt
    FROM seg_counts
    GROUP BY
        CASE
            WHEN seg_cnt > 8 THEN '9+'
            ELSE CAST(seg_cnt AS TEXT)
        END,
        CASE
            WHEN seg_cnt > 8 THEN 99
            ELSE seg_cnt
        END
)
SELECT
    d.seg_group AS [Сегментов],
    d.call_cnt AS [Звонков],
    ROUND(
        d.call_cnt * 100.0 / t.total_cnt,
        2
    ) AS [Доля, %]
FROM dist d
CROSS JOIN total_calls t
ORDER BY
    d.sort_key;


/* ------------------------------------------------------------
   3. Дубли call_id + segment_no
   Проверяем, нет ли двух строк с одинаковым номером
   сегмента внутри одного звонка.
   ------------------------------------------------------------ */

SELECT
    call_id,
    segment_no,
    COUNT(*) AS [Количество строк]
FROM call_segments
GROUP BY
    call_id,
    segment_no
HAVING COUNT(*) > 1
ORDER BY
    call_id,
    segment_no;


/* ------------------------------------------------------------
   4. Пропуски ключевых идентификаторов
   Проверяем call_id и global_call_uid.
   ------------------------------------------------------------ */

SELECT
    SUM(
        CASE
            WHEN call_id IS NULL OR TRIM(call_id) = ''
            THEN 1
            ELSE 0
        END
    ) AS [Пустой CallID],
    SUM(
        CASE
            WHEN global_call_uid IS NULL
                 OR TRIM(global_call_uid) = ''
            THEN 1
            ELSE 0
        END
    ) AS [Пустой UCID]
FROM call_segments;


/* ------------------------------------------------------------
   5. Некорректные значения времени
   Проверяем отрицательные значения.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS [Некорректных строк]
FROM call_segments
WHERE
       COALESCE(total_wait_sec, 0) < 0
    OR COALESCE(talk_sec, 0) < 0
    OR COALESCE(hold_sec, 0) < 0
    OR COALESCE(consult_sec, 0) < 0;


/* ------------------------------------------------------------
   6. Проверка операторских сегментов
   Смотрим количество строк с оператором и Skill.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS [Всего сегментов],
    SUM(
        CASE
            WHEN agent_login IS NOT NULL
                 AND TRIM(agent_login) <> ''
            THEN 1
            ELSE 0
        END
    ) AS [С оператором],
    SUM(
        CASE
            WHEN exit_skill IS NOT NULL
                 AND exit_skill <> 0
            THEN 1
            ELSE 0
        END
    ) AS [С Skill],
    SUM(
        CASE
            WHEN agent_login IS NOT NULL
                 AND TRIM(agent_login) <> ''
                 AND exit_skill IS NOT NULL
                 AND exit_skill <> 0
            THEN 1
            ELSE 0
        END
    ) AS [Операторские сегменты]
FROM call_segments;


/* ------------------------------------------------------------
   7. Проверка количества операторских сегментов
   Позволяет убедиться, что максимальная цепочка
   действительно содержит не более 7 операторских сегментов.
   ------------------------------------------------------------ */

WITH agent_counts AS (
    SELECT
        call_id,
        COUNT(*) AS agent_segments
    FROM call_segments
    WHERE
        agent_login IS NOT NULL
        AND TRIM(agent_login) <> ''
        AND exit_skill IS NOT NULL
        AND exit_skill <> 0
    GROUP BY
        call_id
)
SELECT
    agent_segments AS [Операторских сегментов],
    COUNT(*) AS [Звонков]
FROM agent_counts
GROUP BY
    agent_segments
ORDER BY
    agent_segments;


/* ------------------------------------------------------------
   8. Проверка количества строк без Skill
   Среди строк с оператором.
   ------------------------------------------------------------ */

SELECT
    COUNT(*) AS [Оператор без Skill]
FROM call_segments
WHERE
    agent_login IS NOT NULL
    AND TRIM(agent_login) <> ''
    AND (
        exit_skill IS NULL
        OR exit_skill = 0
    );
