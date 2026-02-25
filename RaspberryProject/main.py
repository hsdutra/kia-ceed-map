import signal
import sys
import time
import os
from project_introspector import ProjectIntrospector
from can_runtime import CanRuntime
from tx_engine import TxEngine
from rx_engine import RxEngine
import config
import threading

# Global variables for engines and runtime to be accessible by signal handler
tx_engine = None
rx_engine = None
can_runtime = None

def signal_handler(sig, frame):
    print('\n[Main] Encerrando simulador...')
    global tx_engine, rx_engine, can_runtime
    if tx_engine:
        tx_engine.stop()
    if rx_engine:
        rx_engine.stop()
    if can_runtime:
        can_runtime.disconnect()
    sys.exit(0)

signal.signal(signal.SIGINT, signal_handler)

def main():
    global tx_engine, rx_engine, can_runtime # Declare global to allow signal_handler access
    print("==================================================")
    print(" KIA CEED CAN SIMULATOR - RASPBERRY NODE A")
    print("==================================================")
    
    # 1. Introspecção do Projeto (Apenas para configurações de barramento, se necessário)
    intro = ProjectIntrospector()
    params = intro.auto_detect()
    
    # Dados carregados diretamente do config.py (sem dependência de .ps1 externos)
    stations = config.RADIO_STATIONS
        
    print(f"[Main] Configurações de Barramento:")
    print(f"  - Bitrate:   {params['bitrate']}")
    print(f"  - Interface: {params['interface']}")
    print(f"  - Porta:     {params['port']}")
    print(f"  - Módulos Ativos: Rádio={config.ENABLE_RADIO_EMISSION}, Relógio={config.ENABLE_CLOCK_EMISSION}")
    
    # 2. Inicialização do Barramento
    can_runtime = CanRuntime(params["port"], params["bitrate"])
    if not can_runtime.connect():
        print("[ERRO] Falha ao inicializar o CANable. Verifique a ligação.")
        sys.exit(1)
        
    # 4. Verificação de Permissões (Crítico para Relógio)
    if config.ENABLE_CLOCK_EMISSION and os.geteuid() != 0:
        print("\n[AVISO] A sincronização de relógio de sistema requer 'sudo'.")
        print("        O programa continuará, mas não conseguirá alterar a hora do Raspberry.\n")

    # 5. Inicialização dos Motores TX e RX
    rx_engine = RxEngine(can_runtime)
    tx_engine = TxEngine(can_runtime, stations, rx_engine)
    rx_engine.tx_engine = tx_engine # Link bidirecional para filtragem de echo
    
    try:
        # Iniciar RX numa thread separada (Escuta contínua)
        rx_thread = threading.Thread(target=rx_engine.start, daemon=True)
        rx_thread.start()

        # Iniciar TX no loop principal (Envio periódico + Dashboard)
        tx_engine.start()

    except KeyboardInterrupt:
        print("\n\n[Main] Encerrando simulador...")
    finally:
        if tx_engine:
            tx_engine.stop()
        if rx_engine:
            rx_engine.stop()
        if can_runtime:
            can_runtime.disconnect()
        print("[Main] Finalizado.")

if __name__ == "__main__":
    main()
