import os
import subprocess
import time
import config

class RxEngine:
    """Motor de recepção para ouvir e processar comandos CAN (ex: Tempo)."""

    def __init__(self, runtime):
        self.runtime = runtime
        self.tx_engine = None # Será definido após inicialização do TxEngine
        self.running = False
        self.last_sync_time = None
        self.last_parsed_time = "Nenhum detetado"
        self.last_rx_frame = "Nenhum recebido"
        self.last_error = None
        self.rx_count = 0
        self.last_rx_ts = "NUNCA"

        # Estado do Rádio Capturado (RX)
        self.radio_mode = "Desconhecido"
        self.radio_freq = "---"
        self.radio_station = "---"
        self.radio_label = "---"
        self.last_external_radio_ts = 0
        
        # Tabela de rastreio por ID CAN (apenas RX, atualiza apenas se o RAW mudar)
        # Esta tabela alimenta a parte superior do dashboard.
        self.id_table = {
            # TIME
            0x5E2: {"group": "TIME",  "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x12F: {"group": "TIME",  "last_raw": "---", "last_ts": "---", "decoded": "---"},
            # RADIO
            0x100: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x114: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x115: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x169: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x1EB: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x44D: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x120: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x506: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x4E8: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
            0x485: {"group": "RADIO", "last_raw": "---", "last_ts": "---", "decoded": "---"},
        }
        
        # Tabela REAL-TIME consolidada (RX e TX, atualiza sempre)
        self.realtime_table = {k: v.copy() for k, v in self.id_table.items()}
        for k in self.realtime_table:
            self.realtime_table[k].update({"dir": "---"})
        
        # Buffers ISO-TP para reconstrução de strings
        self.isotp_buffers = {
            0x4E8: {"data": bytearray(), "len": 0, "sn": 0},
            0x485: {"data": bytearray(), "len": 0, "sn": 0}
        }

    def update_id_state(self, can_id, data, direction):
        """Atualiza o estado consolidado de um ID (TX ou RX) para a tabela REAL-TIME."""
        if can_id in self.realtime_table:
            raw_hex = " ".join(f"{b:02X}" for b in data)
            self.realtime_table[can_id]["last_raw"] = raw_hex
            self.realtime_table[can_id]["last_ts"] = time.strftime("%H:%M:%S")
            self.realtime_table[can_id]["dir"] = direction

    def start(self):
        """Loop de escuta de frames."""
        self.running = True
        
        while self.running:
            try:
                frames = self.runtime.read_frames()
                if frames:
                    for frame in frames:
                        self.rx_count += 1
                        self.last_rx_ts = time.strftime("%H:%M:%S")
                        self.last_rx_frame = f"ID: 0x{frame['id']:03X} Data: {' '.join([f'{b:02X}' for b in frame['data']])}"
                        self._process_frame(frame)
                else:
                    time.sleep(0.005)
            except Exception as e:
                self.last_error = f"Erro RX: {e}"
                time.sleep(0.1)

    def stop(self):
        self.running = False

    def _process_frame(self, frame):
        can_id = frame["id"]
        data = frame["data"]
        
        # 1. Atualizar tabela REAL-TIME (sempre)
        self.update_id_state(can_id, data, "RX")

        # 2. Atualizar tabela de monitorização original (apenas se o RAW mudar)
        if can_id in self.id_table:
            raw_hex = " ".join(f"{b:02X}" for b in data)
            if self.id_table[can_id]["last_raw"] != raw_hex:
                self.id_table[can_id]["last_raw"] = raw_hex
                self.id_table[can_id]["last_ts"] = time.strftime("%H:%M:%S")
        
        # Filtragem de Echo
        if self._is_local_frame(can_id, data):
            return

        # 1. Sincronização de Tempo
        if can_id in [0x5E2, 0x12F] and len(data) >= 8:
            self._handle_time_sync(can_id, data)
            
        # 2. Modo e Frequência de Rádio (0x114)
        elif can_id == 0x114 and len(data) >= 8:
            self.last_external_radio_ts = time.monotonic()
            self._handle_radio_status(data)
            
        # 3. ISO-TP para Labels (Nome da Estação/BT)
        elif can_id in [0x4E8, 0x485]:
            self.last_external_radio_ts = time.monotonic()
            self._handle_isotp(can_id, data)

    def _is_local_frame(self, can_id, data):
        """Verifica se o frame recebido é um eco da nossa própria transmissão."""
        if not self.tx_engine: return False
        
        # Se for rádio (0x114), comparamos com o modo/frequência atual do Node A
        if can_id == 0x114:
            # Simplificação: Se o rádio do Node A estiver ativo, e o ID coincidir, 
            # assumimos que pode ser echo se não houver atividade externa recente comprovada.
            # Mas a forma mais segura é comparar o payload.
            pass
        return False # Por padrão processamos tudo, a lógica de prioridade será no TX

    def _handle_radio_status(self, data):
        """Descodifica o ID 0x114 (Modo e Frequência)."""
        mode_byte = data[0]
        if mode_byte == 0x11: self.radio_mode = "FM"
        elif mode_byte == 0x14: self.radio_mode = "AM"
        elif mode_byte == 0x08: self.radio_mode = "BT"
        else: self.radio_mode = f"HEX(0x{mode_byte:02X})"
        
        raw_freq = (data[6] << 8) | data[7]
        if self.radio_mode == "FM":
            mhz = (raw_freq / 320.0) + 87.5
            self.radio_freq = f"{mhz:.1f} MHz"
        elif self.radio_mode == "AM":
            khz = (raw_freq * 9 / 16) + 517
            self.radio_freq = f"{int(khz)} KHz"
        else:
            self.radio_freq = "N/A"
            
        if 0x114 in self.id_table:
            self.id_table[0x114]["decoded"] = f"{self.radio_mode} {self.radio_freq}"

    def _handle_isotp(self, can_id, data):
        """Reconstrói strings ISO-TP (Segmentadas)."""
        if not data: return
        
        pci = data[0] & 0xF0
        buf = self.isotp_buffers[can_id]

        if pci == 0x10: # First Frame
            length = ((data[0] & 0x0F) << 8) | data[1]
            buf["len"] = length
            buf["data"] = bytearray(data[2:])
            buf["sn"] = 1
        elif pci == 0x20: # Consecutive Frame
            if buf["len"] > 0:
                buf["data"].extend(data[1:])
                buf["sn"] += 1
                
        # Se temos dados suficientes para o label
        if len(buf["data"]) >= buf["len"] and buf["len"] > 0:
            try:
                full_payload = buf["data"][:buf["len"]]
                raw_bytes = full_payload
                if can_id == 0x485 and len(full_payload) > 0 and full_payload[0] == 0x03:
                    raw_bytes = full_payload[1:]
                
                label = raw_bytes.decode('utf-16-le', errors='ignore').strip()
                if label:
                    self.radio_label = label
                    if can_id in self.id_table:
                        self.id_table[can_id]["decoded"] = f"'{label}'"
            except:
                pass
            buf["len"] = 0 # Reset buffer

    def _handle_time_sync(self, can_id, data):
        """Decodifica o frame de tempo e atualiza o relógio do sistema."""
        try:
            if can_id == 0x5E2:
                year = 2000 + data[1]
                hour = data[2]
                minute = data[3]
                second = data[4]
                day = data[5]
                month = (data[6] - 1) // 4
            else: # 0x12F
                hour = data[1]
                minute = data[2]
                second = data[3]
                month = (data[4] - 1) // 4
                year = 2000 + data[5]
                day = data[6]

            if not (1 <= month <= 12 and 1 <= day <= 31 and 0 <= hour <= 23):
                return

            # Formato para o comando date: "YYYY-MM-DD HH:MM:SS"
            new_time_str = f"{year:04d}-{month:02d}-{day:02d} {hour:02d}:{minute:02d}:{second:02d}"
            
            # Atualizar coluna de descodificação
            if can_id in self.id_table:
                self.id_table[can_id]["decoded"] = new_time_str
                
            # Debug: Mostrar sempre o último frame de tempo interpretado (mesmo que igual ao anterior)
            self.last_parsed_time = new_time_str
            
            # Só atualiza se for diferente (evitar spam de comandos de sistema)
            if new_time_str != self.last_sync_time:
                self._set_system_date(new_time_str)
                self.last_sync_time = new_time_str

        except Exception as e:
            self.last_error = f"Erro Decodificação: {e}"

    def _set_system_date(self, date_str):
        """Executa o comando de sistema para alterar a data/hora."""
        try:
            cmd = ["sudo", "date", "-s", date_str]
            subprocess.run(cmd, check=True, capture_output=True)
        except subprocess.CalledProcessError as e:
            self.last_error = f"Erro Sudo Date: {e.stderr.decode().strip()}"
        except Exception as e:
            self.last_error = f"Erro Inesperado: {e}"
