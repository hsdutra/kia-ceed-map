# KIA CEED 2015 - CAN SIMULATOR COMPLETO (v3.0)
# Combina: Sincronizacao de Tempo + Controlo de Radio (FM/AM/BT)
# ==========================================================

# --- Configuracoes ---
$Port          = "COM3"
$Bitrate       = "S3"      # 100 kbps
$UpdateEveryMs = 1000      # Injecao de tempo a cada 1 segundo
$Hz114         = 10        # Frequencia de atualizacao de radio (10Hz)
$LabelEveryMs  = 400       # Frequencia do nome ISO-TP (ms)
$IsoTpGapMs    = 15        # Delay entre pacotes ISO-TP (ms)

# --- Base de Dados de Estacoes e Faixas ---
$RadioData = @(
    @{ Band="FM"; Name="CIDADE FM";       MHz=106.2; KHz=0; Label="CIDADEFM 106.2" },
    @{ Band="FM"; Name="M80 RADIO";     MHz=104.3; KHz=0; Label="M80 PORTUGAL"  },
    @{ Band="FM"; Name="TEST STATION";  MHz=93.6;  KHz=0; Label="RADIO TEST 1"  },
    @{ Band="FM"; Name="TEST GRANDE";   MHz=94.8;  KHz=0; Label="TESTE COM NOME GRANDE PARA SER EXIBIDO" },
    @{ Band="AM"; Name="AM Calib Low";  MHz=0; KHz=531;   Label="AM CALIB 531"  },
    @{ Band="AM"; Name="AM Calib High"; MHz=0; KHz=1602;  Label="AM CALIB 1602" },
    @{ Band="AM"; Name="LOCAL AM 1";    MHz=0; KHz=999;   Label="LOCAL AM 999"  },
    @{ Band="BT"; Name="Track 01";      MHz=0; KHz=0;     Label="ARTIST - SONG 1" },
    @{ Band="BT"; Name="Track 02";      MHz=0; KHz=0;     Label="PODCAST KIA 2" },
    @{ Band="BT"; Name="Track 03";      MHz=0; KHz=0;     Label="LIVE STREAM BT" },
    @{ Band="BT"; Name="Track 04";      MHz=0; KHz=0;     Label="Our Lawyer Made Us Change The Name Of This Song So We Wouldn't Get Sued" }
)

# ==========================================================
# --- Funcoes Utilitarias ---
# ==========================================================
function BytesToHex([int[]]$b) { ($b | ForEach-Object { "{0:X2}" -f ($_ -band 0xFF) }) -join "" }
function BuildFrame([int]$id, [int[]]$data) { "t{0:X3}{1:X1}{2}" -f $id, $data.Count, (BytesToHex $data) }
function Send-SLCAN($sp, $cmd) { if ($sp.IsOpen) { $sp.Write($cmd + "`r") } }
function Clear-HostSafe { try { Clear-Host } catch {} }

# ==========================================================
# --- Leitura de Hora do Node A ---
# ==========================================================
function Read-NodeATime($sp, [int]$timeoutSec = 6) {
    <#
      Limpa buffer e tenta capturar um frame genuíno do Node A.
    #>
    Write-Host "  Limpando buffer serial..." -ForegroundColor Gray
    $sp.DiscardInBuffer()
    # Leitura exaustiva para garantir que limpamos tudo
    while ($sp.BytesToRead -gt 0) { $null = $sp.ReadExisting(); Start-Sleep -Milliseconds 50 }

    $deadline = (Get-Date).AddSeconds($timeoutSec)
    Write-Host "  Escaneando barramento (Node A Master)..." -ForegroundColor Yellow
    Write-Host "  (Timeout em ${timeoutSec}s)" -ForegroundColor Gray

    while ((Get-Date) -lt $deadline) {
        try {
            if ($sp.BytesToRead -gt 0) {
                $lines = $sp.ReadExisting().Split("`r")
                foreach ($l in $lines) {
                    $line = $l.Trim()
                    if ($line.Length -ge 5 -and $line.StartsWith("t")) {
                        $idStr = $line.Substring(1, 3)
                        # Feedback visual rápido
                        Write-Host -NoNewline "." -ForegroundColor Gray
                        
                        try {
                            $id  = [Convert]::ToInt32($idStr, 16)
                            $len = [int]$line.Substring(4,1)
                            if (($id -eq 0x5E2 -or $id -eq 0x12F) -and $line.Length -ge (5 + $len*2)) {
                                $hex   = $line.Substring(5, $len*2)
                                $bytes = (0..($len-1) | ForEach-Object { [Convert]::ToInt32($hex.Substring($_*2,2),16) })
                                if ($bytes.Count -gt 6) {
                                    if ($id -eq 0x5E2) {
                                        $year  = 2000 + $bytes[1]; $hour = $bytes[2]; $min = $bytes[3]
                                        $day   = $bytes[5]; $month = [int](($bytes[6]-1)/4)
                                    } else {
                                        $hour  = $bytes[1]; $min = $bytes[2]
                                        $month = [int](($bytes[4]-1)/4)
                                        $year  = 2000 + $bytes[5]; $day = $bytes[6]
                                    }
                                    if ($month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31) {
                                        Write-Host "`n  [OK] Frame 0x$idStr capturado do Node A!" -ForegroundColor Green
                                        $dtStr = "{0:D2}/{1:D2}/{2} {3:D2}:{4:D2}" -f $day, $month, $year, $hour, $min
                                        Write-Host "  HORA DO CARRO: $dtStr" -ForegroundColor Green
                                        Start-Sleep -Milliseconds 800
                                        return Get-Date -Year $year -Month $month -Day $day -Hour $hour -Minute $min -Second 0
                                    }
                                }
                            }
                        } catch { }
                    }
                }
            }
        } catch { }
        Start-Sleep -Milliseconds 100
    }
    Write-Host "`n  [AVISO] Node A nao detectado." -ForegroundColor Red
    return $null
}

# ==========================================================
# --- Funcoes de TEMPO ---
# ==========================================================
function Build5E2Frame($dt) {
    $y = $dt.Year % 100
    $m = ($dt.Month * 4) + 1
    BuildFrame 0x5E2 @(0x4E, $y, $dt.Hour, $dt.Minute, $dt.Second, $dt.Day, $m, 0xCF)
}

function Build12FFrame($dt) {
    $y = $dt.Year % 100
    $m = ($dt.Month * 4) + 1
    BuildFrame 0x12F @(0x4E, $dt.Hour, $dt.Minute, $dt.Second, $m, $y, $dt.Day, 0xCF)
}

function Run-TimeSimulator($sp, $mode) {
    if ($mode -eq "MANUAL") {
        # Node A e a fonte primaria do tempo — ler a hora actual do barramento
        $dt = Read-NodeATime $sp
        if (-not $dt) {
            Write-Host ""
            Write-Host "  [ERRO] Node A nao respondeu ou esta em silencio." -ForegroundColor Red
            Write-Host "  O Modo Manual requer acesso aos dados do carro para ajuste." -ForegroundColor DarkYellow
            Write-Host "  Verifique se o Raspberry Pi (Node A) esta ligado e a emitir." -ForegroundColor Gray
            Write-Host "  Pressione ENTER para voltar ao menu." -ForegroundColor Gray
            Read-Host | Out-Null
            return
        }
    } else {
        # Modo AUTO: Sincroniza com o relógio do PC (Node B)
        $dt = Get-Date
    }

    $lastHeartbeat = 0
    $needsDisplay   = $true
    $needsSend      = ($mode -eq "AUTO") # Envia logo se for AUTO. Se for MANUAL, aguarda interacao.
    $fields         = @("DAY", "MONTH", "YEAR", "HOUR", "MINUTE")
    $fi             = 0

    while ($true) {
        # Lógica de atualização periódica (apenas para exibição ou Modo AUTO)
        if ($mode -eq "AUTO") {
            $dt = Get-Date
            if (([Environment]::TickCount - $lastHeartbeat) -gt $UpdateEveryMs) {
                $needsSend = $true
            }
        }

        # Envio de Frames CAN (Apenas quando necessário ou periodicamente em AUTO)
        if ($needsSend) {
            $f5E2 = Build5E2Frame $dt
            $f12F = Build12FFrame $dt
            Send-SLCAN $sp $f5E2
            Start-Sleep -Milliseconds 10
            Send-SLCAN $sp $f12F
            
            $lastHeartbeat = [Environment]::TickCount
            $needsSend     = ($mode -eq "AUTO") # Reset para MANUAL; contínuo para AUTO
            $needsDisplay   = $true
        }

        # Atualização Visual do Dashboard
        if ($needsDisplay) {
            Clear-HostSafe
            Write-Host "==============================================="
            Write-Host " SIMULADOR DE TEMPO KIA CEED (DUAL BUS)"
            Write-Host "==============================================="
            Write-Host " MODO: $mode"

            Write-Host -NoNewline " DATA: "
            if ($mode -eq "MANUAL" -and $fields[$fi] -eq "DAY")   { Write-Host -NoNewline $dt.Day.ToString('00')   -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline $dt.Day.ToString('00') }
            Write-Host -NoNewline "/"
            if ($mode -eq "MANUAL" -and $fields[$fi] -eq "MONTH") { Write-Host -NoNewline $dt.Month.ToString('00') -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline $dt.Month.ToString('00') }
            Write-Host -NoNewline "/"
            if ($mode -eq "MANUAL" -and $fields[$fi] -eq "YEAR")  { Write-Host -NoNewline $dt.Year               -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline $dt.Year }
            Write-Host ""

            Write-Host -NoNewline " HORA: "
            if ($mode -eq "MANUAL" -and $fields[$fi] -eq "HOUR")   { Write-Host -NoNewline $dt.Hour.ToString('00')   -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline $dt.Hour.ToString('00') }
            Write-Host -NoNewline ":"
            if ($mode -eq "MANUAL" -and $fields[$fi] -eq "MINUTE") { Write-Host -NoNewline $dt.Minute.ToString('00') -BackgroundColor DarkCyan -ForegroundColor White } else { Write-Host -NoNewline $dt.Minute.ToString('00') }
            
            if ($mode -eq "MANUAL") {
                Write-Host "" # Sem segundos em manual
            } else {
                Write-Host ":$($dt.Second.ToString('00'))"
            }

            Write-Host ""
            if ($mode -eq "MANUAL") {
                Write-Host " [TAB]               Trocar Campo ($($fields[$fi]))"
                Write-Host " [Setas Cima/Baixo]  Ajustar valor"
            }
            Write-Host " [Q ou ESC]          Voltar ao Menu"
            Write-Host "==============================================="
            if ($mode -eq "MANUAL" -and $lastHeartbeat -eq 0) {
                Write-Host " STATUS: Aguardando ajuste... (Node B passivo)" -ForegroundColor Cyan
            } else {
                Write-Host " CAN 5E2: $(Build5E2Frame $dt)" -ForegroundColor Gray
                Write-Host " CAN 12F: $(Build12FFrame $dt)" -ForegroundColor Gray
            }
            $needsDisplay = ($mode -eq "AUTO") # Auto refresca sempre por causa dos segundos; Manual apenas em interacao.
        }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($mode -eq "MANUAL") {
                if ($key.Key -eq "Tab") { 
                    $fi = ($fi + 1) % $fields.Count
                    $needsDisplay = $true
                }
                if ($key.Key -eq "UpArrow" -or $key.Key -eq "DownArrow") {
                    $val = if($key.Key -eq "UpArrow") { 1 } else { -1 }
                    switch ($fields[$fi]) {
                        "DAY"    { $dt = $dt.AddDays($val)    }
                        "MONTH"  { $dt = $dt.AddMonths($val)  }
                        "YEAR"   { $dt = $dt.AddYears($val)   }
                        "HOUR"   { $dt = $dt.AddHours($val)   }
                        "MINUTE" { $dt = $dt.AddMinutes($val) }
                    }
                    # Segundos sempre a zero no modo manual
                    $dt = Get-Date -Year $dt.Year -Month $dt.Month -Day $dt.Day -Hour $dt.Hour -Minute $dt.Minute -Second 0
                    $needsSend = $true # DISPARA o comando CAN apenas aqui
                }
            }
            if ($key.Key -eq "Escape" -or $key.Key -eq "Q") { return }
        }
        Start-Sleep -Milliseconds 50
    }
}

# ==========================================================
# --- Funcoes de LEITURA PASSIVA ---
# ==========================================================
function Show-ReadDisplay($date, $time, $id, $raw, $count) {
    Clear-HostSafe
    Write-Host "==============================================="
    Write-Host " MODO LEITURA - DATA/HORA DO BARRAMENTO CAN"
    Write-Host "==============================================="
    Write-Host " DATA:      $date"
    Write-Host " HORA:      $time"
    Write-Host "-----------------------------------------------"
    Write-Host " ULTIMO ID: $id"
    Write-Host " RAW:       $raw" -ForegroundColor Gray
    Write-Host "-----------------------------------------------"
    Write-Host " FRAMES CAN RECEBIDOS: $count" -ForegroundColor Cyan
    Write-Host "==============================================="
    Write-Host " [Q ou ESC]  Voltar ao Menu"
}

function Run-ReadMode($sp) {
    $lastDate = "---"; $lastTime = "---"
    $lastID   = "---"; $lastRaw  = "---"
    $rxCount  = 0

    Show-ReadDisplay $lastDate $lastTime $lastID $lastRaw $rxCount

    while ($true) {
        $refresh = $false
        try {
            if ($sp.BytesToRead -gt 0) {
                $lines = $sp.ReadExisting().Split("`r")
                foreach ($l in $lines) {
                    $line = $l.Trim()
                    if ($line.Length -ge 5 -and $line.StartsWith("t")) {
                        $rxCount++
                        $refresh = $true
                        try {
                            $idStr = $line.Substring(1, 3)
                            $id    = [Convert]::ToInt32($idStr, 16)
                            $len   = [int]($line.Substring(4, 1))

                            if (($id -eq 0x5E2 -or $id -eq 0x12F) -and $line.Length -ge (5 + $len * 2)) {
                                $dataHex = $line.Substring(5, $len * 2)
                                $bytes   = (0..($len-1) | ForEach-Object { [Convert]::ToInt32($dataHex.Substring($_*2,2), 16) })

                                if ($bytes.Count -gt 6) {
                                    $lastID  = "0x$idStr"
                                    $lastRaw = ($bytes | ForEach-Object { "{0:X2}" -f $_ }) -join " "

                                    if ($id -eq 0x5E2) {
                                        $year = 2000 + $bytes[1]; $hour = $bytes[2]; $min = $bytes[3]; $sec = $bytes[4]
                                        $day  = $bytes[5]; $month = [int](($bytes[6] - 1) / 4)
                                    } else {
                                        $hour = $bytes[1]; $min = $bytes[2]; $sec = $bytes[3]
                                        $month = [int](($bytes[4] - 1) / 4)
                                        $year = 2000 + $bytes[5]; $day = $bytes[6]
                                    }

                                    if ($month -ge 1 -and $month -le 12 -and $day -ge 1 -and $day -le 31) {
                                        $lastDate = "{0:D2}/{1:D2}/{2}" -f $day, $month, $year
                                        $lastTime = "{0:D2}:{1:D2}:{2:D2}" -f $hour, $min, $sec
                                    }
                                }
                            }
                        } catch { }
                    }
                }
            }
        } catch { }

        if ($refresh) { Show-ReadDisplay $lastDate $lastTime $lastID $lastRaw $rxCount }

        if ([Console]::KeyAvailable) {
            $key = [Console]::ReadKey($true)
            if ($key.Key -eq "Escape" -or $key.Key -eq "Q") { break }
        }
        Start-Sleep -Milliseconds 50
    }
}

# ==========================================================
# --- Funcoes de RADIO ---
# ==========================================================
function MHzToRaw([double]$mhz)  { [int][Math]::Round(($mhz - 87.5) * 320.0) }
function RawToBytesBE([int]$raw) { @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF)) }

function ToUtf16Bytes([string]$s) {
    $s = $s.ToUpper()
    if ($s.Length -gt 16) { $s = $s.Substring(0, 16) }
    $s = $s.PadRight(16, ' ')
    $b = New-Object System.Collections.Generic.List[int]
    foreach ($c in $s.ToCharArray()) {
        $code = [int][char]$c
        $b.Add($code -band 0xFF)
        $b.Add(($code -shr 8) -band 0xFF)
    }
    return , $b.ToArray()
}

function Get-FormattedLabel([string]$label, [int]$tick) {
    if ($label.Length -le 16) {
        $spaces = 16 - $label.Length
        $left   = [Math]::Floor($spaces / 2)
        return $label.PadLeft($label.Length + $left, ' ').PadRight(16, ' ')
    } else {
        $ext   = $label + "          "
        $len   = $ext.Length
        $start = $tick % $len
        $res   = $ext.Substring($start)
        if ($res.Length -lt 16) { $res += $ext.Substring(0, 16 - $res.Length) }
        return $res.Substring(0, 16)
    }
}

function Build4E8Frames([string]$label) {
    $payload = ToUtf16Bytes $label
    $frames  = @()
    $frames += BuildFrame 0x4E8 (@(0x10, 0x20) + $payload[0..5])
    $idx = 6; $sn = 1
    while ($idx -lt 32) {
        $take  = [Math]::Min(7, 32 - $idx)
        $chunk = $payload[$idx..($idx+$take-1)]
        while ($chunk.Count -lt 7) { $chunk += 0x00 }
        $frames += BuildFrame 0x4E8 (@(0x20 + $sn) + $chunk)
        $idx += 7; $sn++
    }
    return , $frames
}

function Build485BTFrames([string]$label) {
    $utf16   = ToUtf16Bytes $label
    $payload = @(0x03) + $utf16
    $len     = $payload.Count
    $frames  = @()
    $frames += BuildFrame 0x485 (@(0x10, $len) + $payload[0..5])
    $idx = 6; $sn = 1
    while ($idx -lt $len) {
        $take  = [Math]::Min(7, $len - $idx)
        $chunk = $payload[$idx..($idx+$take-1)]
        while ($chunk.Count -lt 7) { $chunk += 0x00 }
        $frames += BuildFrame 0x485 (@(0x20 + $sn) + $chunk)
        $idx += 7; $sn++
    }
    return , $frames
}

function Run-RadioMode($sp, $band) {
    $list     = @($RadioData | Where-Object { $_.Band -eq $band })
    $idx      = 0
    $lastLabel = 0
    $interval = [int](1000 / $Hz114)

    while ($true) {
        $item      = $list[$idx]
        $scrollTick = 0; $lastLabel = 0

        $prefix = 0x11; $suffix = @(0x00, 0x00)
        if ($band -eq "AM") {
            $prefix = 0x14
            $raw    = [int](($item.KHz - 517) * 16 / 9)
            if ($raw -lt 0) { $raw = 0 }
            $suffix = @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF))
        }
        if ($band -eq "BT") { $prefix = 0x08 }
        if ($band -eq "FM") { $suffix = RawToBytesBE (MHzToRaw $item.MHz) }

        $f100  = BuildFrame 0x100 @(0x62, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00)
        $f114  = BuildFrame 0x114 @($prefix, 0x60, 0x00, 0x01, 0x00, 0x00, $suffix[0], $suffix[1])
        $f115  = BuildFrame 0x115 @(0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        $f506  = BuildFrame 0x506 @(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x00)
        $f169  = BuildFrame 0x169 @(0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        $f1EB  = BuildFrame 0x1EB @(0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        $f44D  = BuildFrame 0x44D @(0x40, 0x02, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF)
        $f120  = BuildFrame 0x120 @(0x00, 0x00, 0x00, 0x00)

        while ($true) {
            $formattedLabel = Get-FormattedLabel $item.Label $scrollTick
            $labelFrames    = if ($band -eq "BT") { Build485BTFrames $formattedLabel } else { Build4E8Frames $formattedLabel }

            Clear-HostSafe
            Write-Host "==============================================="
            Write-Host " KIA CEED 2015 - MODO RADIO: $band"
            Write-Host "==============================================="
            Write-Host " ITEM [$($idx+1)/$($list.Count)]: $($item.Name)"
            if ($band -eq "FM") { Write-Host " FREQUENCIA: $($item.MHz) MHz" }
            if ($band -eq "AM") { Write-Host " FREQUENCIA: $($item.KHz) KHz" }
            Write-Host " LABEL: '$($item.Label)'"
            if ($item.Label.Length -gt 16) { Write-Host " SCROLL: '$formattedLabel'" -ForegroundColor Cyan }
            Write-Host ""
            Write-Host " [Setas Esq/Dir]  Trocar item"
            Write-Host " [Q ou ESC]       Menu Principal"
            Write-Host "==============================================="

            Send-SLCAN $sp $f100; Send-SLCAN $sp $f114; Send-SLCAN $sp $f115
            Send-SLCAN $sp $f506; Send-SLCAN $sp $f169; Send-SLCAN $sp $f1EB
            Send-SLCAN $sp $f44D; Send-SLCAN $sp $f120

            if (([Environment]::TickCount - $lastLabel) -gt $LabelEveryMs) {
                $labelFrames | ForEach-Object { Send-SLCAN $sp $_; Start-Sleep -Milliseconds $IsoTpGapMs }
                $lastLabel = [Environment]::TickCount; $scrollTick++
            }

            if ([Console]::KeyAvailable) {
                $key = [Console]::ReadKey($true)
                if ($key.Key -eq "RightArrow") { $idx = ($idx + 1) % $list.Count; break }
                if ($key.Key -eq "LeftArrow")  { $idx = ($idx - 1 + $list.Count) % $list.Count; break }
                if ($key.Key -eq "Escape" -or $key.Key -eq "Q") { return }
            }
            Start-Sleep -Milliseconds $interval
        }
    }
}

# ==========================================================
# --- Main ---
# ==========================================================
$sp = New-Object System.IO.Ports.SerialPort $Port, 115200, None, 8, one
try {
    Write-Host "Abrindo porta $Port..." -ForegroundColor Gray
    $sp.Open()
    Send-SLCAN $sp "C"; Send-SLCAN $sp $Bitrate; Send-SLCAN $sp "O"

    while ($true) {
        Clear-HostSafe
        Write-Host "=================================================="
        Write-Host " KIA CEED 2015 - SIMULADOR CAN COMPLETO v3.0"
        Write-Host "=================================================="
        Write-Host ""
        Write-Host "  [TEMPO]"
        Write-Host "  1) Leitura do Barramento CAN (Passivo)"
        Write-Host "  2) Ajuste Manual de Tempo (Setas)"
        Write-Host "  3) Sincronizar com Relogio do PC (AUTO)"
        Write-Host ""
        Write-Host "  [RADIO]"
        Write-Host "  4) Modo Radio FM"
        Write-Host "  5) Modo Radio AM"
        Write-Host "  6) Modo Bluetooth / Media"
        Write-Host ""
        Write-Host "  0) Sair"
        Write-Host "=================================================="

        $opt = Read-Host "`nEscolha uma opcao"

        switch ($opt) {
            "1" { Run-ReadMode $sp               }
            "2" { Run-TimeSimulator $sp "MANUAL" }
            "3" { Run-TimeSimulator $sp "AUTO"   }
            "4" { Run-RadioMode $sp "FM"         }
            "5" { Run-RadioMode $sp "AM"         }
            "6" { Run-RadioMode $sp "BT"         }
            "0" { break }
        }
    }
} catch {
    Write-Error $_.Exception.Message
} finally {
    if ($sp.IsOpen) { Send-SLCAN $sp "C"; $sp.Close() }
    Write-Host "`nFinalizado."
}
