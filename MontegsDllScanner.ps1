[Console]::OutputEncoding = [System.Text.Encoding]::UTF8
Clear-Host

$primary = "Cyan"
$success = "Green"
$warning = "Yellow"
$danger  = "Red"
$muted   = "Gray"
$light   = "White"

$Banner = @"
╔════════════════════════════════════════════════════════════════════╗
║   ██████╗ ██╗     ██╗         ███████╗ ██████╗ █████╗ ███╗   ██╗   ║
║   ██╔══██╗██║     ██║         ██╔════╝██╔════╝██╔══██╗████╗  ██║   ║
║   ██║  ██║██║     ██║         ███████╗██║     ███████║██╔██╗ ██║   ║
║   ██║  ██║██║     ██║         ╚════██║██║     ██╔══██║██║╚██╗██║   ║
║   ██████╔╝███████╗███████╗    ███████║╚██████╗██║  ██║██║ ╚████║   ║
║   ╚═════╝ ╚══════╝╚══════╝    ╚══════╝ ╚═════╝╚═╝  ╚═╝╚═╝  ╚═══╝   ║
╚════════════════════════════════════════════════════════════════════╝
"@

Write-Host $Banner -ForegroundColor $primary
Write-Host ""

Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor $primary
Write-Host "  │                   Путь к папке для проверки                 │" -ForegroundColor $light
Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor $primary
Write-Host ""

$scanPath = Read-Host "   Введите путь"

if ([string]::IsNullOrWhiteSpace($scanPath)) {
    $scanPath = "$env:USERPROFILE\AppData\Local\Temp"
    Write-Host "   Путь по умолчанию: $scanPath" -ForegroundColor $muted
}

if (-not (Test-Path $scanPath)) {
    Write-Host "`n   Путь не найден." -ForegroundColor $danger
    pause
    exit
}

$dllFiles = Get-ChildItem $scanPath -Recurse -Filter *.dll -ErrorAction SilentlyContinue

if ($dllFiles.Count -eq 0) {
    Write-Host "`n   DLL файлы не найдены." -ForegroundColor $warning
    pause
    exit
}

Write-Host "`n   Найдено DLL файлов: $($dllFiles.Count)" -ForegroundColor $primary
Write-Host ""

$injectPatterns = @(
"CreateRemoteThread","WriteProcessMemory","VirtualAllocEx",
"SetWindowsHookEx","LoadLibrary","GetProcAddress",
"NtWriteVirtualMemory","NtInject","ManualMap",
"GetAsyncKeyState","mouse_event","SendInput"
)

$cheatPatterns = @(
"AimAssist","AutoAnchor","AutoCrystal","AutoDoubleHand",
"AutoHitCrystal","AutoPot","AutoTotem","AutoArmor","InventoryTotem",
"Hitboxes","HitBox","LegitTotem","PingSpoof","SelfDestruct",
"ShieldBreaker","TriggerBot","AxeSpam","WebMacro",
"FastPlace","WalksyCrystalOptimizerMod","Replace Mod","ShieldDisabler",
"SilentAim","Totem Hit","FakeLag","NoDelay",
"BlockESP","AntiMissClick",
"LagReach","PopSwitch","ChestSteal","AntiBot","ElytraSwap",
"FastXP","FastExp","Refill","NoJumpDelay","AirAnchor","jnativehook",
"FakeInv","HoverTotem","AutoFirework","Freecam",
"PackSpoof","AntiKB","Impulsion","CameraExploit","FreeCam",
"AuthBypass","Asteria","Prestige","AutoEat","AutoMine","FastSwap",
"FastBow","AutoTPA","BaseFinder","AxisAlignedBB","Grim",
"grim","imgui","BowAim",
"FakeItem","invsee","ItemExploit",
"KeyboardMixin","ClientPlayerInteractionManagerMixin",
"LicenseCheckMixin","ClientPlayerInteractionManagerAccessor",
"ClientPlayerEntityMixim","obfuscatedAuth",
"Chams", "GlowESP","GlowEsp","TriggerBot",
"AutoClicker","LeftMouseButton","RightMouseButton"
)

$results = @()
$idx = 0
$total = $dllFiles.Count

foreach ($dll in $dllFiles) {

    $idx++
    $percent = [math]::Round(($idx / $total) * 100)

    Write-Host "   [" -NoNewline
    Write-Host ("█" * [math]::Min($percent/2,50)).PadRight(50,"░") -ForegroundColor $primary -NoNewline
    Write-Host "] $percent% ($idx/$total)"

    $risk = 0
    $flags = @()
    $cheatsFound = @()

    $sig = Get-AuthenticodeSignature $dll.FullName
    if ($sig.Status -ne "Valid") {
        $risk += 15
        $flags += "Нет цифровой подписи"
    }

    try {
        $bytes = [System.IO.File]::ReadAllBytes($dll.FullName)
        $text  = -join ($bytes | ForEach-Object {
            if ($_ -ge 32 -and $_ -le 126) {[char]$_} else {" "}
        })

        foreach ($p in $injectPatterns) {
            if ($text -match [regex]::Escape($p)) {
                $risk += 10
                $flags += "API: $p"
            }
        }

        foreach ($p in $cheatPatterns) {
            if ($text -match [regex]::Escape($p)) {
                $risk += 5
                $cheatsFound += $p
            }
        }

    } catch {}

    try {
        $java = Get-Process javaw -ErrorAction SilentlyContinue
        if ($java) {
            foreach ($module in $java.Modules) {
                if ($module.FileName -eq $dll.FullName) {
                    $risk += 40
                    $flags += "Загружена в javaw.exe"
                }
            }
        }
    } catch {}

    if ($risk -gt 0) {
        $results += [PSCustomObject]@{
            File = $dll.FullName
            Risk = $risk
            Flags = $flags | Sort-Object -Unique
            Cheats = $cheatsFound | Sort-Object -Unique
        }
    }
}

Write-Host ""
Write-Host "  ═══════════════════════════════════════════════════════════════" -ForegroundColor $primary
Write-Host ""

if ($results.Count -eq 0) {
    Write-Host "   Подозрительных DLL не обнаружено." -ForegroundColor $success
} else {

    Write-Host "  ┌─────────────────────────────────────────────────────────────┐" -ForegroundColor $danger
    Write-Host "  │               Обнаружены возможные читы DLL                 │" -ForegroundColor $danger
    Write-Host "  └─────────────────────────────────────────────────────────────┘" -ForegroundColor $danger
    Write-Host ""

    foreach ($r in $results | Sort-Object Risk -Descending) {

        Write-Host "   Файл: " -ForegroundColor $muted -NoNewline
        Write-Host $r.File -ForegroundColor $light

        Write-Host "   Риск: " -ForegroundColor $muted -NoNewline

        if ($r.Risk -ge 70) {
            Write-Host "$($r.Risk) (ВЫСОКИЙ)" -ForegroundColor $danger
        }
        elseif ($r.Risk -ge 35) {
            Write-Host "$($r.Risk) (СРЕДНИЙ)" -ForegroundColor $warning
        }
        else {
            Write-Host "$($r.Risk) (НИЗКИЙ)" -ForegroundColor $primary
        }

        if ($r.Cheats.Count -gt 0) {
            Write-Host "   Найдены строки читов:" -ForegroundColor $danger
            foreach ($c in $r.Cheats) {
                Write-Host "     - $c" -ForegroundColor $light
            }
        }

        if ($r.Flags.Count -gt 0) {
            Write-Host "   Технические признаки:" -ForegroundColor $warning
            foreach ($f in $r.Flags) {
                Write-Host "     - $f" -ForegroundColor $light
            }
        }

        Write-Host ""
    }
}

Write-Host "  Нажмите любую клавишу для выхода..." -ForegroundColor $muted
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
