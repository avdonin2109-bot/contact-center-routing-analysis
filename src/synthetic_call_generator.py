sql = ('# =============================================================================
# synthetic_call_generator.py
# Генератор синтетических данных звонков контактного центра.
# Один звонок = 1-8 сегментов по типовым цепочкам маршрутизации
# (вход, очередь, робот, агент, консультация, фидбек).
# Распределение: 1 seg 4%, 2-3 seg 30% each, 4-5 seg 15% each,
# 6 seg 3%, 7 seg 2%, 8 seg 1%. Матожидание 3.29 сегмента на звонок.
# Выход: CSV, SQLite (таблица call_segments), Excel.
# =============================================================================

# =============================================================================
# ЯЧЕЙКА 1: Импорты и константы
# Библиотеки, сиды для воспроизводимости, распределение числа сегментов
# на звонок (доли от 1 до 8).
# =============================================================================
import os import random import JSON import sqlite3 import hashlib '
       'FROM datetime import datetime, timedelta '
       'FROM dataclasses import dataclass, field '
       'FROM typing import List, Optional, Dict, Tuple
import pandas AS pd
import numpy AS np

random.seed(42) np.random.seed(42)

SEG_WEIGHTS = {1: 0.04, 2: 0.30, 3: 0.30, 4: 0.15, 5: 0.15, 6: 0.03, 7: 0.02, 8: 0.01} # типы сегментов: entry вход+очередь, queue_abn сброс в очереди, agent разговор,
# consult разговор с консультацией, robot IVR, ivr_menu IVR с вводом цифр,
# feedback автоответчик, internal внутренний перевод (direct queue)
KINDS = ("entry", "queue_abn", "agent", "consult", "robot", "ivr_menu", "feedback", "internal")

# 10 типовых цепочек на каждое число сегментов: (вес, цепочка видов)
CHAINS = { 1: [(16, ("entry",)), (14, ("queue_abn",)), (12, ("agent",)), (10, ("robot",)),
        (10, ("ivr_menu",)), (10, ("feedback",)), (8, ("internal",)), (8, ("consult",)),
        (6, ("agent",)), (6, ("entry",))],
    2: [(28, ("entry", "agent")), (22, ("entry", "feedback")), (10, ("entry", "queue_abn")),
        (10, ("agent", "feedback")), (8, ("robot", "agent")), (6, ("entry", "consult")),
        (5, ("agent", "agent")), (4, ("ivr_menu", "agent")), (4, ("entry", "robot")),
        (3, ("robot", "feedback"))],
    3: [(30, ("entry", "agent", "feedback")), (25, ("entry", "agent", "agent")),
        (10, ("entry", "robot", "agent")), (8, ("robot", "agent", "feedback")),
        (6, ("entry", "consult", "agent")), (6, ("entry", "agent", "queue_abn")),
        (5, ("agent", "agent", "feedback")), (4, ("entry", "robot", "feedback")),
        (4, ("ivr_menu", "agent", "agent")), (2, ("entry", "agent", "robot"))],
    4: [(25, ("entry", "agent", "agent", "feedback")), (20, ("entry", "agent", "agent", "agent")),
        (10, ("entry", "robot", "agent", "feedback")), (8, ("entry", "agent", "consult", "agent")),
        (8, ("agent", "agent", "agent", "feedback")), (7, ("agent", "agent", "agent", "agent")),
        (6, ("entry", "agent", "agent", "queue_abn")), (6, ("robot", "agent", "agent", "feedback")),
        (5, ("entry", "ivr_menu", "agent", "feedback")), (5, ("entry", "agent", "robot", "feedback"))],
    5: [(25, ("entry", "agent", "agent", "agent", "feedback")),
        (18, ("entry", "agent", "agent", "agent", "agent")),
        (12, ("entry", "robot", "agent", "agent", "feedback")),
        (10, ("entry", "agent", "consult", "agent", "feedback")),
        (10, ("agent", "agent", "agent", "agent", "feedback")),
        (8, ("entry", "agent", "agent", "consult", "agent")),
        (7, ("entry", "robot", "agent", "agent", "agent")),
        (5, ("entry", "agent", "robot", "agent", "feedback")),
        (3, ("robot", "agent", "agent", "agent", "feedback")),
        (2, ("entry", "agent", "agent", "agent", "queue_abn"))],
    6: [(25, ("entry", "agent", "agent", "agent", "agent", "feedback")),
        (15, ("entry", "agent", "agent", "agent", "agent", "agent")),
        (15, ("entry", "robot", "agent", "agent", "agent", "feedback")),
        (12, ("entry", "agent", "consult", "agent", "agent", "feedback")),
        (10, ("agent", "agent", "agent", "agent", "agent", "feedback")),
        (8, ("entry", "agent", "agent", "agent", "consult", "agent")),
        (6, ("entry", "robot", "agent", "agent", "agent", "agent")),
        (5, ("entry", "agent", "agent", "robot", "agent", "feedback")),
        (2, ("robot", "agent", "agent", "agent", "agent", "feedback")),
        (2, ("entry", "agent", "agent", "agent", "agent", "queue_abn"))],
    7: [(25, ("entry", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (15, ("entry", "agent", "agent", "agent", "agent", "agent", "agent")),
        (15, ("entry", "robot", "agent", "agent", "agent", "agent", "feedback")),
        (12, ("entry", "agent", "consult", "agent", "agent", "agent", "feedback")),
        (10, ("agent", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (8, ("entry", "agent", "agent", "agent", "agent", "consult", "agent")),
        (6, ("entry", "robot", "agent", "agent", "agent", "agent", "agent")),
        (5, ("entry", "agent", "agent", "agent", "robot", "agent", "feedback")),
        (2, ("robot", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (2, ("entry", "agent", "agent", "agent", "agent", "agent", "queue_abn"))],
    8: [(25, ("entry", "agent", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (15, ("entry", "agent", "agent", "agent", "agent", "agent", "agent", "agent")),
        (15, ("entry", "robot", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (12, ("entry", "agent", "consult", "agent", "agent", "agent", "agent", "feedback")),
        (10, ("agent", "agent", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (8, ("entry", "agent", "agent", "agent", "agent", "agent", "consult", "agent")),
        (6, ("entry", "robot", "agent", "agent", "agent", "agent", "agent", "agent")),
        (5, ("entry", "agent", "agent", "agent", "agent", "robot", "agent", "feedback")),
        (2, ("robot", "agent", "agent", "agent", "agent", "agent", "agent", "feedback")),
        (2, ("entry", "agent", "agent", "agent", "agent", "agent", "agent", "queue_abn"))], } # =============================================================================
# ЯЧЕЙКА 2: Конфигурация
# Период 01.01-31.08.2026. Пулы VDN генерируются синтетически, реальные номера
# не используются. n_calls=280_000 дает примерно 921K сегментов.
# Папка вывода: создается автоматически, если не существует.
# =============================================================================
def _make_vdn_pools() -> tuple: agent_vdns = [str(n) for n in random.sample(range(3000, 3999), 12)]
    agent_vdns += [str(n) for n in random.sample(range(6000, 6999), 12)] short_vdns = [str(n) for n in random.sample(range(5000, 5999), 8)] service_vdns = [str(random.randint(77000000, 77999999)) for _ in range(4)] robot_vdns = [str(random.randint(88000000, 88999999)) for _ in range(6)] feedback_vdn = "77000001" entry_vdns = agent_vdns + short_vdns + service_vdns RETURN entry_vdns, agent_vdns, robot_vdns, feedback_vdn


VDN_ENTRY, VDN_AGENT, VDN_ROBOT, FEEDBACK_VDN = _make_vdn_pools()


@dataclass CLASS CallConfig: n_calls: int = 280_000 start_date: datetime = field(default_factory=lambda: datetime(2026, 1, 1))
    end_date: datetime = field(default_factory=lambda: datetime(2026, 8, 31, 23, 59, 59))
    output_dir: STR = r"C:\Users\Александр\Documents\Экспорт из БД\Моделирование данных" entry_vdns: List[STR] = field(default_factory=lambda: VDN_ENTRY)
    agent_vdns: List[STR] = field(default_factory=lambda: VDN_AGENT)
    robot_vdns: List[STR] = field(default_factory=lambda: VDN_ROBOT)
    feedback_vdn: STR = FEEDBACK_VDN
    skills: List[int] = field(default_factory=lambda: list(range(101, 160)))
    n_agents: int = 120
    n_trunks: int = 200
    trunk_prefix: STR = "T"
    acd_id: int = 1
    seg_weights: Dict[int, float] = field(default_factory=lambda: SEG_WEIGHTS)
    null_rate: float = 0.02
    outlier_rate: float = 0.005 # =============================================================================
# ЯЧЕЙКА 3: Пулы ресурсов
# Логины агентов с привязкой скиллов и локаций, ID транков.
# =============================================================================
CLASS AgentPool: def __init__(SELF, n: int): self.logins = [str(i).zfill(4) for i in range(1, n + 1)]
        self.skill_map = {l: random.choice(list(range(101, 160))) '
       'FOR l IN self.logins} self.loc_map = {l: random.randint(1, 5) '
       'FOR l IN self.logins} def random(SELF) -> STR: RETURN random.choice(self.logins) CLASS TrunkPool: def __init__(SELF, n: int, PREFIX: STR = "T"): self.ids = [f"{prefix}{str(i).zfill(5)}" for i in range(1, n + 1)]
    def random(SELF) -> STR: RETURN random.choice(self.ids)


# =============================================================================
# ЯЧЕЙКА 4: Построитель сценария
# Выбирает число сегментов по распределению, затем типовую цепочку из CHAINS.
# Каждый вид сегмента (entry, agent, consult, robot, ivr_menu, feedback,
# queue_abn, internal) генерируется со своей логикой: VDN, очередь, разговор,
# hold, консультация, исход. 94 смысловых поля.
# =============================================================================
CLASS ScenarioBuilder: def __init__(SELF, cfg: CallConfig, agents: AgentPool, trunks: TrunkPool): self.cfg = cfg self.agents = agents self.trunks = trunks self._seg_keys = list(cfg.seg_weights.keys()) self._seg_vals = list(cfg.seg_weights.VALUES())
    def _ts(SELF, dt: datetime) -> int: RETURN int(dt.timestamp())
    def _rnd_phone(SELF) -> STR: RETURN "9" + "".join(random.choices("0123456789", k=9))
    def _crm_payload(SELF, entry_vdn: STR, clid: STR, dialed: STR) -> STR: RETURN json.dumps({"entryVdn": entry_vdn, "caller": clid, "dialed": dialed}, ensure_ascii=FALSE)
    def _anom(SELF, val: int) -> int: IF random.random() < self.cfg.outlier_rate: RETURN int(val * random.uniform(5, 20)) RETURN val
    def _maybe_null(SELF, val: STR) -> Optional[STR]: IF random.random() < self.cfg.null_rate: RETURN NONE RETURN val
    def _make_segment(SELF, kind: STR, is_first: bool, is_last: bool, caller: STR,
                      entry_vdn: STR, prev_agent: Optional[STR]) -> Dict: cfg = self.cfg
        anslogin = NONE;')
sql2 = ' '
        '
origlogin = prev_agent;'
sql3 = ' '
        '
talk = 0;'
sql4 = ' '
        '
queue = 0;'
sql5 = ' '
        '
ring = 0 acw = 0;'
sql6 = ' '
        '
HOLD = 0;'
sql7 = ' '
        '
consult = 0;'
sql8 = ' '
        '
da_queued = 0;'
sql9 = ' '
        '
transferred = 0 dtmf = "";'
sql10 = ' '
         '
SPLIT = 0 IF kind == "entry": dialed = entry_vdn IF is_first ELSE random.choice(cfg.entry_vdns) calling = self.trunks.random() IF random.random() < 0.08 ELSE caller queue = random.choices([0, random.randint(1, 120)], weights=[40, 60])[0] disp = random.choices([3, 5, 7], weights=[50, 15, 35])[0] IF is_last ELSE 4 dur = queue + random.randint(1, 5) IF disp == 3 ELSE random.randint(2, 15) SPLIT = random.choice(cfg.skills) IF queue > 0 ELSE 0
        elif kind == "queue_abn": dialed = entry_vdn IF is_first ELSE random.choice(cfg.entry_vdns) calling = caller;'
sql11 = ' '
         '
queue = random.randint(5, 300) disp = 3;'
sql12 = (' '
         '
dur = queue + random.randint(1, 5) SPLIT = random.choice(cfg.skills)
        elif kind IN ("agent", "consult"): dialed = random.choice(cfg.agent_vdns) calling = caller;')
sql13 = ' '
         '
anslogin = self.agents.random() talk = self._anom(random.randint(20, 600));'
sql14 = ' '
         '
queue = random.randint(0, 90) ring = random.randint(1, 20);'
sql15 = ' '
         '
acw = self._anom(random.randint(5, 45)) HOLD = random.choices([0, random.randint(5, 120)], weights=[88, 12])[0] consult = random.choices([0, random.randint(10, 180)], weights=[92, 8])[0] IF kind == "consult" ELSE 0 disp = 2 IF is_last ELSE 4 dur = talk + ring + HOLD + consult + random.randint(1, 3) SPLIT = self.agents.skill_map.get(anslogin, random.choice(cfg.skills)) transferred = 0 IF is_last ELSE 1
        elif kind == "robot": dialed = random.choice(cfg.robot_vdns) calling = self.trunks.random() IF random.random() < 0.3 ELSE caller queue = random.randint(0, 30) disp = random.choices([6, 7], weights=[70, 30])[0] IF is_last ELSE 4 dur = queue + random.randint(2, 40) SPLIT = random.choice(cfg.skills);'
sql16 = ' '
         '
transferred = 1 IF NOT is_last ELSE 0
        elif kind == "ivr_menu": dialed = random.choice(cfg.robot_vdns) calling = caller;'
sql17 = ' '
         '
queue = 0 dtmf = "".join(random.choices("0123456789", k=random.randint(1, 6))) disp = random.choices([6, 7], weights=[70, 30])[0] IF is_last ELSE 4 dur = random.randint(10, 90) SPLIT = random.choice(cfg.skills);'
sql18 = ' '
         '
transferred = 1 IF NOT is_last ELSE 0
        elif kind == "feedback": dialed = cfg.feedback_vdn;'
sql19 = (' '
         '
calling = caller disp = random.choices([1, 3, 4, 6], weights=[10, 5, 5, 80])[0] dur = random.randint(0, 3) ELSE: dialed = random.choice(cfg.agent_vdns) calling = prev_agent IF prev_agent '
         'AND random.random() < 0.5 ELSE caller da_queued = 1;')
sql20 = (' '
         '
queue = random.randint(0, 30) disp = random.choices([2, 4, 6], weights=[40, 30, 30])[0] IF is_last ELSE 4 dur = queue + random.randint(1, 60) SPLIT = random.choice(cfg.skills) RETURN {"dialed": dialed, "calling": calling, "anslogin": anslogin, "origlogin": origlogin,
                "talk": talk, "queue": queue, "ring": ring, "acw": acw, "hold": HOLD,
                "consult": consult, "da_queued": da_queued, "disp": disp, "dur": dur,
                "split": SPLIT, "transferred": transferred, "dtmf": dtmf, "kind": kind} def build(SELF, call_id: int, start_dt: datetime) -> List[Dict]: n_seg = random.choices(self._seg_keys, weights=self._seg_vals)[0] patterns = CHAINS[n_seg] CHAIN = random.choices([p[1] FOR p IN patterns], weights=[p[0] FOR p IN patterns])[0]
        segments = [] cur_dt = start_dt caller = self._rnd_phone() entry_vdn = random.choice(self.cfg.entry_vdns) payload_id = hashlib.md5(f"{call_id}_{start_dt.isoformat()}".encode()).hexdigest()[:20].upper() prev_agent = NONE  '
         'FOR seg_num, kind IN enumerate(CHAIN, 1): is_first = seg_num == 1 is_last = seg_num == n_seg s = self._make_segment(kind, is_first, is_last, caller, entry_vdn, prev_agent) IF s["anslogin"]: prev_agent = s["anslogin"] segstart = self._ts(cur_dt) segstop = segstart + s["dur"] day_time = cur_dt.hour * 3600 + cur_dt.minute * 60 + cur_dt.second crm = "" IF s["anslogin"] '
         'AND random.random() < 0.65: crm = self._crm_payload(entry_vdn, caller, s["dialed"]) wrap = random.choices(["", str(random.randint(1, 9)).zfill(4)], weights=[70, 30])[0] IF s["anslogin"] ELSE "" split_prev1 = segments[-1]["queue_skill_1"] IF segments ELSE NONE split_prev2 = segments[-2]["queue_skill_2"] IF len(segments) > 1 ELSE NONE split_prev3 = segments[-3]["queue_skill_3"] IF len(segments) > 2 ELSE NONE ROW = { "segment_id": NONE,
                "segment_uid": random.randint(1_000_000_000, 2_000_000_000),
                "acd_id": self.cfg.acd_id,
                "call_date": cur_dt.strftime("%Y-%m-%d 00:00:00.000"),
                "day_time_sec": day_time,
                "acw_sec": s["acw"], "hold_sec": s["hold"],
                "agent_login": self._maybe_null(s["anslogin"]) IF s["anslogin"] ELSE NONE,
                "assist_flag": random.choices([0, 1], weights=[98, 2])[0] IF s["anslogin"] ELSE 0,
                "audio_flag": 0, "call_id": str(call_id), "caller_number": s["calling"],
                "conference_flag": random.choices([0, 1], weights=[95, 5])[0] IF s["anslogin"] ELSE 0,
                "consult_sec": s["consult"], "direct_queue_flag": s["da_queued"],
                "dialed_number": s["dialed"],
                "exit_vector": random.choice(["", str(random.randint(100, 1500))]),
                "outcome_code": s["disp"], "exit_priority": random.randint(1, 6),
                "exit_skill": s["split"] IF s["split"] ELSE NONE,
                "total_wait_sec": s["queue"] + s["ring"] + random.randint(0, 5),
                "exit_vdn": s["dialed"] IF is_last ELSE "",
                "duration_sec": s["dur"], "trunk_code": self.trunks.random(),
                "event_cnt_1": 0, "event_cnt_2": 0, "event_cnt_3": 0, "event_cnt_4": 0, "event_cnt_5": 0,
                "event_cnt_6": 0, "event_cnt_7": 0, "event_cnt_8": 0, "event_cnt_9": 0,
                "entry_vector": "", "entry_vdn": entry_vdn,
                "route_vdn_2": "", "route_vdn_3": "", "route_vdn_4": "", "route_vdn_5": "",
                "route_vdn_6": "", "route_vdn_7": "", "route_vdn_8": "", "route_vdn_9": "",
                "hold_flag": 1 IF s["hold"] > 0 ELSE 0,
                "hold_abandon_flag": random.choices([0, 1], weights=[99, 1])[0] IF s["hold"] > 0 ELSE 0,
                "wrap_code": wrap, "dtmf_digits": s["dtmf"], "observer_login": "",
                "malicious_flag": 0, "observe_flag": 0,
                "origin_agent_login": s["origlogin"], "segment_no": seg_num,
                "start_ts": segstart, "start_utc_ts": segstart - 3600,
                "end_ts": segstop, "end_utc_ts": segstop - 3600,
                "queue_skill_1": s["split"] IF is_first ELSE split_prev1,
                "queue_skill_2": s["split"] IF seg_num == 2 ELSE split_prev2,
                "queue_skill_3": s["split"] IF seg_num == 3 ELSE split_prev3,
                "talk_sec": s["talk"], "trunk_group": random.randint(0, 100),
                "transfer_flag": s["transferred"],
                "agent_released": random.choices(["n", "y"], weights=[60, 40])[0] IF s["anslogin"] ELSE "n",
                "answer_reason_code": random.randint(0, 99) IF s["anslogin"] ELSE 0,
                "line_type_code": "", "exit_skill_level": random.randint(1, 16) IF s["anslogin"] ELSE 0,
                "origin_reason_code": 0, "net_in_sec": 0, "origin_hold_sec": 0,
                "global_call_uid": payload_id,
                "agent_location_id": self.agents.loc_map.get(s["anslogin"], 0) IF s["anslogin"] ELSE 0,
                "trunk_location_id": random.randint(1, 5),
                "observer_location_id": 0, "origin_location_id": 0,
                "wrap_code_1": wrap, "wrap_code_2": "", "wrap_code_3": "", "wrap_code_4": "", "wrap_code_5": "",
                "queue_sec": s["queue"], "ring_sec": s["ring"],
                "uui_bytes": len(crm) IF crm ELSE 0, "crm_payload": crm,
                "interrupt_type": 0,
                "staffing_balance": random.choices([0, 1, 2], weights=[10, 60, 30])[0],
                "agent_skill_level": random.randint(1, 16) IF s["anslogin"] ELSE 0,
                "pref_skill_match": random.choices([0, 1, 2], weights=[10, 20, 70])[0] IF s["anslogin"] ELSE 0,
                "icr_resent_flag": 0, "icr_pull_reason": 0,
                "origin_attrib": "", "agent_attrib": "", "observer_attrib": "",
                "loaded_at": (cur_dt + timedelta(minutes=random.randint(1, 30))).strftime("%Y-%m-%d %H:%M:%S.%f")[:-3],
                "event_at": cur_dt.strftime("%Y-%m-%d %H:%M:%S.%f")[:-3], } segments.append(ROW) cur_dt = datetime.fromtimestamp(segstop) RETURN segments



# =============================================================================
# ЯЧЕЙКА 5: Генератор датасета
# Создает звонки в периоде 01.01-31.08.2026, собирает сегменты по цепочкам,
# формирует DataFrame и назначает segment_id. 90% звонков в 08:00-22:00.
# =============================================================================
CLASS CallDataGenerator: def __init__(SELF, cfg: CallConfig): self.cfg = cfg self.agents = AgentPool(cfg.n_agents) self.trunks = TrunkPool(cfg.n_trunks, cfg.trunk_prefix) self.builder = ScenarioBuilder(cfg, self.agents, self.trunks)
        self.rows: List[Dict] = [] def _random_datetime(SELF) -> datetime: delta = self.cfg.end_date - self.cfg.start_date  '
         'OFFSET = random.randint(0, int(delta.total_seconds())) dt = self.cfg.start_date + timedelta(seconds=OFFSET) IF random.random() < 0.90: HOUR = random.choices(list(range(8, 23)), weights=[2, 3, 5, 7, 8, 7, 6, 5, 4, 3, 2, 2, 2, 2, 1])[0] dt = dt.replace(HOUR=HOUR, MINUTE=random.randint(0, 59), SECOND=random.randint(0, 59)) RETURN dt
    def run(SELF) -> pd.DataFrame:  '
         'FOR i IN range(1, self.cfg.n_calls + 1): start_dt = self._random_datetime()
            self.rows.extend(self.builder.build(i, start_dt)) df = pd.DataFrame(self.rows) df["segment_id"] = range(1, len(df) + 1) RETURN df
		
		
# =============================================================================
# ЯЧЕЙКА 6: Функции сохранения
# CSV (разделитель ;), SQLite (таблица call_segments, индексы по ключам),
# Excel с умной таблицей. Папка создается автоматически.
# =============================================================================
def save_csv(df: pd.DataFrame, out_dir: STR, name: STR = "call_segments.csv") -> NONE: df.to_csv(os.path.join(out_dir, name), INDEX=FALSE, ENCODING="utf-8-sig", sep=";")


def save_sqlite(df: pd.DataFrame, out_dir: STR, db_name: STR = "call_segments.db",
                TABLE: STR = "call_segments") -> NONE: conn = sqlite3.connect(os.path.join(out_dir, db_name))
    df.to_sql(TABLE, conn, if_exists="replace", INDEX=FALSE)  '
         'FOR col IN ["call_id", "call_date", "agent_login"]: conn.execute(f\'CREATE INDEX IF NOT EXISTS idx_{col} ON "{table}"("{col}")\')
    conn.commit() conn.close()


def save_excel(df: pd.DataFrame, out_dir: STR, name: STR = "call_segments.xlsx") -> NONE: PATH = os.path.join(out_dir, name)
    try:  '
         'FROM openpyxl import load_workbook  '
         'FROM openpyxl.worksheet.table import TABLE, TableStyleInfo
        df.to_excel(PATH, INDEX=FALSE, ENGINE="openpyxl") wb = load_workbook(PATH) ws = wb.active tab = Table(displayName="CallSegments", REF=ws.dimensions) tab.tableStyleInfo = TableStyleInfo(name="TableStyleMedium9", showFirstColumn=FALSE, showLastColumn=FALSE, showRowStripes=TRUE, showColumnStripes=FALSE)
        ws.add_table(tab) wb.save(PATH)  '
         'EXCEPT ImportError: df.to_excel(PATH, INDEX=FALSE, ENGINE="openpyxl") print("openpyxl не найден, сохранен обычный xlsx. Для умной таблицы: pip install openpyxl")		
		
		
# =============================================================================
# ЯЧЕЙКА 7: Запуск генерации
# n_calls=280_000 дает примерно 921K сегментов. Время: 60-100 сек, RAM ~2 GB.
# =============================================================================
IF __name__ == "__main__": cfg = CallConfig(n_calls=280_000)
    os.makedirs(cfg.output_dir, exist_ok=TRUE) df = CallDataGenerator(cfg).run() print(f"Звонков: {df[\'call_id\'].nunique()}") print(f"Сегментов: {len(df)}") print(f"Период: {df[\'call_date\'].min()[:10]} - {df[\'call_date\'].max()[:10]}") dist = df.groupby("call_id").size().value_counts().sort_index() total = df["call_id"].nunique() print("\nРаспределение сегментов:")  '
         'FOR seg, cnt IN dist.items(): IF seg <= 8: print(f"  {seg} сегмент: {cnt} ({cnt/total*100:.1f}%)") save_csv(df, cfg.output_dir) save_sqlite(df, cfg.output_dir, TABLE="call_segments") save_excel(df, cfg.output_dir) print(f"\nСохранено в {cfg.output_dir}:") print("  call_segments.csv, call_segments.db (call_segments), call_segments.xlsx") ')
