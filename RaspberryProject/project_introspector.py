import os
import re
import config

class ProjectIntrospector:
    """Explora os ficheiros do projeto para extrair configurações sem Hardcoding."""

    def __init__(self):
        self.bitrate = config.OVERRIDE_BITRATE
        self.interface = config.OVERRIDE_INTERFACE
        self.port = config.OVERRIDE_PORT
        self.detected_sources = {}

    def auto_detect(self):
        print("[Introspector] Iniciando auto-detecção...")
        
        # 1. Detecção de Bitrate
        if not self.bitrate:
            self._detect_bitrate()
        
        # 2. Detecção de Interface e Porta
        if not self.interface or not self.port:
            self._detect_hardware()

        return {
            "bitrate": self.bitrate or config.DEFAULT_BITRATE_CODE,
            "interface": self.interface or "slcan",
            "port": self.port or config.DEFAULT_RASPBERRY_PORT,
            "sources": self.detected_sources
        }

    def _detect_bitrate(self):
        # Procura por "100 kbps" ou "S3" em manuais e scripts
        files_to_scan = [config.MANUAL_FILE]
        if os.path.exists(config.SIMULATOR_DIR):
            for f in os.listdir(config.SIMULATOR_DIR):
                if f.endswith(".ps1"):
                    files_to_scan.append(os.path.join(config.SIMULATOR_DIR, f))

        for file_path in files_to_scan:
            if not os.path.exists(file_path): continue
            
            with open(file_path, "r", encoding="utf-8", errors="ignore") as f:
                content = f.read()
                # Regex para "S3" ou "100 kbps"
                match = re.search(r'Bitrate\s*=\s*"([^"]+)"|S([0-8])|100\s*kbps', content, re.IGNORECASE)
                if match:
                    self.bitrate = "S3" # Mapeia para código Lawicel detectado
                    self.detected_sources["bitrate"] = f"{os.path.basename(file_path)}: {match.group(0)}"
                    print(f"[Introspector] Bitrate detetado: S3 (100 kbps) em {os.path.basename(file_path)}")
                    break

    def _detect_hardware(self):
        # Heurística baseada no ambiente e scripts
        if os.name == 'posix': # Raspberry/Linux
            self.interface = "slcan"
            if os.path.exists("/dev/ttyACM0"):
                self.port = "/dev/ttyACM0"
            elif os.path.exists("/dev/ttyUSB0"):
                self.port = "/dev/ttyUSB0"
            self.detected_sources["port"] = "Ambiente POSIX (Raspberry Heuristic)"
        else:
            self.port = "COM3" # Fallback Windows test
            self.interface = "slcan"
            self.detected_sources["port"] = "Ambiente Windows (Fallback COM3)"

    def extract_radio_data(self):
        """Extrai a lista de estações do script PowerShell."""
        radio_file = os.path.join(config.SIMULATOR_DIR, "fake_radio_menu.ps1")
        print(f"[Introspector] Procurando dados em: {radio_file}")
        
        stations = []
        if not os.path.exists(radio_file):
            print(f"[Aviso] Ficheiro não encontrado: {radio_file}")
            print(f"        Certifique-se de que a pasta 'simulador' está no mesmo nível da 'RaspberryProject'.")
            return stations

        with open(radio_file, "r", encoding="utf-8", errors="ignore") as f:
            content = f.read()
            # Regex mais flexível para capturar objetos @{ Band=... }
            entries = re.findall(r'@\s*{\s*Band\s*=\s*"[^"]+"[^}]+}', content, re.IGNORECASE)
            for entry in entries:
                station = {}
                band_match = re.search(r'Band\s*=\s*"([^"]+)"', entry, re.IGNORECASE)
                name_match = re.search(r'Name\s*=\s*"([^"]+)"', entry, re.IGNORECASE)
                label_match = re.search(r'Label\s*=\s*"([^"]+)"', entry, re.IGNORECASE)
                mhz_match = re.search(r'MHz\s*=\s*([\d.]+)', entry, re.IGNORECASE)
                khz_match = re.search(r'KHz\s*=\s*(\d+)', entry, re.IGNORECASE)
                
                if band_match: station["band"] = band_match.group(1)
                if name_match: station["name"] = name_match.group(1)
                if label_match: station["label"] = label_match.group(1)
                if mhz_match: station["mhz"] = float(mhz_match.group(1))
                if khz_match: station["khz"] = int(khz_match.group(1))
                
                if station: stations.append(station)
        
        print(f"[Introspector] {len(stations)} entradas de rádio extraídas de fake_radio_menu.ps1")
        return stations

if __name__ == "__main__":
    intro = ProjectIntrospector()
    print(intro.auto_detect())
    print(intro.extract_radio_data())
