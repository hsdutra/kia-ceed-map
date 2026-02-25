import time
import serial
import threading

class CanRuntime:
    """Gerencia a interface física com o CANable v2.0 Pro S."""

    def __init__(self, port, bitrate_code):
        self.port = port
        self.bitrate_code = bitrate_code
        self.ser = None
        self.lock = threading.Lock() # Garante acesso atómico ao hardware

    def connect(self):
        try:
            print(f"[Runtime] Abrindo porta {self.port} a 115200 bps...")
            self.ser = serial.Serial(self.port, 115200, timeout=0.1)
            
            with self.lock:
                # Protocolo Lawicel
                self._send_command_unlocked("C")          
                self._send_command_unlocked(self.bitrate_code) 
                self._send_command_unlocked("O")          
            
            print(f"[Runtime] CAN conectado e operando em {self.bitrate_code}")
            return True
        except Exception as e:
            print(f"[Runtime] ERRO na conexão: {e}")
            return False

    def disconnect(self):
        with self.lock:
            if self.ser and self.ser.is_open:
                self._send_command_unlocked("C")
                self.ser.close()
                print("[Runtime] CAN desconectado.")

    def send_frame(self, can_id, data):
        """Envia um frame CAN padrão (11-bit)."""
        if not self.ser or not self.ser.is_open: return
        
        id_hex = f"{can_id:03X}"
        length = len(data)
        data_hex = "".join([f"{b:02X}" for b in data])
        raw_cmd = f"t{id_hex}{length}{data_hex}\r"

        with self.lock:
            self.ser.write(raw_cmd.encode())

    def read_frames(self):
        """Lê todos os frames pendentes no buffer e retorna uma lista."""
        if not self.ser or not self.ser.is_open: return []
        
        frames = []
        with self.lock:
            if self.ser.in_waiting > 0:
                raw_data = self.ser.read(self.ser.in_waiting)
                parts = raw_data.decode(errors='ignore').split('\r')
                
                for part in parts:
                    line = part.strip()
                    if line.startswith('t') and len(line) >= 5:
                        try:
                            can_id = int(line[1:4], 16)
                            length = int(line[4:5])
                            data_str = line[5:5+(length*2)]
                            data = [int(data_str[i:i+2], 16) for i in range(0, len(data_str), 2)]
                            frames.append({"id": can_id, "data": data})
                        except Exception:
                            continue
        return frames

    def _send_command_unlocked(self, cmd):
        """Versão interna sem lock para uso em métodos que já possuem o lock."""
        if self.ser and self.ser.is_open:
            self.ser.write(f"{cmd}\r".encode())
            time.sleep(0.01)
