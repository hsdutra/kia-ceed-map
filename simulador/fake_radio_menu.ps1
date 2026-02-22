# ==========================================================
# KIA CEED 2015 - CAN INTERACTIVE SIMULATOR (v2.0)
# Suporte: AM, FM e Bluetooth (Mapeamento corrigido)
# Controles: Setas Direita/Esquerda para mudar faixas/estações
# ==========================================================

# --- Configurações ---
$Port         = "COM3"
$Bitrate      = "S3"     # 100 kbps
$Hz114        = 10       # Frequência de atualização (10Hz)
$LabelEveryMs = 400      # Frequência do nome (0x4E8)
$IsoTpGapMs   = 15       # Delay entre pacotes ISO-TP

# --- Estações e Faixas ---
$Data = @(
  # Opção 1: FM (ID 0x11)
  @{ Band="FM"; Name="CITY FM"; MHz=106.2; Label="CIDADEFM 106.2" },
  @{ Band="FM"; Name="M80 RADIO"; MHz=104.3; Label="M80 PORTUGAL" },
  @{ Band="FM"; Name="TEST STATION"; MHz=93.6; Label="RADIO TEST 1" },
  
  # Opção 2: AM (ID 0x14)
  @{ Band="AM"; Name="AM Calib Low"; KHz=531;  Label="AM CALIB 531" },
  @{ Band="AM"; Name="AM Calib High"; KHz=1602; Label="AM CALIB 1602" },
  @{ Band="AM"; Name="LOCAL AM 1"; KHz=999; Label="LOCAL AM 999" },

  # Opção 3: BT (ID 0x08)
  @{ Band="BT"; Name="Track 01"; Label="ARTIST - SONG 1" },
  @{ Band="BT"; Name="Track 02"; Label="PODCAST KIA 2" },
  @{ Band="BT"; Name="Track 03"; Label="LIVE STREAM BT" }
)

# --- Funções Internas ---
function BytesToHex([int[]]$b) { ($b | ForEach-Object { "{0:X2}" -f ($_ -band 0xFF) }) -join "" }
function BuildFrame([int]$id, [int[]]$data) { "t{0:X3}{1:X1}{2}" -f $id, $data.Count, (BytesToHex $data) }
function Send-SLCAN($sp, $cmd) { if($sp.IsOpen){ $sp.Write($cmd + "`r") } }

function MHzToRaw([double]$mhz) { [int][Math]::Round(($mhz - 87.5) * 320.0) }
function RawToBytesBE([int]$raw) { @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF)) }
function Build114FM([double]$mhz) { 
    $be = RawToBytesBE (MHzToRaw $mhz)
    @(0x11,0x60,0x00,0x01,0x00,0x00,$be[0],$be[1]) 
}

function ToUtf16Bytes([string]$s, [bool]$pad16=$true) {
    if($pad16) { $s = $s.ToUpper().PadRight(16, ' ').Substring(0,16) }
    else { $s = $s.ToUpper() }
    
    $b = New-Object System.Collections.Generic.List[int]
    foreach($c in $s.ToCharArray()){ 
        $code = [int][char]$c
        $b.Add($code -band 0xFF)
        $b.Add(($code -shr 8) -band 0xFF) 
    }
    return ,$b.ToArray()
}

function Build4E8Frames([string]$label) {
    $payload = ToUtf16Bytes $label $true
    $frames = @()
    # First Frame (10 20 ...) - 32 bytes total (16 chars * 2)
    $ff = @(0x10, 0x20) + $payload[0..5]
    $frames += BuildFrame 0x4E8 $ff
    $idx = 6
    $sn = 1
    while($idx -lt 32){
        $take = [Math]::Min(7, 32 - $idx)
        $chunk = $payload[$idx..($idx+$take-1)]
        while($chunk.Count -lt 7){ $chunk += 0x00 }
        $frames += BuildFrame 0x4E8 (@(0x20 + $sn) + $chunk)
        $idx += 7
        $sn++
    }
    return ,$frames
}

function Build485BTFrames([string]$label) {
    $utf16 = ToUtf16Bytes $label $false
    # No rádio original, BT usa ID 0x485 precedido por 0x03
    $payload = @(0x03) + $utf16
    $len = $payload.Count
    $frames = @()

    # First Frame (10 [len] ...)
    $ff = @(0x10, $len) + $payload[0..5]
    $frames += BuildFrame 0x485 $ff

    $idx = 6
    $sn = 1
    while($idx -lt $len){
        $take = [Math]::Min(7, $len - $idx)
        $chunk = $payload[$idx..($idx+$take-1)]
        while($chunk.Count -lt 7){ $chunk += 0x00 }
        $frames += BuildFrame 0x485 (@(0x20 + $sn) + $chunk)
        $idx += 7
        $sn++
    }
    return ,$frames
}

function Clear-HostSafe { try { Clear-Host } catch {} }

# --- Loop Interativo ---
function Run-Mode($sp, $band) {
    $list = @($Data | Where-Object { $_.Band -eq $band })
    $idx = 0
    $lastLabel = 0
    $interval = [int](1000 / $Hz114)
    
    Write-Host "Iniciando Modo $band. Pressione ESC para voltar." -ForegroundColor Yellow
    
    while($true) {
        $item = $list[$idx]
        
        # Selecionar frames de label baseados na banda
        $labelFrames = @()
        if($band -eq "BT") {
            $labelFrames = Build485BTFrames $item.Label
        } else {
            $labelFrames = Build4E8Frames $item.Label
        }
        
        # ID 0x114 Prefixos
        $prefix = 0x11 # Default FM
        $suffix = @(0x00, 0x00)
        if($band -eq "AM"){ 
            $prefix = 0x14
            # Fórmula de Calibração AM (Baseada nos seus testes):
            # O cluster usa uma escala de 9/16 com offset de 517 KHz.
            # Para injetar X KHz, enviamos: (X - 517) * 16 / 9
            $raw = [int](($item.KHz - 517) * 16 / 9)
            if($raw -lt 0){ $raw = 0 }
            $suffix = @((($raw -shr 8) -band 0xFF), ($raw -band 0xFF))
        }
        if($band -eq "BT"){ $prefix = 0x08; $suffix = @(0x00, 0x00) }
        if($band -eq "FM"){ $suffix = RawToBytesBE (MHzToRaw $item.MHz) }

        $frame114 = BuildFrame 0x114 @($prefix, 0x60, 0x00, 0x01, 0x00, 0x00, $suffix[0], $suffix[1])

        Clear-HostSafe
        Write-Host "==============================================="
        Write-Host " MODO ATUAL: $band"
        Write-Host "==============================================="
        Write-Host " ITEM [$($idx+1)/$($list.Count)]: $($item.Name)"
        if($band -eq "FM") { Write-Host " FREQUÊNCIA: $($item.MHz) MHz" }
        if($band -eq "AM") { Write-Host " FREQUÊNCIA: $($item.KHz) KHz" }
        Write-Host " LABEL: '$($item.Label)'"
        Write-Host ""
        Write-Host " [Setas Esq/Dir] Trocar item"
        Write-Host " [Q ou ESC]      Menu Principal"
        Write-Host "==============================================="

        # Sub-loop de injeção contínua
        while($true){
            Send-SLCAN $sp $frame114
            
            if(([Environment]::TickCount - $lastLabel) -gt $LabelEveryMs){
                $labelFrames | ForEach-Object { Send-SLCAN $sp $_; Start-Sleep -Milliseconds $IsoTpGapMs }
                $lastLabel = [Environment]::TickCount
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
    Write-Host "Abrindo porta $Port..." -ForegroundColor Gray
    $sp.Open()
    Send-SLCAN $sp "C" ; Send-SLCAN $sp $Bitrate ; Send-SLCAN $sp "O"
    
    while($true){
        Clear-HostSafe
        Write-Host "KIA CEED 2015 CAN SIMULATOR"
        Write-Host "1) Modo Rádio FM"
        Write-Host "2) Modo Rádio AM"
        Write-Host "3) Modo Bluetooth / Media"
        Write-Host "0) Sair"
        $opt = Read-Host "`nEscolha uma opção"
        
        switch ($opt) {
            "1" { Run-Mode $sp "FM" }
            "2" { Run-Mode $sp "AM" }
            "3" { Run-Mode $sp "BT" }
            "0" { break }
        }
    }
} catch {
    Write-Error $_.Exception.Message
} finally {
    if($sp.IsOpen){ Send-SLCAN $sp "C"; $sp.Close() }
    Write-Host "`nFinalizado."
}