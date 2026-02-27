import time
import threading
from datetime import datetime
import config

class TxEngine:
    """Motor de transmissão sincronizada para Rádio, Ícones e Relógio."""

    def __init__(self, runtime, stations, rx_engine=None):
        self.runtime = runtime
        self.stations = stations
        self.rx_engine = rx_engine
        self.current_radio_idx = 0
        self.running = False
        
        # Timestamps para controle de cadência
        self.last_hb_10hz = 0
        self.last_sync_1hz = 0
        self.last_text_tick = 0
        
        # Estado do Scroll de Texto
        self.scroll_char_idx = 0
        
        # Estatísticas de Transmissão
        self.tx_count = 0
        self.last_dash_update = 0

    def start(self):
        self.running = True
        print("[Engine] Motor de transmissão iniciado.")
        
        # Limpar a tela inicialmente
        print("\033[H\033[J", end="") 
        
        # Inicializar timestamps com monotonic para evitar congelamento em saltos temporais
        now_mono = time.monotonic()
        self.last_hb_10hz = now_mono
        self.last_sync_1hz = now_mono
        self.last_text_tick = now_mono
        self.last_dash_update = now_mono

        while self.running:
            now_mono = time.monotonic()
            
            # Verificar se há rádio externo ativo (Node B injetando)
            # Se houve atividade nos últimos 3 segundos, o Node A silencia-se
            is_ext_radio = self.rx_engine and (now_mono - self.rx_engine.last_external_radio_ts < 3.0)

            # 1. BUNDLE DE RÁDIO/ÍCONES (10Hz / 100ms) - Apenas se não houver rádio externo
            if config.ENABLE_RADIO_EMISSION and not is_ext_radio and (now_mono - self.last_hb_10hz >= 0.1):
                self._send_radio_bundle()
                self._send_icon_bundle()
                self.last_hb_10hz = now_mono
            
            # 2. SINCRONIZAÇÃO DE TEMPO (1Hz / 1000ms)
            if config.ENABLE_CLOCK_EMISSION and (now_mono - self.last_sync_1hz >= 1.0):
                self._send_time_sync()
                self.last_sync_1hz = now_mono

            # 3. TEXTO ISO-TP (Scroll) - Apenas se não houver rádio externo
            if config.ENABLE_RADIO_EMISSION and not is_ext_radio and (now_mono - self.last_text_tick >= config.ISOTP_TEXT_DELAY):
                self._send_current_label()
                self.last_text_tick = now_mono
            
            # 4. DASHBOARD VISUAL (10ms / 100Hz)
            if (now_mono - self.last_dash_update >= 0.01):
                self._print_dashboard()
                self.last_dash_update = now_mono

            time.sleep(0.001) # Alta frequência para dashboard de 10ms

    def stop(self):
        self.running = False

    def _send_radio_bundle(self):
        # Heartbeat vital do rádio e parâmetros da banda/frequência
        station = self.stations[self.current_radio_idx]
        
        # Heartbeat Vital
        self.runtime.send_frame(0x100, [0x62, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00])
        self.tx_count += 1
        if self.rx_engine: self.rx_engine.update_id_state(0x100, [0x62, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00], "TX")
        
        # ID 0x114 (Modo e Frequência)
        prefix = 0x11 # FM default
        suffix = [0x00, 0x00]
        
        if station["band"] == "AM":
            prefix = 0x14
            raw = int((station["khz"] - 517) * 16 / 9)
            raw = max(0, raw)
            suffix = [(raw >> 8) & 0xFF, raw & 0xFF]
        elif station["band"] == "FM":
            prefix = 0x11
            raw = int(round((station["mhz"] - 87.5) * 320.0))
            suffix = [(raw >> 8) & 0xFF, raw & 0xFF]
        elif station["band"] == "BT":
            prefix = 0x08
            
        p114 = [prefix, 0x60, 0x00, 0x01, 0x00, 0x00, suffix[0], suffix[1]]
        self.runtime.send_frame(0x114, p114)
        p115 = [0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        self.runtime.send_frame(0x115, p115)
        self.tx_count += 2
        if self.rx_engine:
            self.rx_engine.update_id_state(0x114, p114, "TX")
            self.rx_engine.update_id_state(0x115, p115, "TX")

    def _send_icon_bundle(self):
        # Visibilidade de menus (Musical + GPS)
        p169 = [0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        p1eb = [0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00]
        p44d = [0x40, 0x02, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF]
        p120 = [0x00, 0x00, 0x00, 0x00]
        p506 = [0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x00]
        
        self.runtime.send_frame(0x169, p169)
        self.runtime.send_frame(0x1EB, p1eb)
        self.runtime.send_frame(0x44D, p44d)
        self.runtime.send_frame(0x120, p120)
        self.runtime.send_frame(0x506, p506)
        self.tx_count += 5
        
        if self.rx_engine:
            self.rx_engine.update_id_state(0x169, p169, "TX")
            self.rx_engine.update_id_state(0x1EB, p1eb, "TX")
            self.rx_engine.update_id_state(0x44D, p44d, "TX")
            self.rx_engine.update_id_state(0x120, p120, "TX")
            self.rx_engine.update_id_state(0x506, p506, "TX")

    def _send_time_sync(self):
        # Dual-Bus Time Sync: 0x5E2 e 0x12F
        now = datetime.now()
        y_short = now.year % 100
        m_enc = (now.month * 4) + 1
        
        # Frame 0x5E2
        payload_5e2 = [0x4E, y_short, now.hour, now.minute, now.second, now.day, m_enc, 0xCF]
        self.runtime.send_frame(0x5E2, payload_5e2)
        
        time.sleep(0.01)
        
        # Frame 0x12F
        payload_12f = [0x4E, now.hour, now.minute, now.second, m_enc, y_short, now.day, 0xCF]
        self.runtime.send_frame(0x12F, payload_12f)
        self.tx_count += 2
        
        if self.rx_engine:
            self.rx_engine.update_id_state(0x5E2, payload_5e2, "TX")
            self.rx_engine.update_id_state(0x12F, payload_12f, "TX")

    def _send_current_label(self):
        # ISO-TP para exibição de texto
        station = self.stations[self.current_radio_idx]
        label = station["label"]
        band = station["band"]
        
        # Gerar label formatado (Scroll se > 16 chars)
        display_text = self._get_scroll_text(label)
        utf16_bytes = self._to_utf16_bytes(display_text)
        
        can_id = 0x485 if band == "BT" else 0x4E8
        
        # Reconstrução da lógica de fragmentação porta dos .ps1
        # First Frame (10 Len ...) e Consecutive Frames (21, 22, 23...)
        if band == "BT":
            full_payload = [0x03] + utf16_bytes # Prefixo 03 para BT
            self._send_isotp_fragmented(can_id, full_payload)
        else:
            self._send_isotp_fragmented(can_id, utf16_bytes)
            
        self.scroll_char_idx += 1

    def _get_scroll_text(self, label):
        if len(label) <= 16:
            return label.center(16)
        extended = label + "          "
        l = len(extended)
        start = self.scroll_char_idx % l
        res = extended[start:]
        if len(res) < 16:
            res += extended[:(16-len(res))]
        return res[:16]

    def _to_utf16_bytes(self, text):
        b = []
        for char in text.upper()[:16]:
            code = ord(char)
            b.append(code & 0xFF)
            b.append((code >> 8) & 0xFF)
        return b

    def _send_isotp_fragmented(self, can_id, payload):
        length = len(payload)
        # 10 [LEN] [D...]
        ff = [0x10, length] + payload[0:6]
        self.runtime.send_frame(can_id, ff)
        self.tx_count += 1
        
        if self.rx_engine: self.rx_engine.update_id_state(can_id, ff, "TX")
        
        time.sleep(config.ISOTP_GAP_MS / 1000.0)
        
        idx = 6
        sn = 1
        while idx < length:
            chunk = payload[idx:idx+7]
            while len(chunk) < 7: chunk.append(0x00)
            cf = [0x20 + (sn & 0x0F)] + chunk
            self.runtime.send_frame(can_id, cf)
            self.tx_count += 1
            if self.rx_engine: self.rx_engine.update_id_state(can_id, cf, "TX")
            idx += 7
            sn += 1
            time.sleep(config.ISOTP_GAP_MS / 1000.0)

    def _print_dashboard(self):
        """Exibe as informações atuais na consola (estilo dashboard PowerShell)."""
        now = datetime.now()
        
        print("\033[2J\033[H", end="")
        
        print("================================================================================")
        print(" KIA CEED CAN SIMULATOR - RASPBERRY NODE A")
        print(f" {now.strftime('%d/%m/%Y %H:%M:%S')}")
        print(f" TX: {self.tx_count} frames")
        rx_c = self.rx_engine.rx_count if self.rx_engine else 0
        print(f" RX: {rx_c} frames")
        print("================================================================================")
        
        if not self.rx_engine:
            print(" [ERRO] RX Engine não inicializado")
            print("================================================================================")
            return

        # --- Decoded (valores interpretados) ---
        sync_st = self.rx_engine.last_sync_time or "---"
        print(f" [CLOCK]  Sinc: {sync_st}")
        print(f" [RÁDIO]  Modo:  {self.rx_engine.radio_mode}")
        print(f" [RÁDIO]  Freq:  {self.rx_engine.radio_freq}")
        print(f" [RÁDIO]  Label: '{self.rx_engine.radio_label}'")

        tbl = self.rx_engine.id_table

        # --- GRUPO: TIME ---
        print("--------------------------------------------------------------------------------")
        print(" [TIME]")
        print(f"  {'ID':<6}  {'ÚLTIMO RAW':<28}  {'TIMESTAMP':<10}  {'DECODIFICADO'}")
        print(f"  {'-'*6}  {'-'*28}  {'-'*10}  {'-'*28}")
        for can_id in [0x5E2, 0x12F]:
            entry = tbl.get(can_id, {"last_raw": "---", "last_ts": "---", "decoded": "---"})
            raw = entry["last_raw"][:28].ljust(28)
            ts = entry["last_ts"].ljust(10)
            print(f"  {f'0x{can_id:03X}':<6}  {raw}  {ts}  {entry.get('decoded', '---')}")

        # --- GRUPO: RADIO ---
        print("--------------------------------------------------------------------------------")
        print(" [RADIO]")
        print(f"  {'ID':<6}  {'ÚLTIMO RAW':<28}  {'TIMESTAMP':<10}  {'DECODIFICADO'}")
        print(f"  {'-'*6}  {'-'*28}  {'-'*10}  {'-'*28}")
        radio_ids = [0x100, 0x114, 0x115, 0x169, 0x1EB, 0x44D, 0x120, 0x506, 0x4E8, 0x485]
        for can_id in radio_ids:
            entry = tbl.get(can_id, {"last_raw": "---", "last_ts": "---", "decoded": "---"})
            raw = entry["last_raw"][:28].ljust(28)
            ts = entry["last_ts"].ljust(10)
            print(f"  {f'0x{can_id:03X}':<6}  {raw}  {ts}  {entry.get('decoded', '---')}")

        if self.rx_engine.last_error:
            print(f" [ALERTA] {self.rx_engine.last_error}")

        print("================================================================================")
        print(" Ctrl+C para encerrar.")
