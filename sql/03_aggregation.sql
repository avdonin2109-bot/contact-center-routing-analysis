/* ============================================================
1. Распределение многосегментных звонков по количеству переводов
Что показывает: сколько переводов было в звонке и какая доля многосегментных звонков приходится на каждый вариант.
   ============================================================ */
SELECT
    [Количество переводов] AS [Количество переводов],
    COUNT(*) AS [Количество звонков],
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS [Доля, %]
FROM routing_analysis
GROUP BY
    [Количество переводов]
ORDER BY
    [Количество переводов];

/* ============================================================
| Количество переводов | Количество звонков | Доля, % |
| :---: | :---: | :---: |
| 1 | 60 081 | 47,07 |
| 2 | 36 188 | 28,35 |
| 3 | 21 923 | 17,18 |
| 4 | 5 692 | 4,46 |
| 5 | 2 912 | 2,28 |
| 6 | 843 | 0,66 |
   ============================================================ */


/* ============================================================
2. Распределение по количеству операторских сегментов
Что показывает: сколько многосегментных звонков содержит 2, 3, 4 и т.д. операторских сегмента.
   ============================================================ */
SELECT
    [Количество переводов] + 1 AS [Операторских сегментов],
    COUNT(*) AS [Количество звонков],
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS [Доля, %]
FROM routing_analysis
GROUP BY
    [Количество переводов]
ORDER BY
    [Операторских сегментов];
/* ============================================================
| Операторских сегментов | Количество звонков | Доля, % |
| :---: | :---: | :---: |
| 2 | 60 081 | 47,07 |
| 3 | 36 188 | 28,35 |
| 4 | 21 923 | 17,18 |
| 5 | 5 692 | 4,46 |
| 6 | 2 912 | 2,28 |
| 7 | 843 | 0,66 |
   ============================================================ */


/* ============================================================
3. Среднее ожидание до финального Skill
Что показывает: Среднее время ожидания до финального Skill: среднее суммарное время ожидания на всех операторских сегментах до последнего Skill.
   ============================================================ */
SELECT
    ROUND(
        AVG([Ожидание до финального]),
        2
    ) AS [Среднее ожидание до финального, сек]
FROM routing_analysis;
/* ============================================================
| Среднее ожидание до финального, сек |
| :---: |
| 539,62 |
   ============================================================ */


/* ============================================================
4. Среднее время разговора до финального Skill
Что показывает: сколько времени в среднем клиент уже провёл в разговоре с операторами до попадания на финальный Skill.
это только talk_sec, без hold_sec и consult_sec
   ============================================================ */
SELECT
    ROUND(
        AVG([Разговор до финального]),
        2
    ) AS [Средний разговор до финального, сек]
FROM routing_analysis;
/* ============================================================
| Средний разговор до финального, сек |
| :---: |
| 3 053,19 |
   ============================================================ */


/* ============================================================
5. Среднее время мостов
Что показывает: среднее время, которое приходится на промежуточные неоператорские сегменты между операторскими сегментами.
   ============================================================ */
SELECT
    ROUND(
        AVG([Время мостов]),
        2
    ) AS [Среднее время мостов, сек]
FROM routing_analysis;
/* ============================================================
| Среднее время мостов, сек |
| :---: |
| 44 |
   ============================================================ */


/* ============================================================
6. Распределение по первому Skill
Что показывает: какие Skills чаще всего являются первым операторским звеном многосегментного звонка.
Он отвечает на вопрос: с какого Skill чаще всего начинается многосегментный звонок.
"то не все звонки, а только routing_analysis, то есть только многосегментные звонки.
   ============================================================ */
SELECT
    Skill1 AS [Первый Skill],
    COUNT(*) AS [Количество звонков],
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS [Доля, %]
FROM routing_analysis
WHERE Skill1 IS NOT NULL
GROUP BY
    Skill1
ORDER BY
    [Количество звонков] DESC;
/* ============================================================
| Первый Skill | Количество звонков | Доля, % |
| :---: | :---: | :---: |
| 118 | 5 138 | 4,03 |
| 141 | 4 322 | 3,39 |
| 130 | 4 311 | 3,38 |
| 125 | 4 301 | 3,37 |
| 124 | 4 279 | 3,35 |
| 115 | 4 269 | 3,34 |
| 114 | 4 248 | 3,33 |
| 106 | 3 275 | 2,57 |
| 150 | 3 269 | 2,56 |
| 145 | 3 262 | 2,56 |
| 121 | 3 249 | 2,55 |
| 142 | 3 235 | 2,53 |
| 111 | 3 217 | 2,52 |
| 117 | 3 204 | 2,51 |
| 123 | 3 190 | 2,5 |
| 135 | 3 171 | 2,48 |
| 103 | 3 168 | 2,48 |
| 136 | 3 166 | 2,48 |
| 126 | 3 150 | 2,47 |
| 107 | 3 138 | 2,46 |
| 157 | 3 138 | 2,46 |
| 105 | 3 137 | 2,46 |
| 154 | 3 134 | 2,46 |
| 146 | 2 219 | 1,74 |
| 156 | 2 213 | 1,73 |
| 138 | 2 158 | 1,69 |
| 144 | 2 148 | 1,68 |
| 152 | 2 147 | 1,68 |
| 143 | 2 143 | 1,68 |
| 139 | 2 139 | 1,68 |
| 119 | 2 135 | 1,67 |
| 147 | 2 115 | 1,66 |
| 137 | 2 094 | 1,64 |
| 155 | 2 094 | 1,64 |
| 110 | 2 093 | 1,64 |
| 116 | 2 076 | 1,63 |
| 128 | 2 074 | 1,62 |
| 148 | 2 064 | 1,62 |
| 122 | 2 063 | 1,62 |
| 159 | 2 041 | 1,6 |
| 113 | 1 114 | 0,87 |
| 153 | 1 108 | 0,87 |
| 104 | 1 098 | 0,86 |
| 109 | 1 080 | 0,85 |
| 108 | 1 071 | 0,84 |
| 140 | 1 061 | 0,83 |
| 158 | 1 057 | 0,83 |
| 132 | 1 038 | 0,81 |
| 149 | 1 025 | 0,8 |
   ============================================================ */


/* ============================================================
7. Распределение переходов Skill1 → Skill2
Что показывает: какие переходы между первым и вторым операторским Skill встречаются чаще всего.
   ============================================================ */
SELECT
    Skill1 AS [Skill1],
    Skill2 AS [Skill2],
    COUNT(*) AS [Количество переходов],
    ROUND(
        COUNT(*) * 100.0
        / SUM(COUNT(*)) OVER (),
        2
    ) AS [Доля, %]
FROM routing_analysis
WHERE
    Skill1 IS NOT NULL
    AND Skill2 IS NOT NULL
GROUP BY
    Skill1,
    Skill2
ORDER BY
    [Количество переходов] DESC;
/* ============================================================
| Skill1 | Skill2 | Количество переходов | Доля, % |
| :---: | :---: | :---: | :---: |
| 118 | 118 | 225 | 0,18 |
| 118 | 130 | 195 | 0,15 |
| 124 | 118 | 184 | 0,14 |
| 118 | 115 | 182 | 0,14 |
| 141 | 118 | 181 | 0,14 |
| 114 | 118 | 179 | 0,14 |
| 115 | 118 | 177 | 0,14 |
| 118 | 141 | 172 | 0,13 |
| 118 | 114 | 171 | 0,13 |
| 125 | 130 | 169 | 0,13 |
| 115 | 130 | 167 | 0,13 |
| 118 | 125 | 165 | 0,13 |
| 124 | 114 | 164 | 0,13 |
| 130 | 114 | 164 | 0,13 |
| 141 | 130 | 163 | 0,13 |
| 125 | 118 | 161 | 0,13 |
| 130 | 118 | 161 | 0,13 |
| 115 | 125 | 160 | 0,13 |
| 118 | 124 | 158 | 0,12 |
| 114 | 124 | 156 | 0,12 |
| 150 | 118 | 156 | 0,12 |
| 103 | 118 | 154 | 0,12 |
| 115 | 124 | 153 | 0,12 |
| 136 | 118 | 153 | 0,12 |
| 141 | 114 | 152 | 0,12 |
| 118 | 135 | 151 | 0,12 |
| 118 | 142 | 150 | 0,12 |
| 124 | 115 | 149 | 0,12 |
-- 
   ============================================================ */


/* ============================================================
8. Общая статистика многосегментных звонков
Что показывает: базовые KPI по результату 02.
   ============================================================ */
SELECT
    COUNT(*) AS [Многосегментные звонки],
    ROUND(
        AVG([Количество переводов]),
        2
    ) AS [Среднее количество переводов],
    ROUND(
        AVG([Ожидание до финального]),
        2
    ) AS [Среднее ожидание до финального, сек],
    ROUND(
        AVG([Разговор до финального]),
        2
    ) AS [Средний разговор до финального, сек],
    ROUND(
        AVG([Время мостов]),
        2
    ) AS [Среднее время мостов, сек]
FROM routing_analysis;
/* ============================================================
| Многосегментные звонки | Среднее количество переводов | Среднее ожидание до финального, сек | Средний разговор до финального, сек | Среднее время мостов, сек |
| :---: | :---: | :---: | :---: | :---: |
| 127 639 | 1,89 | 539,62 | 3 053,19 | 44 |
   ============================================================ */















/* ============================================================
 02_routing_analysis.sql
   ============================================================ */

WITH routing_analysis AS (WITH base AS
  (SELECT cr.call_id,
          cr.call_date,
          cr.event_at,
          cr.segment_no,
          cr.agent_login,
          cr.exit_skill,
          cr.total_wait_sec,
          cr.talk_sec,
          cr.hold_sec,
          cr.consult_sec,
          cr.caller_number,
          cr.dialed_number,
          cr.global_call_uid,
          cr.crm_payload,
          ROW_NUMBER() OVER (PARTITION BY cr.call_id
                             ORDER BY cr.event_at, cr.segment_no) AS rn
   FROM call_segments cr
   WHERE cr.call_date >= '2026-01-01'
     AND cr.call_date < '2026-09-01'),
     agents AS
  (SELECT b.call_id,
          b.rn,
          b.agent_login,
          CAST(b.exit_skill AS INTEGER) AS exit_skill,
          b.total_wait_sec,
          b.talk_sec,
          b.hold_sec,
          b.consult_sec,
          b.caller_number,
          b.call_date,
          b.event_at,
          b.global_call_uid,
          b.crm_payload,
          ROW_NUMBER() OVER (PARTITION BY b.call_id
                             ORDER BY b.rn) AS agent_rn
   FROM base b
   WHERE b.agent_login IS NOT NULL
     AND b.agent_login <> ''
     AND b.exit_skill IS NOT NULL
     AND b.exit_skill <> 0
     AND b.dialed_number <> '792501'
     AND (b.caller_number NOT LIKE 'T%'
          OR b.caller_number IS NULL)),
     last_skill AS
  (SELECT call_id,
          MAX(agent_rn) AS max_agent_rn,
          MAX(rn) AS max_rn
   FROM agents
   GROUP BY call_id),
     multi_skill AS
  (SELECT call_id,
          max_agent_rn,
          max_rn
   FROM last_skill
   WHERE max_agent_rn >= 2),
     CHAIN AS
  (SELECT a.call_id,
          a.rn,
          a.agent_login,
          a.exit_skill AS skill_display,
          a.total_wait_sec,
          a.talk_sec,
          a.hold_sec,
          a.consult_sec,
          a.caller_number,
          a.call_date,
          a.event_at,
          a.global_call_uid,
          a.crm_payload,
          a.agent_rn
   FROM agents a
   INNER JOIN multi_skill m ON a.call_id = m.call_id
   AND a.agent_rn <= m.max_agent_rn), all_with_bridge AS
  (SELECT b.call_id,
          b.rn,
          b.total_wait_sec,
          b.talk_sec,
          CASE
              WHEN a.agent_rn IS NOT NULL THEN 1
              ELSE 0
          END AS is_agent,
          m.max_rn
   FROM base b
   INNER JOIN multi_skill m ON b.call_id = m.call_id
   LEFT JOIN agents a ON b.call_id = a.call_id
   AND b.rn = a.rn
   WHERE b.rn <= m.max_rn),
                                      bridge_time AS
  (SELECT call_id,
          SUM(CASE
                  WHEN is_agent = 0 THEN COALESCE(total_wait_sec, 0) + COALESCE(talk_sec, 0)
                  ELSE 0
              END) AS bridge_total
   FROM all_with_bridge
   GROUP BY call_id),
                                      client_num AS
  (SELECT call_id,
          CASE
              WHEN LENGTH(TRIM(caller_number)) > 10
                   AND (SUBSTR(TRIM(caller_number), 1, 1) = '7'
                        OR SUBSTR(TRIM(caller_number), 1, 1) = '8') THEN SUBSTR(TRIM(caller_number), 2)
              ELSE TRIM(caller_number)
          END AS client_number
   FROM base),
                                      asai_data AS
  (SELECT call_id,
          MAX(crm_payload) AS asai_value
   FROM base
   GROUP BY call_id)
SELECT /* Основная информация */ DATE(MAX(c.call_date)) AS [Дата],
                                 strftime('%Y-%m-%d %H:%M', MAX(c.event_at)) AS [Дата-время],
                                 c.call_id AS [CallID],
                                 MAX(c.global_call_uid) AS [UCID],
                                 MAX(cl.client_number) AS [Номер клиента],
                                 MAX(ad.asai_value) AS [ASAI_UUI], /* Навыки */ CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 1 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill1],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 2 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill2],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 3 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill3],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 4 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill4],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 5 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill5],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 6 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill6],
                                                                                CAST(MAX(CASE
                                                                                             WHEN c.agent_rn = 7 THEN c.skill_display
                                                                                         END) AS INTEGER) AS [Skill7], /* Skill 1 */ MAX(CASE
                                                                                                                                             WHEN c.agent_rn = 1 THEN c.total_wait_sec
                                                                                                                                             ELSE 0
                                                                                                                                         END) AS [Skill1_Ожидание],
                                                                                                                                     MAX(CASE
                                                                                                                                             WHEN c.agent_rn = 1 THEN c.talk_sec
                                                                                                                                             ELSE 0
                                                                                                                                         END) AS [Skill1_Разговор],
                                                                                                                                     MAX(CASE
                                                                                                                                             WHEN c.agent_rn = 1 THEN c.hold_sec
                                                                                                                                             ELSE 0
                                                                                                                                         END) AS [Skill1_Удержание],
                                                                                                                                     MAX(CASE
                                                                                                                                             WHEN c.agent_rn = 1 THEN c.consult_sec
                                                                                                                                             ELSE 0
                                                                                                                                         END) AS [Skill1_Консультация], /* Skill 2 */ MAX(CASE
                                                                                                                                                                                              WHEN c.agent_rn = 2 THEN c.total_wait_sec
                                                                                                                                                                                              ELSE 0
                                                                                                                                                                                          END) AS [Skill2_Ожидание],
                                                                                                                                                                                      MAX(CASE
                                                                                                                                                                                              WHEN c.agent_rn = 2 THEN c.talk_sec
                                                                                                                                                                                              ELSE 0
                                                                                                                                                                                          END) AS [Skill2_Разговор],
                                                                                                                                                                                      MAX(CASE
                                                                                                                                                                                              WHEN c.agent_rn = 2 THEN c.hold_sec
                                                                                                                                                                                              ELSE 0
                                                                                                                                                                                          END) AS [Skill2_Удержание],
                                                                                                                                                                                      MAX(CASE
                                                                                                                                                                                              WHEN c.agent_rn = 2 THEN c.consult_sec
                                                                                                                                                                                              ELSE 0
                                                                                                                                                                                          END) AS [Skill2_Консультация], /* Skill 3 */ MAX(CASE
                                                                                                                                                                                                                                               WHEN c.agent_rn = 3 THEN c.total_wait_sec
                                                                                                                                                                                                                                               ELSE 0
                                                                                                                                                                                                                                           END) AS [Skill3_Ожидание],
                                                                                                                                                                                                                                       MAX(CASE
                                                                                                                                                                                                                                               WHEN c.agent_rn = 3 THEN c.talk_sec
                                                                                                                                                                                                                                               ELSE 0
                                                                                                                                                                                                                                           END) AS [Skill3_Разговор],
                                                                                                                                                                                                                                       MAX(CASE
                                                                                                                                                                                                                                               WHEN c.agent_rn = 3 THEN c.hold_sec
                                                                                                                                                                                                                                               ELSE 0
                                                                                                                                                                                                                                           END) AS [Skill3_Удержание],
                                                                                                                                                                                                                                       MAX(CASE
                                                                                                                                                                                                                                               WHEN c.agent_rn = 3 THEN c.consult_sec
                                                                                                                                                                                                                                               ELSE 0
                                                                                                                                                                                                                                           END) AS [Skill3_Консультация], /* Skill 4 */ MAX(CASE
                                                                                                                                                                                                                                                                                                WHEN c.agent_rn = 4 THEN c.total_wait_sec
                                                                                                                                                                                                                                                                                                ELSE 0
                                                                                                                                                                                                                                                                                            END) AS [Skill4_Ожидание],
                                                                                                                                                                                                                                                                                        MAX(CASE
                                                                                                                                                                                                                                                                                                WHEN c.agent_rn = 4 THEN c.talk_sec
                                                                                                                                                                                                                                                                                                ELSE 0
                                                                                                                                                                                                                                                                                            END) AS [Skill4_Разговор],
                                                                                                                                                                                                                                                                                        MAX(CASE
                                                                                                                                                                                                                                                                                                WHEN c.agent_rn = 4 THEN c.hold_sec
                                                                                                                                                                                                                                                                                                ELSE 0
                                                                                                                                                                                                                                                                                            END) AS [Skill4_Удержание],
                                                                                                                                                                                                                                                                                        MAX(CASE
                                                                                                                                                                                                                                                                                                WHEN c.agent_rn = 4 THEN c.consult_sec
                                                                                                                                                                                                                                                                                                ELSE 0
                                                                                                                                                                                                                                                                                            END) AS [Skill4_Консультация], /* Skill 5 */ MAX(CASE
                                                                                                                                                                                                                                                                                                                                                 WHEN c.agent_rn = 5 THEN c.total_wait_sec
                                                                                                                                                                                                                                                                                                                                                 ELSE 0
                                                                                                                                                                                                                                                                                                                                             END) AS [Skill5_Ожидание],
                                                                                                                                                                                                                                                                                                                                         MAX(CASE
                                                                                                                                                                                                                                                                                                                                                 WHEN c.agent_rn = 5 THEN c.talk_sec
                                                                                                                                                                                                                                                                                                                                                 ELSE 0
                                                                                                                                                                                                                                                                                                                                             END) AS [Skill5_Разговор],
                                                                                                                                                                                                                                                                                                                                         MAX(CASE
                                                                                                                                                                                                                                                                                                                                                 WHEN c.agent_rn = 5 THEN c.hold_sec
                                                                                                                                                                                                                                                                                                                                                 ELSE 0
                                                                                                                                                                                                                                                                                                                                             END) AS [Skill5_Удержание],
                                                                                                                                                                                                                                                                                                                                         MAX(CASE
                                                                                                                                                                                                                                                                                                                                                 WHEN c.agent_rn = 5 THEN c.consult_sec
                                                                                                                                                                                                                                                                                                                                                 ELSE 0
                                                                                                                                                                                                                                                                                                                                             END) AS [Skill5_Консультация], /* Skill 6 */ MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                  WHEN c.agent_rn = 6 THEN c.total_wait_sec
                                                                                                                                                                                                                                                                                                                                                                                                  ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                              END) AS [Skill6_Ожидание],
                                                                                                                                                                                                                                                                                                                                                                                          MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                  WHEN c.agent_rn = 6 THEN c.talk_sec
                                                                                                                                                                                                                                                                                                                                                                                                  ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                              END) AS [Skill6_Разговор],
                                                                                                                                                                                                                                                                                                                                                                                          MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                  WHEN c.agent_rn = 6 THEN c.hold_sec
                                                                                                                                                                                                                                                                                                                                                                                                  ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                              END) AS [Skill6_Удержание],
                                                                                                                                                                                                                                                                                                                                                                                          MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                  WHEN c.agent_rn = 6 THEN c.consult_sec
                                                                                                                                                                                                                                                                                                                                                                                                  ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                              END) AS [Skill6_Консультация], /* Skill 7 */ MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN c.agent_rn = 7 THEN c.total_wait_sec
                                                                                                                                                                                                                                                                                                                                                                                                                                                   ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                               END) AS [Skill7_Ожидание],
                                                                                                                                                                                                                                                                                                                                                                                                                                           MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN c.agent_rn = 7 THEN c.talk_sec
                                                                                                                                                                                                                                                                                                                                                                                                                                                   ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                               END) AS [Skill7_Разговор],
                                                                                                                                                                                                                                                                                                                                                                                                                                           MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN c.agent_rn = 7 THEN c.hold_sec
                                                                                                                                                                                                                                                                                                                                                                                                                                                   ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                               END) AS [Skill7_Удержание],
                                                                                                                                                                                                                                                                                                                                                                                                                                           MAX(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                   WHEN c.agent_rn = 7 THEN c.consult_sec
                                                                                                                                                                                                                                                                                                                                                                                                                                                   ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                               END) AS [Skill7_Консультация], /* Мосты */ MAX(bt.bridge_total) AS [Время мостов], /* Количество переводов Количество операторских сегментов - 1 */ m.max_agent_rn - 1 AS [Количество переводов], /* Время до финального навыка */ SUM(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          WHEN c.agent_rn < m.max_agent_rn THEN COALESCE(c.total_wait_sec, 0)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      END) AS [Ожидание до финального],
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                  SUM(CASE
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          WHEN c.agent_rn < m.max_agent_rn THEN COALESCE(c.talk_sec, 0)
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                          ELSE 0
                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                                      END) AS [Разговор до финального]
FROM CHAIN c
INNER JOIN multi_skill m ON c.call_id = m.call_id
LEFT JOIN client_num cl ON c.call_id = cl.call_id
LEFT JOIN asai_data ad ON c.call_id = ad.call_id
LEFT JOIN bridge_time bt ON c.call_id = bt.call_id
GROUP BY c.call_id,
         m.max_agent_rn
ORDER BY [Дата],
         c.call_id)
