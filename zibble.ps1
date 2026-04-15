# =============================================================================
#  _______ _____ ____  ____  _     _____   ____
# |__  __||_   _|  _ \|  _ \| |   | ____| / ___|
#    | |    | | | |_) | |_) | |   |  _|   \___ \
#    | |    | | |  _ <|  _ <| |___| |___   ___) |
#    |_|   |___|_| \_\_| \_\|_____|_____| |____/
#
#  ZIBBLE'S PERFORMANCE — Windows Optimization Toolkit
#  Version: 1.0  |  github.com/zibble/zibble
#  Run: irm https://raw.githubusercontent.com/zibble/zibble/main/zibble.ps1 | iex
# =============================================================================

#Requires -RunAsAdministrator

Set-StrictMode -Off
$ErrorActionPreference = "SilentlyContinue"
$ProgressPreference    = "SilentlyContinue"

# ── Globals ──────────────────────────────────────────────────────────────────
$Global:ZibbleVersion = "1.0"
$Global:LogPath       = "$env:USERPROFILE\Desktop\zibble_log.txt"
$Global:WinVer        = (Get-WmiObject Win32_OperatingSystem).Version
$Global:IsWin11       = [System.Version]$Global:WinVer -ge [System.Version]"10.0.22000"
$Global:GPU           = (Get-WmiObject Win32_VideoController | Where-Object {$_.Name -notmatch "Microsoft"} | Select-Object -First 1).Name

# ── Color Palette (Matrix Green) ─────────────────────────────────────────────
$C = @{
    Primary   = "Green"          # #00FF41 — main green
    Bright    = "White"          # bright highlights
    Dim       = "DarkGreen"      # dimmed green
    Accent    = "Cyan"           # accent color
    Warning   = "Yellow"         # warnings
    Error     = "Red"            # errors/danger
    ON        = "Green"          # toggle ON
    OFF       = "DarkRed"        # toggle OFF
    Header    = "Green"          # headers
    Separator = "DarkGreen"      # separator lines
}

# ── Logging ───────────────────────────────────────────────────────────────────
function Write-Log {
    param([string]$Message, [string]$Level = "INFO")
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $entry = "[$timestamp] [$Level] $Message"
    Add-Content -Path $Global:LogPath -Value $entry -ErrorAction SilentlyContinue
}

function Start-Log {
    $header = @"
================================================================================
  ZIBBLE'S PERFORMANCE — Log Session
  Date   : $(Get-Date -Format "dd/MM/yyyy HH:mm:ss")
  OS     : $($Global:WinVer) $(if($Global:IsWin11){"(Windows 11)"}else{"(Windows 10)"})
  GPU    : $($Global:GPU)
  User   : $env:USERNAME
================================================================================
"@
    Set-Content -Path $Global:LogPath -Value $header
}

# ── UI Helpers ────────────────────────────────────────────────────────────────
function Write-Color {
    param([string]$Text, [string]$Color = "Green", [switch]$NoNewline)
    if ($NoNewline) { Write-Host $Text -ForegroundColor $Color -NoNewline }
    else            { Write-Host $Text -ForegroundColor $Color }
}

function Write-Separator {
    param([string]$Char = "═", [int]$Width = 72)
    Write-Color ($Char * $Width) $C.Separator
}

function Write-Header {
    param([string]$Title = "")
    Clear-Host
    Write-Host ""
    Write-Color "  ██████╗ ██╗██████╗ ██████╗ ██╗     ███████╗" $C.Primary
    Write-Color "  ╚════██╗██║██╔══██╗██╔══██╗██║     ██╔════╝" $C.Primary
    Write-Color "   █████╔╝██║██████╔╝██████╔╝██║     █████╗  " $C.Primary
    Write-Color "  ██╔═══╝ ██║██╔══██╗██╔══██╗██║     ██╔══╝  " $C.Dim
    Write-Color "  ███████╗██║██████╔╝██████╔╝███████╗███████╗" $C.Dim
    Write-Color "  ╚══════╝╚═╝╚═════╝ ╚═════╝ ╚══════╝╚══════╝" $C.Dim
    Write-Host ""
    Write-Color "              Z I B B L E ' S   P E R F O R M A N C E" $C.Accent
    Write-Color "                         Version $Global:ZibbleVersion" $C.Dim
    Write-Host ""
    Write-Separator
    if ($Title -ne "") {
        Write-Color "  $Title" $C.Accent
        Write-Separator
    }
    Write-Host ""
}

function Write-Status {
    param([string]$Action, [string]$Detail = "", [string]$Status = "DONE")
    $statusColor = switch ($Status) {
        "DONE" { $C.Primary }; "SKIP" { $C.Dim }; "FAIL" { $C.Error }; "WARN" { $C.Warning }
        default { $C.Primary }
    }
    Write-Color "  [" $C.Dim -NoNewline
    Write-Color "$Status" $statusColor -NoNewline
    Write-Color "] " $C.Dim -NoNewline
    Write-Color $Action $C.Bright -NoNewline
    if ($Detail) { Write-Color " — $Detail" $C.Dim -NoNewline }
    Write-Host ""
}

function Write-Toggle {
    param([string]$Name, [bool]$State, [int]$Number)
    $stateText  = if ($State) { " ON " } else { "OFF" }
    $stateColor = if ($State) { $C.ON   } else { $C.OFF }
    Write-Color "  [$Number] " $C.Dim -NoNewline
    Write-Color "[$stateText]" $stateColor -NoNewline
    Write-Color " $Name" $C.Bright
}

function Pause-Menu {
    Write-Host ""
    Write-Color "  Pressione qualquer tecla para continuar..." $C.Dim
    $null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
}

function Read-MenuChoice {
    param([string]$Prompt = "Escolha")
    Write-Host ""
    Write-Color "  $Prompt" $C.Dim -NoNewline
    Write-Color " > " $C.Primary -NoNewline
    return (Read-Host).Trim()
}

function Confirm-Action {
    param([string]$Message = "Tem certeza?")
    Write-Host ""
    Write-Color "  ⚠  $Message" $C.Warning
    Write-Color "  [S] Sim    [N] Não" $C.Dim
    $r = Read-MenuChoice "Confirmar"
    return ($r -eq "S" -or $r -eq "s")
}

function Create-RestorePoint {
    param([string]$Description = "Zibble's Performance Backup")
    Write-Status "Criando ponto de restauração..." "" "DONE"
    try {
        reg add "HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore" /v "SystemRestorePointCreationFrequency" /t REG_DWORD /d "0" /f | Out-Null
        Checkpoint-Computer -Description $Description -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
        Write-Status "Ponto de restauração criado" $Description "DONE"
        Write-Log "Restore point created: $Description"
    } catch {
        Write-Status "Falha ao criar ponto de restauração" $_.Exception.Message "WARN"
        Write-Log "Restore point failed: $($_.Exception.Message)" "WARN"
    }
}

function Apply-Registry {
    param([string]$Path, [string]$Name, [string]$Type, $Value, [string]$Description = "")
    try {
        if (-not (Test-Path $Path)) { New-Item -Path $Path -Force | Out-Null }
        Set-ItemProperty -Path $Path -Name $Name -Value $Value -Type $Type -Force
        if ($Description) { Write-Status $Description "" "DONE" }
        Write-Log "REG: $Path\$Name = $Value"
    } catch {
        if ($Description) { Write-Status $Description $_.Exception.Message "FAIL" }
        Write-Log "REG FAIL: $Path\$Name — $($_.Exception.Message)" "FAIL"
    }
}

function Run-Command {
    param([string]$Command, [string]$Description = "")
    try {
        $result = Invoke-Expression $Command 2>&1
        if ($Description) { Write-Status $Description "" "DONE" }
        Write-Log "CMD: $Command"
        return $result
    } catch {
        if ($Description) { Write-Status $Description $_.Exception.Message "FAIL" }
        Write-Log "CMD FAIL: $Command — $($_.Exception.Message)" "FAIL"
    }
}

# =============================================================================
#  MODULE 1 — PERFORMANCE
# =============================================================================
function Menu-Performance {
    Write-Header "⚡  PERFORMANCE  —  Otimizações do Sistema"
    Write-Color "  Sistema detectado: " $C.Dim -NoNewline
    if ($Global:IsWin11) { Write-Color "Windows 11" $C.Accent }
    else { Write-Color "Windows 10" $C.Accent }
    Write-Host ""
    Write-Color "  [1] Tweaks BCD (Boot Configuration)"        $C.Bright
    Write-Color "  [2] Desativar Mitigações de Segurança"       $C.Bright
    Write-Color "  [3] Tweaks NTFS"                             $C.Bright
    Write-Color "  [4] Tweaks de Memória"                       $C.Bright
    Write-Color "  [5] Prioridades de Processo (MMCSS/CSRSS)"   $C.Bright
    Write-Color "  [6] Desativar Power Throttling"              $C.Bright
    Write-Color "  [7] Ativar HAGS + Game Mode"                 $C.Bright
    Write-Color "  [8] Otimizações de Latência GPU"             $C.Bright
    Write-Color "  [9] ✅  APLICAR TUDO"                        $C.Accent
    Write-Host ""
    Write-Color "  [0] Voltar"                                  $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1" { Apply-BCDTweaks;          Pause-Menu; Menu-Performance }
        "2" { Apply-Mitigations;        Pause-Menu; Menu-Performance }
        "3" { Apply-NTFSTweaks;         Pause-Menu; Menu-Performance }
        "4" { Apply-MemoryTweaks;       Pause-Menu; Menu-Performance }
        "5" { Apply-ProcessPriorities;  Pause-Menu; Menu-Performance }
        "6" { Apply-PowerThrottling;    Pause-Menu; Menu-Performance }
        "7" { Apply-HAGS;               Pause-Menu; Menu-Performance }
        "8" { Apply-GPULatency;         Pause-Menu; Menu-Performance }
        "9" { Apply-AllPerformance;     Pause-Menu; Menu-Performance }
        "0" { return }
        default { Menu-Performance }
    }
}

function Apply-BCDTweaks {
    Write-Header "⚡  BCD Tweaks"
    Write-Status "Aplicando tweaks BCD..." "" "DONE"
    Write-Log "--- BCD Tweaks ---"

    $bcdCmds = @(
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
        $bcdCmds += @(
            "bcdedit /set pae ForceEnable",
            "bcdedit /set disableelamdrivers Yes",
            "bcdedit /set highestmode Yes",
            "bcdedit /set noumex Yes",
            "bcdedit /set extendedinput Yes"
        )
    }

    foreach ($cmd in $bcdCmds) {
        $key = ($cmd -split "/set ")[1]
        Run-Command $cmd "BCD: $key" | Out-Null
    }
    Write-Status "BCD Tweaks aplicados com sucesso" "" "DONE"
}

function Apply-Mitigations {
    Write-Header "🛡️  Desativar Mitigações"
    Write-Color "  ⚠  Isso desativa proteções de segurança do kernel." $C.Warning
    Write-Color "  Recomendado apenas para PCs de gaming dedicados." $C.Warning
    Write-Host ""
    if (-not (Confirm-Action "Desativar mitigações de segurança?")) { return }

    Write-Log "--- Disable Mitigations ---"
    powershell "ForEach(`$v in (Get-Command -Name 'Set-ProcessMitigation').Parameters['Disable'].Attributes.ValidValues){Set-ProcessMitigation -System -Disable `$v.ToString() -ErrorAction SilentlyContinue}" 2>$null
    Write-Status "Mitigações de processo desativadas" "" "DONE"

    $regTweaks = @(
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\FVE";                                                            Name="DisableExternalDMAUnderLock";            Type="DWord"; Value=0;  Desc="DMA Lock desativado" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceGuard";                                            Name="EnableVirtualizationBasedSecurity";      Type="DWord"; Value=0;  Desc="VBS desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";                                    Name="DisableExceptionChainValidation";        Type="DWord"; Value=1;  Desc="Exception chain validation off" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel";                                    Name="KernelSEHOPEnabled";                     Type="DWord"; Value=0;  Desc="SEHOP desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";                         Name="EnableCfg";                              Type="DWord"; Value=0;  Desc="CFG desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager";                                           Name="ProtectionMode";                         Type="DWord"; Value=0;  Desc="Protection mode off" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";                         Name="FeatureSettingsOverride";                Type="DWord"; Value=3;  Desc="Spectre/Meltdown mitigations off" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management";                         Name="FeatureSettingsOverrideMask";             Type="DWord"; Value=3;  Desc="Spectre mask off" }
    )
    foreach ($t in $regTweaks) { Apply-Registry $t.Path $t.Name $t.Type $t.Value $t.Desc }
}

function Apply-NTFSTweaks {
    Write-Header "💾  NTFS Tweaks"
    Write-Log "--- NTFS Tweaks ---"
    $cmds = @(
        @{ Cmd="fsutil behavior set memoryusage 2";          Desc="NTFS Memory Usage = 2" },
        @{ Cmd="fsutil behavior set mftzone 4";              Desc="MFT Zone = 4" },
        @{ Cmd="fsutil behavior set disablelastaccess 1";    Desc="Last Access desativado" },
        @{ Cmd="fsutil behavior set disabledeletenotify 0";  Desc="TRIM ativo" },
        @{ Cmd="fsutil behavior set encryptpagingfile 0";    Desc="Page file encryption off" }
    )
    foreach ($c in $cmds) { Run-Command $c.Cmd $c.Desc | Out-Null }
}

function Apply-MemoryTweaks {
    Write-Header "🧠  Tweaks de Memória"
    Write-Log "--- Memory Tweaks ---"
    Run-Command "powershell Disable-MMAgent -MemoryCompression" "Memory Compression desativado" | Out-Null
    Run-Command "powershell Disable-MMAgent -PageCombining"     "Page Combining desativado"     | Out-Null

    $tweaks = @(
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="LargeSystemCache";        Type="DWord"; Value=1; Desc="Large System Cache ativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="DisablePagingExecutive";  Type="DWord"; Value=1; Desc="Paging Executive desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"; Name="MoveImages";              Type="DWord"; Value=0; Desc="ASLR desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power";             Name="HiberbootEnabled";        Type="DWord"; Value=0; Desc="Fast Startup desativado" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Control\Power";                             Name="HibernateEnabled";        Type="DWord"; Value=0; Desc="Hibernação desativada" }
    )
    foreach ($t in $tweaks) { Apply-Registry $t.Path $t.Name $t.Type $t.Value $t.Desc }
    Run-Command "powercfg /h off" "Hibernação desligada" | Out-Null

    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl" "Win32PrioritySeparation" "DWord" 38 "Win32Priority = 38 (gaming)"
}

function Apply-ProcessPriorities {
    Write-Header "⚙️  Prioridades de Processo"
    Write-Log "--- Process Priorities ---"
    $procs = @(
        @{ Name="csrss.exe";          CPU=4; IO=3; Page=$null },
        @{ Name="dwm.exe";            CPU=4; IO=3; Page=$null },
        @{ Name="ntoskrnl.exe";       CPU=4; IO=3; Page=$null },
        @{ Name="audiodg.exe";        CPU=2; IO=$null; Page=$null },
        @{ Name="lsass.exe";          CPU=1; IO=0; Page=0 },
        @{ Name="SearchIndexer.exe";  CPU=1; IO=0; Page=$null },
        @{ Name="svchost.exe";        CPU=1; IO=$null; Page=$null },
        @{ Name="TrustedInstaller.exe"; CPU=1; IO=0; Page=$null },
        @{ Name="wuauclt.exe";        CPU=1; IO=0; Page=$null },
        @{ Name="MsMpEng.exe";        CPU=1; IO=$null; Page=$null }
    )
    foreach ($p in $procs) {
        $base = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Image File Execution Options\$($p.Name)\PerfOptions"
        Apply-Registry $base "CpuPriorityClass" "DWord" $p.CPU "CPU Priority: $($p.Name)"
        if ($null -ne $p.IO)   { Apply-Registry $base "IoPriority"   "DWord" $p.IO   "" }
        if ($null -ne $p.Page) { Apply-Registry $base "PagePriority" "DWord" $p.Page "" }
    }

    # MMCSS
    $mmcss = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
    Apply-Registry $mmcss "NoLazyMode"         "DWord"  1    "MMCSS NoLazyMode"
    Apply-Registry $mmcss "AlwaysOn"           "DWord"  1    "MMCSS AlwaysOn"
    Apply-Registry $mmcss "SystemResponsiveness" "DWord" 10  "System Responsiveness = 10"
    Apply-Registry $mmcss "NetworkThrottlingIndex" "DWord" 4294967295 "Network Throttling off"

    $games = "$mmcss\Tasks\Games"
    Apply-Registry $games "GPU Priority"        "DWord"  8       "MMCSS Games GPU Priority = 8"
    Apply-Registry $games "Priority"            "DWord"  6       "MMCSS Games Priority = 6"
    Apply-Registry $games "Scheduling Category" "String" "High"  "MMCSS Scheduling = High"
    Apply-Registry $games "SFIO Priority"       "String" "High"  "MMCSS SFIO = High"
    Apply-Registry $games "Latency Sensitive"   "String" "True"  "MMCSS Latency Sensitive"
}

function Apply-PowerThrottling {
    Write-Header "⚡  Power Throttling"
    Write-Log "--- Power Throttling ---"
    $keys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\kernel",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive",
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power"
    )
    foreach ($k in $keys) { Apply-Registry $k "CoalescingTimerInterval" "DWord" 0 "" }
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling" "PowerThrottlingOff"     "DWord" 1 "Power Throttling desativado"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 "CsEnabled"             "DWord" 0 "Connected Standby desativado"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\Power"                 "EnergyEstimationEnabled" "DWord" 0 "Energy Estimation desativado"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\KernelVelocity"        "DisableFGBoostDecay"   "DWord" 1 "FG Boost Decay desativado"
}

function Apply-HAGS {
    Write-Header "🖥️  HAGS + Game Mode"
    Write-Log "--- HAGS + GameMode ---"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"  "HwSchMode"        "DWord" 2 "HAGS ativado"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\GameBar"                         "AllowAutoGameMode" "DWord" 1 "Auto Game Mode ativado"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\GameBar"                         "AutoGameModeEnabled" "DWord" 1 "Game Mode ativado"
    Apply-Registry "HKCU:\SYSTEM\GameConfigStore"                             "GameDVR_FSEBehaviorMode"          "DWord" 0 "FSO ativado"
    Apply-Registry "HKCU:\SYSTEM\GameConfigStore"                             "GameDVR_HonorUserFSEBehaviorMode" "DWord" 1 ""
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\DirectX\UserGpuPreferences"      "DirectXUserGlobalSettings" "String" "VRROptimizeEnable=0;SwapEffectUpgradeEnable=1;" "Windowed Game Optimizations"
    Apply-Registry "HKCU:\Control Panel\Desktop"                              "MenuShowDelay"    "DWord" 0 "Menu delay = 0ms"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"  "DpiMapIommuContiguous" "DWord" 1 "Contiguous memory allocation (DX Kernel)"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl"         "MonitorLatencyTolerance"        "DWord" 1 "Monitor Latency Tolerance = 1"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Services\DXGKrnl"         "MonitorRefreshLatencyTolerance" "DWord" 1 "Monitor Refresh Latency = 1"
}

function Apply-GPULatency {
    Write-Header "🎮  Latência GPU"
    Write-Log "--- GPU Latency ---"
    $latKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Control\Power",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"
    )
    $latValues = @("ExitLatency","Latency","LatencyToleranceDefault","LatencyToleranceFSVP",
                   "LatencyTolerancePerfOverride","LatencyToleranceScreenOffIR","LatencyToleranceVSyncEnabled",
                   "RtlCapabilityCheckLatency","DefaultD3TransitionLatencyActivelyUsed",
                   "DefaultD3TransitionLatencyIdleLongTime","DefaultD3TransitionLatencyIdleMonitorOff",
                   "DefaultD3TransitionLatencyIdleNoContext","DefaultD3TransitionLatencyIdleShortTime",
                   "DefaultLatencyToleranceIdle0","DefaultLatencyToleranceIdle1",
                   "DefaultLatencyToleranceMemory","DefaultLatencyToleranceNoContext",
                   "DefaultLatencyToleranceOther","DefaultLatencyToleranceTimerPeriod",
                   "MonitorLatencyTolerance","MonitorRefreshLatencyTolerance","TransitionLatency","Latency")

    foreach ($k in $latKeys) {
        foreach ($v in $latValues) { Apply-Registry $k $v "DWord" 1 "" }
    }
    Write-Status "Latência GPU otimizada" "" "DONE"
}

function Apply-AllPerformance {
    Write-Header "✅  Aplicando TUDO — Performance"
    Write-Color "  Isso aplicará todas as otimizações de performance." $C.Warning
    if (-not (Confirm-Action "Criar ponto de restauração e aplicar tudo?")) { return }
    Create-RestorePoint "Zibble Performance - Before All Tweaks"
    Apply-BCDTweaks
    Apply-NTFSTweaks
    Apply-MemoryTweaks
    Apply-ProcessPriorities
    Apply-PowerThrottling
    Apply-HAGS
    Apply-GPULatency
    Write-Host ""
    Write-Status "✅  Todas as otimizações de performance aplicadas!" "" "DONE"
    Write-Color "  Reinicie o computador para que todas as mudanças tenham efeito." $C.Accent
}

# =============================================================================
#  MODULE 2 — GPU & DISPLAY
# =============================================================================
function Menu-GPU {
    Write-Header "🖥️  GPU & DISPLAY"
    Write-Color "  GPU detectada: " $C.Dim -NoNewline
    Write-Color "$($Global:GPU)" $C.Accent
    Write-Host ""

    $isNvidia = $Global:GPU -match "NVIDIA|GeForce|RTX|GTX"
    $isAMD    = $Global:GPU -match "AMD|Radeon|RX "
    $isIntel  = $Global:GPU -match "Intel"

    if ($isNvidia) {
        Write-Color "  ── NVIDIA ──────────────────────────────────" $C.Separator
        Write-Color "  [1] MSI Mode para GPU"                         $C.Bright
        Write-Color "  [2] NVIDIA Latency Tweaks"                     $C.Bright
        Write-Color "  [3] Desativar HDCP"                            $C.Bright
        Write-Color "  [4] Desativar TCC"                             $C.Bright
        Write-Color "  [5] Desativar Telemetria NVIDIA"               $C.Bright
        Write-Color "  [6] Desativar Power Saving NVIDIA"             $C.Bright
        Write-Color "  [7] KBoost (Forçar clock máximo)"              $C.Bright
        Write-Color "  [8] Desativar TDR"                             $C.Bright
        Write-Color "  [9] ✅  Aplicar tudo NVIDIA"                   $C.Accent
    } elseif ($isAMD) {
        Write-Color "  ── AMD ─────────────────────────────────────" $C.Separator
        Write-Color "  [1] MSI Mode para GPU"                         $C.Bright
        Write-Color "  [2] Desativar Power Gating"                    $C.Bright
        Write-Color "  [3] Desativar Clock Gating"                    $C.Bright
        Write-Color "  [4] Desativar ULPS"                            $C.Bright
        Write-Color "  [5] Ativar De-Lag"                             $C.Bright
        Write-Color "  [6] Desativar Anti-Aliasing"                   $C.Bright
        Write-Color "  [7] Desativar ASPM"                            $C.Bright
        Write-Color "  [8] ✅  Aplicar tudo AMD"                      $C.Accent
    } else {
        Write-Color "  [1] MSI Mode para GPU"                         $C.Bright
        Write-Color "  [2] Tweaks iGPU Intel"                         $C.Bright
    }

    Write-Host ""
    Write-Color "  [P] Plano de Energia Customizado"                  $C.Bright
    Write-Color "  [0] Voltar"                                        $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    if ($isNvidia) {
        switch ($choice) {
            "1" { Apply-GPUMSIMode;           Pause-Menu; Menu-GPU }
            "2" { Apply-NvidiaLatency;        Pause-Menu; Menu-GPU }
            "3" { Apply-NvidiaHDCP;           Pause-Menu; Menu-GPU }
            "4" { Apply-NvidiaTCC;            Pause-Menu; Menu-GPU }
            "5" { Apply-NvidiaTelemetry;      Pause-Menu; Menu-GPU }
            "6" { Apply-NvidiaPowerSaving;    Pause-Menu; Menu-GPU }
            "7" { Apply-KBoost;               Pause-Menu; Menu-GPU }
            "8" { Apply-NvidiaTDR;            Pause-Menu; Menu-GPU }
            "9" { Apply-AllNvidia;            Pause-Menu; Menu-GPU }
            "P" { Apply-PowerPlan;            Pause-Menu; Menu-GPU }
            "0" { return }
            default { Menu-GPU }
        }
    } elseif ($isAMD) {
        switch ($choice) {
            "1" { Apply-GPUMSIMode;           Pause-Menu; Menu-GPU }
            "2" { Apply-AMDPowerGating;       Pause-Menu; Menu-GPU }
            "3" { Apply-AMDClockGating;       Pause-Menu; Menu-GPU }
            "4" { Apply-AMDULPS;              Pause-Menu; Menu-GPU }
            "5" { Apply-AMDDeLag;             Pause-Menu; Menu-GPU }
            "6" { Apply-AMDAntiAliasing;      Pause-Menu; Menu-GPU }
            "7" { Apply-AMDASPM;              Pause-Menu; Menu-GPU }
            "8" { Apply-AllAMD;               Pause-Menu; Menu-GPU }
            "P" { Apply-PowerPlan;            Pause-Menu; Menu-GPU }
            "0" { return }
            default { Menu-GPU }
        }
    } else {
        switch ($choice) {
            "1" { Apply-GPUMSIMode;           Pause-Menu; Menu-GPU }
            "2" { Apply-InteliGPU;            Pause-Menu; Menu-GPU }
            "P" { Apply-PowerPlan;            Pause-Menu; Menu-GPU }
            "0" { return }
            default { Menu-GPU }
        }
    }
}

function Apply-GPUMSIMode {
    Write-Header "🔧  MSI Mode para GPU"
    Write-Log "--- GPU MSI Mode ---"
    $gpuIds = (Get-WmiObject Win32_VideoController | Where-Object {$_.Name -notmatch "Microsoft"}).PNPDeviceID
    foreach ($id in $gpuIds) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        Apply-Registry $path "MSISupported" "DWord" 1 "MSI Mode: $id"
        $affPath = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\Affinity Policy"
        Apply-Registry $affPath "DevicePriority" "DWord" 0 "Device Priority = 0"
    }
}

function Apply-NvidiaLatency {
    Write-Header "⚡  NVIDIA Latency Tweaks"
    Write-Log "--- NVIDIA Latency ---"
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    $vals = @("D3PCLatency","F1TransitionLatency","LOWLATENCY","Node3DLowLatency","RMDeepL1EntryLatencyUsec",
              "RmGspcMaxFtuS","RmGspcMinFtuS","RmGspcPerioduS","RMLpwrEiIdleThresholdUs",
              "RMLpwrGrIdleThresholdUs","RMLpwrGrRgIdleThresholdUs","RMLpwrMsIdleThresholdUs",
              "VRDirectFlipDPCDelayUs","VRDirectFlipTimingMarginUs","VRDirectJITFlipMsHybridFlipDelayUs",
              "vrrCursorMarginUs","vrrDeflickerMarginUs","vrrDeflickerMaxUs")
    foreach ($v in $vals) { Apply-Registry $base $v "DWord" 1 "" }
    Apply-Registry $base "PciLatencyTimerControl"     "DWord" 20 "PCI Latency Timer = 20"
    Apply-Registry $base "PreferSystemMemoryContiguous" "DWord" 1 "Contiguous Memory Allocation"
    Write-Status "NVIDIA Latency Tweaks aplicados" "" "DONE"
}

function Apply-NvidiaHDCP {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "RMHdcpKeyGlobZero" "DWord" 1 "HDCP desativado"
}

function Apply-NvidiaTCC {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "TCCSupported" "DWord" 0 "TCC desativado"
}

function Apply-NvidiaTelemetry {
    Write-Header "📡  Desativar Telemetria NVIDIA"
    Write-Log "--- NVIDIA Telemetry ---"
    $tasks = @("NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NVIDIA GeForce Experience SelfUpdate_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}",
               "NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}")
    foreach ($t in $tasks) {
        schtasks /change /disable /tn $t 2>$null
        Write-Status "Task desativada: $t" "" "DONE"
    }
    Apply-Registry "HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client" "OptInOrOutPreference" "DWord" 0 "NVIDIA telemetry opt-out"
    Apply-Registry "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID66610" "DWord" 0 ""
    Apply-Registry "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID64640" "DWord" 0 ""
    Apply-Registry "HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS" "EnableRID44231" "DWord" 0 ""
}

function Apply-NvidiaPowerSaving {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak"
    Apply-Registry $base "DisplayPowerSaving" "DWord" 0 "NVIDIA Display Power Saving off"
    Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm" "DisableWriteCombining" "DWord" 1 "Write Combining desativado"
    $dpcKeys = @(
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm",
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\NVAPI",
        "HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers",
        "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers\Power"
    )
    foreach ($k in $dpcKeys) { Apply-Registry $k "RmGpsPsEnablePerCpuCoreDpc" "DWord" 1 "" }
    Write-Status "DPC por core ativado" "" "DONE"
}

function Apply-KBoost {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "PerfLevelSrc"   "DWord" 0x2222 "KBoost ativado"
    Apply-Registry $base "PowerMizerEnable"  "DWord" 0 ""
    Apply-Registry $base "PowerMizerLevel"   "DWord" 0 ""
    Apply-Registry $base "PowerMizerLevelAC" "DWord" 0 ""
    Write-Status "KBoost ativado (clock máximo forçado)" "" "DONE"
}

function Apply-NvidiaTDR {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers"
    $vals = @("TdrLevel","TdrDelay","TdrDdiDelay","TdrDebugMode","TdrLimitCount","TdrLimitTime","TdrTestMode")
    foreach ($v in $vals) { Apply-Registry $base $v "DWord" 0 "" }
    Write-Status "NVIDIA TDR desativado" "" "DONE"
}

function Apply-AllNvidia {
    Write-Header "✅  Aplicar tudo NVIDIA"
    if (-not (Confirm-Action "Aplicar todos os tweaks NVIDIA?")) { return }
    Create-RestorePoint "Zibble - Before NVIDIA Tweaks"
    Apply-GPUMSIMode; Apply-NvidiaLatency; Apply-NvidiaHDCP; Apply-NvidiaTCC
    Apply-NvidiaTelemetry; Apply-NvidiaPowerSaving; Apply-KBoost; Apply-NvidiaTDR
    Write-Status "✅  Todos os tweaks NVIDIA aplicados!" "" "DONE"
}

function Apply-AMDPowerGating {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    $vals = @("DisableSAMUPowerGating","DisableUVDPowerGatingDynamic","DisableVCEPowerGating","DisablePowerGating","DisableDrmdmaPowerGating","PP_GPUPowerDownEnabled")
    foreach ($v in $vals) { Apply-Registry $base $v "DWord" 1 "" }
    Write-Status "AMD Power Gating desativado" "" "DONE"
}

function Apply-AMDClockGating {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "EnableVceSwClockGating" "DWord" 0 "VCE Clock Gating off"
    Apply-Registry $base "EnableUvdClockGating"   "DWord" 0 "UVD Clock Gating off"
    Write-Status "AMD Clock Gating desativado" "" "DONE"
}

function Apply-AMDULPS {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "EnableUlps"    "DWord"  0 "ULPS desativado"
    Apply-Registry $base "EnableUlps_NA" "String" "0" ""
    Write-Status "AMD Ultra Low Power State desativado" "" "DONE"
}

function Apply-AMDDeLag {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "KMD_DeLagEnabled" "DWord" 1 "AMD De-Lag ativado"
    Apply-Registry $base "KMD_FRTEnabled"   "DWord" 0 "Frame Rate Target desativado"
    Write-Status "AMD De-Lag ativado" "" "DONE"
}

function Apply-AMDAntiAliasing {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "AAF_NA"      "DWord"  0 "Anti-Aliasing off"
    Apply-Registry $base "AntiAlias_NA" "String" "0" ""
    Apply-Registry $base "StutterMode"  "DWord" 0 "Stutter Mode off"
    Write-Status "AMD Anti-Aliasing desativado" "" "DONE"
}

function Apply-AMDASPM {
    $base = "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}\0000"
    Apply-Registry $base "EnableAspmL0s" "DWord" 0 "ASPM L0s desativado"
    Apply-Registry $base "EnableAspmL1"  "DWord" 0 "ASPM L1 desativado"
    Write-Status "AMD ASPM desativado" "" "DONE"
}

function Apply-AllAMD {
    Write-Header "✅  Aplicar tudo AMD"
    if (-not (Confirm-Action "Aplicar todos os tweaks AMD?")) { return }
    Create-RestorePoint "Zibble - Before AMD Tweaks"
    Apply-GPUMSIMode; Apply-AMDPowerGating; Apply-AMDClockGating
    Apply-AMDULPS; Apply-AMDDeLag; Apply-AMDAntiAliasing; Apply-AMDASPM
    Write-Status "✅  Todos os tweaks AMD aplicados!" "" "DONE"
}

function Apply-InteliGPU {
    Apply-Registry "HKLM:\SOFTWARE\Intel\GMM" "DedicatedSegmentSize" "DWord" 512 "iGPU Dedicated Segment = 512MB"
}

function Apply-PowerPlan {
    Write-Header "🔋  Plano de Energia"
    Write-Color "  [1] Alto Desempenho (nativo Windows)" $C.Bright
    Write-Color "  [2] Desempenho Máximo (Ultimate)"     $C.Bright
    Write-Color "  [0] Voltar"                           $C.Dim
    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1" { powercfg -setactive 8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c; Write-Status "Alto Desempenho ativado" "" "DONE" }
        "2" {
            powercfg -duplicatescheme e9a42b02-d5df-448d-aa00-03f14749eb61 2>$null
            $guid = (powercfg /list | Select-String "Ultimate").ToString() -replace ".*\((.*)\).*","$1" -replace "\s",""
            if ($guid) { powercfg -setactive $guid }
            Write-Status "Desempenho Máximo ativado" "" "DONE"
        }
    }
}

# =============================================================================
#  MODULE 3 — REDE
# =============================================================================
function Menu-Network {
    Write-Header "🌐  REDE"
    Write-Color "  [1] Reset completo de rede"              $C.Bright
    Write-Color "  [2] Tweaks TCP/IP"                       $C.Bright
    Write-Color "  [3] Desativar IPv6 / Teredo / ISATAP"    $C.Bright
    Write-Color "  [4] Otimizar NIC (Power Saving)"         $C.Bright
    Write-Color "  [5] Desativar Delivery Optimization"     $C.Bright
    Write-Color "  [6] MSI Mode NIC"                        $C.Bright
    Write-Color "  [7] ✅  Aplicar tudo"                    $C.Accent
    Write-Host ""
    Write-Color "  [0] Voltar"                              $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1" { Apply-NetworkReset;       Pause-Menu; Menu-Network }
        "2" { Apply-TCPTweaks;          Pause-Menu; Menu-Network }
        "3" { Apply-DisableIPv6;        Pause-Menu; Menu-Network }
        "4" { Apply-NICPowerSaving;     Pause-Menu; Menu-Network }
        "5" { Apply-DeliveryOpt;        Pause-Menu; Menu-Network }
        "6" { Apply-NICMSIMode;         Pause-Menu; Menu-Network }
        "7" { Apply-AllNetwork;         Pause-Menu; Menu-Network }
        "0" { return }
        default { Menu-Network }
    }
}

function Apply-NetworkReset {
    Write-Header "🔄  Reset de Rede"
    Write-Color "  ⚠  A conexão à internet será interrompida brevemente." $C.Warning
    if (-not (Confirm-Action "Resetar rede completo?")) { return }
    Write-Log "--- Network Reset ---"
    $cmds = @("ipconfig /release","ipconfig /renew","ipconfig /flushdns",
              "netsh int ip reset","netsh int ipv4 reset","netsh int ipv6 reset",
              "netsh int tcp reset","netsh winsock reset","netsh advfirewall reset",
              "netsh http flush logbuffer")
    foreach ($c in $cmds) { Run-Command $c $c | Out-Null }
    Write-Status "Reset de rede concluído. Reinicie para finalizar." "" "DONE"
}

function Apply-TCPTweaks {
    Write-Header "⚡  TCP/IP Tweaks"
    Write-Log "--- TCP Tweaks ---"

    if ($Global:IsWin11) {
        Run-Command "netsh int tcp set supplemental Template=Internet CongestionProvider=bbr2" "BBR2 (Win11)" | Out-Null
        Run-Command "netsh int tcp set supplemental Template=Compat CongestionProvider=bbr2" "" | Out-Null
    } else {
        Run-Command "netsh int tcp set supplemental Internet congestionprovider=ctcp" "CTCP (Win10)" | Out-Null
    }

    $netshCmds = @(
        @{ Cmd="netsh int tcp set global autotuninglevel=disabled";   Desc="AutoTuning desativado" },
        @{ Cmd="netsh int tcp set global ecncapability=disabled";     Desc="ECN desativado" },
        @{ Cmd="netsh int tcp set global dca=enabled";                Desc="DCA ativado" },
        @{ Cmd="netsh int tcp set global netdma=enabled";             Desc="NetDMA ativado" },
        @{ Cmd="netsh int tcp set global rsc=disabled";               Desc="RSC desativado" },
        @{ Cmd="netsh int tcp set global rss=enabled";                Desc="RSS ativado" },
        @{ Cmd="netsh int tcp set global timestamps=disabled";        Desc="TCP Timestamps off" },
        @{ Cmd="netsh int tcp set global initialRto=2000";            Desc="Initial RTO = 2000ms" },
        @{ Cmd="netsh int tcp set global nonsackrttresiliency=disabled"; Desc="NonSack RTT off" },
        @{ Cmd="netsh int tcp set global maxsynretransmissions=2";    Desc="Max SYN retransmissions = 2" },
        @{ Cmd="netsh int tcp set security mpp=disabled";             Desc="MPP desativado" },
        @{ Cmd="netsh int tcp set security profiles=disabled";        Desc="Security Profiles off" },
        @{ Cmd="netsh int tcp set heuristics disabled";               Desc="Scaling Heuristics off" },
        @{ Cmd="netsh int ip set global neighborcachelimit=4096";     Desc="ARP Cache = 4096" },
        @{ Cmd="netsh int ip set global taskoffload=disabled";        Desc="Task Offloading off" }
    )
    foreach ($c in $netshCmds) { Run-Command $c.Cmd $c.Desc | Out-Null }

    $tcpRegs = @(
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="DefaultTTL";       Type="DWord"; Value=64;       Desc="TTL = 64" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="Tcp1323Opts";      Type="DWord"; Value=1;        Desc="TCP Window Scaling on" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpMaxDupAcks";    Type="DWord"; Value=2;        Desc="TcpMaxDupAcks = 2" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="SackOpts";         Type="DWord"; Value=0;        Desc="SackOpts off" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="MaxUserPort";      Type="DWord"; Value=65534;    Desc="Max Port = 65534" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"; Name="TcpTimedWaitDelay"; Type="DWord"; Value=30;      Desc="TimedWaitDelay = 30" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"; Name="LocalPriority"; Type="DWord"; Value=4;     Desc="LocalPriority = 4" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"; Name="HostsPriority"; Type="DWord"; Value=5;     Desc="HostsPriority = 5" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\ServiceProvider"; Name="DnsPriority";   Type="DWord"; Value=6;     Desc="DnsPriority = 6" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; Name="TcpAckFrequency"; Type="DWord"; Value=1; Desc="Nagle's Algorithm off (ACK)" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; Name="TCPNoDelay";      Type="DWord"; Value=1; Desc="Nagle's Algorithm off (NoDelay)" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces"; Name="TcpDelAckTicks";  Type="DWord"; Value=0; Desc="DelAck = 0" },
        @{ Path="HKLM:\SYSTEM\CurrentControlSet\Services\Ndis\Parameters"; Name="RssBaseCpu"; Type="DWord"; Value=1; Desc="RSS Base CPU = 1" }
    )
    foreach ($t in $tcpRegs) { Apply-Registry $t.Path $t.Name $t.Type $t.Value $t.Desc }
}

function Apply-DisableIPv6 {
    Write-Log "--- Disable IPv6/Teredo ---"
    Run-Command "netsh int ipv6 set state disabled"       "IPv6 desativado"  | Out-Null
    Run-Command "netsh int isatap set state disabled"     "ISATAP desativado"| Out-Null
    Run-Command "netsh int teredo set state disabled"     "Teredo desativado"| Out-Null
    Write-Status "IPv6, ISATAP e Teredo desativados" "" "DONE"
}

function Apply-NICPowerSaving {
    Write-Header "🔌  NIC Power Saving"
    Write-Log "--- NIC Power Saving ---"
    $nicKeys = Get-ItemProperty "HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002bE10318}\*" -ErrorAction SilentlyContinue |
               Where-Object { $_."*SpeedDuplex" -ne $null }
    $powerProps = @("AutoPowerSaveModeEnabled","AdvancedEEE","*EEE","EEE","EnablePME","EEELinkAdvertisement",
                    "EnableGreenEthernet","EnableSavePowerNow","EnablePowerManagement","EnableDynamicPowerGating",
                    "EnableConnectedPowerGating","EnableWakeOnLan","GigaLite","NicAutoPowerSaver",
                    "PowerDownPll","PowerSavingMode","ReduceSpeedOnPowerDown","SmartPowerDownEnable",
                    "S5WakeOnLan","ULPMode","WakeOnDisconnect","*WakeOnMagicPacket","*WakeOnPattern","WakeOnLink")
    foreach ($nic in $nicKeys) {
        $path = $nic.PSPath
        foreach ($p in $powerProps) {
            try { Set-ItemProperty -Path $path -Name $p -Value "0" -ErrorAction SilentlyContinue } catch {}
        }
        try { Set-ItemProperty -Path $path -Name "JumboPacket"       -Value "1514" -ErrorAction SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $path -Name "ReceiveBuffers"     -Value "1024" -ErrorAction SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $path -Name "TransmitBuffers"    -Value "4096" -ErrorAction SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $path -Name "*InterruptModeration" -Value "0" -ErrorAction SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $path -Name "*FlowControl"       -Value "0" -ErrorAction SilentlyContinue } catch {}
        try { Set-ItemProperty -Path $path -Name "RSS"                -Value "1" -ErrorAction SilentlyContinue } catch {}
    }
    Write-Status "NIC Power Saving desativado" "" "DONE"
    # WeakHost
    Get-NetAdapter -IncludeHidden | Set-NetIPInterface -WeakHostSend Enabled -WeakHostReceive Enabled -ErrorAction SilentlyContinue
    Write-Status "WeakHost Send/Receive ativado" "" "DONE"
}

function Apply-DeliveryOpt {
    Apply-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DODownloadMode" "DWord" 0 "Delivery Optimization desativado"
    Apply-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config" "DownloadMode"   "DWord" 0 ""
    Apply-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Settings" "DownloadMode" "DWord" 0 ""
    Write-Status "Delivery Optimization desativado" "" "DONE"
}

function Apply-NICMSIMode {
    Write-Log "--- NIC MSI Mode ---"
    $nicIds = (Get-WmiObject Win32_NetworkAdapter | Where-Object {$_.PNPDeviceID -match "PCI\\VEN"}).PNPDeviceID
    foreach ($id in $nicIds) {
        $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$id\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
        Apply-Registry $path "MSISupported" "DWord" 1 "MSI Mode NIC: $id"
    }
}

function Apply-AllNetwork {
    Write-Header "✅  Aplicar tudo — Rede"
    Write-Color "  ⚠  A conexão à internet será interrompida brevemente." $C.Warning
    if (-not (Confirm-Action "Aplicar todas as otimizações de rede?")) { return }
    Create-RestorePoint "Zibble - Before Network Tweaks"
    Apply-NetworkReset; Apply-TCPTweaks; Apply-DisableIPv6
    Apply-NICPowerSaving; Apply-DeliveryOpt; Apply-NICMSIMode
    Write-Status "✅  Todas as otimizações de rede aplicadas!" "" "DONE"
    Write-Color "  Reinicie o computador para finalizar." $C.Accent
}

# =============================================================================
#  MODULE 4 — TELEMETRIA & PRIVACIDADE
# =============================================================================
function Menu-Telemetry {
    Write-Header "🔇  TELEMETRIA & PRIVACIDADE"
    Write-Color "  [1] Desativar Telemetria (Registry)"             $C.Bright
    Write-Color "  [2] Desativar Tasks Agendadas (Telemetria)"      $C.Bright
    Write-Color "  [3] Desativar AutoLoggers"                       $C.Bright
    Write-Color "  [4] Desativar Serviços de Telemetria"            $C.Bright
    Write-Color "  [5] Desativar Publicidade & Rastreamento"        $C.Bright
    Write-Color "  [6] Desativar Windows Defender Telemetria"       $C.Bright
    Write-Color "  [7] ✅  Aplicar tudo"                            $C.Accent
    Write-Host ""
    Write-Color "  [0] Voltar"                                      $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1" { Apply-TelemetryRegistry; Pause-Menu; Menu-Telemetry }
        "2" { Apply-TelemetryTasks;    Pause-Menu; Menu-Telemetry }
        "3" { Apply-AutoLoggers;       Pause-Menu; Menu-Telemetry }
        "4" { Apply-TelemetryServices; Pause-Menu; Menu-Telemetry }
        "5" { Apply-AdTracking;        Pause-Menu; Menu-Telemetry }
        "6" { Apply-DefenderTelemetry; Pause-Menu; Menu-Telemetry }
        "7" { Apply-AllTelemetry;      Pause-Menu; Menu-Telemetry }
        "0" { return }
        default { Menu-Telemetry }
    }
}

function Apply-TelemetryRegistry {
    Write-Header "📋  Telemetria — Registry"
    Write-Log "--- Telemetry Registry ---"
    $tweaks = @(
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";      Name="AllowTelemetry";                Type="DWord";  Value=0; Desc="Telemetria desativada" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";      Name="DoNotShowFeedbackNotifications"; Type="DWord";  Value=1; Desc="Feedback notifications off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection";      Name="AllowDeviceNameInTelemetry";    Type="DWord";  Value=0; Desc="Device name in telemetry off" },
        @{ Path="HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\DataCollection"; Name="AllowTelemetry"; Type="DWord"; Value=0; Desc="AllowTelemetry = 0" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\InputPersonalization";                 Name="RestrictImplicitInkCollection"; Type="DWord";  Value=1; Desc="Ink collection off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\InputPersonalization";                 Name="RestrictImplicitTextCollection"; Type="DWord"; Value=1; Desc="Text collection off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat";           Name="DisableInventory";              Type="DWord";  Value=1; Desc="App inventory off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat";           Name="AITEnable";                     Type="DWord";  Value=0; Desc="AIT off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat";           Name="DisableUAR";                    Type="DWord";  Value=1; Desc="UAR off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";              Name="PublishUserActivities";         Type="DWord";  Value=0; Desc="User activities off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";              Name="EnableActivityFeed";            Type="DWord";  Value=0; Desc="Activity feed off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\System";              Name="UploadUserActivities";          Type="DWord";  Value=0; Desc="Upload activities off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\SQMClient\Windows";           Name="CEIPEnable";                    Type="DWord";  Value=0; Desc="CEIP off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";  Name="DisableLocation";               Type="DWord";  Value=1; Desc="Localização off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors";  Name="DisableSensors";                Type="DWord";  Value=1; Desc="Sensores off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search";        Name="BingSearchEnabled";             Type="DWord";  Value=0; Desc="Bing Search off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Search";        Name="HistoryViewEnabled";            Type="DWord";  Value=0; Desc="Search history off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SoftLandingEnabled";  Type="DWord";  Value=0; Desc="Windows Tips off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="RotatingLockScreenOverlayEnabled"; Type="DWord"; Value=0; Desc="Spotlight off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="RemediationRequired"; Type="DWord";  Value=0; Desc="Remediation off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="PreInstalledAppsEnabled"; Type="DWord"; Value=0; Desc="Pre-installed apps off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\ContentDeliveryManager"; Name="SilentInstalledAppsEnabled"; Type="DWord"; Value=0; Desc="Silent install off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Privacy";       Name="TailoredExperiencesWithDiagnosticDataEnabled"; Type="DWord"; Value=0; Desc="Tailored experiences off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer";      Name="ShowFrequent";                  Type="DWord";  Value=0; Desc="Frequent files off" },
        @{ Path="HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer";      Name="ShowRecent";                    Type="DWord";  Value=0; Desc="Recent files off" }
    )
    foreach ($t in $tweaks) { Apply-Registry $t.Path $t.Name $t.Type $t.Value $t.Desc }
}

function Apply-TelemetryTasks {
    Write-Header "📅  Tasks Agendadas — Telemetria"
    Write-Log "--- Telemetry Tasks ---"
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
    foreach ($t in $tasks) {
        schtasks /change /tn $t /disable 2>$null
        Write-Status "Task off: $($t.Split('\')[-1])" "" "DONE"
        Write-Log "Task disabled: $t"
    }
}

function Apply-AutoLoggers {
    Write-Header "📜  AutoLoggers"
    Write-Log "--- AutoLoggers ---"
    $loggers = @("AppModel","Cellcore","Circular Kernel Context Logger","CloudExperienceHostOobe",
                 "DataMarket","DefenderApiLogger","DefenderAuditLogger","DiagLog",
                 "HolographicDevice","iclsClient","iclsProxy","LwtNetLog",
                 "Microsoft-Windows-AssignedAccess-Trace","Microsoft-Windows-Setup",
                 "PEAuthLog","RdrLog","ReadyBoot","SetupPlatform","SetupPlatformTel",
                 "SocketHeciServer","SpoolerLogger","SQMLogger","TCPIPLOGGER","TileStore",
                 "Tpm","TPMProvisioningService","UBPM","WdiContextLog","WFP-IPsec Trace",
                 "WiFiSession","WinPhoneCritical")
    foreach ($l in $loggers) {
        Apply-Registry "HKLM:\SYSTEM\CurrentControlSet\Control\WMI\Autologger\$l" "Start" "DWord" 0 "AutoLogger off: $l"
    }
}

function Apply-TelemetryServices {
    Write-Log "--- Telemetry Services ---"
    $services = @("DiagTrack","dmwappushservice","diagnosticshub.standardcollector.service")
    foreach ($s in $services) {
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Set-Service  -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        Write-Status "Serviço desativado: $s" "" "DONE"
    }
}

function Apply-AdTracking {
    Write-Log "--- Ad Tracking ---"
    Apply-Registry "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\AdvertisingInfo" "Enabled" "DWord" 0 "Advertising Info off"
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo"       "DisabledByGroupPolicy" "DWord" 1 "Ads policy off"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"             "CdpSessionUserAuthzPolicy"     "DWord" 0 "CDP off"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\CDP"             "NearShareChannelUserAuthzPolicy" "DWord" 0 "Near Share off"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\AppSync"      "Enabled" "DWord" 0 "App sync off"
    Apply-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\SettingSync\Groups\BrowserSettings" "Enabled" "DWord" 0 "Browser sync off"
    Write-Status "Publicidade e rastreamento desativados" "" "DONE"
}

function Apply-DefenderTelemetry {
    Write-Log "--- Defender Telemetry ---"
    $tweaks = @(
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet";                Name="SpynetReporting";           Type="DWord"; Value=0; Desc="SpyNet off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Spynet";                Name="SubmitSamplesConsent";      Type="DWord"; Value=2; Desc="Sample submission off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting";             Name="DisableGenericReports";     Type="DWord"; Value=1; Desc="Generic reports off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Reporting";             Name="DisableEnhancedNotifications"; Type="DWord"; Value=1; Desc="Enhanced notifications off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender Security Center\Notifications"; Name="DisableNotifications"; Type="DWord"; Value=1; Desc="Defender notifications off" },
        @{ Path="HKLM:\SOFTWARE\Policies\Microsoft\MRT";                                    Name="DontReportInfectionInformation"; Type="DWord"; Value=1; Desc="MRT reporting off" }
    )
    foreach ($t in $tweaks) { Apply-Registry $t.Path $t.Name $t.Type $t.Value $t.Desc }
    Write-Color "  ⚠  Nota: Defender foi configurado apenas para não reportar telemetria." $C.Warning
    Write-Color "     Para desativar o Defender completamente, use a seção Debloat." $C.Dim
}

function Apply-AllTelemetry {
    Write-Header "✅  Aplicar tudo — Telemetria"
    if (-not (Confirm-Action "Aplicar todas as configurações de privacidade?")) { return }
    Create-RestorePoint "Zibble - Before Telemetry Tweaks"
    Apply-TelemetryRegistry; Apply-TelemetryTasks; Apply-AutoLoggers
    Apply-TelemetryServices; Apply-AdTracking; Apply-DefenderTelemetry
    Write-Status "✅  Telemetria e privacidade configuradas!" "" "DONE"
}

# =============================================================================
#  MODULE 5 — DEBLOAT
# =============================================================================
function Menu-Debloat {
    Write-Header "🧹  DEBLOAT WINDOWS"
    Write-Color "  [1] Remover Apps Desnecessários"               $C.Bright
    Write-Color "  [2] Desativar Cortana"                         $C.Bright
    Write-Color "  [3] Desativar / Remover OneDrive"              $C.Bright
    Write-Color "  [4] Desativar Serviços Desnecessários"         $C.Bright
    Write-Color "  [5] Desativar Apps no Startup"                 $C.Bright
    Write-Color "  [6] Desativar Windows Defender"                $C.Warning
    Write-Color "  [7] ✅  Aplicar tudo (exceto Defender)"        $C.Accent
    Write-Host ""
    Write-Color "  [0] Voltar"                                    $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1" { Remove-BloatApps;          Pause-Menu; Menu-Debloat }
        "2" { Disable-Cortana;           Pause-Menu; Menu-Debloat }
        "3" { Disable-OneDrive;          Pause-Menu; Menu-Debloat }
        "4" { Disable-UnnecessaryServices; Pause-Menu; Menu-Debloat }
        "5" { Disable-StartupApps;       Pause-Menu; Menu-Debloat }
        "6" { Disable-WindowsDefender;   Pause-Menu; Menu-Debloat }
        "7" { Apply-AllDebloat;          Pause-Menu; Menu-Debloat }
        "0" { return }
        default { Menu-Debloat }
    }
}

function Remove-BloatApps {
    Write-Header "🗑️  Remover Apps Bloatware"
    Write-Log "--- Remove Bloat Apps ---"
    $apps = @(
        "*3DBuilder*","*bing*","*bingfinance*","*bingsports*","*BingWeather*",
        "*CommsPhone*","*Facebook*","*Getstarted*","*Microsoft.Messaging*",
        "*MicrosoftOfficeHub*","*Office.OneNote*","*OneNote*","*people*",
        "*SkypeApp*","*solit*","*Sway*","*Twitter*","*WindowsAlarms*",
        "*WindowsPhone*","*WindowsMaps*","*WindowsFeedbackHub*",
        "*WindowsSoundRecorder*","*windowscommunicationsapps*","*zune*",
        "*Xbox*","*MixedReality*","*Wallet*","*Cortana*","*549981C3F5F10*",
        "*YourPhone*","*Microsoft3DViewer*","*BingSearch*","*PowerAutomate*"
    )
    $total = $apps.Count; $i = 0
    foreach ($app in $apps) {
        $i++
        Write-Color "  [$i/$total] Removendo $app..." $C.Dim
        Get-AppxPackage -AllUsers $app | Remove-AppxPackage -ErrorAction SilentlyContinue
        Write-Log "Removed app: $app"
    }
    Write-Status "Apps bloatware removidos" "" "DONE"
}

function Disable-Cortana {
    Write-Log "--- Disable Cortana ---"
    $path = "HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Search"
    Apply-Registry $path "AllowCortana"                              "DWord" 0 "Cortana desativada"
    Apply-Registry $path "AllowCloudSearch"                         "DWord" 0 "Cloud Search off"
    Apply-Registry $path "AllowCortanaAboveLock"                    "DWord" 0 "Cortana na tela de bloqueio off"
    Apply-Registry $path "ConnectedSearchUseWeb"                    "DWord" 0 "Connected search off"
    Apply-Registry $path "DisableWebSearch"                         "DWord" 1 "Web search off"
    Get-AppxPackage -AllUsers "*549981C3F5F10*" | Remove-AppxPackage -ErrorAction SilentlyContinue
    Write-Status "Cortana desativada e removida" "" "DONE"
}

function Disable-OneDrive {
    Write-Color "  ⚠  Isso desinstalará o OneDrive e removerá seus dados locais." $C.Warning
    if (-not (Confirm-Action "Desativar e remover OneDrive?")) { return }
    Write-Log "--- Disable OneDrive ---"
    Start-Process "$env:SYSTEMROOT\SYSWOW64\ONEDRIVESETUP.EXE" "/UNINSTALL" -Wait -ErrorAction SilentlyContinue
    @("$env:USERPROFILE\OneDrive","$env:LOCALAPPDATA\Microsoft\OneDrive","$env:PROGRAMDATA\Microsoft OneDrive") |
        ForEach-Object { Remove-Item -Path $_ -Recurse -Force -ErrorAction SilentlyContinue }
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSyncNGSC" "DWord" 1 "OneDrive sync off"
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive" "DisableFileSync"     "DWord" 1 ""
    Write-Status "OneDrive removido" "" "DONE"
}

function Disable-UnnecessaryServices {
    Write-Header "⚙️  Serviços Desnecessários"
    Write-Log "--- Unnecessary Services ---"
    $services = @("TapiSrv","WpcMonSvc","SEMgrSvc","PNRPsvc","WEPHOSTSVC","p2psvc","p2pimsvc",
                  "PhoneSvc","Wecsvc","SensorDataService","SensrSvc","perceptionsimulation",
                  "StiSvc","OneSyncSvc","WMPNetworkSvc","autotimesvc","edgeupdatem",
                  "MicrosoftEdgeElevationService","ALG","QWAVE","IpxlatCfgSvc","icssvc",
                  "DusmSvc","MapsBroker","edgeupdate","SensorService","shpamsvc","svsvc",
                  "SysMain","Netlogon","CscService","ssh-agent","AppReadiness","tzautoupdate",
                  "wisvc","defragsvc","SharedRealitySvc","RetailDemo","lltdsvc","TrkWks",
                  "DiagTrack","diagsvc","dmwappushsvc","TroubleshootingSvc","DsSvc",
                  "FrameServer","FontCache","InstallService","SENS","TabletInputService",
                  "lfsvc","diagnosticshub.standardcollector.service","SecurityHealthService")
    foreach ($s in $services) {
        Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue
        Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
        Write-Status "Desativado: $s" "" "DONE"
        Write-Log "Service disabled: $s"
    }
}

function Disable-StartupApps {
    Write-Log "--- Disable Startup Apps ---"
    $apps = @("Discord","Synapse3","Spotify","EpicGamesLauncher","RiotClient","Steam")
    foreach ($a in $apps) {
        Apply-Registry "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run" $a "Binary" ([byte[]](0x03,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00,0x00)) "Startup off: $a"
    }
}

function Disable-WindowsDefender {
    Write-Color "  ⚠  AVISO CRÍTICO: Isso desativará o Windows Defender completamente." $C.Error
    Write-Color "  Seu PC ficará VULNERÁVEL sem um antivírus alternativo." $C.Error
    Write-Color "  Recomendado APENAS para PCs de gaming dedicados com AV terceiro." $C.Warning
    if (-not (Confirm-Action "CONFIRMAR desativação do Windows Defender?")) { return }
    Write-Log "--- Disable Windows Defender ---"
    $defServices = @("Sense","WdNisSvc","WinDefend","SecurityHealthService","wscsvc")
    foreach ($s in $defServices) { Set-Service -Name $s -StartupType Disabled -ErrorAction SilentlyContinue }
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableAntiSpyware"     "DWord" 1 "Defender desativado"
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender" "DisableRoutinelyTakingAction" "DWord" 1 ""
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableRealtimeMonitoring" "DWord" 1 "Real-time protection off"
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Real-Time Protection" "DisableBehaviorMonitoring" "DWord" 1 ""
    Apply-Registry "HKLM:\SOFTWARE\Policies\Microsoft\Windows"          "EnableSmartScreen"     "DWord" 0 "SmartScreen off"
    Write-Status "Windows Defender desativado" "" "DONE"
    Write-Color "  Reinicie o computador para concluir." $C.Accent
}

function Apply-AllDebloat {
    Write-Header "✅  Debloat Completo"
    if (-not (Confirm-Action "Aplicar debloat completo (sem desativar Defender)?")) { return }
    Create-RestorePoint "Zibble - Before Debloat"
    Remove-BloatApps; Disable-Cortana
    Disable-UnnecessaryServices; Disable-StartupApps
    Write-Status "✅  Debloat concluído!" "" "DONE"
}

# =============================================================================
#  MODULE 6 — INSTALAR APLICATIVOS
# =============================================================================
function Menu-Install {
    Write-Header "📦  INSTALAR APLICATIVOS"

    # Check Winget
    $wingetOk = $null -ne (Get-Command winget -ErrorAction SilentlyContinue)
    if (-not $wingetOk) {
        Write-Color "  ⚠  Winget não encontrado! Instalando..." $C.Warning
        Start-Process "ms-appinstaller:" -ErrorAction SilentlyContinue
        Pause-Menu; return
    }
    Write-Color "  ✅  Winget disponível" $C.Primary
    Write-Host ""
    Write-Color "  ── 🎮 Gaming ────────────────────────────────" $C.Separator
    Write-Color "  [1]  Steam                [2]  Epic Games"      $C.Bright
    Write-Color "  [3]  Discord              [4]  MSI Afterburner" $C.Bright
    Write-Color "  [5]  HWiNFO64             [6]  CPU-Z"           $C.Bright
    Write-Color "  [7]  GPU-Z                [8]  HWMONITOR"       $C.Bright
    Write-Color "  [9]  FurMark              [10] OBS Studio"       $C.Bright
    Write-Host ""
    Write-Color "  ── 🛠️  Utilitários ──────────────────────────" $C.Separator
    Write-Color "  [11] 7-Zip                [12] VLC"             $C.Bright
    Write-Color "  [13] Chrome               [14] Firefox"         $C.Bright
    Write-Color "  [15] VS Code              [16] Notepad++"       $C.Bright
    Write-Color "  [17] WinRAR               [18] Everything"      $C.Bright
    Write-Color "  [19] ShareX               [20] Spotify"         $C.Bright
    Write-Host ""
    Write-Color "  ── 📦 Pacotes ───────────────────────────────" $C.Separator
    Write-Color "  [G]  Instalar TUDO Gaming"                      $C.Accent
    Write-Color "  [U]  Instalar TUDO Utilitários"                 $C.Accent
    Write-Color "  [A]  Instalar TUDO"                             $C.Accent
    Write-Host ""
    Write-Color "  [0]  Voltar"                                    $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção (ex: 1, 5, G)"
    $appMap = @{
        "1"  = @{ ID="Valve.Steam";                    Name="Steam" }
        "2"  = @{ ID="EpicGames.EpicGamesLauncher";    Name="Epic Games" }
        "3"  = @{ ID="Discord.Discord";                Name="Discord" }
        "4"  = @{ ID="MSI.Afterburner";                Name="MSI Afterburner" }
        "5"  = @{ ID="REALiX.HWiNFO";                 Name="HWiNFO64" }
        "6"  = @{ ID="CPUID.CPU-Z";                    Name="CPU-Z" }
        "7"  = @{ ID="TechPowerUp.GPU-Z";              Name="GPU-Z" }
        "8"  = @{ ID="CPUID.HWMonitor";                Name="HWMONITOR" }
        "9"  = @{ ID="Geeks3D.FurMark";                Name="FurMark" }
        "10" = @{ ID="OBSProject.OBSStudio";           Name="OBS Studio" }
        "11" = @{ ID="7zip.7zip";                      Name="7-Zip" }
        "12" = @{ ID="VideoLAN.VLC";                   Name="VLC" }
        "13" = @{ ID="Google.Chrome";                  Name="Chrome" }
        "14" = @{ ID="Mozilla.Firefox";                Name="Firefox" }
        "15" = @{ ID="Microsoft.VisualStudioCode";     Name="VS Code" }
        "16" = @{ ID="Notepad++.Notepad++";            Name="Notepad++" }
        "17" = @{ ID="RARLab.WinRAR";                  Name="WinRAR" }
        "18" = @{ ID="voidtools.Everything";            Name="Everything" }
        "19" = @{ ID="ShareX.ShareX";                  Name="ShareX" }
        "20" = @{ ID="Spotify.Spotify";                Name="Spotify" }
    }

    $gamingApps = @("1","2","3","4","5","6","7","8","9","10")
    $utilApps   = @("11","12","13","14","15","16","17","18","19","20")

    if ($choice -eq "G") {
        foreach ($k in $gamingApps) { Install-App $appMap[$k].ID $appMap[$k].Name }
        Pause-Menu; Menu-Install
    } elseif ($choice -eq "U") {
        foreach ($k in $utilApps)   { Install-App $appMap[$k].ID $appMap[$k].Name }
        Pause-Menu; Menu-Install
    } elseif ($choice -eq "A") {
        foreach ($k in $appMap.Keys) { Install-App $appMap[$k].ID $appMap[$k].Name }
        Pause-Menu; Menu-Install
    } elseif ($appMap.ContainsKey($choice)) {
        Install-App $appMap[$choice].ID $appMap[$choice].Name
        Pause-Menu; Menu-Install
    } elseif ($choice -eq "0") { return }
    else { Menu-Install }
}

function Install-App {
    param([string]$AppID, [string]$AppName)
    Write-Color "  ⬇  Instalando $AppName..." $C.Accent
    Write-Log "Installing: $AppName ($AppID)"
    $result = winget install --id $AppID --silent --accept-source-agreements --accept-package-agreements 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Status "$AppName instalado com sucesso" "" "DONE"
    } else {
        Write-Status "$AppName — falha ou já instalado" "" "WARN"
    }
    Write-Log "Install result [$AppID]: exit $LASTEXITCODE"
}

# =============================================================================
#  MODULE 7 — FIXES & DIAGNÓSTICO
# =============================================================================
function Menu-Fixes {
    Write-Header "🔧  FIXES & DIAGNÓSTICO"
    Write-Color "  ── Reparação ────────────────────────────────" $C.Separator
    Write-Color "  [1] SFC (Verificar ficheiros do sistema)"      $C.Bright
    Write-Color "  [2] DISM (Reparar imagem do Windows)"          $C.Bright
    Write-Color "  [3] SFC + DISM (Scan completo)"               $C.Accent
    Write-Color "  [4] Reset Windows Update"                      $C.Bright
    Write-Color "  [5] Limpar fila de impressão (Spooler)"        $C.Bright
    Write-Host ""
    Write-Color "  ── Diagnóstico ──────────────────────────────" $C.Separator
    Write-Color "  [6] Ping / Teste de Conexão"                   $C.Bright
    Write-Color "  [7] Reset completo de Rede"                    $C.Bright
    Write-Color "  [8] Recuperar senha Wi-Fi"                     $C.Bright
    Write-Color "  [9] Listar processos ativos (Top CPU)"         $C.Bright
    Write-Color "  [10] Verificar portas abertas"                  $C.Bright
    Write-Color "  [11] Ver espaço em disco"                      $C.Bright
    Write-Color "  [12] Reiniciar Windows Explorer"               $C.Bright
    Write-Host ""
    Write-Color "  [0] Voltar"                                    $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1"  { Run-SFC;              Pause-Menu; Menu-Fixes }
        "2"  { Run-DISM;             Pause-Menu; Menu-Fixes }
        "3"  { Run-SFC; Run-DISM;   Pause-Menu; Menu-Fixes }
        "4"  { Reset-WindowsUpdate;  Pause-Menu; Menu-Fixes }
        "5"  { Clear-PrintSpooler;   Pause-Menu; Menu-Fixes }
        "6"  { Test-Connection-Menu; Pause-Menu; Menu-Fixes }
        "7"  { Apply-NetworkReset;   Pause-Menu; Menu-Fixes }
        "8"  { Get-WiFiPassword;     Pause-Menu; Menu-Fixes }
        "9"  { Show-TopProcesses;    Pause-Menu; Menu-Fixes }
        "10" { Show-OpenPorts;       Pause-Menu; Menu-Fixes }
        "11" { Show-DiskSpace;       Pause-Menu; Menu-Fixes }
        "12" { Restart-Explorer;     Pause-Menu; Menu-Fixes }
        "0"  { return }
        default { Menu-Fixes }
    }
}

function Run-SFC {
    Write-Header "🔍  SFC — Verificação do Sistema"
    Write-Color "  Isso pode demorar alguns minutos..." $C.Warning
    Write-Log "--- SFC Scan ---"
    sfc /scannow
    Write-Log "SFC completed"
}

function Run-DISM {
    Write-Header "🔧  DISM — Reparação da Imagem"
    Write-Color "  Requer conexão com a internet. Pode demorar bastante..." $C.Warning
    Write-Log "--- DISM ---"
    DISM /Online /Cleanup-Image /RestoreHealth
    Write-Log "DISM completed"
}

function Reset-WindowsUpdate {
    Write-Header "🔄  Reset Windows Update"
    Write-Log "--- Reset WU ---"
    $services = @("wuauserv","bits","cryptsvc","msiserver")
    foreach ($s in $services) { Stop-Service $s -Force -ErrorAction SilentlyContinue }
    Remove-Item "C:\Windows\SoftwareDistribution" -Recurse -Force -ErrorAction SilentlyContinue
    Remove-Item "C:\Windows\System32\catroot2"    -Recurse -Force -ErrorAction SilentlyContinue
    foreach ($s in $services) { Start-Service $s -ErrorAction SilentlyContinue }
    Write-Status "Windows Update resetado com sucesso" "" "DONE"
}

function Clear-PrintSpooler {
    Write-Log "--- Print Spooler ---"
    Stop-Service spooler -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SYSTEMROOT\System32\Spool\Printers\*" -Force -ErrorAction SilentlyContinue
    Start-Service spooler -ErrorAction SilentlyContinue
    Write-Status "Fila de impressão limpa" "" "DONE"
}

function Test-Connection-Menu {
    Write-Header "📡  Teste de Conexão"
    Write-Color "  Pingando 8.8.8.8 (Google DNS)..." $C.Dim
    $result = Test-Connection -ComputerName 8.8.8.8 -Count 4 -ErrorAction SilentlyContinue
    if ($result) {
        $avg = [math]::Round(($result | Measure-Object ResponseTime -Average).Average, 2)
        Write-Status "Conexão OK — Latência média: ${avg}ms" "" "DONE"
    } else {
        Write-Status "Sem resposta — verifique sua conexão" "" "FAIL"
    }
    Write-Color "  Pingando 1.1.1.1 (Cloudflare)..." $C.Dim
    Test-Connection -ComputerName 1.1.1.1 -Count 2 | Format-Table -AutoSize
}

function Get-WiFiPassword {
    Write-Header "📶  Senhas Wi-Fi"
    $profiles = netsh wlan show profiles | Select-String ":\s+(.+)$" | ForEach-Object { $_.Matches.Groups[1].Value.Trim() }
    if (-not $profiles) { Write-Status "Nenhum perfil Wi-Fi encontrado" "" "WARN"; return }
    foreach ($p in $profiles) {
        $key = netsh wlan show profile name="$p" key=clear | Select-String "Conteúdo da chave\s*:\s*(.+)$|Key Content\s*:\s*(.+)$"
        $pass = if ($key) { $key.Matches.Groups[1].Value.Trim() + $key.Matches.Groups[2].Value.Trim() } else { "(sem senha / não disponível)" }
        Write-Color "  📶 $p" $C.Accent -NoNewline
        Write-Color " — " $C.Dim -NoNewline
        Write-Color $pass $C.Primary
    }
}

function Show-TopProcesses {
    Write-Header "📊  Top 20 Processos por CPU"
    Get-Process | Sort-Object CPU -Descending | Select-Object -First 20 |
        Format-Table Name, Id, @{N="CPU(s)";E={[math]::Round($_.CPU,1)}}, @{N="RAM(MB)";E={[math]::Round($_.WorkingSet/1MB,1)}} -AutoSize
}

function Show-OpenPorts {
    Write-Header "🔌  Portas Abertas"
    netstat -ano | Select-String "LISTENING" | ForEach-Object { $_.Line } | Format-Table | Out-String | Write-Host
}

function Show-DiskSpace {
    Write-Header "💾  Espaço em Disco"
    Get-Volume | Where-Object { $_.DriveLetter } |
        Select-Object DriveLetter, FileSystemLabel,
            @{N="Total (GB)";E={[math]::Round($_.Size/1GB,2)}},
            @{N="Livre (GB)";E={[math]::Round($_.SizeRemaining/1GB,2)}},
            @{N="Uso (%)";E={[math]::Round((($_.Size - $_.SizeRemaining)/$_.Size)*100,1)}} |
        Format-Table -AutoSize
}

function Restart-Explorer {
    Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
    Start-Sleep 1
    Start-Process explorer
    Write-Status "Windows Explorer reiniciado" "" "DONE"
}

# =============================================================================
#  MODULE 8 — PAINÉIS & EXTRAS
# =============================================================================
function Menu-Extras {
    Write-Header "🗂️  PAINÉIS & EXTRAS"
    Write-Color "  ── 🪟 Painéis do Windows ───────────────────" $C.Separator
    Write-Color "  [1]  Painel de Controle"                       $C.Bright
    Write-Color "  [2]  Gerenciamento do Computador"              $C.Bright
    Write-Color "  [3]  Conexões de Rede"                         $C.Bright
    Write-Color "  [4]  Propriedades do Sistema"                  $C.Bright
    Write-Color "  [5]  Gerenciador de Dispositivos"              $C.Bright
    Write-Color "  [6]  Configurações de Energia"                 $C.Bright
    Write-Color "  [7]  Editor de Registro"                       $C.Bright
    Write-Color "  [8]  Serviços do Windows"                      $C.Bright
    Write-Color "  [9]  Agendador de Tarefas"                     $C.Bright
    Write-Color "  [10] Restauração do Sistema"                   $C.Bright
    Write-Host ""
    Write-Color "  ── 🧹 Limpeza & Relatórios ─────────────────" $C.Separator
    Write-Color "  [11] Limpeza de PC (Temp, Prefetch, Logs)"     $C.Bright
    Write-Color "  [12] Relatório de bateria (HTML)"              $C.Bright
    Write-Color "  [13] Diagnóstico do sistema (TXT)"             $C.Bright
    Write-Color "  [14] Abrir log do Zibble"                      $C.Bright
    Write-Host ""
    Write-Color "  [0]  Voltar"                                   $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Opção"
    switch ($choice) {
        "1"  { Start-Process control;                        Write-Status "Painel de Controle aberto" "" "DONE";    Pause-Menu; Menu-Extras }
        "2"  { Start-Process compmgmt.msc;                   Write-Status "Gerenciamento do Comp. aberto" "" "DONE"; Pause-Menu; Menu-Extras }
        "3"  { Start-Process ncpa.cpl;                       Write-Status "Conexões de Rede abertas" "" "DONE";     Pause-Menu; Menu-Extras }
        "4"  { Start-Process sysdm.cpl;                      Write-Status "Propriedades do Sistema abertas" "" "DONE"; Pause-Menu; Menu-Extras }
        "5"  { Start-Process devmgmt.msc;                    Write-Status "Gerenciador de Dispositivos aberto" "" "DONE"; Pause-Menu; Menu-Extras }
        "6"  { Start-Process powercfg.cpl;                   Write-Status "Configurações de Energia abertas" "" "DONE"; Pause-Menu; Menu-Extras }
        "7"  { Start-Process regedit;                        Write-Status "Editor de Registro aberto" "" "DONE";    Pause-Menu; Menu-Extras }
        "8"  { Start-Process services.msc;                   Write-Status "Serviços abertos" "" "DONE";             Pause-Menu; Menu-Extras }
        "9"  { Start-Process taskschd.msc;                   Write-Status "Agendador de Tarefas aberto" "" "DONE";  Pause-Menu; Menu-Extras }
        "10" { Start-Process rstrui.exe;                     Write-Status "Restauração do Sistema aberta" "" "DONE"; Pause-Menu; Menu-Extras }
        "11" { Run-PCCleaner;           Pause-Menu; Menu-Extras }
        "12" { Get-BatteryReport;       Pause-Menu; Menu-Extras }
        "13" { Get-SystemDiagnostic;    Pause-Menu; Menu-Extras }
        "14" { if (Test-Path $Global:LogPath) { notepad $Global:LogPath } else { Write-Status "Log não encontrado" "" "WARN" }; Pause-Menu; Menu-Extras }
        "0"  { return }
        default { Menu-Extras }
    }
}

function Run-PCCleaner {
    Write-Header "🧹  Limpeza de PC"
    Write-Log "--- PC Cleaner ---"
    $paths = @(
        "$env:TEMP\*",
        "$env:WINDIR\Temp\*",
        "$env:WINDIR\Prefetch\*",
        "$env:LOCALAPPDATA\Microsoft\Windows\Explorer\thumbcache_*.db",
        "$env:SYSTEMDRIVE\*.tmp",
        "$env:SYSTEMDRIVE\*.log"
    )
    $totalFreed = 0
    foreach ($p in $paths) {
        try {
            $items = Get-Item $p -ErrorAction SilentlyContinue
            $size  = ($items | Measure-Object -Property Length -Sum -ErrorAction SilentlyContinue).Sum
            Remove-Item $p -Recurse -Force -ErrorAction SilentlyContinue
            $freed = [math]::Round($size/1MB, 2)
            if ($freed -gt 0) {
                Write-Status "Limpo: $p" "${freed} MB liberados" "DONE"
                $totalFreed += $freed
            }
        } catch {}
    }
    # CBS and DISM logs
    Remove-Item "$env:SYSTEMROOT\Logs\CBS\CBS.log"  -Force -ErrorAction SilentlyContinue
    Remove-Item "$env:SYSTEMROOT\Logs\DISM\DISM.log" -Force -ErrorAction SilentlyContinue

    Write-Host ""
    Write-Color "  Total liberado: " $C.Dim -NoNewline
    Write-Color "$([math]::Round($totalFreed,2)) MB" $C.Accent
    Write-Log "PC Cleaner: freed ${totalFreed}MB"
}

function Get-BatteryReport {
    $path = "$env:USERPROFILE\Desktop\zibble_bateria.html"
    powercfg /batteryreport /output $path 2>$null
    if (Test-Path $path) {
        Write-Status "Relatório de bateria salvo" "Desktop\zibble_bateria.html" "DONE"
        Start-Process $path
    } else {
        Write-Status "Não foi possível gerar relatório (sem bateria?)" "" "WARN"
    }
}

function Get-SystemDiagnostic {
    $path = "$env:USERPROFILE\Desktop\zibble_diagnostico.txt"
    Write-Color "  Gerando diagnóstico... Aguarde." $C.Dim
    $info = Get-ComputerInfo
    $info | Out-File $path -Encoding UTF8
    Write-Status "Diagnóstico salvo" "Desktop\zibble_diagnostico.txt" "DONE"
    notepad $path
}

# =============================================================================
#  MAIN MENU
# =============================================================================
function Menu-Main {
    Write-Header ""
    Write-Color "  Sistema : " $C.Dim -NoNewline
    if ($Global:IsWin11) { Write-Color "Windows 11" $C.Accent -NoNewline } else { Write-Color "Windows 10" $C.Accent -NoNewline }
    Write-Color "  |  GPU : " $C.Dim -NoNewline
    Write-Color "$($Global:GPU)" $C.Accent
    Write-Host ""
    Write-Color "  [1]  ⚡  Performance"                    $C.Primary
    Write-Color "  [2]  🖥️   GPU & Display"                 $C.Primary
    Write-Color "  [3]  🌐  Rede"                           $C.Primary
    Write-Color "  [4]  🔇  Telemetria & Privacidade"       $C.Primary
    Write-Color "  [5]  🧹  Debloat Windows"               $C.Primary
    Write-Color "  [6]  📦  Instalar Aplicativos"           $C.Primary
    Write-Color "  [7]  🔧  Fixes & Diagnóstico"            $C.Primary
    Write-Color "  [8]  🗂️   Painéis & Extras"              $C.Primary
    Write-Host ""
    Write-Color "  [R]  🔁  Criar Ponto de Restauração"     $C.Accent
    Write-Color "  [L]  📄  Abrir Log"                      $C.Dim
    Write-Color "  [0]  ❌  Sair"                           $C.Dim
    Write-Separator

    $choice = Read-MenuChoice "Escolha um módulo"
    switch ($choice) {
        "1" { Menu-Performance }
        "2" { Menu-GPU }
        "3" { Menu-Network }
        "4" { Menu-Telemetry }
        "5" { Menu-Debloat }
        "6" { Menu-Install }
        "7" { Menu-Fixes }
        "8" { Menu-Extras }
        "R" { Create-RestorePoint; Pause-Menu }
        "L" { if (Test-Path $Global:LogPath) { notepad $Global:LogPath } else { Write-Status "Log ainda não criado" "" "WARN"; Pause-Menu } }
        "0" {
            Clear-Host
            Write-Host ""
            Write-Color "  Até mais! — Zibble's Performance v$Global:ZibbleVersion" $C.Primary
            Write-Host ""
            exit
        }
        default {}
    }
    Menu-Main
}

# =============================================================================
#  ENTRY POINT
# =============================================================================
Start-Log
$Host.UI.RawUI.WindowTitle = "Zibble's Performance v$Global:ZibbleVersion"
try { $Host.UI.RawUI.BackgroundColor = "Black"; Clear-Host } catch {}

Menu-Main
