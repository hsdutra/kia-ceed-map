# KIA CEED 2015 - CAN ICON ACTIVATOR (v1.5 - Final Tab Control)
# Objetivo: Ligar/Desligar as abas de Midia e GPS no Cluster. 🚀

# --- Configurações ---
$Port         = "COM3"
$Bitrate      = "S3"     
$UpdateDelay  = 100     

# --- Grupos de Teste ---
$Toggles = @{
    # 1. BUNDLE DE PODER (Resolve o Loading)
    "1" = @{ Name = "PODER 1: Heartbeats (Resolve Loading)"; Active = $false; IDs = @(
            @{ ID = 0x100; Data = @(0x62, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x114; Data = @(0x08, 0x60, 0x00, 0x01, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x115; Data = @(0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x506; Data = @(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x00) }
          )}

    # 2. ABA MUSICAL (Nota)
    "2" = @{ Name = "ABA 3: Visibilidade Musica (0x169=40, 1EB=01)"; Active = $false; IDs = @(
            @{ ID = 0x169; Data = @(0x40, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x1EB; Data = @(0x01, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) }
          )}

    # 3. ABA GPS (Seta)
    "3" = @{ Name = "ABA 2: Visibilidade GPS (0x169=80, 1EB=02)"; Active = $false; IDs = @(
            @{ ID = 0x169; Data = @(0x80, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x1EB; Data = @(0x02, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) }
          )}

    # 4. AMBAS AS ABAS
    "4" = @{ Name = "ABAS 2+3: (Musical + GPS) (0x169=C0, 1EB=03)"; Active = $false; IDs = @(
            @{ ID = 0x169; Data = @(0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) },
            @{ ID = 0x1EB; Data = @(0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) }
          )}

    # 5. GPS HEARTBEAT (Necessario para ABA 2 não sumir)
    "5" = @{ Name = "GPS ALIVE: (Heartbeat 0x120 - 4 bytes)"; Active = $false; IDs = @(
            @{ ID = 0x120; Data = @(0x00, 0x00, 0x00, 0x00) }
          )}
}

# --- Funções SLCAN (Simples, sem formatacao complexa) ---
function Send-CAN-Internal($sp, $id, $binData) {
    if ($sp.IsOpen) {
        $idStr = $id.ToString("X3")
        $len = $binData.Count
        $hex = ""
        foreach($b in $binData) { $hex += $b.ToString("X2") }
        $msg = "t" + $idStr + $len.ToString() + $hex + "`r"
        $sp.Write($msg)
    }
}

function Clear-Host-Safe { try { [Console]::Clear() } catch { Clear-Host } }

# --- Inicialização ---
$sp = New-Object System.IO.Ports.SerialPort($Port, 115200, "None", 8, "One")

try {
    Write-Host "Abrindo $Port..."
    $sp.Open()
    $sp.Write("C`r")
    $sp.Write("S3`r")
    $sp.Write("O`r")
    
    $lastHB = 0

    while ($true) {
        $now = [Environment]::TickCount
        if (($now - $lastHB) -gt $UpdateDelay) {
            foreach ($key in $Toggles.Keys | Sort-Object) {
                if ($Toggles[$key].Active) {
                    foreach ($msg in $Toggles[$key].IDs) {
                        Send-CAN-Internal $sp $msg.ID $msg.Data
                    }
                }
            }
            $lastHB = $now
            
            # UI
            Clear-Host-Safe
            Write-Host "==============================================="
            Write-Host " KIA CEED 2015 - CONTROLE DE ABAS v1.5"
            Write-Host "==============================================="
            foreach ($k in $Toggles.Keys | Sort-Object) {
                $status = if ($Toggles[$k].Active) { "LIGADO" } else { "---" }
                $color = if ($Toggles[$k].Active) { "Green" } else { "DarkGray" }
                Write-Host " $k) [$status] $($Toggles[$k].Name)" -ForegroundColor $color
            }
            Write-Host "==============================================="
            Write-Host " [Q] Sair"
            Write-Host " DICA: Ligue a 1 e depois tente a 2, 3 ou 4."
        }

        if ([Console]::KeyAvailable) {
            $char = [Console]::ReadKey($true).KeyChar.ToString()
            if ($Toggles.ContainsKey($char)) { 
                $Toggles[$char].Active = -not $Toggles[$char].Active 
                $lastHB = 0 
            }
            if ($char -eq 'q') { break }
        }
        Start-Sleep -Milliseconds 20
    }
}
catch { Write-Error "Erro: $($_.Exception.Message)" }
finally { 
    if ($sp.IsOpen) { $sp.Write("C`r"); $sp.Close() }
    Write-Host "Finalizado."
}
