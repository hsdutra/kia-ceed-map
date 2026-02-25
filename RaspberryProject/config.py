import os

# =================================================================
# KIA CEED 2015 - CENTRAL CONFIGURATION (Raspberry Node A)
# =================================================================

# --- Toggles de Emissão ---
ENABLE_RADIO_EMISSION = True  # IDs de Rádio, Ícones e ISO-TP Texto
ENABLE_CLOCK_EMISSION = True  # IDs de Data e Hora

# --- Overrides Técnicos (Deixar None para Auto-detecção) ---
OVERRIDE_BITRATE = "S3"       # Fixado para Kia Ceed 100kbps
OVERRIDE_INTERFACE = "slcan"  # Modo CANable Pro S
OVERRIDE_PORT = "/dev/ttyACM0" # Detetado via ls /dev/ttyACM*

# --- Caminhos do Projeto (Opcional) ---
MANUAL_FILE = os.path.join(os.path.dirname(__file__), "..", "MANUAL_TECNICO_V3.md")

# --- Bases de Dados (Extraídas dos testes originais) ---
RADIO_STATIONS = [
    # FM (ID 0x11)
    {"band": "FM", "name": "CITY FM", "mhz": 106.2, "label": "CIDADEFM 106.2"},
    {"band": "FM", "name": "M80 RADIO", "mhz": 104.3, "label": "M80 PORTUGAL"},
    {"band": "FM", "name": "TEST STATION", "mhz": 93.6, "label": "RADIO TEST 1"},
    
    # AM (ID 0x14)
    {"band": "AM", "name": "AM Calib Low", "khz": 531,  "label": "AM CALIB 531"},
    {"band": "AM", "name": "AM Calib High", "khz": 1602, "label": "AM CALIB 1602"},
    
    # Bluetooth (ID 0x08)
    {"band": "BT", "name": "Track 01", "label": "ARTIST - SONG 1"},
    {"band": "BT", "name": "Track 02", "label": "PODCAST KIA 2"},
    {"band": "BT", "name": "Track 03", "label": "LIVE STREAM BT"}
]

# --- Parâmetros de Performance ---
DEFAULT_HZ_RADIO = 10         # Heartbeat vital (10Hz = 100ms)
DEFAULT_HZ_CLOCK = 1          # Sync de tempo (1Hz = 1000ms)
ISOTP_TEXT_DELAY = 0.4        # Delay entre atualizações de texto (segundos)
ISOTP_GAP_MS = 15             # Gap entre frames ISO-TP (milissegundos)

# --- Heurística Raspberry ---
DEFAULT_RASPBERRY_PORT = "/dev/ttyACM0"
DEFAULT_BITRATE_CODE = "S3"   # 100 kbps SLCAN
