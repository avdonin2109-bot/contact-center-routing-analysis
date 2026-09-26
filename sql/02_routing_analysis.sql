/* ============================================================
   Назначение:
   Анализ многосегментных звонков на уровне одного call_id.

   На выходе:
   одна строка = один многосегментный звонок.

   Рассчитываем:
   - последовательность навыков Skill1 ... Skill8
   - ожидание / разговор / удержание / консультацию
     по каждому навыку
   - время мостов между сегментами
   - количество переводов
   - ожидание до финального навыка
   - разговор до финального навыка
   - номер клиента
   - синтетический UCID и CRM payload

   Важно:
   - данные полностью синтетические
   - звено Skill9 не используется
   - повторное построение цепочек после этого запроса не требуется
   ============================================================ */ WITH base AS
  (/* --------------------------------------------------------
       1. Базовый набор данных

       Добавляем порядковый номер сегмента внутри звонка.
       rn показывает фактическую последовательность сегментов.
       -------------------------------------------------------- */  SELECT cr.call_id,
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
  (/* --------------------------------------------------------
       2. Выделяем сегменты, относящиеся к оператору.

       agent_rn показывает порядковый номер навыка
       в цепочке операторских сегментов:

       1 = первый навык
       2 = второй навык
       ...
       8 = восьмой навык
       -------------------------------------------------------- */  SELECT b.call_id,
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
     AND b.exit_skill <> 0 /* Сохраняем исходное условие фильтра */
     AND b.dialed_number <> '792501' /* Исключаем синтетические номера транков */
     AND (b.caller_number NOT LIKE 'T%'
          OR b.caller_number IS NULL)),
                                                                        last_skill AS
  (/* --------------------------------------------------------
       3. Определяем последний операторский сегмент
       для каждого звонка.

       max_agent_rn = номер последнего навыка
       max_rn       = последний сегмент звонка,
                      который учитывается в расчете
       -------------------------------------------------------- */  SELECT call_id,
                                                                           MAX(agent_rn) AS max_agent_rn,
                                                                           MAX(rn) AS max_rn
   FROM agents
   GROUP BY call_id),
                                                                        multi_skill AS
  (/* --------------------------------------------------------
       4. Оставляем только многосегментные звонки.

       Если max_agent_rn >= 2,
       значит в звонке было минимум два
       операторских навыка.
       -------------------------------------------------------- */  SELECT call_id,
                                                                           max_agent_rn,
                                                                           max_rn
   FROM last_skill
   WHERE max_agent_rn >= 2),
                                                                        CHAIN AS
  (/* --------------------------------------------------------
       5. Формируем цепочку операторских сегментов.

       Здесь уже определена последовательность навыков
       конкретного звонка.

       В дальнейших расчетах повторно строить цепочку
       не требуется.
       -------------------------------------------------------- */  SELECT a.call_id,
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
  (/* --------------------------------------------------------
       6. Подготовка расчета времени мостов.

       Для каждого сегмента определяем:

       is_agent = 1  -> операторский сегмент
       is_agent = 0  -> промежуточный сегмент

       Время промежуточных сегментов далее используется
       для расчета "Время мостов".
       -------------------------------------------------------- */  SELECT b.call_id,
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
  (/* --------------------------------------------------------
       7. Считаем время промежуточных сегментов.

       Для неоператорских сегментов складываем:

       ожидание + разговор

       Получаем итоговое время мостов по звонку.
       -------------------------------------------------------- */  SELECT call_id,
                                                                           SUM(CASE
                                                                                   WHEN is_agent = 0 THEN COALESCE(total_wait_sec, 0) + COALESCE(talk_sec, 0)
                                                                                   ELSE 0
                                                                               END) AS bridge_total
   FROM all_with_bridge
   GROUP BY call_id),
                                      client_num AS
  (/* --------------------------------------------------------
       8. Нормализация номера клиента.

       Если номер начинается с 7 или 8
       и содержит более 10 символов,
       убираем первый символ.

       Пример:

       79251234567 -> 9251234567
       89251234567 -> 9251234567
       -------------------------------------------------------- */  SELECT call_id,
                                                                           CASE
                                                                               WHEN LENGTH(TRIM(caller_number)) > 10
                                                                                    AND (SUBSTR(TRIM(caller_number), 1, 1) = '7'
                                                                                         OR SUBSTR(TRIM(caller_number), 1, 1) = '8') THEN SUBSTR(TRIM(caller_number), 2)
                                                                               ELSE TRIM(caller_number)
                                                                           END AS client_number
   FROM base),
                                      asai_data AS
  (/* --------------------------------------------------------
       9. Получаем CRM payload для звонка.

       В синтетическом проекте это аналог дополнительного
       идентификатора/полезной нагрузки звонка.

       Реальных ASAI-данных здесь нет.
       -------------------------------------------------------- */  SELECT call_id,
                                                                           MAX(crm_payload) AS asai_value
   FROM base
   GROUP BY call_id) /* ============================================================
   10. Финальный результат

   Одна строка = один многосегментный звонок.
   ============================================================ */
SELECT /* --------------------------------------------------------
       Основная информация
       -------------------------------------------------------- */  DATE(MAX(c.call_date)) AS [Дата],
                                                                    strftime('%Y-%m-%d %H:%M', MAX(c.event_at)) AS [Дата-время],
                                                                    c.call_id AS [CallID],
                                                                    MAX(c.global_call_uid) AS [UCID],
                                                                    MAX(cl.client_number) AS [Номер клиента],
                                                                    MAX(ad.asai_value) AS [ASAI_UUI], /* --------------------------------------------------------
       Навыки в последовательности звонка

       Максимум 8 операторских навыков,
       так как синтетический генератор использует
       от 1 до 8 сегментов.
       -------------------------------------------------------- */  CAST(MAX(CASE
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
                                                                             END) AS INTEGER) AS [Skill7],
                                                                    CAST(MAX(CASE
                                                                                 WHEN c.agent_rn = 8 THEN c.skill_display
                                                                             END) AS INTEGER) AS [Skill8], /* ========================================================
       Метрики Skill 1
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill1_Консультация], /* ========================================================
       Метрики Skill 2
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill2_Консультация], /* ========================================================
       Метрики Skill 3
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill3_Консультация], /* ========================================================
       Метрики Skill 4
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill4_Консультация], /* ========================================================
       Метрики Skill 5
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill5_Консультация], /* ========================================================
       Метрики Skill 6
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill6_Консультация], /* ========================================================
       Метрики Skill 7
       ======================================================== */  MAX(CASE
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
                                                                        END) AS [Skill7_Консультация], /* ========================================================
       Метрики Skill 8
       ======================================================== */  MAX(CASE
                                                                            WHEN c.agent_rn = 8 THEN c.total_wait_sec
                                                                            ELSE 0
                                                                        END) AS [Skill8_Ожидание],
                                                                    MAX(CASE
                                                                            WHEN c.agent_rn = 8 THEN c.talk_sec
                                                                            ELSE 0
                                                                        END) AS [Skill8_Разговор],
                                                                    MAX(CASE
                                                                            WHEN c.agent_rn = 8 THEN c.hold_sec
                                                                            ELSE 0
                                                                        END) AS [Skill8_Удержание],
                                                                    MAX(CASE
                                                                            WHEN c.agent_rn = 8 THEN c.consult_sec
                                                                            ELSE 0
                                                                        END) AS [Skill8_Консультация], /* ========================================================
       Общие показатели звонка
       ======================================================== */ /* Время промежуточных сегментов между операторами */  MAX(bt.bridge_total) AS [Время мостов], /* Количество переходов между операторскими сегментами */  COUNT(*) - 1 AS [Количество переводов], /* --------------------------------------------------------
       Время до финального навыка.

       Учитываются только операторские сегменты,
       которые находятся ДО последнего навыка.
       -------------------------------------------------------- */  SUM(CASE
                                                                            WHEN c.agent_rn < m.max_agent_rn THEN COALESCE(c.total_wait_sec, 0)
                                                                            ELSE 0
                                                                        END) AS [Ожидание до финального],
                                                                    SUM(CASE
                                                                            WHEN c.agent_rn < m.max_agent_rn THEN COALESCE(c.talk_sec, 0)
                                                                            ELSE 0
                                                                        END) AS [Разговор до финального]
FROM CHAIN c /* Подключаем информацию о последнем навыке */
INNER JOIN multi_skill m ON c.call_id = m.call_id /* Подключаем нормализованный номер клиента */
LEFT JOIN client_num cl ON c.call_id = cl.call_id /* Подключаем CRM payload */
LEFT JOIN asai_data ad ON c.call_id = ad.call_id /* Подключаем рассчитанное время мостов */
LEFT JOIN bridge_time bt ON c.call_id = bt.call_id /* Одна строка на один звонок */
GROUP BY c.call_id /* Сортировка результата */
ORDER BY [Дата],
         c.call_id;
