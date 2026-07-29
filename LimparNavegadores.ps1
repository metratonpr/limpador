<#
    LimparNavegadores.ps1

    Fecha Chrome, Firefox, Brave e Opera; apaga historico, cache, cookies
    e senhas salvas de cada perfil; edita os atalhos da area de trabalho
    para abrirem em modo de navegacao anonima/privada; e configura os
    navegadores para limparem os dados automaticamente ao fechar.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1
        powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1 -Silencioso

    Sem backup: os dados apagados (historico, cookies, senhas) NAO podem
    ser recuperados depois. Rode por sua conta e risco.
#>

[CmdletBinding()]
param(
    [switch]$Silencioso   # pula a confirmacao interativa
)

$ErrorActionPreference = 'SilentlyContinue'

function Write-Secao($texto) {
    Write-Host ""
    Write-Host "=== $texto ===" -ForegroundColor Cyan
}

function Write-Item($texto, $status = 'ok') {
    $cor = switch ($status) {
        'ok'   { 'Green' }
        'skip' { 'DarkGray' }
        'warn' { 'Yellow' }
        default { 'White' }
    }
    $marca = switch ($status) {
        'ok'   { '[OK]' }
        'skip' { '[--]' }
        'warn' { '[!!]' }
        default { '[..]' }
    }
    Write-Host "  $marca $texto" -ForegroundColor $cor
}

# ---------------------------------------------------------------------------
# 0. Confirmacao
# ---------------------------------------------------------------------------
if (-not $Silencioso) {
    Write-Host "Este script vai FECHAR Chrome, Firefox, Brave e Opera," -ForegroundColor Yellow
    Write-Host "apagar historico/cache/cookies/senhas salvas e alterar os" -ForegroundColor Yellow
    Write-Host "atalhos da area de trabalho para modo anonimo. Sem backup." -ForegroundColor Yellow
    $resp = Read-Host "Digite CONFIRMAR para continuar"
    if ($resp -ne 'CONFIRMAR') {
        Write-Host "Cancelado pelo usuario." -ForegroundColor Red
        exit 1
    }
}

# ---------------------------------------------------------------------------
# 1. Fechar os navegadores
# ---------------------------------------------------------------------------
Write-Secao "Fechando navegadores"

$processos = @('chrome', 'firefox', 'brave', 'opera', 'opera_gx')
foreach ($p in $processos) {
    $procs = Get-Process -Name $p -ErrorAction SilentlyContinue
    if ($procs) {
        $procs | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Item "$p encerrado"
    } else {
        Write-Item "$p nao estava rodando" 'skip'
    }
}
Start-Sleep -Seconds 2

# ---------------------------------------------------------------------------
# 2. Definicao dos navegadores baseados em Chromium (Chrome, Brave, Opera)
# ---------------------------------------------------------------------------
$local = $env:LOCALAPPDATA
$roaming = $env:APPDATA

$navegadoresChromium = @(
    @{
        Nome       = 'Google Chrome'
        UserData   = Join-Path $local 'Google\Chrome\User Data'
        PolicyKey  = 'HKCU:\SOFTWARE\Policies\Google\Chrome'
        Executavel = Join-Path $local 'Google\Chrome\Application\chrome.exe'
    },
    @{
        Nome       = 'Brave'
        UserData   = Join-Path $local 'BraveSoftware\Brave-Browser\User Data'
        PolicyKey  = 'HKCU:\SOFTWARE\Policies\BraveSoftware\Brave'
        Executavel = Join-Path $local 'BraveSoftware\Brave-Browser\Application\brave.exe'
    },
    @{
        Nome       = 'Opera'
        UserData   = Join-Path $roaming 'Opera Software\Opera Stable'
        PolicyKey  = 'HKCU:\SOFTWARE\Policies\Opera Software\Opera'
        Executavel = Join-Path $local 'Programs\Opera\launcher.exe'
    }
)

# Arquivos/pastas de dado sensivel dentro de cada perfil Chromium
$arquivosChromium = @('History', 'Cookies', 'Login Data', 'Login Data For Account', 'Web Data', 'Top Sites', 'Visited Links', 'Shortcuts')
$pastasChromium   = @('Cache', 'Code Cache', 'GPUCache', 'Service Worker')

Write-Secao "Limpando navegadores baseados em Chromium (Chrome, Brave, Opera)"

foreach ($nav in $navegadoresChromium) {
    if (-not (Test-Path $nav.UserData)) {
        Write-Item "$($nav.Nome) nao encontrado (pasta de perfil ausente)" 'skip'
        continue
    }

    # percorre todos os perfis (Default, Profile 1, Profile 2, ...)
    $perfis = Get-ChildItem -Path $nav.UserData -Directory -ErrorAction SilentlyContinue |
        Where-Object { $_.Name -eq 'Default' -or $_.Name -match '^Profile \d+$' }

    if (-not $perfis) {
        Write-Item "$($nav.Nome): nenhum perfil encontrado" 'skip'
        continue
    }

    foreach ($perfil in $perfis) {
        foreach ($arq in $arquivosChromium) {
            $caminho = Join-Path $perfil.FullName $arq
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
        foreach ($pasta in $pastasChromium) {
            $caminho = Join-Path $perfil.FullName $pasta
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Force -Recurse -ErrorAction SilentlyContinue
            }
        }
    }
    Write-Item "$($nav.Nome): historico, cache, cookies e senhas apagados ($($perfis.Count) perfil(is))"

    # ---- trava o navegador via politica (HKCU, sem precisar de admin) ----
    try {
        if (-not (Test-Path $nav.PolicyKey)) {
            New-Item -Path $nav.PolicyKey -Force | Out-Null
        }

        # limpa tudo ao fechar (fica valendo caso alguma politica abaixo falhe)
        $itensParaLimpar = @(
            'browsing_history', 'download_history', 'cookies_and_other_site_data',
            'cached_images_and_files', 'password_signin', 'autofill', 'site_settings', 'hosted_app_data'
        )
        New-ItemProperty -Path $nav.PolicyKey -Name 'ClearBrowsingDataOnExitList' `
            -Value $itensParaLimpar -PropertyType MultiString -Force | Out-Null

        # forca TODA janela a abrir em modo anonimo, nao importa por onde for aberta
        New-ItemProperty -Path $nav.PolicyKey -Name 'IncognitoModeAvailability' `
            -Value 2 -PropertyType DWord -Force | Out-Null

        # desativa o gerenciador de senhas (nada mais fica salvo, nem se a pessoa clicar "salvar")
        New-ItemProperty -Path $nav.PolicyKey -Name 'PasswordManagerEnabled' `
            -Value 0 -PropertyType DWord -Force | Out-Null

        # desativa autofill de endereco e cartao de credito
        New-ItemProperty -Path $nav.PolicyKey -Name 'AutofillAddressEnabled' `
            -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'AutofillCreditCardEnabled' `
            -Value 0 -PropertyType DWord -Force | Out-Null

        # impede login de conta no navegador e sincronizacao (senha nao volta da nuvem)
        New-ItemProperty -Path $nav.PolicyKey -Name 'BrowserSignin' `
            -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'SyncDisabled' `
            -Value 1 -PropertyType DWord -Force | Out-Null

        Write-Item "$($nav.Nome): travado (modo anonimo forcado, sem gerenciador de senha, sem login/sync)"
    } catch {
        Write-Item "$($nav.Nome): nao foi possivel aplicar todas as politicas de bloqueio" 'warn'
    }
}

# ---------------------------------------------------------------------------
# 3. Firefox
# ---------------------------------------------------------------------------
Write-Secao "Limpando Firefox"

$firefoxProfilesDir = Join-Path $roaming 'Mozilla\Firefox\Profiles'

if (Test-Path $firefoxProfilesDir) {
    $perfisFirefox = Get-ChildItem -Path $firefoxProfilesDir -Directory -ErrorAction SilentlyContinue

    $arquivosFirefox = @('places.sqlite', 'cookies.sqlite', 'formhistory.sqlite', 'logins.json', 'key4.db', 'webappsstore.sqlite', 'favicons.sqlite')
    $pastasFirefox   = @('cache2', 'startupCache', 'shader-cache', 'storage')

    foreach ($perfil in $perfisFirefox) {
        foreach ($arq in $arquivosFirefox) {
            $caminho = Join-Path $perfil.FullName $arq
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Force -ErrorAction SilentlyContinue
            }
        }
        foreach ($pasta in $pastasFirefox) {
            $caminho = Join-Path $perfil.FullName $pasta
            if (Test-Path $caminho) {
                Remove-Item -Path $caminho -Force -Recurse -ErrorAction SilentlyContinue
            }
        }

        # ---- trava o perfil via prefs.js ----
        $prefsPath = Join-Path $perfil.FullName 'prefs.js'
        $prefsLimpeza = @(
            # limpa tudo ao fechar
            'user_pref("privacy.sanitize.sanitizeOnShutdown", true);',
            'user_pref("privacy.clearOnShutdown.history", true);',
            'user_pref("privacy.clearOnShutdown.formdata", true);',
            'user_pref("privacy.clearOnShutdown.downloads", true);',
            'user_pref("privacy.clearOnShutdown.cookies", true);',
            'user_pref("privacy.clearOnShutdown.cache", true);',
            'user_pref("privacy.clearOnShutdown.sessions", true);',
            'user_pref("privacy.clearOnShutdown.offlineApps", true);',
            'user_pref("privacy.clearOnShutdown.siteSettings", false);',
            # forca toda janela/aba nova a abrir em navegacao privada
            'user_pref("browser.privatebrowsing.autostart", true);',
            # desativa o gerenciador de senhas e autofill
            'user_pref("signon.rememberSignons", false);',
            'user_pref("signon.autofillForms", false);',
            'user_pref("signon.generation.enabled", false);',
            'user_pref("browser.formfill.enable", false);',
            # desativa Firefox Sync / login de conta (senha nao volta da nuvem)
            'user_pref("identity.fxaccounts.enabled", false);'
        )

        $conteudoAtual = @()
        if (Test-Path $prefsPath) {
            $conteudoAtual = Get-Content -Path $prefsPath -ErrorAction SilentlyContinue |
                Where-Object { $_ -notmatch 'privacy\.(sanitize\.sanitizeOnShutdown|clearOnShutdown\.)|browser\.privatebrowsing\.autostart|signon\.(rememberSignons|autofillForms|generation\.enabled)|browser\.formfill\.enable|identity\.fxaccounts\.enabled' }
        }
        $novoConteudo = $conteudoAtual + $prefsLimpeza
        Set-Content -Path $prefsPath -Value $novoConteudo -Force -ErrorAction SilentlyContinue
    }

    if ($perfisFirefox) {
        Write-Item "Firefox: historico, cookies, cache e senhas apagados ($($perfisFirefox.Count) perfil(is))"
        Write-Item "Firefox: travado (navegacao privada forcada, sem gerenciador de senha, sem sync)"
    } else {
        Write-Item "Firefox: nenhum perfil encontrado" 'skip'
    }
} else {
    Write-Item "Firefox nao encontrado (pasta de perfis ausente)" 'skip'
}

# ---------------------------------------------------------------------------
# 4. Atalhos (Area de trabalho, Menu Iniciar, Barra de tarefas) -> modo anonimo
# ---------------------------------------------------------------------------
Write-Secao "Ajustando atalhos para modo anonimo (mesmo com politica de bloqueio ja forcando isso)"

$pastasAtalhos = @(
    [Environment]::GetFolderPath('Desktop')
    (Join-Path $env:PUBLIC 'Desktop')
    [Environment]::GetFolderPath('StartMenu')
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu')
    (Join-Path $roaming 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
) | Select-Object -Unique | Where-Object { Test-Path $_ }

$shell = New-Object -ComObject WScript.Shell

# nome do executavel -> argumento de navegacao privada
$flagsPrivados = @{
    'chrome.exe'    = '--incognito'
    'brave.exe'     = '--incognito'
    'opera.exe'     = '--private'
    'launcher.exe'  = '--private'   # Opera as vezes usa launcher.exe
    'firefox.exe'   = '-private-window'
}

$atalhosAlterados = 0

foreach ($pasta in $pastasAtalhos) {
    $lnks = Get-ChildItem -Path $pasta -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue
    foreach ($lnk in $lnks) {
        try {
            $atalho = $shell.CreateShortcut($lnk.FullName)
            $alvo = $atalho.TargetPath
            if (-not $alvo) { continue }

            $exeNome = Split-Path $alvo -Leaf
            if ($flagsPrivados.ContainsKey($exeNome.ToLower())) {
                $flag = $flagsPrivados[$exeNome.ToLower()]
                if ($atalho.Arguments -notmatch [regex]::Escape($flag)) {
                    $atalho.Arguments = ($atalho.Arguments + ' ' + $flag).Trim()
                    $atalho.Save()
                    $atalhosAlterados++
                    Write-Item "Atalho '$($lnk.Name)' -> adicionado $flag"
                } else {
                    Write-Item "Atalho '$($lnk.Name)' ja estava em modo privado" 'skip'
                }
            }
        } catch {
            Write-Item "Falha ao processar atalho '$($lnk.Name)'" 'warn'
        }
    }
}

if ($atalhosAlterados -eq 0) {
    Write-Item "Nenhum atalho de navegador encontrado na area de trabalho" 'skip'
}

[Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

# ---------------------------------------------------------------------------
# 5. Resumo
# ---------------------------------------------------------------------------
Write-Secao "Concluido"
Write-Host "Historico, cache, cookies e senhas foram apagados (sem backup)." -ForegroundColor Green
Write-Host "Chrome/Brave/Opera: modo anonimo FORCADO em toda janela, gerenciador de" -ForegroundColor Green
Write-Host "senha e autofill desativados, login de conta/sync bloqueado, limpeza" -ForegroundColor Green
Write-Host "automatica ao fechar ativada." -ForegroundColor Green
Write-Host "Firefox: navegacao privada FORCADA em toda janela, gerenciador de senha" -ForegroundColor Green
Write-Host "e autofill desativados, Firefox Sync desativado, limpeza automatica" -ForegroundColor Green
Write-Host "ao fechar ativada." -ForegroundColor Green
Write-Host "Atalhos (Area de trabalho, Menu Iniciar, barra de tarefas) ajustados: $atalhosAlterados" -ForegroundColor Green
Write-Host ""
Write-Host "Como o modo anonimo agora e forcado por politica, o navegador vai abrir" -ForegroundColor DarkYellow
Write-Host "sempre em modo privado, seja qual atalho a pessoa usar." -ForegroundColor DarkYellow
Write-Host "Observacao: o Opera nao documenta oficialmente suporte total as politicas" -ForegroundColor DarkYellow
Write-Host "de Chromium; se IncognitoModeAvailability nao for respeitado, o atalho" -ForegroundColor DarkYellow
Write-Host "com '--private' fica como reforco, mas pode nao funcionar em toda versao." -ForegroundColor DarkYellow
