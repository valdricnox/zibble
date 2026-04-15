# ==============================================================================
#
#   ███████╗██╗██████╗ ██████╗ ██╗     ███████╗
#   ╚════██║██║██╔══██╗██╔══██╗██║     ██╔════╝
#       ██╔╝██║██████╔╝██████╔╝██║     █████╗
#      ██╔╝ ██║██╔══██╗██╔══██╗██║     ██╔══╝
#      ██║  ██║██████╔╝██████╔╝███████╗███████╗
#      ╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚══════╝
#
#   ZIBBLE'S PERFORMANCE v2.0
#   Windows Optimization Toolkit — Professional Edition
#
#   Uso rápido (PowerShell Admin):
#   irm https://raw.githubusercontent.com/valdricnox/zibble/refs/heads/main/zibble_v2.ps1 | iex
#
#   GitHub : github.com/SEU_USUARIO/zibble
#   Versão : 2.0.0
# ==============================================================================

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

# ── Auto-elevação ─────────────────────────────────────────────────────────────
if (-not ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]"Administrator")) {
    Start-Process PowerShell -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`""
    exit
}

# ==============================================================================
#  GLOBALS & CONFIGURAÇÃO
# ==============================================================================
$Global:Version       = "2.0.0"
$Global:ConfigPath    = "$env:APPDATA\Zibble\zibble_config.json"
$Global:LogPath       = "$env:APPDATA\Zibble\zibble_log.txt"
$Global:ReportPath    = "$env:USERPROFILE\Desktop\zibble_report.html"
$Global:UpdateUrl     = "https://raw.githubusercontent.com/SEU_USUARIO/zibble/main/version.txt"
$Global:ScriptUrl     = "https://raw.githubusercontent.com/SEU_USUARIO/zibble/main/zibble.ps1"

# Garantir diretório de dados
if (-not (Test-Path "$env:APPDATA\Zibble")) { New-Item -Path "$env:APPDATA\Zibble" -ItemType Directory -Force | Out-Null }

# Detecção do sistema
$Global:WinBuild = [System.Environment]::OSVersion.Version.Build
$Global:IsWin11  = $Global:WinBuild -ge 22000
$Global:WinName  = if ($Global:IsWin11) { "Windows 11" } else { "Windows 10" }
$Global:CPU      = (Get-WmiObject Win32_Processor | Select-Object -First 1).Name
$Global:RAM      = [math]::Round((Get-WmiObject Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 1)
$Global:GPU      = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft|Basic" } | Select-Object -First 1).Name
$Global:GPUType  = if ($Global:GPU -match "NVIDIA|GeForce|RTX|GTX") { "NVIDIA" } elseif ($Global:GPU -match "AMD|Radeon|RX ") { "AMD" } else { "INTEL" }
$Global:IsLaptop = (Get-WmiObject Win32_Battery -ErrorAction SilentlyContinue) -ne $null
$Global:Hostname = $env:COMPUTERNAME
$Global:Username = $env:USERNAME
$Global:SafeMode = $false   # Alterado por modo de inicialização
$Global:Config   = $null    # Carregado depois
$Global:SessionStart = Get-Date
$Global:SessionActions = [System.Collections.Generic.List[hashtable]]::new()

# Paleta Matrix Green
$C = @{
    Primary   = "Green"; Bright  = "White";   Dim      = "DarkGreen"
    Accent    = "Cyan";  Warning = "Yellow";  Error    = "Red"
    ON        = "Green"; OFF     = "DarkRed"; Header   = "Green"
    Sep       = "DarkGreen"; Info = "Cyan";   Success  = "Green"
}

# ==============================================================================
#  SISTEMA DE LOG
# ==============================================================================
function Write-Log {
    param([string]$Msg, [string]$Level = "INFO", [string]$Module = "CORE")
    $ts    = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $line  = "[$ts][$Level][$Module] $Msg"
    Add-Content -Path $Global:LogPath -Value $line -ErrorAction SilentlyContinue
}

function Start-Session-Log {
    $sep = "=" * 80
    $header = @"
$sep
  ZIBBLE'S PERFORMANCE v$($Global:Version) — Nova Sessão
  Data     : $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
  OS       : $Global:WinName (Build $Global:WinBuild)
  CPU      : $Global:CPU
  RAM      : $($Global:RAM) GB
  GPU      : $Global:GPU ($Global:GPUType)
  Host     : $Global:Hostname  |  User: $Global:Username
  Laptop   : $(if($Global:IsLaptop){"Sim"}else{"Não"})
  Modo     : $(if($Global:SafeMode){"Seguro"}else{"Avançado"})
$sep
"@
    Add-Content -Path $Global:LogPath -Value $header -ErrorAction SilentlyContinue
}

function Log-Action {
    param([string]$Module, [string]$Action, [string]$Result = "OK")
    Write-Log "$Action — $Result" "ACTION" $Module
    $Global:SessionActions.Add(@{ Time=(Get-Date); Module=$Module; Action=$Action; Result=$Result })
}

# ==============================================================================
#  CONFIGURAÇÃO / PERFIL
# ==============================================================================
function Load-Config {
    if (Test-Path $Global:ConfigPath) {
        try {
            $raw = Get-Content $Global:ConfigPath -Raw
            $Global:Config = $raw | ConvertFrom-Json
            return $true
        } catch { }
    }
    # Config padrão
    $Global:Config = [PSCustomObject]@{
        Version        = $Global:Version
        Preset         = "custom"
        Mode           = "advanced"
        GPU            = $Global:GPUType
        Applied        = @()
        FirstRun       = $true
        LastRun        = $null
        SessionCount   = 0
        TweaksApplied  = 0
        AppInstalled   = @()
        BenchmarkBefore = $null
        BenchmarkAfter  = $null
    }
    return $false
}

function Save-Config {
    $Global:Config.LastRun      = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")
    $Global:Config.SessionCount = [int]$Global:Config.SessionCount + 1
    $Global:Config | ConvertTo-Json -Depth 5 | Set-Content $Global:ConfigPath -Encoding UTF8
}

function Mark-Applied {
    param([string]$TweakId)
    $list = [System.Collections.Generic.List[string]]$Global:Config.Applied
    if ($list -notcontains $TweakId) {
        $list.Add($TweakId)
        $Global:Config.Applied = $list.ToArray()
        $Global:Config.TweaksApplied = [int]$Global:Config.TweaksApplied + 1
    }
    Save-Config
}

function Is-Applied { param([string]$TweakId); return $Global:Config.Applied -contains $TweakId }

# ==============================================================================
#  UI ENGINE
# ==============================================================================
function W {
    param([string]$Text, [string]$Color = "Green", [switch]$NL)
    if ($NL) { Write-Host $Text -ForegroundColor $Color -NoNewline }
    else      { Write-Host $Text -ForegroundColor $Color }
}

function Sep { param([string]$Ch = "─", [int]$W = 74); W ($Ch * $W) $C.Sep }
function Sep2{ param([int]$W = 74); W ("═" * $W) $C.Sep }

function Header {
    param([string]$Title = "", [string]$Sub = "")
    Clear-Host
    W "" 
    W "  ███████╗██╗██████╗ ██████╗ ██╗     ███████╗" $C.Primary
    W "  ╚════██║██║██╔══██╗██╔══██╗██║     ██╔════╝" $C.Primary
    W "      ██╔╝██║██████╔╝██████╔╝██║     █████╗  " $C.Dim
    W "     ██╔╝ ██║██╔══██╗██╔══██╗██║     ██╔══╝  " $C.Dim
    W "     ██║  ██║██████╔╝██████╔╝███████╗███████╗" $C.Dim
    W "     ╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚══════╝" $C.Dim
    W ""
    $modeTag = if ($Global:SafeMode) { " [MODO SEGURO]" } else { "" }
    W "           ZIBBLE'S PERFORMANCE v$($Global:Version)$modeTag" $C.Accent
    W ""
    Sep2
    if ($Title) {
        W "  $Title" $C.Accent
        if ($Sub) { W "  $Sub" $C.Dim }
        Sep2
    }
    W ""
}

function Status {
    param([string]$Label, [string]$Detail = "", [string]$State = "OK")
    $icon  = switch ($State) { "OK" {"✓"}; "FAIL" {"✗"}; "WARN" {"⚠"}; "INFO" {"›"}; "SKIP" {"○"}; default {"·"} }
    $color = switch ($State) { "OK" {$C.Success}; "FAIL" {$C.Error}; "WARN" {$C.Warning}; "INFO" {$C.Info}; "SKIP" {$C.Dim}; default {$C.Dim} }
    W "  [$icon] " $color -NL; W $Label $C.Bright -NL
    if ($Detail) { W "  — $Detail" $C.Dim }
    else { W "" }
}

function Progress-Bar {
    param([int]$Current, [int]$Total, [string]$Label = "", [int]$Width = 40)
    $pct  = if ($Total -gt 0) { [math]::Round(($Current / $Total) * 100) } else { 0 }
    $fill = [math]::Round(($pct / 100) * $Width)
    $bar  = ("█" * $fill) + ("░" * ($Width - $fill))
    Write-Host "`r  [$bar] $pct% $Label      " -NoNewline -ForegroundColor Green
    if ($Current -ge $Total) { Write-Host "" }
}

function Spinner {
    param([scriptblock]$Action, [string]$Label = "Aguarde...")
    $frames = @("⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏")
    $job = Start-Job -ScriptBlock $Action
    $i = 0
    while ($job.State -eq "Running") {
        Write-Host "`r  $($frames[$i % $frames.Count]) $Label   " -NoNewline -ForegroundColor Green
        Start-Sleep -Milliseconds 100
        $i++
    }
    Write-Host "`r  ✓ $Label — Concluído.      " -ForegroundColor Green
    $result = Receive-Job $job
    Remove-Job $job
    return $result
}

function Toggle-Display {
    param([int]$Num, [string]$Label, [bool]$State, [string]$Tag = "")
    $st    = if ($State) { " ON " } else { "OFF" }
    $sc    = if ($State) { $C.ON  } else { $C.OFF }
    $check = if (Is-Applied $Tag) { "✓" } else { " " }
    W "  [$Num] " $C.Dim -NL; W "[$st]" $sc -NL; W " $Label " $C.Bright -NL
    if ($Tag) { W "[$check]" $C.Dim }
    else { W "" }
}

function Confirm {
    param([string]$Msg = "Confirmar?")
    W ""
    W "  ⚠  $Msg" $C.Warning
    W "  [S] Sim    [N] Não" $C.Dim
    $r = Ask "Confirmar"
    return ($r -ieq "S")
}

function Ask {
    param([string]$Prompt = "Escolha")
    W ""
    W "  $Prompt" $C.Dim -NL; W " ❯ " $C.Primary -NL
    return (Read-Host).Trim()
}

function Pause-Screen {
    W ""; W "  Pressione qualquer tecla para continuar..." $C.Dim
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Restore-Point {
    param([string]$Desc = "Zibble Backup")
    Status "Criando ponto de restauração..." "" "INFO"
    try {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "SystemRestorePointCreationFrequency" /t REG_DWORD /d "0" /f | Out-Null
        Checkpoint-Computer -Description $Desc -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Status "Ponto de restauração criado" $Desc "OK"
        Write-Log "Restore point: $Desc" "INFO" "SYSTEM"
    } catch {
        Status "Restore point falhou" $_.Exception.Message "WARN"
    }
}

function Reg-Set {
    param([string]$Path, [string]$Name, [string]$Type, $Value, [string]$Label = "")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force -ErrorAction Stop
        if ($Label) { Status $Label "" "OK" }
        Write-Log "REG SET: $Path :: $Name = $Value" "ACTION" "REGISTRY"
        return $true
    } catch {
        if ($Label) { Status $Label $_.Exception.Message "FAIL" }
        Write-Log "REG FAIL: $Path :: $Name — $($_.Exception.Message)" "FAIL" "REGISTRY"
        return $false
    }
}

function Cmd-Run {
    param([string]$Cmd, [string]$Label = "")
    try {
        $out = Invoke-Expression $Cmd 2>&1
        if ($Label) { Status $Label "" "OK" }
        Write-Log "CMD: $Cmd" "ACTION" "CMD"
        return $out
    } catch {
        if ($Label) { Status $Label $_.Exception.Message "FAIL" }
        Write-Log "CMD FAIL: $Cmd" "FAIL" "CMD"
    }
}

# ==============================================================================
#  HEALTH CHECK — STATUS DO SISTEMA
# ==============================================================================
function Get-SystemHealth {
    $h = @{}

    # HAGS
    $hags = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" -Name "HwSchMode" -EA SilentlyContinue).HwSchMode
    $h.HAGS = ($hags -eq 2)

    # Game Mode
    $gm = (Get-ItemProperty "HKCU:\SOFTWARE\Microsoft\GameBar" -Name "AutoGameModeEnabled" -EA SilentlyContinue).AutoGameModeEnabled
    $h.GameMode = ($gm -eq 1)

    # Power Throttling
    $pt = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -EA SilentlyContinue).PowerThrottlingOff
    $h.PowerThrottling = ($pt -eq 1)

    # IPv6
    $ipv6 = (Get-NetAdapterBinding -ComponentID ms_tcpip6 -EA SilentlyContinue | Where-Object Enabled).Count
    $h.IPv6Disabled = ($ipv6 -eq 0)

    # Fast Startup
    $fs = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power" -Name "HiberbootEnabled" -EA SilentlyContinue).HiberbootEnabled
    $h.FastStartupOff = ($fs -eq 0)

    # Telemetria
    $tel = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection" -Name "AllowTelemetry" -EA SilentlyContinue).AllowTelemetry
    $h.TelemetryOff = ($tel -eq 0)

    # Windows Defender
    $def = (Get-ItemProperty "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" -Name "DisableAntiSpyware" -EA SilentlyContinue).DisableAntiSpyware
    $h.DefenderOff = ($def -eq 1)

    # Memory Compression
    try { $mc = (Get-MMAgent).MemoryCompression; $h.MemCompressionOff = (-not $mc) } catch { $h.MemCompressionOff = $false }

    # Nagle
    $nagle = (Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces" -Name "TCPNoDelay" -EA SilentlyContinue).TCPNoDelay
    $h.NagleOff = ($nagle -eq 1)

    # Bloatware count
    $bloatPatterns = @("*3DBuilder*","*bing*","*Facebook*","*Xbox*","*Cortana*","*MixedReality*","*YourPhone*","*PowerAutomate*")
    $bloatCount = 0
    foreach ($p in $bloatPatterns) { $bloatCount += (Get-AppxPackage -AllUsers $p -EA SilentlyContinue | Measure-Object).Count }
    $h.BloatCount = $bloatCount

    # Disk usage
    $disk = Get-Volume | Where-Object { $_.DriveLetter -eq "C" }
    if ($disk) { $h.DiskFreeGB = [math]::Round($disk.SizeRemaining/1GB,1); $h.DiskUsePct = [math]::Round((($disk.Size-$disk.SizeRemaining)/$disk.Size)*100) }

    # Uptime
    $boot = (Get-CimInstance Win32_OperatingSystem).LastBootUpTime
    $h.UptimeHours = [math]::Round((New-TimeSpan -Start $boot -End (Get-Date)).TotalHours, 1)

    # CPU Usage
    $h.CpuUsage = [math]::Round((Get-Counter '\Processor(_Total)\% Processor Time' -EA SilentlyContinue).CounterSamples.CookedValue, 1)

    return $h
}

function Show-Dashboard {
    $h = Get-SystemHealth
    Header "📊  DASHBOARD — Estado do Sistema" "$Global:Hostname  |  $Global:WinName  |  $Global:GPU"

    # Info do hardware
    W "  ┌─ Hardware ──────────────────────────────────────────────────────────┐" $C.Sep
    W "  │  CPU  : " $C.Dim -NL; W "$($Global:CPU.Substring(0,[Math]::Min(52,$Global:CPU.Length)))" $C.Bright
    W "  │  RAM  : " $C.Dim -NL; W "$($Global:RAM) GB" $C.Bright -NL; W "   GPU : " $C.Dim -NL; W "$($Global:GPU)" $C.Bright
    W "  │  CPU% : " $C.Dim -NL; W "$($h.CpuUsage)%" $C.Bright -NL; W "   Uptime: " $C.Dim -NL; W "$($h.UptimeHours)h" $C.Bright
    W "  │  Disco: " $C.Dim -NL; W "$($h.DiskFreeGB) GB livres" $C.Bright -NL; W " ($($h.DiskUsePct)% usado)" $C.Dim
    W "  └────────────────────────────────────────────────────────────────────┘" $C.Sep
    W ""

    # Status dos tweaks
    W "  ┌─ Tweaks ──────────────────── ┬─ Sistema ──────────────────────────┐" $C.Sep
    $rows = @(
        @{L="HAGS";           V=$h.HAGS;           L2="Power Throttling Off"; V2=$h.PowerThrottling},
        @{L="Game Mode";      V=$h.GameMode;        L2="Fast Startup Off";     V2=$h.FastStartupOff},
        @{L="Telemetria Off"; V=$h.TelemetryOff;    L2="IPv6 Desativado";      V2=$h.IPv6Disabled},
        @{L="Nagle Off";      V=$h.NagleOff;        L2="Mem. Compress. Off";   V2=$h.MemCompressionOff},
        @{L="Defender Off";   V=$h.DefenderOff;     L2="Bloatware";            V2=($h.BloatCount -eq 0)}
    )
    foreach ($r in $rows) {
        $s1 = if ($r.V)  { "[$($C.ON) ON ]" }  else { "[$($C.OFF) OFF]" }
        $s2 = if ($r.V2) { "[$($C.ON) ON ]" }  else { "[$($C.OFF) OFF]" }
        $c1 = if ($r.V)  { $C.ON }  else { $C.OFF }
        $c2 = if ($r.V2) { $C.ON }  else { $C.OFF }
        W "  │  " $C.Sep -NL; W "$($r.L.PadRight(18))" $C.Bright -NL
        W "[" $C.Sep -NL; if ($r.V) { W " ON " $C.ON -NL } else { W "OFF" $C.OFF -NL }; W "]" $C.Sep -NL
        W "  " "" -NL; W "$($r.L2.PadRight(22))" $C.Bright -NL
        W "[" $C.Sep -NL; if ($r.V2) { W " ON " $C.ON -NL } else { W "OFF" $C.OFF -NL }; W "]" $C.Sep
    }
    W "  └─────────────────────────────┴────────────────────────────────────┘" $C.Sep
    W ""

    # Bloatware alert
    if ($h.BloatCount -gt 0) {
        W "  ⚠  $($h.BloatCount) app(s) bloatware detectado(s) — Módulo 5 para remover" $C.Warning
    }

    # Score de otimização
    $score = 0
    @($h.HAGS,$h.GameMode,$h.PowerThrottling,$h.FastStartupOff,$h.TelemetryOff,$h.IPv6Disabled,$h.NagleOff,$h.MemCompressionOff) | ForEach-Object { if ($_) { $score++ } }
    $pct = [math]::Round(($score / 8) * 100)
    $bar = ("█" * [math]::Round($pct/5)) + ("░" * (20 - [math]::Round($pct/5)))
    W ""
    W "  Score de Otimização  [$bar] $pct%" $C.Accent
    if ($pct -lt 40)      { W "  Dica: Execute os módulos Performance e Telemetria primeiro!" $C.Warning }
    elseif ($pct -lt 80)  { W "  Bom! Execute GPU & Rede para maximizar a performance." $C.Info }
    else                  { W "  Excelente! Sistema bem otimizado." $C.Success }

    # Sessão
    W ""
    W "  Última sessão : " $C.Dim -NL
    if ($Global:Config.LastRun) { W $Global:Config.LastRun $C.Accent } else { W "Primeira execução" $C.Accent }
    W "  Tweaks aplicados: " $C.Dim -NL; W "$($Global:Config.TweaksApplied)" $C.Accent -NL
    W "  |  Sessões: " $C.Dim -NL; W "$($Global:Config.SessionCount)" $C.Accent

    W ""
    W "  [Enter] Continuar para o Menu Principal" $C.Dim
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

# ==============================================================================
#  BENCHMARK
# ==============================================================================
function Run-Benchmark {
    param([string]$Phase = "before")
    Header "📈  BENCHMARK — $($Phase.ToUpper())"
    W "  Coletando métricas do sistema..." $C.Dim
    W ""

    $results = @{}

    # Disk latency
    Status "Testando latência de disco..." "" "INFO"
    $diskStart = Get-Date
    $testFile  = "$env:TEMP\zibble_bench_$(Get-Random).tmp"
    $data = [byte[]]::new(10MB)
    [System.IO.File]::WriteAllBytes($testFile, $data)
    $diskWrite = [math]::Round((New-TimeSpan -Start $diskStart -End (Get-Date)).TotalMilliseconds)
    $readStart = Get-Date
    [System.IO.File]::ReadAllBytes($testFile) | Out-Null
    $diskRead  = [math]::Round((New-TimeSpan -Start $readStart  -End (Get-Date)).TotalMilliseconds)
    Remove-Item $testFile -Force -EA SilentlyContinue
    $results.DiskWrite = $diskWrite
    $results.DiskRead  = $diskRead
    Status "Disco  — Escrita: ${diskWrite}ms  |  Leitura: ${diskRead}ms" "" "OK"

    # Network latency
    Status "Testando latência de rede..." "" "INFO"
    $pings = @()
    1..5 | ForEach-Object {
        $p = Test-Connection -ComputerName 8.8.8.8 -Count 1 -EA SilentlyContinue
        if ($p) { $pings += $p.ResponseTime }
    }
    $avgPing = if ($pings) { [math]::Round(($pings | Measure-Object -Average).Average) } else { 999 }
    $results.AvgPing = $avgPing
    Status "Rede   — Ping médio: ${avgPing}ms" "" "OK"

    # RAM free
    $ramFree = [math]::Round((Get-CimInstance Win32_OperatingSystem).FreePhysicalMemory / 1MB, 1)
    $results.RamFreeMB = $ramFree
    Status "RAM    — Memória livre: ${ramFree} MB" "" "OK"

    # CPU idle
    $cpuIdle = [math]::Round(100 - (Get-Counter '\Processor(_Total)\% Processor Time' -EA SilentlyContinue).CounterSamples.CookedValue)
    $results.CpuIdle = $cpuIdle
    Status "CPU    — Ociosidade: ${cpuIdle}%" "" "OK"

    # Boot time
    try {
        $bootMs = (Get-EventLog System -Source "Microsoft-Windows-Kernel-General" -InstanceId 12 -Newest 1 -EA Stop).TimeGenerated
        $results.LastBootTime = $bootMs.ToString("HH:mm:ss")
        Status "Boot   — Último boot às $($results.LastBootTime)" "" "OK"
    } catch { $results.LastBootTime = "N/A" }

    $results.Phase     = $Phase
    $results.Timestamp = (Get-Date -Format "yyyy-MM-dd HH:mm:ss")

    if ($Phase -eq "before") {
        $Global:Config.BenchmarkBefore = $results
    } else {
        $Global:Config.BenchmarkAfter  = $results
    }
    Save-Config

    W ""
    Status "Benchmark $Phase concluído" "" "OK"
    Write-Log "Benchmark $Phase — Ping:${avgPing}ms Disk:${diskWrite}ms RAM:${ramFree}MB" "BENCH" "BENCHMARK"
    return $results
}

function Show-BenchmarkComparison {
    $b = $Global:Config.BenchmarkBefore
    $a = $Global:Config.BenchmarkAfter
    if (-not $b -or -not $a) {
        Status "Execute o benchmark antes e depois de aplicar tweaks" "" "WARN"
        return
    }
    Header "📊  BENCHMARK — Comparativo"
    W "  Antes vs Depois das otimizações" $C.Dim
    W ""

    $metrics = @(
        @{ Name="Ping médio (ms)";      Before=$b.AvgPing;  After=$a.AvgPing;  Lower=$true },
        @{ Name="Latência disco escrita"; Before=$b.DiskWrite; After=$a.DiskWrite; Lower=$true },
        @{ Name="Latência disco leitura"; Before=$b.DiskRead;  After=$a.DiskRead;  Lower=$true },
        @{ Name="RAM livre (MB)";        Before=$b.RamFreeMB; After=$a.RamFreeMB; Lower=$false },
        @{ Name="CPU ocioso (%)";        Before=$b.CpuIdle;   After=$a.CpuIdle;   Lower=$false }
    )

    W "  ┌──────────────────────────┬──────────┬──────────┬──────────────┐" $C.Sep
    W "  │ Métrica                  │  Antes   │  Depois  │  Resultado   │" $C.Sep
    W "  ├──────────────────────────┼──────────┼──────────┼──────────────┤" $C.Sep

    foreach ($m in $metrics) {
        $diff = [math]::Round($m.After - $m.Before, 1)
        $pct  = if ($m.Before -ne 0) { [math]::Round(($diff / $m.Before) * 100, 1) } else { 0 }
        $improved = if ($m.Lower) { $diff -lt 0 } else { $diff -gt 0 }
        $icon  = if ($improved) { "▲ +" } else { "▼ " }
        $color = if ($improved) { $C.ON } else { $C.OFF }
        $name  = $m.Name.PadRight(26)
        $bef   = "$($m.Before)".PadLeft(8)
        $aft   = "$($m.After)".PadLeft(8)
        $res   = "$icon$([Math]::Abs($pct))%".PadLeft(12)
        W "  │ $name│$bef  │$aft  │" $C.Dim -NL; W "$res " $color; W "│" $C.Sep
    }
    W "  └──────────────────────────┴──────────┴──────────┴──────────────┘" $C.Sep
}

# ==============================================================================
#  MÓDULO 1 — PERFORMANCE
# ==============================================================================
function Menu-Performance {
    Header "⚡  PERFORMANCE" "Otimizações de sistema, kernel e boot  |  $Global:WinName detectado"
    W "  [1] Tweaks BCD (Boot Configuration)"          $C.Bright
    W "  [2] Desativar Mitigações de Segurança"         $C.Warning
    W "  [3] Tweaks NTFS"                               $C.Bright
    W "  [4] Tweaks de Memória + RAM"                   $C.Bright
    W "  [5] Prioridades MMCSS + CSRSS + Processos"    $C.Bright
    W "  [6] Desativar Power Throttling"                $C.Bright
    W "  [7] HAGS + Game Mode + FSO"                    $C.Bright
    W "  [8] Latência GPU + Resource Policy"            $C.Bright
    W "  [9] Tweaks de Inicialização (Startup)"         $C.Bright
    W "  [R] Reverter Performance ao padrão"            $C.Warning
    W "  [A] ✅  APLICAR TUDO + Benchmark"              $C.Accent
    W ""; W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1" { Apply-BCD;                 Pause-Screen; Menu-Performance }
        "2" { Apply-Mitigations;         Pause-Screen; Menu-Performance }
        "3" { Apply-NTFS;                Pause-Screen; Menu-Performance }
        "4" { Apply-Memory;              Pause-Screen; Menu-Performance }
        "5" { Apply-Priorities;          Pause-Screen; Menu-Performance }
        "6" { Apply-PowerThrottle;       Pause-Screen; Menu-Performance }
        "7" { Apply-HAGS;                Pause-Screen; Menu-Performance }
        "8" { Apply-GPULatency;          Pause-Screen; Menu-Performance }
        "9" { Apply-Startup;             Pause-Screen; Menu-Performance }
        "R" { Undo-Performance;          Pause-Screen; Menu-Performance }
        "A" { Apply-AllPerformance;      Pause-Screen; Menu-Performance }
        "0" { return }
        default { Menu-Performance }
    }
}

function Apply-BCD {
    Header "⚡  BCD Tweaks"
    if ($Global:SafeMode) { Status "Disponível apenas no Modo Avançado" "" "WARN"; return }
    $cmds = @(
        "bcdedit /set useplatformclock No",
        "bcdedit /set useplatformtick No",
        "bcdedit /set disabledynamictick Yes",
        "bcdedit /set tscsyncpolicy Enhanced",
        "bcdedit /set firstmegabytepolicy UseAll",
        "bcdedit /set avoidlowmemory 0x8000000",
        "bcdedit /set nolowmem Yes",
        "bcdedit /set allowedinmemorysettings 0x0",
        "bcdedit /set x2apicpolicy Enable",
        "bcdedit /set configaccesspolicy Default",
        "bcdedit /set MSI Default",
        "bcdedit /set usephysicaldestination No",
        "bcdedit /set usefirmwarepcisettings No",
        "bcdedit /set nx optout",
        "bcdedit /set debug No",
        "bcdedit /set hypervisorlaunchtype Off",
        "bcdedit /set ems No"
    )
    if (-not $Global:IsWin11) {
        $cmds += @(
            "bcdedit /set pae ForceEnable",
            "bcdedit /set disableelamdrivers Yes",
            "bcdedit /set highestmode Yes",
            "bcdedit /set noumex Yes",
            "bcdedit /set extendedinput Yes"
        )
    }
    $i = 0
    foreach ($c in $cmds) {
        $i++; Progress-Bar $i $cmds.Count "BCD"
        Invoke-Expression $c 2>$null
        Write-Log "BCD: $c" "ACTION" "PERF"
    }
    Status "BCD Tweaks aplicados" "Reinicie para efeito completo" "OK"
    Mark-Applied "bcd"; Log-Action "PERF" "BCD Tweaks"
}

function Undo-BCD {
    $restore = @(
        "bcdedit /set useplatformclock Yes",
        "bcdedit /deletevalue useplatformtick",
        "bcdedit /set disabledynamictick No",
        "bcdedit /deletevalue tscsyncpolicy",
        "bcdedit /set hypervisorlaunchtype Auto",
        "bcdedit /set nx OptIn"
    )
    foreach ($c in $restore) { Invoke-Expression $c 2>$null }
    Status "BCD restaurado ao padrão" "" "OK"
    Log-Action "PERF" "BCD Undo"
}

function Apply-Mitigations {
    Header "🛡️  Mitigações de Segurança"
    W "  ⚠  Desativa proteções Spectre/Meltdown e CFG." $C.Warning
    W "     Recomendado apenas para PCs de gaming dedicados." $C.Dim
    if (-not (Confirm "Desativar mitigações de segurança?")) { return }

    powershell -Command "ForEach(`$v in (Get-Command -Name 'Set-ProcessMitigation').Parameters['Disable'].Attributes.ValidValues){Set-ProcessMitigation -System -Disable `$v.ToString() -ErrorAction SilentlyContinue}" 2>$null

    $tweaks = @(
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\FVE";                                                Name="DisableExternalDMAUnderLock";     T="DWord"; V=0; L="DMA Lock off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard";                               Name="EnableVirtualizationBasedSecurity"; T="DWord"; V=0; L="VBS off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";                       Name="DisableExceptionChainValidation";  T="DWord"; V=1; L="Exception chain off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";                       Name="KernelSEHOPEnabled";               T="DWord"; V=0; L="SEHOP off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";            Name="EnableCfg";                        T="DWord"; V=0; L="CFG off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager";                              Name="ProtectionMode";                   T="DWord"; V=0; L="Protection mode off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";            Name="FeatureSettingsOverride";           T="DWord"; V=3; L="Spectre/Meltdown off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";            Name="FeatureSettingsOverrideMask";       T="DWord"; V=3; L="Spectre mask off" }
    )
    foreach ($t in $tweaks) { Reg-Set $t.P $t.Name $t.T $t.V $t.L }
    Mark-Applied "mitigations"; Log-Action "PERF" "Mitigations disabled"
}

function Undo-Mitigations {
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverride"     "DWord" 0 "Spectre mitigations restauradas"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "FeatureSettingsOverrideMask" "DWord" 3 ""
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "EnableCfg" "DWord" 1 "CFG restaurado"
    Status "Mitigações restauradas" "" "OK"; Log-Action "PERF" "Mitigations restored"
}

function Apply-NTFS {
    Header "💾  NTFS Tweaks"
    $cmds = @(
        @{ C="fsutil behavior set memoryusage 2";          L="NTFS Memory = 2" },
        @{ C="fsutil behavior set mftzone 4";              L="MFT Zone = 4" },
        @{ C="fsutil behavior set disablelastaccess 1";    L="Last Access off" },
        @{ C="fsutil behavior set disabledeletenotify 0";  L="TRIM ativo" },
        @{ C="fsutil behavior set encryptpagingfile 0";    L="Page encryption off" }
    )
    foreach ($c in $cmds) { Cmd-Run $c.C $c.L | Out-Null }
    Mark-Applied "ntfs"; Log-Action "PERF" "NTFS Tweaks"
}

function Undo-NTFS {
    fsutil behavior set memoryusage 1 2>$null
    fsutil behavior set mftzone 1 2>$null
    fsutil behavior set disablelastaccess 0 2>$null
    fsutil behavior set encryptpagingfile 1 2>$null
    Status "NTFS restaurado ao padrão" "" "OK"
}

function Apply-Memory {
    Header "🧠  Tweaks de Memória"
    Cmd-Run "powershell Disable-MMAgent -MemoryCompression" "Memory Compression off" | Out-Null
    Cmd-Run "powershell Disable-MMAgent -PageCombining"     "Page Combining off"     | Out-Null
    $tweaks = @(
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache";       T="DWord"; V=1; L="Large System Cache on" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePagingExecutive"; T="DWord"; V=1; L="Paging Executive off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="MoveImages";             T="DWord"; V=0; L="ASLR off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power";             Name="HiberbootEnabled";       T="DWord"; V=0; L="Fast Startup off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\Power";                             Name="HibernateEnabled";       T="DWord"; V=0; L="Hibernação off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl";                  Name="Win32PrioritySeparation"; T="DWord"; V=38; L="Win32Priority = 38 (gaming)" }
    )
    foreach ($t in $tweaks) { Reg-Set $t.P $t.Name $t.T $t.V $t.L }
    Cmd-Run "powercfg /h off" "Hibernação desativada" | Out-Null
    Mark-Applied "memory"; Log-Action "PERF" "Memory Tweaks"
}

function Undo-Memory {
    Enable-MMAgent -MemoryCompression -EA SilentlyContinue
    Enable-MMAgent -PageCombining     -EA SilentlyContinue
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "LargeSystemCache"       "DWord" 0 "Large System Cache restaurado"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management" "DisablePagingExecutive" "DWord" 0 ""
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl"                   "Win32PrioritySeparation" "DWord" 2 "Win32Priority restaurado"
    powercfg /h on 2>$null
    Status "Memória restaurada ao padrão" "" "OK"
}

function Apply-Priorities {
    Header "⚙️  MMCSS + Prioridades"
    $procs = @(
        @{ N="csrss.exe";           CPU=4; IO=3;   Page=$null },
        @{ N="dwm.exe";             CPU=4; IO=3;   Page=$null },
        @{ N="ntoskrnl.exe";        CPU=4; IO=3;   Page=$null },
        @{ N="audiodg.exe";         CPU=2; IO=$null; Page=$null },
        @{ N="lsass.exe";           CPU=1; IO=0;   Page=0 },
        @{ N="SearchIndexer.exe";   CPU=1; IO=0;   Page=$null },
        @{ N="svchost.exe";         CPU=1; IO=$null; Page=$null },
        @{ N="TrustedInstaller.exe"; CPU=1; IO=0;  Page=$null },
        @{ N="wuauclt.exe";         CPU=1; IO=0;   Page=$null },
        @{ N="MsMpEng.exe";         CPU=1; IO=$null; Page=$null }
    )
    $i = 0
    foreach ($p in $procs) {
        $i++; Progress-Bar $i $procs.Count "Processos"
        $base = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($p.N)\PerfOptions"
        Reg-Set $base "CpuPriorityClass" "DWord" $p.CPU ""
        if ($null -ne $p.IO)   { Reg-Set $base "IoPriority"   "DWord" $p.IO   "" }
        if ($null -ne $p.Page) { Reg-Set $base "PagePriority" "DWord" $p.Page "" }
    }
    Status "Prioridades de processo configuradas" "" "OK"

    $mm = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Reg-Set $mm "NoLazyMode"           "DWord"  1     "MMCSS NoLazyMode on"
    Reg-Set $mm "AlwaysOn"             "DWord"  1     "MMCSS AlwaysOn"
    Reg-Set $mm "SystemResponsiveness" "DWord"  10    "System Responsiveness = 10"
    Reg-Set $mm "NetworkThrottlingIndex" "DWord" 4294967295 "Network Throttling off"
    $g = "$mm\Tasks\Games"
    Reg-Set $g "GPU Priority"        "DWord"  8      "Games GPU Priority = 8"
    Reg-Set $g "Priority"            "DWord"  6      "Games Priority = 6"
    Reg-Set $g "Scheduling Category" "String" "High" "Games Scheduling = High"
    Reg-Set $g "SFIO Priority"       "String" "High" "Games SFIO = High"
    Reg-Set $g "Latency Sensitive"   "String" "True" "Games Latency Sensitive"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity" "DisableFGBoostDecay" "DWord" 1 "FG Boost Decay off"
    Mark-Applied "priorities"; Log-Action "PERF" "Process Priorities + MMCSS"
}

function Apply-PowerThrottle {
    Header "⚡  Power Throttling"
    $keys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power\ModernSleep"
    )
    foreach ($k in $keys) { Reg-Set $k "CoalescingTimerInterval" "DWord" 0 "" }
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff"      "DWord" 1 "Power Throttling off"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 "CsEnabled"              "DWord" 0 "Connected Standby off"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 "EnergyEstimationEnabled" "DWord" 0 "Energy Estimation off"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 "EventProcessorEnabled"   "DWord" 0 "Event Processor off"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power\EnergyEstimation\TaggedEnergy" "DisableTaggedEnergyLogging" "DWord" 1 "Energy logging off"
    Mark-Applied "powerthrottle"; Log-Action "PERF" "Power Throttling disabled"
}

function Undo-PowerThrottle {
    Remove-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" -Name "PowerThrottlingOff" -EA SilentlyContinue
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Power" "CsEnabled" "DWord" 1 "Connected Standby restaurado"
    Status "Power Throttling restaurado" "" "OK"
}

function Apply-HAGS {
    Header "🖥️  HAGS + Game Mode + FSO"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"  "HwSchMode"                "DWord" 2 "HAGS on"
    Reg-Set "HKCU:\SOFTWARE\Microsoft\GameBar"                        "AllowAutoGameMode"        "DWord" 1 "Game Mode on"
    Reg-Set "HKCU:\SOFTWARE\Microsoft\GameBar"                        "AutoGameModeEnabled"      "DWord" 1 ""
    Reg-Set "HKCU:\SYSTEM\GameConfigStore"                            "GameDVR_FSEBehaviorMode"          "DWord" 0 "FSO on"
    Reg-Set "HKCU:\SYSTEM\GameConfigStore"                            "GameDVR_HonorUserFSEBehaviorMode" "DWord" 1 ""
    Reg-Set "HKCU:\SYSTEM\GameConfigStore"                            "GameDVR_DSEBehavior"              "DWord" 0 ""
    Reg-Set "HKCU:\SYSTEM\GameConfigStore"                            "GameDVR_DXGIHonorFSEWindowsCompatible" "DWord" 0 ""
    Reg-Set "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences"     "DirectXUserGlobalSettings" "String" "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" "Windowed Game Opt on"
    Reg-Set "HKCU:\Control Panel\Desktop"                             "MenuShowDelay"             "DWord" 0 "Menu delay = 0ms"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"  "DpiMapIommuContiguous"     "DWord" 1 "Contiguous memory (DXKernel)"
    Mark-Applied "hags"; Log-Action "PERF" "HAGS + GameMode + FSO"
}

function Apply-GPULatency {
    Header "🎮  Latência GPU + Resource Policy"
    $latVals = @("ExitLatency","Latency","LatencyToleranceDefault","LatencyToleranceFSVP",
                 "LatencyTolerancePerfOverride","LatencyToleranceScreenOffIR","LatencyToleranceVSyncEnabled",
                 "RtlCapabilityCheckLatency","DefaultD3TransitionLatencyActivelyUsed",
                 "DefaultD3TransitionLatencyIdleLongTime","DefaultD3TransitionLatencyIdleMonitorOff",
                 "DefaultD3TransitionLatencyIdleNoContext","DefaultD3TransitionLatencyIdleShortTime",
                 "DefaultLatencyToleranceIdle0","DefaultLatencyToleranceIdle1",
                 "DefaultLatencyToleranceMemory","DefaultLatencyToleranceNoContext",
                 "DefaultLatencyToleranceOther","DefaultLatencyToleranceTimerPeriod",
                 "MonitorLatencyTolerance","MonitorRefreshLatencyTolerance","TransitionLatency")

    $latKeys = @("HKLM:\SYSTEM\CurrentControlSet\Control\Power","HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power")
    foreach ($k in $latKeys) { foreach ($v in $latVals) { Reg-Set $k $v "DWord" 1 "" } }

    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorLatencyTolerance"        "DWord" 1 "DXGKrnl Monitor Latency = 1"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl" "MonitorRefreshLatencyTolerance" "DWord" 1 "DXGKrnl Refresh Latency = 1"

    # Resource Policy
    $rp = "HKLM:\SYSTEM\ResourcePolicyStore\ResourceSets\Policies"
    $cpuPolicies = @("HardCap0","Paused","SoftCapFull","SoftCapLow")
    foreach ($p in $cpuPolicies) {
        Reg-Set "$rp\CPU\$p" "CapPercentage"  "DWord" 0 ""
        Reg-Set "$rp\CPU\$p" "SchedulingType" "DWord" 0 ""
    }
    Reg-Set "$rp\Memory\NoCap" "CommitLimit"  "DWord" 4294967295 "Memory NoCap"
    Reg-Set "$rp\Memory\NoCap" "CommitTarget" "DWord" 4294967295 ""
    Reg-Set "$rp\IO\NoCap"     "IOBandwidth"  "DWord" 0 "IO NoCap"
    Status "Latência GPU + Resource Policy configurados" "" "OK"
    Mark-Applied "gpulatency"; Log-Action "PERF" "GPU Latency + Resource Policy"
}

function Apply-Startup {
    Header "🚀  Tweaks de Inicialização"
    # Disable Automatic Maintenance
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance" "MaintenanceDisabled" "DWord" 1 "Auto Maintenance off"
    # Disable FTH
    Reg-Set "HKLM:\SOFTWARE\Microsoft\FTH" "Enabled" "DWord" 0 "Fault Tolerant Heap off"
    # Disable Windows Insider
    Reg-Set "HKLM:\SOFTWARE\Microsoft\PolicyManager\current\device\System" "AllowExperimentation" "DWord" 0 "Insider Experiments off"
    # Timestamp
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Reliability" "TimeStampInterval" "DWord" 1 "Timestamp Interval = 1"
    # Disable DEP for IE
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Internet Explorer\Main" "DEPOff" "DWord" 1 "DEP off"
    Mark-Applied "startup_tweaks"; Log-Action "PERF" "Startup Tweaks"
}

function Undo-Performance {
    Header "🔄  Reverter Performance"
    W "  ⚠  Isso reverterá TODOS os tweaks de performance ao padrão Windows." $C.Warning
    if (-not (Confirm "Reverter performance ao padrão?")) { return }
    Restore-Point "Zibble - Before Undo Performance"
    Undo-BCD; Undo-NTFS; Undo-Memory; Undo-PowerThrottle
    # Undo HAGS
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" "DWord" 1 "HAGS restaurado"
    Reg-Set "HKCU:\Control Panel\Desktop" "MenuShowDelay" "DWord" 400 "Menu delay restaurado"
    Status "✅  Performance restaurada ao padrão Windows" "" "OK"
    Log-Action "PERF" "Full Performance Undo"
}

function Apply-AllPerformance {
    Header "✅  Performance Completa"
    W "  Isso aplicará TODAS as otimizações de performance." $C.Warning
    W "  Um benchmark será executado antes e depois." $C.Info
    if (-not (Confirm "Aplicar tudo + Benchmark?")) { return }
    Restore-Point "Zibble v2 - Before All Performance"
    W ""; W "  ── BENCHMARK INICIAL ─────────────────────────" $C.Sep
    $before = Run-Benchmark "before"
    W ""; W "  ── APLICANDO TWEAKS ─────────────────────────" $C.Sep
    Apply-BCD; Apply-NTFS; Apply-Memory; Apply-Priorities
    Apply-PowerThrottle; Apply-HAGS; Apply-GPULatency; Apply-Startup
    W ""; W "  ── BENCHMARK FINAL ──────────────────────────" $C.Sep
    $after  = Run-Benchmark "after"
    W ""; Show-BenchmarkComparison
    Status "✅  Todas as otimizações de performance aplicadas!" "Reinicie para efeito completo" "OK"
    Log-Action "PERF" "All Performance Applied"
}

# ==============================================================================
#  MÓDULO 2 — KBM (Teclado / Mouse / USB)
# ==============================================================================
function Menu-KBM {
    Header "⌨️  KBM — TECLADO, MOUSE & USB"
    W "  [1] Desativar Mouse Acceleration"           $C.Bright
    W "  [2] Desativar Mouse Smoothing"              $C.Bright
    W "  [3] Otimizar taxa de repetição do teclado"  $C.Bright
    W "  [4] Desativar teclas de acessibilidade"     $C.Bright
    W "  [5] MSI Mode para USB Controller"           $C.Bright
    W "  [6] Desativar USB Power Saving"             $C.Bright
    W "  [7] Fila de dados mouse/teclado"            $C.Bright
    W "  [R] Reverter KBM ao padrão"                 $C.Warning
    W "  [A] ✅  Aplicar tudo KBM"                   $C.Accent
    W ""; W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1" { Apply-MouseAccel;    Pause-Screen; Menu-KBM }
        "2" { Apply-MouseSmooth;   Pause-Screen; Menu-KBM }
        "3" { Apply-KeyboardRate;  Pause-Screen; Menu-KBM }
        "4" { Apply-AccessKeys;   Pause-Screen; Menu-KBM }
        "5" { Apply-USBMSIMode;    Pause-Screen; Menu-KBM }
        "6" { Apply-USBPowerSave;  Pause-Screen; Menu-KBM }
        "7" { Apply-InputQueues;   Pause-Screen; Menu-KBM }
        "R" { Undo-KBM;            Pause-Screen; Menu-KBM }
        "A" { Apply-AllKBM;        Pause-Screen; Menu-KBM }
        "0" { return }
        default { Menu-KBM }
    }
}

function Apply-MouseAccel {
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseSpeed"      "String" "0" "Mouse Acceleration off"
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseThreshold1" "String" "0" "MouseThreshold1 = 0"
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseThreshold2" "String" "0" "MouseThreshold2 = 0"
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseSensitivity" "String" "10" "Sensibilidade 1:1"
    Mark-Applied "mouse_accel"; Log-Action "KBM" "Mouse Acceleration off"
}

function Apply-MouseSmooth {
    if ($Global:IsLaptop) {
        if (-not (Confirm "Você usa o touchpad? Desativar mouse smoothing pode afetar o touchpad.")) { return }
    }
    $zeros = "00000000000000000000000000000000000000000000000000000000000000000000000000000000"
    Reg-Set "HKCU:\Control Panel\Mouse" "SmoothMouseXCurve" "Binary" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Mouse Smoothing X off"
    Reg-Set "HKCU:\Control Panel\Mouse" "SmoothMouseYCurve" "Binary" ([byte[]](0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0,0)) "Mouse Smoothing Y off"
    Mark-Applied "mouse_smooth"; Log-Action "KBM" "Mouse Smoothing off"
}

function Apply-KeyboardRate {
    Reg-Set "HKCU:\Control Panel\Keyboard" "KeyboardDelay" "String" "0"  "Keyboard delay = 0"
    Reg-Set "HKCU:\Control Panel\Keyboard" "KeyboardSpeed" "String" "31" "Keyboard speed = 31 (máx)"
    Mark-Applied "keyboard_rate"; Log-Action "KBM" "Keyboard rate optimized"
}

function Apply-AccessKeys {
    Reg-Set "HKCU:\Control Panel\Accessibility\StickyKeys"       "Flags" "String" "506" "Sticky Keys off"
    Reg-Set "HKCU:\Control Panel\Accessibility\Keyboard Response" "Flags" "String" "122" "Filter Keys off"
    Reg-Set "HKCU:\Control Panel\Accessibility\ToggleKeys"       "Flags" "String" "58"  "Toggle Keys off"
    Mark-Applied "access_keys"; Log-Action "KBM" "Accessibility keys disabled"
}

function Apply-USBMSIMode {
    $usbIds = (Get-WmiObject Win32_USBController | Where-Object {$_.PNPDeviceID -match "PCI\\VEN"}).PNPDeviceID
    foreach ($id in $usbIds) {
        $msiPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        $affPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\Affinity Policy"
        Reg-Set $msiPath "MSISupported" "DWord" 1 "USB MSI Mode: $($id.Substring(0,[Math]::Min(40,$id.Length)))"
        Reg-Set $affPath "DevicePriority" "DWord" 0 ""
    }
    Mark-Applied "usb_msi"; Log-Action "KBM" "USB MSI Mode enabled"
}

function Apply-USBPowerSave {
    $usbIds = (Get-WmiObject Win32_USBController | Where-Object {$_.PNPDeviceID -match "PCI\\VEN"}).PNPDeviceID
    $props = @("AllowIdleIrpInD3","D3ColdSupported","DeviceSelectiveSuspended","EnableSelectiveSuspend","EnhancedPowerManagementEnabled","SelectiveSuspendEnabled","SelectiveSuspendOn")
    foreach ($id in $usbIds) {
        $base = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters"
        foreach ($p in $props) { Reg-Set $base $p "DWord" 0 "" }
    }
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\USB" "DisableSelectiveSuspend" "DWord" 1 "USB Selective Suspend off"
    Mark-Applied "usb_power"; Log-Action "KBM" "USB Power Saving disabled"
    Status "USB Power Saving desativado" "" "OK"
}

function Apply-InputQueues {
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\mouclass\Parameters" "MouseDataQueueSize"    "DWord" 16   "Mouse queue = 16"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\kbdclass\Parameters" "KeyboardDataQueueSize" "DWord" 16   "Keyboard queue = 16"
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel" "DebugPollInterval"   "DWord" 1000 "Debug Poll Interval = 1000"
    Mark-Applied "input_queues"; Log-Action "KBM" "Input queues configured"
}

function Undo-KBM {
    Header "🔄  Reverter KBM"
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseSpeed"      "String" "1"   "Mouse Acceleration restaurado"
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseThreshold1" "String" "6"   ""
    Reg-Set "HKCU:\Control Panel\Mouse" "MouseThreshold2" "String" "10"  ""
    Reg-Set "HKCU:\Control Panel\Keyboard" "KeyboardDelay" "String" "1"  "Keyboard delay restaurado"
    Reg-Set "HKCU:\Control Panel\Keyboard" "KeyboardSpeed" "String" "31" ""
    Status "KBM restaurado ao padrão" "" "OK"
}

function Apply-AllKBM {
    Header "✅  KBM Completo"
    if (-not (Confirm "Aplicar todos os tweaks KBM?")) { return }
    Apply-MouseAccel; Apply-MouseSmooth; Apply-KeyboardRate
    Apply-AccessKeys; Apply-USBMSIMode; Apply-USBPowerSave; Apply-InputQueues
    Status "✅  KBM completo aplicado!" "" "OK"; Log-Action "KBM" "All KBM Applied"
}

# ==============================================================================
#  MÓDULO 3 — GPU & DISPLAY
# ==============================================================================
function Menu-GPU {
    Header "🖥️  GPU & DISPLAY" "GPU: $($Global:GPU)  |  Tipo: $($Global:GPUType)"

    if ($Global:GPUType -eq "NVIDIA") {
        W "  ── NVIDIA ──────────────────────────────────────────────────────" $C.Sep
        W "  [1] MSI Mode GPU          [2] Latency Tweaks"     $C.Bright
        W "  [3] Desativar HDCP        [4] Desativar TCC"      $C.Bright
        W "  [5] Desativar Telemetria  [6] Desativar P-States" $C.Bright
        W "  [7] KBoost (clock máx)    [8] Desativar TDR"      $C.Bright
        W "  [9] ✅  Aplicar tudo NVIDIA"                       $C.Accent
    } elseif ($Global:GPUType -eq "AMD") {
        W "  ── AMD ─────────────────────────────────────────────────────────" $C.Sep
        W "  [1] MSI Mode GPU          [2] Desativar Power Gating" $C.Bright
        W "  [3] Desativar Clock Gating [4] Desativar ULPS"    $C.Bright
        W "  [5] Ativar De-Lag         [6] Desativar AA"       $C.Bright
        W "  [7] Desativar ASPM        [8] ✅  Aplicar tudo AMD" $C.Accent
    } else {
        W "  [1] MSI Mode GPU          [2] iGPU Intel tweaks"  $C.Bright
    }

    W ""
    W "  [P] Plano de Energia    [D] Desativar P-States (GPU)" $C.Bright
    W "  [R] Reverter GPU        [0] Voltar"                   $C.Dim
    Sep2

    switch (Ask "Opção") {
        "1" { Apply-GPUMSIMode;      Pause-Screen; Menu-GPU }
        "2" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaLatency }     elseif ($Global:GPUType -eq "AMD") { Apply-AMDPowerGating }  else { Apply-IntelIGPU }; Pause-Screen; Menu-GPU }
        "3" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaHDCP }        elseif ($Global:GPUType -eq "AMD") { Apply-AMDClockGating }; Pause-Screen; Menu-GPU }
        "4" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaTCC }         elseif ($Global:GPUType -eq "AMD") { Apply-AMDULPS };        Pause-Screen; Menu-GPU }
        "5" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaTelemetry }   elseif ($Global:GPUType -eq "AMD") { Apply-AMDDeLag };       Pause-Screen; Menu-GPU }
        "6" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaPStates }     elseif ($Global:GPUType -eq "AMD") { Apply-AMDAA };          Pause-Screen; Menu-GPU }
        "7" { if ($Global:GPUType -eq "NVIDIA") { Apply-KBoost }            elseif ($Global:GPUType -eq "AMD") { Apply-AMDASPM };        Pause-Screen; Menu-GPU }
        "8" { if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaTDR }         elseif ($Global:GPUType -eq "AMD") { Apply-AllAMD };         Pause-Screen; Menu-GPU }
        "9" { Apply-AllNvidia;       Pause-Screen; Menu-GPU }
        "P" { Apply-PowerPlan;       Pause-Screen; Menu-GPU }
        "D" { Apply-DisablePStates;  Pause-Screen; Menu-GPU }
        "R" { Undo-GPU;              Pause-Screen; Menu-GPU }
        "0" { return }
        default { Menu-GPU }
    }
}

function Apply-GPUMSIMode {
    $gpuIds = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft|Basic" }).PNPDeviceID
    foreach ($id in $gpuIds) {
        Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" "DWord" 1 "GPU MSI Mode on"
        Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\Affinity Policy" "DevicePriority" "DWord" 0 ""
    }
    Mark-Applied "gpu_msi"; Log-Action "GPU" "GPU MSI Mode"
}

function Apply-NvidiaLatency {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    $vals = @("D3PCLatency","F1TransitionLatency","LOWLATENCY","Node3DLowLatency","RMDeepL1EntryLatencyUsec",
              "RmGspcMaxFtuS","RmGspcMinFtuS","RmGspcPerioduS","RMLpwrEiIdleThresholdUs","RMLpwrGrIdleThresholdUs",
              "RMLpwrGrRgIdleThresholdUs","RMLpwrMsIdleThresholdUs","VRDirectFlipDPCDelayUs",
              "VRDirectFlipTimingMarginUs","VRDirectJITFlipMsHybridFlipDelayUs",
              "vrrCursorMarginUs","vrrDeflickerMarginUs","vrrDeflickerMaxUs")
    foreach ($v in $vals) { Reg-Set $base $v "DWord" 1 "" }
    Reg-Set $base "PciLatencyTimerControl"      "DWord" 20 "PCI Latency = 20"
    Reg-Set $base "PreferSystemMemoryContiguous" "DWord" 1  "Contiguous memory on"
    Reg-Set $base "Acceleration.Level"           "DWord" 0  "Video acceleration on"
    Reg-Set $base "TrackResetEngine"             "DWord" 0  "DX event tracking off"
    Reg-Set $base "ValidateBlitSubRects"         "DWord" 0  "Blit verification off"
    Status "NVIDIA Latency Tweaks aplicados" "" "OK"
    Mark-Applied "nv_latency"; Log-Action "GPU" "NVIDIA Latency"
}
function Apply-NvidiaHDCP        { Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "RMHdcpKeyGlobZero" "DWord" 1 "HDCP off"; Mark-Applied "nv_hdcp" }
function Apply-NvidiaTCC         { Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000" "TCCSupported"      "DWord" 0 "TCC off";  Mark-Applied "nv_tcc"  }
function Apply-NvidiaTelemetry {
    $tasks = @("NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NVIDIA GeForce Experience SelfUpdate_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}","NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}")
    foreach ($t in $tasks) { schtasks /change /disable /tn $t 2>$null }
    Reg-Set "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" "DWord" 0 "NVIDIA telemetry off"
    @("EnableRID66610","EnableRID64640","EnableRID44231") | ForEach-Object { Reg-Set "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" $_ "DWord" 0 "" }
    Status "Telemetria NVIDIA desativada" "" "OK"; Mark-Applied "nv_telemetry"
}
function Apply-NvidiaPStates {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "DisableWriteCombining" "DWord" 1 "Write Combining off"
    $dpcKeys = @("HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm","HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\NVAPI","HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak","HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers","HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power")
    foreach ($k in $dpcKeys) { Reg-Set $k "RmGpsPsEnablePerCpuCoreDpc" "DWord" 1 "" }
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak" "DisplayPowerSaving" "DWord" 0 "NVIDIA Power Saving off"
    Status "NVIDIA P-States otimizados" "" "OK"; Mark-Applied "nv_pstates"
}
function Apply-KBoost {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "PerfLevelSrc"      "DWord" 0x2222 "KBoost on"
    Reg-Set $base "PowerMizerEnable"  "DWord" 0 ""; Reg-Set $base "PowerMizerLevel" "DWord" 0 ""; Reg-Set $base "PowerMizerLevelAC" "DWord" 0 ""
    Status "KBoost ativado — GPU travada no clock máximo" "" "OK"; Mark-Applied "kboost"
}
function Apply-NvidiaTDR {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    @("TdrLevel","TdrDelay","TdrDdiDelay","TdrDebugMode","TdrLimitCount","TdrLimitTime","TdrTestMode") | ForEach-Object { Reg-Set $base $_ "DWord" 0 "" }
    Status "TDR NVIDIA desativado" "" "OK"; Mark-Applied "nv_tdr"
}
function Apply-AllNvidia {
    Header "✅  Tudo NVIDIA"
    if (-not (Confirm "Aplicar todos os tweaks NVIDIA?")) { return }
    Restore-Point "Zibble - Before NVIDIA"
    Apply-GPUMSIMode; Apply-NvidiaLatency; Apply-NvidiaHDCP; Apply-NvidiaTCC
    Apply-NvidiaTelemetry; Apply-NvidiaPStates; Apply-KBoost; Apply-NvidiaTDR
    Status "✅  Todos tweaks NVIDIA aplicados!" "" "OK"; Log-Action "GPU" "All NVIDIA"
}
function Apply-AMDPowerGating {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    @("DisableSAMUPowerGating","DisableUVDPowerGatingDynamic","DisableVCEPowerGating","DisablePowerGating","DisableDrmdmaPowerGating","PP_GPUPowerDownEnabled") | ForEach-Object { Reg-Set $base $_ "DWord" 1 "" }
    Status "AMD Power Gating off" "" "OK"; Mark-Applied "amd_powergating"
}
function Apply-AMDClockGating {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "EnableVceSwClockGating" "DWord" 0 "VCE Clock Gating off"
    Reg-Set $base "EnableUvdClockGating"   "DWord" 0 "UVD Clock Gating off"
    Mark-Applied "amd_clockgating"
}
function Apply-AMDULPS {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "EnableUlps"    "DWord"  0 "ULPS off"; Reg-Set $base "EnableUlps_NA" "String" "0" ""
    Mark-Applied "amd_ulps"
}
function Apply-AMDDeLag {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "KMD_DeLagEnabled" "DWord" 1 "AMD De-Lag on"
    Reg-Set $base "KMD_FRTEnabled"   "DWord" 0 "Frame Rate Target off"
    Mark-Applied "amd_delag"
}
function Apply-AMDAA {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "AAF_NA" "DWord" 0 "AA off"; Reg-Set $base "StutterMode" "DWord" 0 "Stutter off"
    Mark-Applied "amd_aa"
}
function Apply-AMDASPM {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Reg-Set $base "EnableAspmL0s" "DWord" 0 "ASPM L0s off"
    Reg-Set $base "EnableAspmL1"  "DWord" 0 "ASPM L1 off"
    Mark-Applied "amd_aspm"
}
function Apply-AllAMD {
    Header "✅  Tudo AMD"
    if (-not (Confirm "Aplicar todos os tweaks AMD?")) { return }
    Restore-Point "Zibble - Before AMD"
    Apply-GPUMSIMode; Apply-AMDPowerGating; Apply-AMDClockGating
    Apply-AMDULPS; Apply-AMDDeLag; Apply-AMDAA; Apply-AMDASPM
    Status "✅  Todos tweaks AMD aplicados!" "" "OK"; Log-Action "GPU" "All AMD"
}
function Apply-IntelIGPU { Reg-Set "HKLM:\SOFTWARE\Intel\GMM" "DedicatedSegmentSize" "DWord" 512 "iGPU Segment = 512MB"; Mark-Applied "igpu" }

function Apply-DisablePStates {
    Header "⚡  Desativar P-States GPU"
    W "  Buscando ID do dispositivo de vídeo..." $C.Dim
    $gpuIds = (Get-WmiObject Win32_VideoController | Where-Object { $_.Name -notmatch "Microsoft|Basic" }).PNPDeviceID
    foreach ($id in $gpuIds) {
        $drvPath = "HKLM:\SYSTEM\ControlSet001\Enum\$id"
        $drv = (Get-ItemProperty $drvPath -Name "Driver" -EA SilentlyContinue).Driver
        if ($drv) {
            $classPath = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\$drv"
            Reg-Set $classPath "DisableDynamicPstate" "DWord" 1 "P-States GPU off: $drv"
        }
    }
    Mark-Applied "pstates"; Log-Action "GPU" "GPU P-States disabled"
}

function Apply-PowerPlan {
    Header "🔋  Plano de Energia"
    W "  [1] Alto Desempenho (Windows nativo)"    $C.Bright
    W "  [2] Desempenho Máximo (Ultimate)"         $C.Bright
    W "  [3] Restaurar planos originais"           $C.Dim
    W "  [0] Voltar"                               $C.Dim
    switch (Ask "Opção") {
        "1" { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c; Status "Alto Desempenho ativado" "" "OK" }
        "2" {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $guid = powercfg /list 2>&1 | Select-String "Ultimate" | ForEach-Object { ($_ -match '\(([\w-]+)\)') | Out-Null; $Matches[1] }
            if ($guid) { powercfg -setactive $guid; Status "Desempenho Máximo ativado" "" "OK" }
            else { Status "Ultimate não disponível nesta edição" "" "WARN" }
        }
        "3" { powercfg -restoredefaultschemes; Status "Planos restaurados" "" "OK" }
    }
}

function Undo-GPU {
    Header "🔄  Reverter GPU"
    if (-not (Confirm "Reverter tweaks de GPU?")) { return }
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    @("PerfLevelSrc","PowerMizerEnable","PowerMizerLevel","PowerMizerLevelAC","DisableWriteCombining") |
        ForEach-Object { Remove-ItemProperty $base -Name $_ -EA SilentlyContinue }
    Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers" "HwSchMode" "DWord" 1 "HAGS restaurado"
    Status "GPU restaurada ao padrão" "" "OK"; Log-Action "GPU" "GPU Undo"
}

# ==============================================================================
#  MÓDULO 4 — REDE
# ==============================================================================
function Menu-Network {
    Header "🌐  REDE" "Tweaks TCP/IP, NIC, IPv6, Delivery Optimization"
    W "  [1] Reset completo de rede"               $C.Bright
    W "  [2] Tweaks TCP/IP + Nagle's"              $C.Bright
    W "  [3] Desativar IPv6 / Teredo / ISATAP"     $C.Bright
    W "  [4] NIC Power Saving off + Buffers"       $C.Bright
    W "  [5] MSI Mode NIC"                         $C.Bright
    W "  [6] Desativar Delivery Optimization"      $C.Bright
    W "  [7] Configurar DNS personalizado"         $C.Bright
    W "  [R] Reverter rede ao padrão"              $C.Warning
    W "  [A] ✅  Aplicar tudo"                     $C.Accent
    W ""; W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1" { Apply-NetworkReset;  Pause-Screen; Menu-Network }
        "2" { Apply-TCPTweaks;     Pause-Screen; Menu-Network }
        "3" { Apply-IPv6Disable;   Pause-Screen; Menu-Network }
        "4" { Apply-NICPower;      Pause-Screen; Menu-Network }
        "5" { Apply-NICMSIMode;    Pause-Screen; Menu-Network }
        "6" { Apply-DelivOpt;      Pause-Screen; Menu-Network }
        "7" { Apply-CustomDNS;     Pause-Screen; Menu-Network }
        "R" { Undo-Network;        Pause-Screen; Menu-Network }
        "A" { Apply-AllNetwork;    Pause-Screen; Menu-Network }
        "0" { return }
        default { Menu-Network }
    }
}

function Apply-NetworkReset {
    W "  ⚠  A conexão cairá brevemente." $C.Warning
    if (-not (Confirm "Resetar rede?")) { return }
    @("ipconfig /release","ipconfig /renew","ipconfig /flushdns","netsh int ip reset",
      "netsh int ipv4 reset","netsh int ipv6 reset","netsh int tcp reset",
      "netsh winsock reset","netsh advfirewall reset","netsh http flush logbuffer") |
      ForEach-Object { Cmd-Run $_ $_ | Out-Null }
    Status "Rede resetada. Reinicie para finalizar." "" "OK"; Log-Action "NET" "Network Reset"
}

function Apply-TCPTweaks {
    if ($Global:IsWin11) { Cmd-Run "netsh int tcp set supplemental Template=Internet CongestionProvider=bbr2" "BBR2 (Win11)" | Out-Null }
    else                 { Cmd-Run "netsh int tcp set supplemental Internet congestionprovider=ctcp" "CTCP (Win10)" | Out-Null }

    $nc = @(
        @{ C="netsh int tcp set global autotuninglevel=disabled";  L="AutoTuning off" },
        @{ C="netsh int tcp set global ecncapability=disabled";    L="ECN off" },
        @{ C="netsh int tcp set global dca=enabled";               L="DCA on" },
        @{ C="netsh int tcp set global netdma=enabled";            L="NetDMA on" },
        @{ C="netsh int tcp set global rsc=disabled";              L="RSC off" },
        @{ C="netsh int tcp set global rss=enabled";               L="RSS on" },
        @{ C="netsh int tcp set global timestamps=disabled";       L="TCP Timestamps off" },
        @{ C="netsh int tcp set global initialRto=2000";           L="Initial RTO = 2000ms" },
        @{ C="netsh int tcp set global nonsackrttresiliency=disabled"; L="NonSack RTT off" },
        @{ C="netsh int tcp set global maxsynretransmissions=2";   L="Max SYN = 2" },
        @{ C="netsh int tcp set security mpp=disabled";            L="MPP off" },
        @{ C="netsh int tcp set security profiles=disabled";       L="Security Profiles off" },
        @{ C="netsh int tcp set heuristics disabled";              L="Scaling Heuristics off" },
        @{ C="netsh int ip set global neighborcachelimit=4096";    L="ARP Cache = 4096" },
        @{ C="netsh int ip set global taskoffload=disabled";       L="Task Offload off" }
    )
    foreach ($c in $nc) { Cmd-Run $c.C $c.L | Out-Null }

    $tr = @(
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="DefaultTTL";       T="DWord"; V=64;    L="TTL = 64" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="Tcp1323Opts";      T="DWord"; V=1;     L="TCP Window Scaling on" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="TcpMaxDupAcks";    T="DWord"; V=2;     L="TcpMaxDupAcks = 2" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="SackOpts";         T="DWord"; V=0;     L="SackOpts off" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="MaxUserPort";      T="DWord"; V=65534; L="Max Port = 65534" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; N="TcpTimedWaitDelay"; T="DWord"; V=30;   L="TimedWait = 30" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; N="TcpAckFrequency"; T="DWord"; V=1; L="Nagle off (ACK)" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; N="TCPNoDelay";      T="DWord"; V=1; L="Nagle off (NoDelay)" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; N="TcpDelAckTicks";  T="DWord"; V=0; L="DelAck = 0" },
        @{ P="HKLM:\SYSTEM\CurrentControlSet\Services\Ndis\Parameters"; N="RssBaseCpu"; T="DWord"; V=1; L="RSS Base CPU = 1" }
    )
    foreach ($t in $tr) { Reg-Set $t.P $t.N $t.T $t.V $t.L }
    Mark-Applied "tcp_tweaks"; Log-Action "NET" "TCP Tweaks"
}

function Apply-IPv6Disable {
    Cmd-Run "netsh int ipv6 set state disabled"   "IPv6 off"    | Out-Null
    Cmd-Run "netsh int isatap set state disabled" "ISATAP off"  | Out-Null
    Cmd-Run "netsh int teredo set state disabled" "Teredo off"  | Out-Null
    Mark-Applied "ipv6_off"; Log-Action "NET" "IPv6/Teredo/ISATAP disabled"
}

function Apply-NICPower {
    $nics = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\*" -EA SilentlyContinue | Where-Object { $_."*SpeedDuplex" -ne $null }
    $props = @("AutoPowerSaveModeEnabled","AdvancedEEE","*EEE","EEE","EnablePME","EnableGreenEthernet","EnableSavePowerNow","EnablePowerManagement","EnableDynamicPowerGating","EnableConnectedPowerGating","EnableWakeOnLan","NicAutoPowerSaver","PowerDownPll","PowerSavingMode","SmartPowerDownEnable","S5WakeOnLan","ULPMode","*WakeOnMagicPacket","*WakeOnPattern","WakeOnLink")
    foreach ($nic in $nics) {
        $path = $nic.PSPath
        foreach ($p in $props) { try { Set-ItemProperty $path $p "0" -EA SilentlyContinue } catch {} }
        try { Set-ItemProperty $path "JumboPacket"          "1514" -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "ReceiveBuffers"       "1024" -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "TransmitBuffers"      "4096" -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "*InterruptModeration" "0"    -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "*FlowControl"         "0"    -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "RSS"                  "1"    -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "TxIntDelay"           "0"    -EA SilentlyContinue } catch {}
        try { Set-ItemProperty $path "RxIntDelay"           "0"    -EA SilentlyContinue } catch {}
    }
    Get-NetAdapter -IncludeHidden | Set-NetIPInterface -WeakHostSend Enabled -WeakHostReceive Enabled -EA SilentlyContinue
    Status "NIC Power Saving off + WeakHost on" "" "OK"
    Mark-Applied "nic_power"; Log-Action "NET" "NIC Power Saving disabled"
}

function Apply-NICMSIMode {
    $ids = (Get-WmiObject Win32_NetworkAdapter | Where-Object { $_.PNPDeviceID -match "PCI\\VEN" }).PNPDeviceID
    foreach ($id in $ids) { Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" "MSISupported" "DWord" 1 "NIC MSI Mode on" }
    Mark-Applied "nic_msi"; Log-Action "NET" "NIC MSI Mode"
}

function Apply-DelivOpt {
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"   "DODownloadMode" "DWord" 0 "Delivery Optimization off"
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config"   "DownloadMode"   "DWord" 0 ""
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" "DownloadMode"   "DWord" 0 ""
    Mark-Applied "delivery_opt"; Log-Action "NET" "Delivery Optimization disabled"
}

function Apply-CustomDNS {
    Header "🌐  DNS Personalizado"
    W "  [1] Cloudflare    1.1.1.1 / 1.0.0.1"       $C.Bright
    W "  [2] Google        8.8.8.8 / 8.8.4.4"        $C.Bright
    W "  [3] Quad9         9.9.9.9 / 149.112.112.112" $C.Bright
    W "  [4] OpenDNS       208.67.222.222"            $C.Bright
    W "  [5] DNS Customizado"                         $C.Bright
    W "  [0] Voltar"                                  $C.Dim
    $dns = switch (Ask "Opção") {
        "1" { @("1.1.1.1","1.0.0.1") }
        "2" { @("8.8.8.8","8.8.4.4") }
        "3" { @("9.9.9.9","149.112.112.112") }
        "4" { @("208.67.222.222","208.67.220.220") }
        "5" { $p = Ask "DNS Primário"; $s = Ask "DNS Secundário"; @($p,$s) }
        default { return }
    }
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ServerAddresses ($dns[0],$dns[1]) -EA SilentlyContinue
        Status "DNS configurado em $($_.Name)" "$($dns[0]) / $($dns[1])" "OK"
    }
    ipconfig /flushdns | Out-Null
    Mark-Applied "custom_dns"; Log-Action "NET" "DNS set to $($dns[0])"
}

function Undo-Network {
    Header "🔄  Reverter Rede"
    if (-not (Confirm "Restaurar configurações de rede ao padrão?")) { return }
    Cmd-Run "netsh int tcp set global autotuninglevel=normal"  "AutoTuning restaurado" | Out-Null
    Cmd-Run "netsh int tcp set global ecncapability=default"   ""                      | Out-Null
    Cmd-Run "netsh int ipv6 set state enabled"                 "IPv6 restaurado"       | Out-Null
    Cmd-Run "netsh int teredo set state default"               "Teredo restaurado"     | Out-Null
    Get-NetAdapter | Where-Object { $_.Status -eq "Up" } | ForEach-Object {
        Set-DnsClientServerAddress -InterfaceIndex $_.ifIndex -ResetServerAddresses -EA SilentlyContinue
    }
    Status "Rede restaurada ao padrão" "" "OK"; Log-Action "NET" "Network Undo"
}

function Apply-AllNetwork {
    Header "✅  Rede Completa"
    W "  ⚠  A conexão cairá brevemente." $C.Warning
    if (-not (Confirm "Aplicar todos os tweaks de rede?")) { return }
    Restore-Point "Zibble - Before Network"
    Apply-NetworkReset; Apply-TCPTweaks; Apply-IPv6Disable
    Apply-NICPower; Apply-NICMSIMode; Apply-DelivOpt
    Status "✅  Todos os tweaks de rede aplicados!" "Reinicie para finalizar." "OK"
    Log-Action "NET" "All Network Applied"
}

# ==============================================================================
#  MÓDULO 5 — TELEMETRIA
# ==============================================================================
function Menu-Telemetry {
    Header "🔇  TELEMETRIA & PRIVACIDADE"
    W "  [1] Registry — Telemetria + Coleta"        $C.Bright
    W "  [2] Tasks Agendadas (desativar CEIP)"       $C.Bright
    W "  [3] AutoLoggers"                            $C.Bright
    W "  [4] Serviços de Telemetria"                 $C.Bright
    W "  [5] Publicidade + Rastreamento"             $C.Bright
    W "  [6] Privacidade de Permissões (câmera...)"  $C.Bright
    W "  [A] ✅  Aplicar tudo"                       $C.Accent
    W ""; W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1" { Apply-TelRegistry;      Pause-Screen; Menu-Telemetry }
        "2" { Apply-TelTasks;         Pause-Screen; Menu-Telemetry }
        "3" { Apply-AutoLoggers;      Pause-Screen; Menu-Telemetry }
        "4" { Apply-TelServices;      Pause-Screen; Menu-Telemetry }
        "5" { Apply-AdTracking;       Pause-Screen; Menu-Telemetry }
        "6" { Apply-Permissions;      Pause-Screen; Menu-Telemetry }
        "A" { Apply-AllTelemetry;     Pause-Screen; Menu-Telemetry }
        "0" { return }
        default { Menu-Telemetry }
    }
}

function Apply-TelRegistry {
    $tweaks = @(
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";          N="AllowTelemetry";                              T="DWord"; V=0; L="Telemetria = 0" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";          N="DoNotShowFeedbackNotifications";              T="DWord"; V=1; L="Feedback notifications off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";          N="AllowDeviceNameInTelemetry";                  T="DWord"; V=0; L="Device name telemetry off" },
        @{ P="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; N="AllowTelemetry";                        T="DWord"; V=0; L="AllowTelemetry policy = 0" },
        @{ P="HKCU:\SOFTWARE\Microsoft\InputPersonalization";                     N="RestrictImplicitInkCollection";               T="DWord"; V=1; L="Ink collection off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\InputPersonalization";                     N="RestrictImplicitTextCollection";              T="DWord"; V=1; L="Text collection off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat";               N="DisableInventory";                            T="DWord"; V=1; L="App inventory off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat";               N="AITEnable";                                   T="DWord"; V=0; L="AIT off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                  N="PublishUserActivities";                       T="DWord"; V=0; L="User activities off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";                  N="EnableActivityFeed";                          T="DWord"; V=0; L="Activity feed off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows";               N="CEIPEnable";                                  T="DWord"; V=0; L="CEIP off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";      N="DisableLocation";                             T="DWord"; V=1; L="Location off" },
        @{ P="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";      N="DisableSensors";                              T="DWord"; V=1; L="Sensors off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search";            N="BingSearchEnabled";                           T="DWord"; V=0; L="Bing Search off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search";            N="HistoryViewEnabled";                          T="DWord"; V=0; L="Search history off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SoftLandingEnabled";                     T="DWord"; V=0; L="Windows Tips off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="RotatingLockScreenOverlayEnabled";       T="DWord"; V=0; L="Spotlight off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="PreInstalledAppsEnabled";                T="DWord"; V=0; L="Pre-installed apps off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; N="SilentInstalledAppsEnabled";             T="DWord"; V=0; L="Silent install off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy";           N="TailoredExperiencesWithDiagnosticDataEnabled"; T="DWord"; V=0; L="Tailored experiences off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer";          N="ShowFrequent";                                T="DWord"; V=0; L="Frequent files off" },
        @{ P="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer";          N="ShowRecent";                                  T="DWord"; V=0; L="Recent files off" }
    )
    $i = 0
    foreach ($t in $tweaks) { $i++; Progress-Bar $i $tweaks.Count "Telemetria"; Reg-Set $t.P $t.N $t.T $t.V "" }
    Status "Registry de telemetria configurado" "" "OK"
    Mark-Applied "tel_registry"; Log-Action "TEL" "Telemetry Registry"
}

function Apply-TelTasks {
    $tasks = @(
        "\Microsoft\Windows\Customer Experience Improvement Program\Consolidator",
        "\Microsoft\Windows\Customer Experience Improvement Program\KernelCeipTask",
        "\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip",
        "\Microsoft\Windows\Customer Experience Improvement Program\Uploader",
        "\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser",
        "\Microsoft\Windows\Application Experience\ProgramDataUpdater",
        "\Microsoft\Windows\Application Experience\StartupAppTask",
        "\Microsoft\Windows\Application Experience\AitAgent",
        "\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector",
        "\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem",
        "\Microsoft\Windows\Autochk\Proxy",
        "\Microsoft\Windows\Maintenance\WinSAT",
        "\Microsoft\Windows\Windows Error Reporting\QueueReporting",
        "\Microsoft\Windows\DiskFootprint\Diagnostics",
        "\Microsoft\Windows\PI\Sqm-Tasks",
        "\Microsoft\Windows\NetTrace\GatherNetworkInfo",
        "\Microsoft\Windows\AppID\SmartScreenSpecific",
        "\Microsoft\Office\OfficeTelemetryAgentFallBack2016",
        "\Microsoft\Office\OfficeTelemetryAgentLogOn2016",
        "\Microsoft\Windows\Device Information\Device"
    )
    $i = 0
    foreach ($t in $tasks) {
        $i++; Progress-Bar $i $tasks.Count "Tasks"
        schtasks /change /tn $t /disable 2>$null
        Write-Log "Task disabled: $t" "ACTION" "TEL"
    }
    Status "Tasks de telemetria desativadas ($($tasks.Count))" "" "OK"
    Mark-Applied "tel_tasks"; Log-Action "TEL" "Telemetry Tasks"
}

function Apply-AutoLoggers {
    $loggers = @("AppModel","Cellcore","Circular Kernel Context Logger","CloudExperienceHostOobe","DataMarket","DefenderApiLogger","DefenderAuditLogger","DiagLog","HolographicDevice","iclsClient","iclsProxy","LwtNetLog","Microsoft-Windows-AssignedAccess-Trace","Microsoft-Windows-Setup","PEAuthLog","RdrLog","ReadyBoot","SetupPlatform","SetupPlatformTel","SocketHeciServer","SpoolerLogger","SQMLogger","TCPIPLOGGER","TileStore","Tpm","TPMProvisioningService","UBPM","WdiContextLog","WFP-IPsec Trace","WiFiSession","WinPhoneCritical")
    $i = 0
    foreach ($l in $loggers) {
        $i++; Progress-Bar $i $loggers.Count "AutoLoggers"
        Reg-Set "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" "Start" "DWord" 0 ""
    }
    Status "AutoLoggers desativados ($($loggers.Count))" "" "OK"
    Mark-Applied "autologgers"; Log-Action "TEL" "AutoLoggers disabled"
}

function Apply-TelServices {
    @("DiagTrack","dmwappushservice","diagnosticshub.standardcollector.service") | ForEach-Object {
        Stop-Service $_ -Force -EA SilentlyContinue
        Set-Service  $_ -StartupType Disabled -EA SilentlyContinue
        Status "Serviço desativado: $_" "" "OK"
    }
    Mark-Applied "tel_services"; Log-Action "TEL" "Telemetry Services"
}

function Apply-AdTracking {
    Reg-Set "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "DWord" 0 "Advertising ID off"
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo" "DisabledByGroupPolicy" "DWord" 1 "Ad policy off"
    Reg-Set "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "CdpSessionUserAuthzPolicy"       "DWord" 0 "CDP off"
    Reg-Set "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP" "NearShareChannelUserAuthzPolicy" "DWord" 0 "Near Share off"
    @("Accessibility","AppSync","BrowserSettings","Credentials","DesktopTheme","Language","PackageState","Personalization","StartLayout","Windows") |
        ForEach-Object { Reg-Set "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\$_" "Enabled" "DWord" 0 "" }
    Status "Publicidade e rastreamento desativados" "" "OK"
    Mark-Applied "ad_tracking"; Log-Action "TEL" "Ad Tracking disabled"
}

function Apply-Permissions {
    Header "🔒  Permissões de Privacidade"
    $perms = @("activity","appDiagnostics","appointments","bluetoothSync","broadFileSystemAccess","cellularData","chat","contacts","documentsLibrary","email","gazeInput","location","phoneCall","phoneCallHistory","picturesLibrary","radios","userDataTasks","userNotificationListener","videosLibrary")
    $base = "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CapabilityAccessManager\ConsentStore"
    $i = 0
    foreach ($p in $perms) {
        $i++; Progress-Bar $i $perms.Count "Permissões"
        Reg-Set "$base\$p" "Value" "String" "Deny" ""
    }
    # Manter câmera e microfone habilitados (úteis)
    Reg-Set "$base\webcam"     "Value" "String" "Allow" "Câmera mantida habilitada"
    Reg-Set "$base\microphone" "Value" "String" "Allow" "Microfone mantido habilitado"
    Status "Permissões de privacidade configuradas" "" "OK"
    Mark-Applied "permissions"; Log-Action "TEL" "Permissions configured"
}

function Apply-AllTelemetry {
    Header "✅  Telemetria Completa"
    if (-not (Confirm "Aplicar todas as configurações de privacidade?")) { return }
    Restore-Point "Zibble - Before Telemetry"
    Apply-TelRegistry; Apply-TelTasks; Apply-AutoLoggers
    Apply-TelServices; Apply-AdTracking; Apply-Permissions
    Status "✅  Telemetria e privacidade configuradas!" "" "OK"
    Log-Action "TEL" "All Telemetry Applied"
}

# ==============================================================================
#  MÓDULO 6 — DEBLOAT
# ==============================================================================
function Menu-Debloat {
    Header "🧹  DEBLOAT WINDOWS"
    W "  [1] Remover Apps Bloatware (lista completa)" $C.Bright
    W "  [2] Desativar Cortana"                       $C.Bright
    W "  [3] Desativar / Remover OneDrive"            $C.Bright
    W "  [4] Desativar Serviços Desnecessários"       $C.Bright
    W "  [5] Desativar Apps no Startup"               $C.Bright
    W "  [6] Remover Microsoft Edge (avançado)"       $C.Warning
    W "  [7] Desativar Windows Defender"              $C.Warning
    W "  [A] ✅  Aplicar tudo (exceto Edge/Defender)" $C.Accent
    W ""; W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1" { Remove-Bloat;           Pause-Screen; Menu-Debloat }
        "2" { Disable-Cortana;        Pause-Screen; Menu-Debloat }
        "3" { Disable-OneDrive;       Pause-Screen; Menu-Debloat }
        "4" { Disable-Services;       Pause-Screen; Menu-Debloat }
        "5" { Disable-StartupApps;    Pause-Screen; Menu-Debloat }
        "6" { Remove-Edge;            Pause-Screen; Menu-Debloat }
        "7" { Disable-Defender;       Pause-Screen; Menu-Debloat }
        "A" { Apply-AllDebloat;       Pause-Screen; Menu-Debloat }
        "0" { return }
        default { Menu-Debloat }
    }
}

function Remove-Bloat {
    Header "🗑️  Bloatware"
    $apps = @("*3DBuilder*","*bing*","*bingfinance*","*bingsports*","*BingWeather*","*CommsPhone*","*Facebook*","*Getstarted*","*Microsoft.Messaging*","*MicrosoftOfficeHub*","*Office.OneNote*","*OneNote*","*people*","*SkypeApp*","*solit*","*Sway*","*Twitter*","*WindowsAlarms*","*WindowsPhone*","*WindowsMaps*","*WindowsFeedbackHub*","*WindowsSoundRecorder*","*windowscommunicationsapps*","*zune*","*Xbox*","*MixedReality*","*Wallet*","*YourPhone*","*Microsoft3DViewer*","*BingSearch*","*PowerAutomate*","*GetHelp*","*Whiteboard*","*MicrosoftTeams*")
    $i = 0
    foreach ($a in $apps) {
        $i++; Progress-Bar $i $apps.Count "Removendo"
        Get-AppxPackage -AllUsers $a | Remove-AppxPackage -EA SilentlyContinue
        Write-Log "App removed: $a" "ACTION" "DEBLOAT"
    }
    Status "Bloatware removido ($($apps.Count) padrões)" "" "OK"
    Mark-Applied "bloat_removed"; Log-Action "DEBLOAT" "Bloatware removed"
}

function Disable-Cortana {
    $p = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Reg-Set $p "AllowCortana"           "DWord" 0 "Cortana off"
    Reg-Set $p "AllowCloudSearch"       "DWord" 0 "Cloud Search off"
    Reg-Set $p "AllowCortanaAboveLock"  "DWord" 0 "Cortana lockscreen off"
    Reg-Set $p "ConnectedSearchUseWeb"  "DWord" 0 "Connected Search off"
    Reg-Set $p "DisableWebSearch"       "DWord" 1 "Web Search off"
    Get-AppxPackage -AllUsers "*549981C3F5F10*" | Remove-AppxPackage -EA SilentlyContinue
    Status "Cortana desativada e removida" "" "OK"
    Mark-Applied "cortana_off"; Log-Action "DEBLOAT" "Cortana disabled"
}

function Disable-OneDrive {
    W "  ⚠  Desinstala o OneDrive e remove dados locais." $C.Warning
    if (-not (Confirm "Remover OneDrive?")) { return }
    Start-Process "$env:SYSTEMROOT\SYSWOW64\ONEDRIVESETUP.EXE" "/UNINSTALL" -Wait -EA SilentlyContinue
    @("$env:USERPROFILE\OneDrive","$env:LOCALAPPDATA\Microsoft\OneDrive","$env:PROGRAMDATA\Microsoft OneDrive") | ForEach-Object { Remove-Item $_ -Recurse -Force -EA SilentlyContinue }
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "DWord" 1 "OneDrive sync off"
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync"     "DWord" 1 ""
    Status "OneDrive removido" "" "OK"; Mark-Applied "onedrive_off"; Log-Action "DEBLOAT" "OneDrive removed"
}

function Disable-Services {
    $svcs = @("TapiSrv","WpcMonSvc","SEMgrSvc","PNRPsvc","WEPHOSTSVC","p2psvc","p2pimsvc","PhoneSvc","Wecsvc","SensorDataService","SensrSvc","perceptionsimulation","StiSvc","OneSyncSvc","WMPNetworkSvc","autotimesvc","edgeupdatem","MicrosoftEdgeElevationService","ALG","QWAVE","IpxlatCfgSvc","icssvc","DusmSvc","MapsBroker","edgeupdate","SensorService","shpamsvc","svsvc","SysMain","Netlogon","CscService","ssh-agent","AppReadiness","tzautoupdate","wisvc","defragsvc","SharedRealitySvc","RetailDemo","lltdsvc","TrkWks","DiagTrack","diagsvc","dmwappushsvc","TroubleshootingSvc","DsSvc","FrameServer","FontCache","InstallService","SENS","TabletInputService","lfsvc","diagnosticshub.standardcollector.service","SecurityHealthService")
    $i = 0
    foreach ($s in $svcs) {
        $i++; Progress-Bar $i $svcs.Count "Serviços"
        Set-Service $s -StartupType Disabled -EA SilentlyContinue
        Stop-Service $s -Force -EA SilentlyContinue
        Write-Log "Service disabled: $s" "ACTION" "DEBLOAT"
    }
    Status "Serviços desnecessários desativados ($($svcs.Count))" "" "OK"
    Mark-Applied "services_off"; Log-Action "DEBLOAT" "Unnecessary Services disabled"
}

function Disable-StartupApps {
    $apps = @("Discord","Synapse3","Spotify","EpicGamesLauncher","RiotClient","Steam","OneDrive","Skype","Teams","Cortana")
    foreach ($a in $apps) { Reg-Set "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" $a "Binary" ([byte[]](3,0,0,0,0,0,0,0,0,0,0,0)) "Startup off: $a" }
    Mark-Applied "startup_off"; Log-Action "DEBLOAT" "Startup apps disabled"
}

function Remove-Edge {
    Header "🗑️  Remover Microsoft Edge"
    W "  ⚠  AVISO: Isso removerá o Edge completamente." $C.Warning
    W "  Tenha outro navegador instalado antes de continuar." $C.Warning
    if (-not (Confirm "Remover Microsoft Edge?")) { return }
    $edgePath = "${env:ProgramFiles(x86)}\Microsoft\Edge\Application"
    $setup    = Get-ChildItem $edgePath -Filter "msedge.exe" -Recurse -EA SilentlyContinue | Select-Object -First 1
    if ($setup) {
        $setupExe = Join-Path (Split-Path $setup.FullName) "Installer\setup.exe"
        if (Test-Path $setupExe) {
            Start-Process $setupExe -ArgumentList "--uninstall --system-level --verbose-logging --force-uninstall" -Wait
            Status "Edge removido" "" "OK"
        }
    } else { Status "Edge não encontrado ou já removido" "" "SKIP" }
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\Main"        "AllowPrelaunch"     "DWord" 0 "Edge prelaunch off"
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\MicrosoftEdge\TabPreloader" "AllowTabPreloading" "DWord" 0 "Edge tab preloading off"
    Log-Action "DEBLOAT" "Edge removal attempted"
}

function Disable-Defender {
    Header "⚠️  Desativar Windows Defender"
    W "  ╔══════════════════════════════════════════════════╗" $C.Error
    W "  ║  AVISO CRÍTICO DE SEGURANÇA                      ║" $C.Error
    W "  ║  Isso desativará a proteção do seu computador.   ║" $C.Error
    W "  ║  Instale um antivírus alternativo ANTES.         ║" $C.Error
    W "  ║  Recomendado APENAS para PCs de gaming isolados. ║" $C.Error
    W "  ╚══════════════════════════════════════════════════╝" $C.Error
    W ""
    if (-not (Confirm "CONFIRMAR: Desativar Windows Defender?")) { return }
    if (-not (Confirm "Segunda confirmação necessária. Tem certeza?")) { return }
    @("Sense","WdNisSvc","WinDefend","SecurityHealthService","wscsvc") | ForEach-Object { Set-Service $_ -StartupType Disabled -EA SilentlyContinue }
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"     "DWord" 1 "Defender off"
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableRoutinelyTakingAction" "DWord" 1 ""
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" "DWord" 1 "Real-time protection off"
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableBehaviorMonitoring" "DWord" 1 ""
    Reg-Set "HKLM:\SOFTWARE\Policies\Microsoft\Windows"          "EnableSmartScreen"     "DWord" 0 "SmartScreen off"
    Status "Windows Defender desativado" "Reinicie para efeito completo" "OK"
    W "  ⚠  Seu PC está VULNERÁVEL. Instale um antivírus!" $C.Error
    Log-Action "DEBLOAT" "Windows Defender disabled" "WARN"
}

function Apply-AllDebloat {
    Header "✅  Debloat Completo"
    if (-not (Confirm "Aplicar debloat completo?")) { return }
    Restore-Point "Zibble - Before Debloat"
    Remove-Bloat; Disable-Cortana; Disable-Services; Disable-StartupApps
    Status "✅  Debloat concluído!" "" "OK"; Log-Action "DEBLOAT" "All Debloat Applied"
}

# ==============================================================================
#  MÓDULO 7 — INSTALAR APLICATIVOS
# ==============================================================================
function Menu-Install {
    Header "📦  INSTALAR APLICATIVOS" "Powered by Winget"

    $hasWinget = $null -ne (Get-Command winget -EA SilentlyContinue)
    if (-not $hasWinget) {
        Status "Winget não encontrado!" "Abra a Microsoft Store e instale o 'App Installer'" "WARN"
        Pause-Screen; return
    }
    Status "Winget disponível" (winget --version) "OK"
    W ""

    $categories = @{
        "G" = @{
            Name = "🎮 Gaming"
            Apps = @(
                @{ ID="Valve.Steam";               Name="Steam" },
                @{ ID="EpicGames.EpicGamesLauncher"; Name="Epic Games" },
                @{ ID="Discord.Discord";            Name="Discord" },
                @{ ID="MSI.Afterburner";            Name="MSI Afterburner" },
                @{ ID="REALiX.HWiNFO";             Name="HWiNFO64" },
                @{ ID="CPUID.CPU-Z";               Name="CPU-Z" },
                @{ ID="TechPowerUp.GPU-Z";         Name="GPU-Z" },
                @{ ID="CPUID.HWMonitor";           Name="HWMONITOR" },
                @{ ID="Geeks3D.FurMark";           Name="FurMark" },
                @{ ID="OBSProject.OBSStudio";      Name="OBS Studio" },
                @{ ID="RiotGames.LeagueOfLegends"; Name="League of Legends" }
            )
        }
        "U" = @{
            Name = "🛠️ Utilitários"
            Apps = @(
                @{ ID="7zip.7zip";                  Name="7-Zip" },
                @{ ID="VideoLAN.VLC";               Name="VLC" },
                @{ ID="Google.Chrome";              Name="Chrome" },
                @{ ID="Mozilla.Firefox";            Name="Firefox" },
                @{ ID="Microsoft.VisualStudioCode"; Name="VS Code" },
                @{ ID="Notepad++.Notepad++";        Name="Notepad++" },
                @{ ID="RARLab.WinRAR";              Name="WinRAR" },
                @{ ID="voidtools.Everything";       Name="Everything" },
                @{ ID="ShareX.ShareX";              Name="ShareX" },
                @{ ID="Spotify.Spotify";            Name="Spotify" },
                @{ ID="Bitwarden.Bitwarden";        Name="Bitwarden" },
                @{ ID="Rufus.Rufus";                Name="Rufus" }
            )
        }
        "D" = @{
            Name = "💻 Dev Tools"
            Apps = @(
                @{ ID="Git.Git";                        Name="Git" },
                @{ ID="Python.Python.3.12";             Name="Python 3.12" },
                @{ ID="OpenJS.NodeJS";                  Name="Node.js" },
                @{ ID="Docker.DockerDesktop";           Name="Docker Desktop" },
                @{ ID="Postman.Postman";                Name="Postman" },
                @{ ID="JetBrains.Toolbox";              Name="JetBrains Toolbox" },
                @{ ID="Microsoft.WindowsTerminal";      Name="Windows Terminal" },
                @{ ID="wez.wezterm";                    Name="WezTerm" }
            )
        }
        "S" = @{
            Name = "🔒 Segurança"
            Apps = @(
                @{ ID="Malwarebytes.Malwarebytes";       Name="Malwarebytes" },
                @{ ID="Piriform.CCleaner";               Name="CCleaner" },
                @{ ID="AnyBurn.AnyBurn";                Name="AnyBurn" },
                @{ ID="WiresharkFoundation.Wireshark";   Name="Wireshark" },
                @{ ID="ProtonTechnologies.ProtonVPN";    Name="ProtonVPN" }
            )
        }
    }

    foreach ($k in @("G","U","D","S")) {
        W "  [$k] $($categories[$k].Name)" $C.Accent
        $i = 0
        foreach ($a in $categories[$k].Apps) {
            $i++
            $isInstalled = (winget list --id $a.ID 2>$null | Select-String $a.ID) -ne $null
            $tag = if ($isInstalled) { "✓" } else { " " }
            $col = if ($isInstalled) { $C.Dim } else { $C.Bright }
            W "     [$tag] $($i.ToString().PadLeft(2)). $($a.Name)" $col
        }
        W ""
    }

    W "  [A] Instalar TUDO    [0] Voltar" $C.Dim
    Sep2

    $choice = Ask "Categoria (G/U/D/S) ou número do app"
    if ($choice -eq "0") { return }
    if ($choice -eq "A") {
        foreach ($k in @("G","U","D","S")) { foreach ($a in $categories[$k].Apps) { Install-Winget $a.ID $a.Name } }
        Pause-Screen; Menu-Install
        return
    }
    if ($categories.ContainsKey($choice.ToUpper())) {
        $cat = $categories[$choice.ToUpper()]
        W "  Instalando categoria: $($cat.Name)" $C.Accent
        foreach ($a in $cat.Apps) { Install-Winget $a.ID $a.Name }
        Pause-Screen; Menu-Install
        return
    }
    # Número de app — busca em todas as categorias
    $idx = [int]$choice - 1
    foreach ($k in @("G","U","D","S")) {
        if ($idx -ge 0 -and $idx -lt $categories[$k].Apps.Count) {
            $a = $categories[$k].Apps[$idx]
            Install-Winget $a.ID $a.Name
            Pause-Screen; Menu-Install
            return
        }
        $idx -= $categories[$k].Apps.Count
    }
    Menu-Install
}

function Install-Winget {
    param([string]$ID, [string]$Name)
    $alreadyInstalled = (winget list --id $ID 2>$null | Select-String $ID) -ne $null
    if ($alreadyInstalled) {
        Status "$Name já instalado" "use 'winget upgrade $ID' para atualizar" "SKIP"
        return
    }
    W "  ⬇  Instalando $Name..." $C.Accent
    $r = winget install --id $ID --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Status "$Name instalado" "" "OK"
        $list = [System.Collections.Generic.List[string]]$Global:Config.AppInstalled
        if ($list -notcontains $ID) { $list.Add($ID); $Global:Config.AppInstalled = $list.ToArray(); Save-Config }
        Log-Action "INSTALL" "$Name installed"
    } else {
        Status "$Name — falha na instalação" "exit: $LASTEXITCODE" "WARN"
        Log-Action "INSTALL" "$Name FAILED" "FAIL"
    }
}

# ==============================================================================
#  MÓDULO 8 — FIXES & DIAGNÓSTICO
# ==============================================================================
function Menu-Fixes {
    Header "🔧  FIXES & DIAGNÓSTICO"
    W "  ── Reparação do Sistema ────────────────────────────────────────" $C.Sep
    W "  [1]  SFC (Verificar ficheiros do sistema)"  $C.Bright
    W "  [2]  DISM (Reparar imagem Windows)"         $C.Bright
    W "  [3]  SFC + DISM (Scan completo)"            $C.Accent
    W "  [4]  Reset Windows Update"                  $C.Bright
    W "  [5]  Limpar fila de impressão (Spooler)"    $C.Bright
    W "  [6]  Verificar e reparar disco (CHKDSK)"    $C.Bright
    W ""
    W "  ── Rede & Conectividade ─────────────────────────────────────────" $C.Sep
    W "  [7]  Ping / Teste de conexão completo"      $C.Bright
    W "  [8]  Reset completo de rede"                $C.Bright
    W "  [9]  Recuperar senhas Wi-Fi"                $C.Bright
    W "  [10] Ver IP + adaptadores de rede"          $C.Bright
    W ""
    W "  ── Diagnóstico ──────────────────────────────────────────────────" $C.Sep
    W "  [11] Top processos por CPU + RAM"           $C.Bright
    W "  [12] Portas abertas (netstat)"              $C.Bright
    W "  [13] Espaço em disco detalhado"             $C.Bright
    W "  [14] Usuários logados"                      $C.Bright
    W "  [15] Reiniciar Windows Explorer"            $C.Bright
    W "  [16] Verificar drivers com erro"            $C.Bright
    W ""
    W "  [0]  Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1"  { Run-SFC;             Pause-Screen; Menu-Fixes }
        "2"  { Run-DISM;            Pause-Screen; Menu-Fixes }
        "3"  { Run-SFC; Run-DISM;  Pause-Screen; Menu-Fixes }
        "4"  { Reset-WinUpdate;     Pause-Screen; Menu-Fixes }
        "5"  { Clear-Spooler;       Pause-Screen; Menu-Fixes }
        "6"  { Run-CHKDSK;          Pause-Screen; Menu-Fixes }
        "7"  { Test-NetConn;        Pause-Screen; Menu-Fixes }
        "8"  { Apply-NetworkReset;  Pause-Screen; Menu-Fixes }
        "9"  { Get-WiFiPasswords;   Pause-Screen; Menu-Fixes }
        "10" { Show-NetworkInfo;    Pause-Screen; Menu-Fixes }
        "11" { Show-TopProcs;       Pause-Screen; Menu-Fixes }
        "12" { Show-Ports;          Pause-Screen; Menu-Fixes }
        "13" { Show-DiskInfo;       Pause-Screen; Menu-Fixes }
        "14" { query user 2>$null;  Pause-Screen; Menu-Fixes }
        "15" { Restart-Explr;       Pause-Screen; Menu-Fixes }
        "16" { Check-Drivers;       Pause-Screen; Menu-Fixes }
        "0"  { return }
        default { Menu-Fixes }
    }
}

function Run-SFC       { Header "🔍  SFC"; W "  Pode demorar alguns minutos..." $C.Warning; sfc /scannow; Log-Action "FIX" "SFC Scan" }
function Run-DISM      { Header "🔧  DISM"; W "  Requer internet. Pode demorar..." $C.Warning; DISM /Online /Cleanup-Image /RestoreHealth; Log-Action "FIX" "DISM Repair" }
function Run-CHKDSK    { Header "💾  CHKDSK"; W "  Será agendado para próximo boot." $C.Warning; chkdsk C: /f /r; Log-Action "FIX" "CHKDSK Scheduled" }
function Clear-Spooler {
    Stop-Service spooler -Force -EA SilentlyContinue
    Remove-Item "$env:SYSTEMROOT\System32\Spool\Printers\*" -Force -EA SilentlyContinue
    Start-Service spooler -EA SilentlyContinue
    Status "Fila de impressão limpa" "" "OK"; Log-Action "FIX" "Spooler cleared"
}
function Reset-WinUpdate {
    Header "🔄  Reset Windows Update"
    @("wuauserv","bits","cryptsvc","msiserver") | ForEach-Object { Stop-Service $_ -Force -EA SilentlyContinue }
    Remove-Item "C:\Windows\SoftwareDistribution" -Recurse -Force -EA SilentlyContinue
    Remove-Item "C:\Windows\System32\catroot2"    -Recurse -Force -EA SilentlyContinue
    @("wuauserv","bits","cryptsvc","msiserver") | ForEach-Object { Start-Service $_ -EA SilentlyContinue }
    Status "Windows Update resetado" "" "OK"; Log-Action "FIX" "Windows Update Reset"
}

function Test-NetConn {
    Header "📡  Teste de Conexão"
    $hosts = @("8.8.8.8","1.1.1.1","google.com","cloudflare.com")
    foreach ($h in $hosts) {
        $r = Test-Connection -ComputerName $h -Count 3 -EA SilentlyContinue
        if ($r) {
            $avg = [math]::Round(($r | Measure-Object ResponseTime -Average).Average)
            $min = ($r | Measure-Object ResponseTime -Minimum).Minimum
            $max = ($r | Measure-Object ResponseTime -Maximum).Maximum
            Status "$h" "avg:${avg}ms  min:${min}ms  max:${max}ms" "OK"
        } else { Status "$h" "sem resposta" "FAIL" }
    }
    W ""
    W "  Velocidade de download (estimativa):" $C.Dim
    try {
        $sw    = [Diagnostics.Stopwatch]::StartNew()
        $bytes = (Invoke-WebRequest "https://speed.cloudflare.com/__down?bytes=1000000" -UseBasicParsing -EA Stop).Content.Length
        $sw.Stop()
        $mbps  = [math]::Round(($bytes * 8) / ($sw.Elapsed.TotalSeconds * 1000000), 2)
        Status "Download estimado" "~${mbps} Mbps (1MB Cloudflare)" "OK"
    } catch { Status "Não foi possível medir velocidade" "" "WARN" }
}

function Get-WiFiPasswords {
    Header "📶  Senhas Wi-Fi"
    $profiles = netsh wlan show profiles 2>$null | Select-String ":\s+(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    if (-not $profiles) { Status "Nenhum perfil Wi-Fi encontrado" "" "WARN"; return }
    W ""; W "  Redes salvas:" $C.Dim; W ""
    foreach ($p in $profiles) {
        $key  = netsh wlan show profile name="$p" key=clear 2>$null | Select-String "Key Content\s*:\s*(.+)$|Conteúdo da chave\s*:\s*(.+)$"
        $pass = if ($key) { ($key.Matches.Groups[1].Value + $key.Matches.Groups[2].Value).Trim() } else { "(sem senha)" }
        W "  📶 " $C.Dim -NL; W "$p".PadRight(30) $C.Accent -NL; W "→ " $C.Sep -NL; W $pass $C.Primary
    }
}

function Show-NetworkInfo {
    Header "🌐  Informações de Rede"
    Get-NetIPConfiguration | Where-Object { $_.IPv4Address } | ForEach-Object {
        W "  Adaptador : " $C.Dim -NL; W $_.InterfaceAlias $C.Accent
        W "  IP        : " $C.Dim -NL; W $_.IPv4Address.IPAddress $C.Primary
        W "  Gateway   : " $C.Dim -NL; W $_.IPv4DefaultGateway.NextHop $C.Primary
        $dns = (Get-DnsClientServerAddress -InterfaceIndex $_.InterfaceIndex -AddressFamily IPv4 -EA SilentlyContinue).ServerAddresses -join " / "
        W "  DNS       : " $C.Dim -NL; W $dns $C.Primary
        Sep
    }
}

function Show-TopProcs {
    Header "📊  Top 20 Processos"
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 |
        Format-Table Name,Id,@{N="CPU(s)";E={[math]::Round($_.CPU,1)}},@{N="RAM(MB)";E={[math]::Round($_.WorkingSet/1MB,1)}},@{N="Threads";E={$_.Threads.Count}} -AutoSize
}

function Show-Ports {
    Header "🔌  Portas em Escuta"
    netstat -ano | Select-String "LISTENING" | Select-Object -First 30 | ForEach-Object { W "  $_" $C.Bright }
}

function Show-DiskInfo {
    Header "💾  Discos"
    Get-Volume | Where-Object { $_.DriveLetter } |
        Select-Object DriveLetter,FileSystemLabel,FileSystem,
            @{N="Total(GB)"; E={[math]::Round($_.Size/1GB,2)}},
            @{N="Livre(GB)"; E={[math]::Round($_.SizeRemaining/1GB,2)}},
            @{N="Uso(%)";    E={[math]::Round((($_.Size-$_.SizeRemaining)/$_.Size)*100,1)}} |
        Format-Table -AutoSize
}

function Restart-Explr {
    Stop-Process -Name explorer -Force -EA SilentlyContinue
    Start-Sleep 1; Start-Process explorer
    Status "Windows Explorer reiniciado" "" "OK"
}

function Check-Drivers {
    Header "🔍  Drivers com Erro"
    $bad = Get-WmiObject Win32_PnPEntity | Where-Object { $_.ConfigManagerErrorCode -ne 0 }
    if ($bad) { $bad | Format-Table Name,ConfigManagerErrorCode,Status -AutoSize }
    else { Status "Nenhum driver com erro detectado" "" "OK" }
}

# ==============================================================================
#  MÓDULO 9 — PRESETS
# ==============================================================================
function Menu-Presets {
    Header "🎯  PRESETS RÁPIDOS" "Aplica um conjunto otimizado de tweaks com um clique"
    W "  ┌──────────────────────────────────────────────────────────────────┐" $C.Sep
    W "  │  [1] 🎮  GAMER EXTREMO                                           │" $C.Bright
    W "  │      Performance + GPU + KBM + Rede + Telemetria + Debloat      │" $C.Dim
    W "  │      Desativa Defender, mitigações, bloatware. Máximo FPS.       │" $C.Dim
    W "  ├──────────────────────────────────────────────────────────────────┤" $C.Sep
    W "  │  [2] 💼  TRABALHO / ESCRITÓRIO                                   │" $C.Bright
    W "  │      Performance + Privacidade + Fixes. Mantém estabilidade.    │" $C.Dim
    W "  │      Sem desativar Defender. Foco em produtividade.              │" $C.Dim
    W "  ├──────────────────────────────────────────────────────────────────┤" $C.Sep
    W "  │  [3] 🛡️   MÍNIMO SEGURO                                          │" $C.Bright
    W "  │      Só tweaks sem risco: NTFS, MMCSS, Telemetria básica.       │" $C.Dim
    W "  │      Ideal para PCs de terceiros ou ambientes corporativos.      │" $C.Dim
    W "  ├──────────────────────────────────────────────────────────────────┤" $C.Sep
    W "  │  [4] 🖥️   SUPORTE TÉCNICO                                        │" $C.Bright
    W "  │      Diagnóstico completo + Fixes + Limpeza. Sem tweaks perm.   │" $C.Dim
    W "  │      Perfeito para uso no PC de cliente.                         │" $C.Dim
    W "  └──────────────────────────────────────────────────────────────────┘" $C.Sep
    W ""
    W "  [0] Voltar" $C.Dim; Sep2

    switch (Ask "Escolha o preset") {
        "1" { Apply-PresetGamer;        Pause-Screen; Menu-Presets }
        "2" { Apply-PresetWork;         Pause-Screen; Menu-Presets }
        "3" { Apply-PresetSafe;         Pause-Screen; Menu-Presets }
        "4" { Apply-PresetSupport;      Pause-Screen; Menu-Presets }
        "0" { return }
        default { Menu-Presets }
    }
}

function Apply-PresetGamer {
    Header "🎮  PRESET: GAMER EXTREMO"
    W "  Este preset aplicará otimizações agressivas." $C.Warning
    W "  Inclui: BCD, mitigações, GPU, KBM, rede, telemetria, debloat." $C.Dim
    if (-not (Confirm "Aplicar Preset Gamer Extremo?")) { return }
    Restore-Point "Zibble - Before Gamer Preset"
    W ""; W "  ── Benchmark inicial ────────────────────────" $C.Sep; Run-Benchmark "before"
    W ""; W "  [1/7] Performance..." $C.Accent
    Apply-BCD; Apply-NTFS; Apply-Memory; Apply-Priorities; Apply-PowerThrottle; Apply-HAGS; Apply-GPULatency
    W "  [2/7] GPU..." $C.Accent
    Apply-GPUMSIMode
    if ($Global:GPUType -eq "NVIDIA") { Apply-NvidiaLatency; Apply-NvidiaPStates; Apply-KBoost }
    elseif ($Global:GPUType -eq "AMD") { Apply-AMDPowerGating; Apply-AMDDeLag }
    W "  [3/7] KBM..." $C.Accent
    Apply-AllKBM
    W "  [4/7] Rede..." $C.Accent
    Apply-TCPTweaks; Apply-IPv6Disable; Apply-NICPower; Apply-DelivOpt
    W "  [5/7] Telemetria..." $C.Accent
    Apply-TelRegistry; Apply-TelTasks; Apply-AutoLoggers; Apply-TelServices; Apply-AdTracking
    W "  [6/7] Debloat..." $C.Accent
    Remove-Bloat; Disable-Cortana; Disable-Services
    W "  [7/7] Benchmark final..." $C.Accent
    Run-Benchmark "after"; Show-BenchmarkComparison
    $Global:Config.Preset = "gamer"; Save-Config
    Status "✅  Preset Gamer Extremo aplicado!" "Reinicie para efeito completo." "OK"
    Log-Action "PRESET" "Gamer Extreme applied"
}

function Apply-PresetWork {
    Header "💼  PRESET: TRABALHO"
    if (-not (Confirm "Aplicar Preset Trabalho/Escritório?")) { return }
    Restore-Point "Zibble - Before Work Preset"
    Apply-NTFS; Apply-Memory; Apply-Priorities; Apply-PowerThrottle; Apply-HAGS
    Apply-TelRegistry; Apply-TelTasks; Apply-AutoLoggers; Apply-TelServices; Apply-AdTracking
    Apply-TCPTweaks; Apply-DelivOpt
    Apply-MouseAccel; Apply-KeyboardRate; Apply-AccessKeys
    $Global:Config.Preset = "work"; Save-Config
    Status "✅  Preset Trabalho aplicado!" "" "OK"; Log-Action "PRESET" "Work preset applied"
}

function Apply-PresetSafe {
    Header "🛡️  PRESET: MÍNIMO SEGURO"
    if (-not (Confirm "Aplicar Preset Mínimo Seguro?")) { return }
    Restore-Point "Zibble - Before Safe Preset"
    Apply-NTFS; Apply-Memory; Apply-Priorities; Apply-HAGS
    Apply-TelRegistry; Apply-TelTasks; Apply-TelServices
    $Global:Config.Preset = "safe"; Save-Config
    Status "✅  Preset Mínimo Seguro aplicado!" "" "OK"; Log-Action "PRESET" "Safe preset applied"
}

function Apply-PresetSupport {
    Header "🖥️  PRESET: SUPORTE TÉCNICO"
    W "  Executando diagnóstico completo..." $C.Dim
    Run-SFC; Reset-WinUpdate; Clear-Spooler
    Apply-NetworkReset; Run-PCCleaner
    $h = Get-SystemHealth
    Status "Diagnóstico concluído" "Score: $(($h.HAGS,$h.GameMode,$h.TelemetryOff,$h.NagleOff | Where-Object {$_}).Count)/4" "OK"
    Log-Action "PRESET" "Support preset run"
}

# ==============================================================================
#  MÓDULO 10 — PAINÉIS & EXTRAS
# ==============================================================================
function Menu-Extras {
    Header "🗂️  PAINÉIS & EXTRAS"
    W "  ── 🪟 Painéis do Windows ──────────────────────────────────────" $C.Sep
    W "  [1]  Painel de Controle      [2]  Gerenciamento do Computador" $C.Bright
    W "  [3]  Conexões de Rede        [4]  Propriedades do Sistema"      $C.Bright
    W "  [5]  Gerenciador de Dispositivos [6]  Configurações de Energia" $C.Bright
    W "  [7]  Editor de Registro      [8]  Serviços do Windows"          $C.Bright
    W "  [9]  Agendador de Tarefas    [10] Restauração do Sistema"       $C.Bright
    W "  [11] Variáveis de Ambiente   [12] Monitor de Desempenho"        $C.Bright
    W ""
    W "  ── 🧹 Limpeza & Relatórios ──────────────────────────────────" $C.Sep
    W "  [13] Limpeza de PC (Temp, Prefetch, Logs)"                      $C.Bright
    W "  [14] Relatório de bateria (HTML no Desktop)"                    $C.Bright
    W "  [15] Diagnóstico do sistema (TXT no Desktop)"                   $C.Bright
    W "  [16] Relatório HTML completo do Zibble"                         $C.Accent
    W "  [17] Abrir log do Zibble"                                       $C.Bright
    W "  [18] Verificar atualizações do Zibble"                          $C.Bright
    W ""
    W "  [0]  Voltar" $C.Dim; Sep2

    switch (Ask "Opção") {
        "1"  { Start-Process control;       Pause-Screen; Menu-Extras }
        "2"  { Start-Process compmgmt.msc;  Pause-Screen; Menu-Extras }
        "3"  { Start-Process ncpa.cpl;      Pause-Screen; Menu-Extras }
        "4"  { Start-Process sysdm.cpl;     Pause-Screen; Menu-Extras }
        "5"  { Start-Process devmgmt.msc;   Pause-Screen; Menu-Extras }
        "6"  { Start-Process powercfg.cpl;  Pause-Screen; Menu-Extras }
        "7"  { Start-Process regedit;       Pause-Screen; Menu-Extras }
        "8"  { Start-Process services.msc;  Pause-Screen; Menu-Extras }
        "9"  { Start-Process taskschd.msc;  Pause-Screen; Menu-Extras }
        "10" { Start-Process rstrui.exe;    Pause-Screen; Menu-Extras }
        "11" { Start-Process rundll32 -ArgumentList "sysdm.cpl,EditEnvironmentVariables"; Pause-Screen; Menu-Extras }
        "12" { Start-Process perfmon;       Pause-Screen; Menu-Extras }
        "13" { Run-PCCleaner;               Pause-Screen; Menu-Extras }
        "14" { Make-BatteryReport;          Pause-Screen; Menu-Extras }
        "15" { Make-SysDiag;               Pause-Screen; Menu-Extras }
        "16" { Make-HTMLReport;             Pause-Screen; Menu-Extras }
        "17" { if (Test-Path $Global:LogPath) { notepad $Global:LogPath } else { Status "Log não criado ainda" "" "WARN" }; Pause-Screen; Menu-Extras }
        "18" { Check-Updates;               Pause-Screen; Menu-Extras }
        "0"  { return }
        default { Menu-Extras }
    }
}

function Run-PCCleaner {
    Header "🧹  Limpeza de PC"
    $paths = @("$env:TEMP\*","$env:WINDIR\Temp\*","$env:WINDIR\Prefetch\*","$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db","$env:SYSTEMDRIVE\*.tmp","$env:WINDIR\SoftwareDistribution\Download\*")
    $totalMB = 0
    foreach ($p in $paths) {
        try {
            $size = (Get-Item $p -EA SilentlyContinue | Measure-Object Length -Sum -EA SilentlyContinue).Sum
            Remove-Item $p -Recurse -Force -EA SilentlyContinue
            $mb = [math]::Round($size/1MB, 2)
            if ($mb -gt 0) { Status "Limpo: $(Split-Path $p -Parent)" "${mb} MB" "OK"; $totalMB += $mb }
        } catch {}
    }
    Remove-Item "$env:SYSTEMROOT\Logs\CBS\CBS.log"   -Force -EA SilentlyContinue
    Remove-Item "$env:SYSTEMROOT\Logs\DISM\DISM.log" -Force -EA SilentlyContinue
    W ""; W "  Total liberado: " $C.Dim -NL; W "$([math]::Round($totalMB,2)) MB" $C.Accent
    Log-Action "EXTRA" "PC Cleaner — freed ${totalMB}MB"
}

function Make-BatteryReport {
    $p = "$env:USERPROFILE\Desktop\zibble_bateria.html"
    powercfg /batteryreport /output $p 2>$null
    if (Test-Path $p) { Status "Relatório de bateria salvo" "Desktop\zibble_bateria.html" "OK"; Start-Process $p }
    else { Status "Sem bateria detectada neste dispositivo" "" "WARN" }
}

function Make-SysDiag {
    $p = "$env:USERPROFILE\Desktop\zibble_diagnostico.txt"
    W "  Gerando diagnóstico completo..." $C.Dim
    $info = Get-ComputerInfo
    $info | Out-File $p -Encoding UTF8
    Status "Diagnóstico salvo" "Desktop\zibble_diagnostico.txt" "OK"
    notepad $p
}

function Make-HTMLReport {
    Header "📄  Relatório HTML do Zibble"
    W "  Gerando relatório completo..." $C.Dim
    $h = Get-SystemHealth
    $score = @($h.HAGS,$h.GameMode,$h.PowerThrottling,$h.FastStartupOff,$h.TelemetryOff,$h.IPv6Disabled,$h.NagleOff,$h.MemCompressionOff) | Where-Object { $_ } | Measure-Object | Select-Object -ExpandProperty Count
    $scorePct = [math]::Round(($score / 8) * 100)
    $date     = Get-Date -Format "dd/MM/yyyy HH:mm:ss"
    $applied  = ($Global:Config.Applied | Measure-Object).Count
    $sessions = $Global:Config.SessionCount
    $preset   = $Global:Config.Preset

    # Session actions table
    $actRows  = ($Global:SessionActions | ForEach-Object { "<tr><td>$($_.Time.ToString('HH:mm:ss'))</td><td>$($_.Module)</td><td>$($_.Action)</td><td style='color:$(if($_.Result -eq "OK"){"#00FF41"}else{"#FF5555"})'>$($_.Result)</td></tr>" }) -join ""

    $html = @"
<!DOCTYPE html><html lang="pt-BR"><head>
<meta charset="UTF-8"><meta name="viewport" content="width=device-width,initial-scale=1">
<title>Zibble's Performance — Relatório</title>
<style>
  :root{--green:#00FF41;--dim:#1a5c2a;--bg:#0a0a0a;--card:#111;--border:#1e4d2e}
  *{margin:0;padding:0;box-sizing:border-box}
  body{background:var(--bg);color:var(--green);font-family:'Courier New',monospace;padding:2rem}
  h1{font-size:2rem;text-align:center;margin-bottom:.5rem;text-shadow:0 0 20px var(--green)}
  h2{font-size:1rem;color:var(--dim);text-align:center;margin-bottom:2rem}
  .grid{display:grid;grid-template-columns:repeat(auto-fit,minmax(300px,1fr));gap:1.5rem;margin-bottom:2rem}
  .card{background:var(--card);border:1px solid var(--border);border-radius:8px;padding:1.5rem}
  .card h3{color:var(--green);margin-bottom:1rem;font-size:.9rem;text-transform:uppercase;letter-spacing:.1em}
  .stat{display:flex;justify-content:space-between;padding:.4rem 0;border-bottom:1px solid var(--border);font-size:.85rem}
  .on{color:#00FF41}.off{color:#cc3333}
  .score-bar{background:#1a1a1a;border-radius:4px;height:20px;overflow:hidden;margin:1rem 0}
  .score-fill{background:linear-gradient(90deg,#00FF41,#00cc33);height:100%;transition:width 1s}
  table{width:100%;border-collapse:collapse;font-size:.8rem}
  th{color:var(--dim);padding:.5rem;text-align:left;border-bottom:1px solid var(--border)}
  td{padding:.4rem;border-bottom:1px solid #1a1a1a}
  .footer{text-align:center;color:var(--dim);font-size:.75rem;margin-top:2rem}
  .ascii{text-align:center;font-size:.7rem;color:var(--dim);margin-bottom:1rem;line-height:1.2}
</style></head><body>
<div class="ascii"><pre>
███████╗██╗██████╗ ██████╗ ██╗     ███████╗
╚════██║██║██╔══██╗██╔══██╗██║     ██╔════╝
    ██╔╝██║██████╔╝██████╔╝██║     █████╗
   ██╔╝ ██║██╔══██╗██╔══██╗██║     ██╔══╝
   ██║  ██║██████╔╝██████╔╝███████╗███████╗
   ╚═╝  ╚═╝╚═════╝ ╚═════╝ ╚══════╝╚══════╝</pre></div>
<h1>Zibble's Performance v$($Global:Version)</h1>
<h2>Relatório gerado em $date</h2>

<div class="grid">
<div class="card">
  <h3>🖥️ Sistema</h3>
  <div class="stat"><span>Host</span><span>$Global:Hostname</span></div>
  <div class="stat"><span>OS</span><span>$Global:WinName (Build $Global:WinBuild)</span></div>
  <div class="stat"><span>CPU</span><span>$($Global:CPU.Substring(0,[Math]::Min(35,$Global:CPU.Length)))</span></div>
  <div class="stat"><span>RAM</span><span>$($Global:RAM) GB</span></div>
  <div class="stat"><span>GPU</span><span>$($Global:GPUType) — $($Global:GPU.Substring(0,[Math]::Min(25,$Global:GPU.Length)))</span></div>
  <div class="stat"><span>Laptop</span><span>$(if($Global:IsLaptop){"Sim"}else{"Não"})</span></div>
  <div class="stat"><span>Uptime</span><span>$($h.UptimeHours)h</span></div>
</div>

<div class="card">
  <h3>⚡ Score de Otimização</h3>
  <div class="score-bar"><div class="score-fill" style="width:$scorePct%"></div></div>
  <div class="stat"><span>Score</span><span class="on">$scorePct%</span></div>
  <div class="stat"><span>Tweaks aplicados</span><span class="on">$applied</span></div>
  <div class="stat"><span>Sessões</span><span>$sessions</span></div>
  <div class="stat"><span>Preset</span><span>$preset</span></div>
  <div class="stat"><span>Disco C livre</span><span>$($h.DiskFreeGB) GB ($($h.DiskUsePct)% usado)</span></div>
</div>

<div class="card">
  <h3>🎮 Status dos Tweaks</h3>
  <div class="stat"><span>HAGS</span><span class="$(if($h.HAGS){"on"}else{"off"})">$(if($h.HAGS){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Game Mode</span><span class="$(if($h.GameMode){"on"}else{"off"})">$(if($h.GameMode){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Power Throttling Off</span><span class="$(if($h.PowerThrottling){"on"}else{"off"})">$(if($h.PowerThrottling){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Fast Startup Off</span><span class="$(if($h.FastStartupOff){"on"}else{"off"})">$(if($h.FastStartupOff){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Telemetria Off</span><span class="$(if($h.TelemetryOff){"on"}else{"off"})">$(if($h.TelemetryOff){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>IPv6 Off</span><span class="$(if($h.IPv6Disabled){"on"}else{"off"})">$(if($h.IPv6Disabled){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Nagle Off</span><span class="$(if($h.NagleOff){"on"}else{"off"})">$(if($h.NagleOff){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Mem Compression Off</span><span class="$(if($h.MemCompressionOff){"on"}else{"off"})">$(if($h.MemCompressionOff){"✓ ON"}else{"✗ OFF"})</span></div>
  <div class="stat"><span>Bloatware detectado</span><span class="$(if($h.BloatCount -eq 0){"on"}else{"off"})">$($h.BloatCount) apps</span></div>
</div></div>

$(if($actRows -ne "") {
"<div class='card' style='margin-bottom:2rem'>
<h3>📋 Ações desta Sessão</h3>
<table><tr><th>Hora</th><th>Módulo</th><th>Ação</th><th>Resultado</th></tr>$actRows</table>
</div>"
})

<div class="footer">
  Gerado por Zibble's Performance v$($Global:Version) — $date<br>
  github.com/SEU_USUARIO/zibble
</div></body></html>
"@

    $html | Set-Content $Global:ReportPath -Encoding UTF8
    Status "Relatório HTML gerado" "Desktop\zibble_report.html" "OK"
    Start-Process $Global:ReportPath
    Log-Action "EXTRA" "HTML Report generated"
}

function Check-Updates {
    Header "🔄  Verificar Atualizações"
    W "  Verificando versão mais recente..." $C.Dim
    try {
        $latest = (Invoke-WebRequest $Global:UpdateUrl -UseBasicParsing -EA Stop -TimeoutSec 5).Content.Trim()
        if ($latest -ne $Global:Version) {
            W ""
            W "  ⬆  Nova versão disponível: v$latest  (atual: v$Global:Version)" $C.Accent
            W "  Execute o comando abaixo para atualizar:" $C.Dim
            W "  irm $Global:ScriptUrl | iex" $C.Primary
        } else {
            Status "Você já está na versão mais recente (v$Global:Version)" "" "OK"
        }
    } catch {
        Status "Não foi possível verificar atualizações" "sem internet ou URL não configurada" "WARN"
    }
}

# ==============================================================================
#  MENU PRINCIPAL
# ==============================================================================
function Menu-Main {
    Header ""
    # Info compacta
    W "  OS: " $C.Dim -NL; W "$Global:WinName" $C.Accent -NL
    W "  │  GPU: " $C.Dim -NL; W "$($Global:GPUType)" $C.Accent -NL
    W "  │  Preset: " $C.Dim -NL; W "$($Global:Config.Preset)" $C.Accent -NL
    W "  │  Tweaks: " $C.Dim -NL; W "$($Global:Config.TweaksApplied)" $C.Accent -NL
    W "  │  Modo: " $C.Dim -NL
    if ($Global:SafeMode) { W "SEGURO" $C.Warning } else { W "AVANÇADO" $C.Primary }
    W ""
    Sep
    W ""
    W "  [1]  ⚡  Performance          [2]  ⌨️   KBM (Mouse/Teclado/USB)" $C.Primary
    W "  [3]  🖥️   GPU & Display        [4]  🌐   Rede"                    $C.Primary
    W "  [5]  🔇  Telemetria           [6]  🧹   Debloat Windows"          $C.Primary
    W "  [7]  📦  Instalar Apps        [8]  🔧   Fixes & Diagnóstico"      $C.Primary
    W "  [9]  🎯  Presets Rápidos      [10] 🗂️   Painéis & Extras"         $C.Primary
    W ""
    Sep
    W "  [D]  📊  Dashboard (Status do Sistema)"                           $C.Accent
    W "  [B]  📈  Benchmark  [R]  🔁  Restore Point  [M]  🔄  Modo $(if($Global:SafeMode){"Avançado"}else{"Seguro"})" $C.Dim
    W "  [U]  🔄  Verificar Updates    [L]  📄  Log"                       $C.Dim
    W "  [0]  ❌  Sair"                                                    $C.Dim
    Sep2

    switch (Ask "Módulo") {
        "1"  { Menu-Performance }
        "2"  { Menu-KBM }
        "3"  { Menu-GPU }
        "4"  { Menu-Network }
        "5"  { Menu-Telemetry }
        "6"  { Menu-Debloat }
        "7"  { Menu-Install }
        "8"  { Menu-Fixes }
        "9"  { Menu-Presets }
        "10" { Menu-Extras }
        "D"  { Show-Dashboard }
        "B"  { $ph = Ask "Fase (before/after)"; if ($ph -match "^[bB]") { Run-Benchmark "before" } else { Run-Benchmark "after"; Show-BenchmarkComparison }; Pause-Screen }
        "R"  { Restore-Point "Zibble Manual Backup"; Pause-Screen }
        "M"  { $Global:SafeMode = -not $Global:SafeMode; Status "Modo alterado para: $(if($Global:SafeMode){"Seguro"}else{"Avançado"})" "" "INFO" }
        "U"  { Check-Updates; Pause-Screen }
        "L"  { if (Test-Path $Global:LogPath) { notepad $Global:LogPath } else { Status "Log não criado ainda" "" "WARN"; Pause-Screen } }
        "0"  {
            Save-Config
            Clear-Host
            W ""
            W "  ████████╗ ██████╗" $C.Primary
            W "  ╚══██╔══╝██╔════╝" $C.Primary
            W "     ██║   ██║     " $C.Dim
            W "     ██║   ██║     " $C.Dim
            W "     ██║   ╚██████╗" $C.Dim
            W "     ╚═╝    ╚═════╝" $C.Dim
            W ""
            W "  Sessão encerrada  |  $($Global:SessionActions.Count) ações  |  v$Global:Version" $C.Accent
            W "  Log salvo em: $Global:LogPath" $C.Dim
            W ""
            exit
        }
        default {}
    }
    Menu-Main
}

# ==============================================================================
#  INICIALIZAÇÃO
# ==============================================================================

# Terminal config
try {
    $Host.UI.RawUI.BackgroundColor = "Black"
    $Host.UI.RawUI.ForegroundColor = "Green"
    $Host.UI.RawUI.WindowTitle     = "Zibble's Performance v$Global:Version"
    if ($Host.UI.RawUI.BufferSize.Width -lt 80) {
        $size = $Host.UI.RawUI.BufferSize; $size.Width = 120; $Host.UI.RawUI.BufferSize = $size
    }
    Clear-Host
} catch {}

# Carregar config
Load-Config | Out-Null
Start-Session-Log

# Tela de boas-vindas
if ($Global:Config.FirstRun) {
    Header "👋  BEM-VINDO!"
    W "  Primeira execução detectada." $C.Accent
    W "  Escolha o modo de operação:" $C.Dim
    W ""
    W "  [S] MODO SEGURO    — Só tweaks testados, sem risco" $C.Primary
    W "       Recomendado para usuários comuns e PCs de terceiros" $C.Dim
    W ""
    W "  [A] MODO AVANÇADO  — Acesso total a todos os módulos"  $C.Accent
    W "       Inclui BCD, mitigações, Defender — para gamers e técnicos" $C.Dim
    W ""
    $mode = Ask "Escolher modo"
    $Global:SafeMode = ($mode -ieq "S")
    $Global:Config.FirstRun = $false
    $Global:Config.Mode     = if ($Global:SafeMode) { "safe" } else { "advanced" }
    Save-Config
    W ""
    W "  Modo selecionado: " $C.Dim -NL
    if ($Global:SafeMode) { W "SEGURO" $C.Warning } else { W "AVANÇADO" $C.Primary }
    W "  (pode ser alterado a qualquer momento com [M] no menu)" $C.Dim
    Start-Sleep 1
    Show-Dashboard
} else {
    Show-Dashboard
}

Menu-Main
