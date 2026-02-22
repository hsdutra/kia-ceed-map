# KIA CEED 2015 - CAN INTERACTIVE SIMULATOR (v2.1)
# Suporte: AM, FM e Bluetooth + Estabilidade de Icones
# Controles: Setas Direita/Esquerda para mudar faixas/estações
# ==========================================================

# --- Configurações ---
$Port         = "COM3"
$Bitrate      = "S3"     # 100 kbps
$Hz114        = 10       # Frequência de atualização (10Hz)
$LabelEveryMs = 400      # Frequência do nome (0x4E8/0x485)
$IsoTpGapMs   = 15       # Delay entre pacotes ISO-TP

# --- Estacoes e Faixas ---
$Data = @(
  # Opção 1: FM (ID 0x11)
  @{ Band="FM"; Name="CITY FM"; MHz=106.2; Label="CIDADEFM 106.2" },
  @{ Band="FM"; Name="M80 RADIO"; MHz=104.3; Label="M80 PORTUGAL" },
  @{ Band="FM"; Name="TEST STATION"; MHz=93.6; Label="RADIO TEST 1" },
  @{ Band="FM"; Name="TEST GRANDE"; MHz=94.8; Label="TESTE COM NOME GRANDE PARA SER EXIBIDO" },
  # Opção 2: AM (ID 0x14)
  @{ Band="AM"; Name="AM Calib Low"; KHz=531;  Label="AM CALIB 531" },
  @{ Band="AM"; Name="AM Calib High"; KHz=1602; Label="AM CALIB 1602" },
  @{ Band="AM"; Name="LOCAL AM 1"; KHz=999; Label="LOCAL AM 999" },
  # Opção 3: BT (ID 0x08)
  @{ Band="BT"; Name="Track 01"; Label="ARTIST - SONG 1" },
  @{ Band="BT"; Name="Track 02"; Label="PODCAST KIA 2" },
  @{ Band="BT"; Name="Track 03"; Label="LIVE STREAM BT" }
  @{ Band="BT"; Name="Track 04"; Label="Our Lawyer Made Us Change The Name Of This Song So We Wouldn't Get Sued" }
)

# --- Funções Internas ---
function BytesToHex([int[]]$b) { ($b | ForEach-Object { "{0:X2}" -f ($_ -band 0xFF) }) -join "" }
function BuildFrame([int]$id, [int[]]$data) { "t{0:X3}{1:X1}{2}" -f $id, $data.Count, (BytesToHex $data) }
function Send-SLCAN($sp, $cmd) { if($sp.IsOpen){ $sp.Write($cmd + "`r") } }

function MHzToRaw([double]$mhz) { [int][Math]::Round(($mhz - 87.5) * 320.0) }
function RawToBytesBE([int]$raw) { @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF)) }

function ToUtf16Bytes([string]$s) {
    $s = $s.ToUpper()
    if($s.Length -gt 16) { $s = $s.Substring(0,16) }
    $s = $s.PadRight(16, ' ')
    $b = New-Object System.Collections.Generic.List[int]
    foreach($c in $s.ToCharArray()){ 
        $code = [int][char]$c
        $b.Add($code -band 0xFF)
        $b.Add(($code -shr 8) -band 0xFF) 
    }
    return ,$b.ToArray()
}

function Get-FormattedLabel([string]$label, [int]$tick) {
    if ($label.Length -le 16) {
        $spaces = 16 - $label.Length
        $left = [Math]::Floor($spaces / 2)
        return $label.PadLeft($label.Length + $left, ' ').PadRight(16, ' ')
    } else {
        $extendedLabel = $label + "          " 
        $len = $extendedLabel.Length
        $start = $tick % $len
        $result = $extendedLabel.Substring($start)
        if ($result.Length -lt 16) {
            $result += $extendedLabel.Substring(0, 16 - $result.Length)
        }
        return $result.Substring(0, 16)
    }
}

function Build4E8Frames([string]$label) {
    $payload = ToUtf16Bytes $label 
    $frames = @()
    $ff = @(0x10, 0x20) + $payload[0..5]
    $frames += BuildFrame 0x4E8 $ff
    $idx = 6; $sn = 1
    while($idx -lt 32){
        $take = [Math]::Min(7, 32 - $idx); $chunk = $payload[$idx..($idx+$take-1)]
        while($chunk.Count -lt 7){ $chunk += 0x00 }
        $frames += BuildFrame 0x4E8 (@(0x20 + $sn) + $chunk)
        $idx += 7; $sn++
    }
    return ,$frames
}

function Build485BTFrames([string]$label) {
    $utf16 = ToUtf16Bytes $label
    $payload = @(0x03) + $utf16
    $len = $payload.Count
    $frames = @()
    $ff = @(0x10, $len) + $payload[0..5]
    $frames += BuildFrame 0x485 $ff
    $idx = 6; $sn = 1
    while($idx -lt $len){
        $take = [Math]::Min(7, $len - $idx); $chunk = $payload[$idx..($idx+$take-1)]
        while($chunk.Count -lt 7){ $chunk += 0x00 }
        $frames += BuildFrame 0x485 (@(0x20 + $sn) + $chunk)
        $idx += 7; $sn++
    }
    return ,$frames
}

function Clear-HostSafe { try { [Console]::Clear() } catch { Clear-Host } }

# --- Loop Interativo ---
function Run-Mode($sp, $band) {
    $list = @($Data | Where-Object { $_.Band -eq $band })
    $idx = 0; $lastLabel = 0
    $interval = [int](1000 / $Hz114)
    
    while($true) {
        $item = $list[$idx]
        $scrollTick = 0; $lastLabel = 0
        
        $prefix = 0x11; $suffix = @(0x00, 0x00)
        if($band -eq "AM"){ 
            $prefix = 0x14
            $raw = [int](($item.KHz - 517) * 16 / 9)
            if($raw -lt 0){ $raw = 0 }
            $suffix = @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF))
        }
        if($band -eq "BT"){ $prefix = 0x08; $suffix = @(0x00, 0x00) }
        if($band -eq "FM"){ $suffix = RawToBytesBE (MHzToRaw $item.MHz) }
        
        # BUNDLE DE ESTABILIDADE (IDs que mantêm a aba viva e sem loading)
        $frame100 = BuildFrame 0x100 @(0x62, 0x00, 0x00, 0x04, 0x00, 0x00, 0x00, 0x00)
        $frame114 = BuildFrame 0x114 @($prefix, 0x60, 0x00, 0x01, 0x00, 0x00, $suffix[0], $suffix[1])
        $frame115 = BuildFrame 0x115 @(0x08, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00)
        $frame506 = BuildFrame 0x506 @(0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0xFF, 0x0F, 0x00)
        
        # VISIBILIDADE (IDs que mostram as abas no menu)
        $frame169 = BuildFrame 0x169 @(0xC0, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) # Musical + GPS
        $frame1EB = BuildFrame 0x1EB @(0x03, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00, 0x00) # Musical + GPS
        $frame44D = BuildFrame 0x44D @(0x40, 0x02, 0x00, 0x00, 0x00, 0x00, 0xFF, 0xFF) # Radio ligado
        $frame120 = BuildFrame 0x120 @(0x00, 0x00, 0x00, 0x00) # GPS Alive

        while($true){
            $formattedLabel = Get-FormattedLabel $item.Label $scrollTick
            $labelFrames = if($band -eq "BT") { Build485BTFrames $formattedLabel } else { Build4E8Frames $formattedLabel }

            Clear-HostSafe
            Write-Host "==============================================="
            Write-Host " KIA CEED 2015 - MODO ATUAL: $band"
            Write-Host "==============================================="
            Write-Host " ITEM [$($idx+1)/$($list.Count)]: $($item.Name)"
            if($band -eq "FM") { Write-Host " FREQUENCIA: $($item.MHz) MHz" }
            if($band -eq "AM") { Write-Host " FREQUENCIA: $($item.KHz) KHz" }
            Write-Host " LABEL: '$($item.Label)'"
            if ($item.Label.Length -gt 16) { Write-Host " SCROLL: '$formattedLabel'" -ForegroundColor Cyan }
            Write-Host ""
            Write-Host " [Setas Esq/Dir] Trocar item"
            Write-Host " [Q ou ESC]      Menu Principal"
            Write-Host "==============================================="

            # Envia Heartbeats (Bundle Completo)
            Send-SLCAN $sp $frame100; Send-SLCAN $sp $frame114; Send-SLCAN $sp $frame115
            Send-SLCAN $sp $frame506; Send-SLCAN $sp $frame169; Send-SLCAN $sp $frame1EB
            Send-SLCAN $sp $frame44D; Send-SLCAN $sp $frame120
            
            # Envia Label (Texto)
            if(([Environment]::TickCount - $lastLabel) -gt $LabelEveryMs){
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

# --- Main ---
$sp = New-Object System.IO.Ports.SerialPort $Port,115200,None,8,one
try {
    $sp.Open()
    Send-SLCAN $sp "C" ; Send-SLCAN $sp $Bitrate ; Send-SLCAN $sp "O"
    while($true){
        Clear-HostSafe
        Write-Host " KIA CEED 2015 CAN SIMULATOR v2.1"
        Write-Host " --------------------------------"
        Write-Host " 1) Modo Radio FM (Atualiza Cluster)"
        Write-Host " 2) Modo Radio AM (Atualiza Cluster)"
        Write-Host " 3) Modo Bluetooth / Media (Aba 3)"
        Write-Host " 0) Sair"
        $opt = Read-Host "`nEscolha uma opcao"
        switch ($opt) {
            "1" { Run-Mode $sp "FM" }
            "2" { Run-Mode $sp "AM" }
            "3" { Run-Mode $sp "BT" }
            "0" { break }
        }
    }
} catch { Write-Error $_.Exception.Message }
finally { if($sp.IsOpen){ Send-SLCAN $sp "C"; $sp.Close() }; Write-Host "Finalizado." }