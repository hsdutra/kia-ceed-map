# KIA CEED 2015 - CAN TIME SIMULATOR (v1.0)
# Suporte: Sincronizacao de Data e Hora (ID 0x5E2)
# Controles: Setas Cima/Baixo (Hora), Esq/Dir (Minuto)
# ==========================================================

# --- Configurações ---
$Port         = "COM3"
$Bitrate      = "S3"     # 100 kbps
$UpdateEveryMs = 1000    # Injecao a cada 1 segundo (conforme logs)

# --- Funções Internas ---
function BytesToHex([int[]]$b) { ($b | ForEach-Object { "{0:X2}" -f ($_ -band 0xFF) }) -join "" }
function BuildFrame([int]$id, [int[]]$data) { "t{0:X3}{1:X1}{2}" -f $id, $data.Count, (BytesToHex $data) }
function Send-SLCAN($sp, $cmd) { if($sp.IsOpen){ $sp.Write($cmd + "`r") } }
function Clear-HostSafe { try { Clear-Host } catch {} }

function Build5E2Frame($dateTime) {
    # Mapeamento do log: 4E YY HH MM SS DD MON_ENC CF
    $yearShort = $dateTime.Year % 100
    $monEnc    = ($dateTime.Month * 4) + 1
    $data = @(
        0x4E,              # Fixo
        $yearShort,        # Ano (ex: 14)
        $dateTime.Hour,    # Hora
        $dateTime.Minute,  # Minuto
        $dateTime.Second,  # Segundo
        $dateTime.Day,     # Dia
        $monEnc,           # Mês Encodado (Month*4+1)
        0xCF               # Fixo
    )
    return BuildFrame 0x5E2 $data
}

function Build12FFrame($dateTime) {
    # Mapeamento do script fornecido: 4E HH MM SS MONenc YY DD CF
    # Nota: O script de patch usava index 7 como check? ou fixo. 
    # Usaremos 0xCF para manter padrão do log.
    $yearShort = $dateTime.Year % 100
    $monEnc    = ($dateTime.Month * 4) + 1
    $data = @(
        0x4E,
        $dateTime.Hour,
        $dateTime.Minute,
        $dateTime.Second,
        $monEnc,
        $yearShort,
        $dateTime.Day,
        0xCF
    )
    return BuildFrame 0x12F $data
}

# --- Loop Interativo ---
function Run-TimeSimulator($sp, $mode) {
    $currentDateTime = Get-Date
    $lastSend = 0
    $fields = @("DAY", "MONTH", "YEAR", "HOUR", "MINUTE")
    $fieldIdx = 0 # Inicia no Dia
    
    Write-Host "Iniciando Simulador de Tempo (Modo: $mode). Pressione Q para sair." -ForegroundColor Yellow
    
    while($true) {
        if ($mode -eq "AUTO") {
            $currentDateTime = Get-Date
        }

        if (([Environment]::TickCount - $lastSend) -gt $UpdateEveryMs) {
            $frame5E2 = Build5E2Frame $currentDateTime
            $frame12F = Build12FFrame $currentDateTime
            
            Send-SLCAN $sp $frame5E2
            Start-Sleep -Milliseconds 10 # Pequeno delay entre frames
            Send-SLCAN $sp $frame12F
            
            Clear-HostSafe
            Write-Host "==============================================="
            Write-Host " SIMULADOR DE TEMPO KIA CEED (DUAL BUS)"
            Write-Host "==============================================="
            Write-Host " MODO: $mode"
            
            Write-Host -NoNewline " DATA: "
            if ($mode -eq "MANUAL" -and $fields[$fieldIdx] -eq "DAY")   { Write-Host -NoNewline "$($currentDateTime.Day.ToString('00'))" -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline "$($currentDateTime.Day.ToString('00'))" }
            Write-Host -NoNewline "/"
            if ($mode -eq "MANUAL" -and $fields[$fieldIdx] -eq "MONTH") { Write-Host -NoNewline "$($currentDateTime.Month.ToString('00'))" -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline "$($currentDateTime.Month.ToString('00'))" }
            Write-Host -NoNewline "/"
            if ($mode -eq "MANUAL" -and $fields[$fieldIdx] -eq "YEAR")  { Write-Host -NoNewline "$($currentDateTime.Year)" -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline "$($currentDateTime.Year)" }
            Write-Host ""

            Write-Host -NoNewline " HORA: "
            if ($mode -eq "MANUAL" -and $fields[$fieldIdx] -eq "HOUR")   { Write-Host -NoNewline "$($currentDateTime.Hour.ToString('00'))" -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline "$($currentDateTime.Hour.ToString('00'))" }
            Write-Host -NoNewline ":"
            if ($mode -eq "MANUAL" -and $fields[$fieldIdx] -eq "MINUTE") { Write-Host -NoNewline "$($currentDateTime.Minute.ToString('00'))" -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline "$($currentDateTime.Minute.ToString('00'))" }
            Write-Host -NoNewline ":$($currentDateTime.Second.ToString('00'))"
            Write-Host ""

            Write-Host ""
            if ($mode -eq "MANUAL") {
                Write-Host " [TAB]               Trocar Campo ($($fields[$fieldIdx]))"
                Write-Host " [Setas Cima/Baixo]  Ajustar valor"
            }
            Write-Host " [Q ou ESC]          Voltar ao Menu"
            Write-Host "==============================================="
            Write-Host " CAN 5E2: $frame5E2" -ForegroundColor Gray
            Write-Host " CAN 12F: $frame12F" -ForegroundColor Gray
            
            $lastSend = [Environment]::TickCount
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($mode -eq "MANUAL") {
                if ($key.Key -eq "Tab") { 
                    $fieldIdx = ($fieldIdx + 1) % $fields.Count
                    $lastSend = 0 # Forçar refresh visual imediato 
                }
                if ($key.Key -eq "UpArrow") { 
                    switch ($fields[$fieldIdx]) {
                        "DAY"    { $currentDateTime = $currentDateTime.AddDays(1) }
                        "MONTH"  { $currentDateTime = $currentDateTime.AddMonths(1) }
                        "YEAR"   { $currentDateTime = $currentDateTime.AddYears(1) }
                        "HOUR"   { $currentDateTime = $currentDateTime.AddHours(1) }
                        "MINUTE" { $currentDateTime = $currentDateTime.AddMinutes(1) }
                    }
                    $lastSend = 0
                }
                if ($key.Key -eq "DownArrow") { 
                    switch ($fields[$fieldIdx]) {
                        "DAY"    { $currentDateTime = $currentDateTime.AddDays(-1) }
                        "MONTH"  { $currentDateTime = $currentDateTime.AddMonths(-1) }
                        "YEAR"   { $currentDateTime = $currentDateTime.AddYears(-1) }
                        "HOUR"   { $currentDateTime = $currentDateTime.AddHours(-1) }
                        "MINUTE" { $currentDateTime = $currentDateTime.AddMinutes(-1) }
                    }
                    $lastSend = 0
                }
            }
            if ($key.Key -eq "Escape" -or $key.Key -eq "Q") { return }
        }
        Start-Sleep -Milliseconds 50
    }
}

# --- Main ---
$sp = New-Object System.IO.Ports.SerialPort $Port,115200,None,8,one
try {
    Write-Host "Abrindo porta $Port..." -ForegroundColor Gray
    $sp.Open()
    Send-SLCAN $sp "C" ; Send-SLCAN $sp $Bitrate ; Send-SLCAN $sp "O"
    
    while($true){
        Clear-HostSafe
        Write-Host " KIA CEED 2015 TIME SIMULATOR"
        Write-Host " 1) Sincronizar com Relogio do PC (AUTO)"
        Write-Host " 2) Ajuste Manual (Setas)"
        Write-Host " 0) Sair"
        $opt = Read-Host "`nEscolha uma opcao"
        
        switch ($opt) {
            "1" { Run-TimeSimulator $sp "AUTO" }
            "2" { Run-TimeSimulator $sp "MANUAL" }
            "0" { break }
        }
    }
} catch {
    Write-Error $_.Exception.Message
} finally {
    if($sp.IsOpen){ Send-SLCAN $sp "C"; $sp.Close() }
    Write-Host "`nFinalizado."
}
