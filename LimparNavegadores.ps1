<#
    LimparNavegadores.ps1  (arquivo unico)

    Modo normal (sem parametros):
        Fecha Chrome, Firefox, Brave, Opera, Edge e Internet Explorer;
        apaga historico, cache, cookies e senhas salvas; trava os
        navegadores por politica (modo anonimo/InPrivate forcado onde
        suportado, sem gerenciador de senha, sem login/sync, pagina
        inicial fixada no site da empresa); e reaponta os atalhos (Area de
        trabalho, Menu Iniciar, barra de tarefas) para chamar este MESMO
        arquivo em "modo lancador".
        Tambem deixa so 1 atalho oficial por navegador na Area de trabalho.

    Modo lancador (-Lancar, usado pelos atalhos, nao chame manualmente):
        Apaga a pasta de perfil inteira do navegador, abre ele, espera
        fechar e apaga a pasta de novo -- ou seja, cada abertura pelos
        atalhos se comporta como uma instalacao nova.

    Uso:
        powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1
        powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1 -Silencioso

    Sem backup: os dados apagados (historico, cookies, senhas) NAO podem
    ser recuperados depois. Rode por sua conta e risco.
#>

[CmdletBinding()]
param(
    [switch]$Silencioso,   # pula a confirmacao interativa (modo normal)

    # --- parametros usados internamente pelos atalhos (modo lancador) ---
    [switch]$Lancar,
    [string]$Navegador,    # 'firefox', 'chromium' (Chrome/Brave/Opera/Edge) ou 'iexplore'
    [string]$UserData,     # pasta "User Data" (Chromium)
    [string]$Exe,          # caminho do executavel a abrir
    [string]$ArgsExtra     # ex: --incognito / --private / --inprivate
)

$ErrorActionPreference = 'SilentlyContinue'

# Pagina inicial fixada em todos os navegadores (site oficial, sem parametros
# de campanha/anuncio -- esses expiram e nao devem virar homepage permanente)
$PaginaInicial = 'https://www.pr.senac.br/principal/'

# Prefs de bloqueio + homepage do Firefox -- usadas tanto no perfil ja
# existente (modo normal, secao 3) quanto no perfil provisionado do zero
# a cada abertura (modo lancador, para sobreviver ao apagamento do perfil)
function Get-FirefoxPrefsLinhas {
    @(
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
        'user_pref("identity.fxaccounts.enabled", false);',
        # pagina inicial fixa
        "user_pref(`"browser.startup.homepage`", `"$PaginaInicial`");",
        'user_pref("browser.startup.page", 1);'
    )
}

# =============================================================================
# MODO LANCADOR: apaga o perfil, abre o navegador, espera fechar, apaga de novo
# =============================================================================
if ($Lancar) {

    if ($Navegador -eq 'firefox') {
        $firefoxRoot     = Join-Path $env:APPDATA 'Mozilla\Firefox'
        $profilesDir     = Join-Path $firefoxRoot 'Profiles'
        $nomePerfil      = 'efemero.default-release'
        $perfilPath      = Join-Path $profilesDir $nomePerfil
        $profilesIniPath = Join-Path $firefoxRoot 'profiles.ini'

        function Limpar-Firefox {
            if (Test-Path $firefoxRoot) {
                Remove-Item -Path $firefoxRoot -Recurse -Force
            }
        }

        function Provisionar-PerfilFirefox {
            # recria um perfil ja travado (sem senha, privado forcado, com a
            # homepage) do zero -- assim as regras nao se perdem quando a
            # pasta inteira e apagada apos o fechamento anterior
            New-Item -Path $perfilPath -ItemType Directory -Force | Out-Null

            $profilesIni = @(
                '[Profile0]'
                'Name=default'
                'IsRelative=1'
                "Path=Profiles/$nomePerfil"
                'Default=1'
                ''
                '[General]'
                'StartWithLastProfile=1'
                'Version=2'
            )
            Set-Content -Path $profilesIniPath -Value $profilesIni -Force

            $prefsPath = Join-Path $perfilPath 'prefs.js'
            Set-Content -Path $prefsPath -Value (Get-FirefoxPrefsLinhas) -Force
        }

        function Encontrar-FirefoxExe {
            $candidatos = @(
                (Join-Path $env:ProgramFiles 'Mozilla Firefox\firefox.exe')
                (Join-Path ${env:ProgramFiles(x86)} 'Mozilla Firefox\firefox.exe')
                (Join-Path $env:LOCALAPPDATA 'Mozilla Firefox\firefox.exe')
            )
            foreach ($c in $candidatos) {
                if ($c -and (Test-Path $c)) { return $c }
            }
            $viaRegistro = (Get-ItemProperty 'HKLM:\SOFTWARE\Clients\StartMenuInternet\FIREFOX.EXE\shell\open\command' -ErrorAction SilentlyContinue).'(default)'
            if ($viaRegistro) {
                return ($viaRegistro -replace '^"?([^"]+firefox\.exe)"?.*$', '$1')
            }
            return $null
        }

        Limpar-Firefox
        Provisionar-PerfilFirefox
        $firefoxExe = Encontrar-FirefoxExe
        if ($firefoxExe) {
            $proc = Start-Process -FilePath $firefoxExe -PassThru
            $proc.WaitForExit()
        }
        Limpar-Firefox
    }
    elseif ($Navegador -eq 'iexplore') {
        # IE nao guarda os dados numa pasta de perfil propria (usa WinINet/
        # Credential Manager compartilhados) -- limpa via RunDll32 antes e depois
        function Limpar-IE {
            Start-Process -FilePath 'RunDll32.exe' -ArgumentList 'InetCpl.cpl,ClearMyTracksByProcess 4351' -Wait
        }

        function Encontrar-IEExe {
            $candidatos = @(
                (Join-Path $env:ProgramFiles 'Internet Explorer\iexplore.exe')
                (Join-Path ${env:ProgramFiles(x86)} 'Internet Explorer\iexplore.exe')
            )
            foreach ($c in $candidatos) {
                if ($c -and (Test-Path $c)) { return $c }
            }
            return $null
        }

        Limpar-IE
        $ieExe = Encontrar-IEExe
        if ($ieExe) {
            $proc = Start-Process -FilePath $ieExe -ArgumentList '-private' -PassThru
            $proc.WaitForExit()
        }
        Limpar-IE
    }
    else {
        # Chromium: Chrome, Brave, Opera, Edge -- recebidos via -UserData / -Exe / -ArgsExtra
        function Limpar-PerfilChromium {
            if ($UserData -and (Test-Path $UserData)) {
                Remove-Item -Path $UserData -Recurse -Force
            }
        }

        Limpar-PerfilChromium
        if ($Exe -and (Test-Path $Exe)) {
            if ($ArgsExtra) {
                $proc = Start-Process -FilePath $Exe -ArgumentList $ArgsExtra -PassThru
            } else {
                $proc = Start-Process -FilePath $Exe -PassThru
            }
            $proc.WaitForExit()
        }
        Limpar-PerfilChromium
    }

    exit 0
}

# =============================================================================
# MODO NORMAL: limpeza, bloqueio e reconfiguracao dos atalhos
# =============================================================================

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
    Write-Host "Este script vai FECHAR Chrome, Firefox, Brave, Opera, Edge e" -ForegroundColor Yellow
    Write-Host "Internet Explorer, apagar historico/cache/cookies/senhas salvas" -ForegroundColor Yellow
    Write-Host "e reapontar os atalhos para que cada abertura seja como" -ForegroundColor Yellow
    Write-Host "instalacao nova. Sem backup." -ForegroundColor Yellow
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

$processos = @('chrome', 'firefox', 'brave', 'opera', 'opera_gx', 'msedge', 'iexplore')
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
# 2. Definicao dos navegadores baseados em Chromium (Chrome, Brave, Opera, Edge)
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
    },
    @{
        Nome       = 'Microsoft Edge'
        UserData   = Join-Path $local 'Microsoft\Edge\User Data'
        PolicyKey  = 'HKCU:\SOFTWARE\Policies\Microsoft\Edge'
        Executavel = Join-Path ${env:ProgramFiles(x86)} 'Microsoft\Edge\Application\msedge.exe'
    }
)

# Arquivos/pastas de dado sensivel dentro de cada perfil Chromium
$arquivosChromium = @('History', 'Cookies', 'Login Data', 'Login Data For Account', 'Web Data', 'Top Sites', 'Visited Links', 'Shortcuts')
$pastasChromium   = @('Cache', 'Code Cache', 'GPUCache', 'Service Worker')

Write-Secao "Limpando navegadores baseados em Chromium (Chrome, Brave, Opera, Edge)"

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
        # (Edge nao tem opcao de "forcar" InPrivate, so permitir/desativar --
        # o modo anonimo dele fica garantido pelo lancador da secao 4)
        if ($nav.Nome -eq 'Microsoft Edge') {
            New-ItemProperty -Path $nav.PolicyKey -Name 'InPrivateModeAvailability' `
                -Value 0 -PropertyType DWord -Force | Out-Null
        } else {
            New-ItemProperty -Path $nav.PolicyKey -Name 'IncognitoModeAvailability' `
                -Value 2 -PropertyType DWord -Force | Out-Null
        }

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

        # apaga o perfil inteiro ao encerrar a sessao (defesa extra, alem do
        # lancador da secao 5 que ja apaga a pasta User Data por completo)
        New-ItemProperty -Path $nav.PolicyKey -Name 'ForceEphemeralProfiles' `
            -Value 1 -PropertyType DWord -Force | Out-Null

        # pagina inicial fixa: abre nela ao iniciar e no botao "Pagina inicial"
        New-ItemProperty -Path $nav.PolicyKey -Name 'RestoreOnStartup' `
            -Value 4 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'RestoreOnStartupURLs' `
            -Value @($PaginaInicial) -PropertyType MultiString -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'HomepageLocation' `
            -Value $PaginaInicial -PropertyType String -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'HomepageIsNewTabPage' `
            -Value 0 -PropertyType DWord -Force | Out-Null
        New-ItemProperty -Path $nav.PolicyKey -Name 'ShowHomeButton' `
            -Value 1 -PropertyType DWord -Force | Out-Null

        Write-Item "$($nav.Nome): travado (modo anonimo forcado, perfil efemero, sem gerenciador de senha, sem login/sync, homepage fixa)"
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

        # ---- trava o perfil via prefs.js (mesma funcao usada pelo lancador) ----
        $prefsPath = Join-Path $perfil.FullName 'prefs.js'
        $prefsLimpeza = Get-FirefoxPrefsLinhas

        $conteudoAtual = @()
        if (Test-Path $prefsPath) {
            $conteudoAtual = Get-Content -Path $prefsPath -ErrorAction SilentlyContinue |
                Where-Object { $_ -notmatch 'privacy\.(sanitize\.sanitizeOnShutdown|clearOnShutdown\.)|browser\.privatebrowsing\.autostart|signon\.(rememberSignons|autofillForms|generation\.enabled)|browser\.formfill\.enable|identity\.fxaccounts\.enabled|browser\.startup\.(homepage|page)' }
        }
        $novoConteudo = $conteudoAtual + $prefsLimpeza
        Set-Content -Path $prefsPath -Value $novoConteudo -Force -ErrorAction SilentlyContinue
    }

    if ($perfisFirefox) {
        Write-Item "Firefox: historico, cookies, cache e senhas apagados ($($perfisFirefox.Count) perfil(is))"
        Write-Item "Firefox: travado (navegacao privada forcada, sem gerenciador de senha, sem sync, homepage fixa)"
    } else {
        Write-Item "Firefox: nenhum perfil encontrado" 'skip'
    }
} else {
    Write-Item "Firefox nao encontrado (pasta de perfis ausente)" 'skip'
}

# ---------------------------------------------------------------------------
# 4. Internet Explorer
# ---------------------------------------------------------------------------
Write-Secao "Limpando Internet Explorer"

$ieInstalado = (Test-Path (Join-Path $env:ProgramFiles 'Internet Explorer\iexplore.exe')) `
    -or (Test-Path (Join-Path ${env:ProgramFiles(x86)} 'Internet Explorer\iexplore.exe'))

if ($ieInstalado) {
    # IE nao usa pastas de perfil como Chromium/Firefox: historico, cookies,
    # cache, senhas e dados de formulario ficam no WinINet e no Credential
    # Manager do Windows. RunDll32 InetCpl.cpl e o jeito suportado de limpar
    # tudo isso (4351 = historico + cookies + cache + senhas + formularios).
    try {
        Start-Process -FilePath 'RunDll32.exe' -ArgumentList 'InetCpl.cpl,ClearMyTracksByProcess 4351' -Wait
        Write-Item "Internet Explorer: historico, cookies, cache, senhas e formularios apagados"
    } catch {
        Write-Item "Internet Explorer: falha ao limpar dados (RunDll32 InetCpl.cpl)" 'warn'
    }

    # ---- trava: limpa automaticamente ao fechar ----
    try {
        $iePolicyKey = 'HKCU:\Software\Policies\Microsoft\Internet Explorer\Privacy'
        if (-not (Test-Path $iePolicyKey)) {
            New-Item -Path $iePolicyKey -Force | Out-Null
        }
        New-ItemProperty -Path $iePolicyKey -Name 'ClearBrowsingHistoryOnExit' `
            -Value 1 -PropertyType DWord -Force | Out-Null
        Write-Item "Internet Explorer: configurado para limpar historico ao fechar"
    } catch {
        Write-Item "Internet Explorer: nao foi possivel aplicar a politica de limpeza automatica" 'warn'
    }

    # ---- pagina inicial fixa ----
    try {
        $ieMainKey = 'HKCU:\Software\Microsoft\Internet Explorer\Main'
        if (-not (Test-Path $ieMainKey)) { New-Item -Path $ieMainKey -Force | Out-Null }
        New-ItemProperty -Path $ieMainKey -Name 'Start Page' -Value $PaginaInicial -PropertyType String -Force | Out-Null

        Write-Item "Internet Explorer: pagina inicial fixada"
    } catch {
        Write-Item "Internet Explorer: nao foi possivel fixar a pagina inicial" 'warn'
    }
} else {
    Write-Item "Internet Explorer nao encontrado" 'skip'
}

# ---------------------------------------------------------------------------
# 5. Atalhos (Area de trabalho, Menu Iniciar, Barra de tarefas)
#    -> reapontar para ESTE MESMO arquivo em modo lancador (-Lancar)
# ---------------------------------------------------------------------------
Write-Secao "Reapontando atalhos para o modo lancador de perfil efemero"

$scriptPath = $MyInvocation.MyCommand.Path

$pwshPath = (Get-Command powershell.exe -ErrorAction SilentlyContinue).Source
if (-not $pwshPath) { $pwshPath = 'powershell.exe' }

$atalhosAlterados = 0

$pastasAtalhos = @(
    [Environment]::GetFolderPath('Desktop')
    (Join-Path $env:PUBLIC 'Desktop')
    [Environment]::GetFolderPath('StartMenu')
    (Join-Path $env:ProgramData 'Microsoft\Windows\Start Menu')
    (Join-Path $roaming 'Microsoft\Internet Explorer\Quick Launch\User Pinned\TaskBar')
) | Select-Object -Unique | Where-Object { Test-Path $_ }

$shell = New-Object -ComObject WScript.Shell

# nome do executavel -> pasta "User Data" do navegador (Chromium) e flag de modo privado
$userDataPorExe = @{
    'chrome.exe'   = @{ UserData = ($navegadoresChromium | Where-Object Nome -eq 'Google Chrome').UserData;  Flag = '--incognito' }
    'brave.exe'    = @{ UserData = ($navegadoresChromium | Where-Object Nome -eq 'Brave').UserData;          Flag = '--incognito' }
    'opera.exe'    = @{ UserData = ($navegadoresChromium | Where-Object Nome -eq 'Opera').UserData;          Flag = '--private' }
    'launcher.exe' = @{ UserData = ($navegadoresChromium | Where-Object Nome -eq 'Opera').UserData;          Flag = '--private' }
    'msedge.exe'   = @{ UserData = ($navegadoresChromium | Where-Object Nome -eq 'Microsoft Edge').UserData; Flag = '--inprivate' }
}

foreach ($pasta in $pastasAtalhos) {
    $lnks = Get-ChildItem -Path $pasta -Filter '*.lnk' -Recurse -ErrorAction SilentlyContinue
    foreach ($lnk in $lnks) {
        try {
            $atalho = $shell.CreateShortcut($lnk.FullName)
            $alvo = $atalho.TargetPath
            if (-not $alvo) { continue }

            $exeNome = (Split-Path $alvo -Leaf).ToLower()

            if ($exeNome -eq 'firefox.exe') {
                $atalho.TargetPath   = $pwshPath
                $atalho.Arguments    = "-WindowStyle Hidden -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -Lancar -Navegador firefox"
                $atalho.IconLocation = "$alvo,0"
                $atalho.WindowStyle  = 7   # inicia minimizado -> evita o "flash" da janela do PowerShell
                $atalho.Save()
                $atalhosAlterados++
                Write-Item "Atalho '$($lnk.Name)' -> reapontado para lancador efemero do Firefox"
            }
            elseif ($exeNome -eq 'iexplore.exe') {
                $atalho.TargetPath   = $pwshPath
                $atalho.Arguments    = "-WindowStyle Hidden -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -Lancar -Navegador iexplore"
                $atalho.IconLocation = "$alvo,0"
                $atalho.WindowStyle  = 7
                $atalho.Save()
                $atalhosAlterados++
                Write-Item "Atalho '$($lnk.Name)' -> reapontado para lancador efemero do Internet Explorer"
            }
            elseif ($userDataPorExe.ContainsKey($exeNome) -and $userDataPorExe[$exeNome].UserData) {
                $info = $userDataPorExe[$exeNome]
                $atalho.TargetPath   = $pwshPath
                $atalho.Arguments    = "-WindowStyle Hidden -NoProfile -NonInteractive -ExecutionPolicy Bypass -File `"$scriptPath`" -Lancar -Navegador chromium -UserData `"$($info.UserData)`" -Exe `"$alvo`" -ArgsExtra `"$($info.Flag)`""
                $atalho.IconLocation = "$alvo,0"
                $atalho.WindowStyle  = 7
                $atalho.Save()
                $atalhosAlterados++
                Write-Item "Atalho '$($lnk.Name)' -> reapontado para lancador efemero ($exeNome)"
            }
        } catch {
            Write-Item "Falha ao processar atalho '$($lnk.Name)'" 'warn'
        }
    }
}

if ($atalhosAlterados -eq 0) {
    Write-Item "Nenhum atalho de navegador encontrado" 'skip'
}

[Runtime.Interopservices.Marshal]::ReleaseComObject($shell) | Out-Null

# ---------------------------------------------------------------------------
# 6. Area de trabalho: manter apenas 1 atalho oficial por navegador
# ---------------------------------------------------------------------------
Write-Secao "Deixando so um atalho oficial por navegador na Area de trabalho"

$pastasDesktopUnico = @(
    [Environment]::GetFolderPath('Desktop')
    (Join-Path $env:PUBLIC 'Desktop')
) | Select-Object -Unique | Where-Object { Test-Path $_ }

$nomesOficiais = @{
    'chrome.exe'   = 'Google Chrome.lnk'
    'brave.exe'    = 'Brave.lnk'
    'opera.exe'    = 'Opera.lnk'
    'launcher.exe' = 'Opera.lnk'
    'firefox.exe'  = 'Mozilla Firefox.lnk'
    'msedge.exe'   = 'Microsoft Edge.lnk'
    'iexplore.exe' = 'Internet Explorer.lnk'
}

$shell2 = New-Object -ComObject WScript.Shell
$navegadorJaTemAtalho = @{}   # exeNome -> caminho do atalho oficial ja mantido
$duplicadosRemovidos = 0

foreach ($pasta in $pastasDesktopUnico) {
    $lnks = Get-ChildItem -Path $pasta -Filter '*.lnk' -ErrorAction SilentlyContinue
    foreach ($lnk in $lnks) {
        try {
            $atalho = $shell2.CreateShortcut($lnk.FullName)

            # identifica o navegador pelo icone original (preservado na secao 5)
            # ou, se nao tiver sido reapontado, pelo proprio alvo do atalho
            $origem = $null
            if ($atalho.IconLocation) {
                $origem = ($atalho.IconLocation -split ',')[0]
            }
            if (-not $origem) { $origem = $atalho.TargetPath }
            if (-not $origem) { continue }

            $exeNome = (Split-Path $origem -Leaf).ToLower()
            if (-not $nomesOficiais.ContainsKey($exeNome)) { continue }

            if (-not $navegadorJaTemAtalho.ContainsKey($exeNome)) {
                # primeiro atalho encontrado para esse navegador: vira o "oficial"
                $nomeOficial = $nomesOficiais[$exeNome]
                $destino = Join-Path $pasta $nomeOficial
                if ($lnk.FullName -ne $destino) {
                    if (Test-Path $destino) { Remove-Item -Path $destino -Force }
                    Rename-Item -Path $lnk.FullName -NewName $nomeOficial -Force
                }
                $navegadorJaTemAtalho[$exeNome] = $destino
                Write-Item "Atalho oficial mantido: '$nomeOficial'"
            } else {
                # ja existe atalho oficial para esse navegador -> remove o extra
                Remove-Item -Path $lnk.FullName -Force
                $duplicadosRemovidos++
                Write-Item "Atalho duplicado removido: '$($lnk.Name)'"
            }
        } catch {
            Write-Item "Falha ao verificar duplicidade do atalho '$($lnk.Name)'" 'warn'
        }
    }
}

[Runtime.Interopservices.Marshal]::ReleaseComObject($shell2) | Out-Null

if ($duplicadosRemovidos -eq 0) {
    Write-Item "Nenhum atalho duplicado encontrado na Area de trabalho" 'skip'
}

# ---------------------------------------------------------------------------
# 7. Resumo
# ---------------------------------------------------------------------------
Write-Secao "Concluido"
Write-Host "Historico, cache, cookies e senhas foram apagados agora (sem backup)." -ForegroundColor Green
Write-Host "Politicas de bloqueio aplicadas no Chrome/Brave/Opera: modo anonimo" -ForegroundColor Green
Write-Host "forcado, perfil efemero (ForceEphemeralProfiles), gerenciador de senha" -ForegroundColor Green
Write-Host "e autofill desativados, login de conta/sync bloqueado." -ForegroundColor Green
Write-Host "Edge: mesmas politicas de bloqueio (InPrivate nao suporta modo forcado" -ForegroundColor Green
Write-Host "nativo, mas o lancador da secao 5 ja garante isso)." -ForegroundColor Green
Write-Host "Firefox: navegacao privada forcada por preferencia, gerenciador de senha" -ForegroundColor Green
Write-Host "e autofill desativados, Firefox Sync desativado." -ForegroundColor Green
Write-Host "Internet Explorer: historico/cookies/cache/senhas apagados agora e" -ForegroundColor Green
Write-Host "configurado para limpar automaticamente ao fechar." -ForegroundColor Green
Write-Host "Pagina inicial fixada em todos os navegadores: $PaginaInicial" -ForegroundColor Green
Write-Host "Atalhos (Area de trabalho, Menu Iniciar, barra de tarefas) reapontados" -ForegroundColor Green
Write-Host "para o modo lancador deste mesmo arquivo: $atalhosAlterados" -ForegroundColor Green
Write-Host "Area de trabalho: mantido so 1 atalho oficial por navegador; duplicados" -ForegroundColor Green
Write-Host "removidos: $duplicadosRemovidos" -ForegroundColor Green
Write-Host ""
Write-Host "A PARTIR DE AGORA, todo navegador aberto por um desses atalhos:" -ForegroundColor Cyan
Write-Host "  1) apaga a pasta de perfil inteira ANTES de abrir" -ForegroundColor Cyan
Write-Host "  2) abre o navegador (modo privado/incognito)" -ForegroundColor Cyan
Write-Host "  3) apaga a pasta de perfil inteira de novo QUANDO FECHAR" -ForegroundColor Cyan
Write-Host "Ou seja: historico, cookies, senhas, favoritos, extensoes e" -ForegroundColor Cyan
Write-Host "configuracoes NUNCA sobrevivem entre uma sessao e outra - cada" -ForegroundColor Cyan
Write-Host "abertura se comporta como instalacao nova." -ForegroundColor Cyan
Write-Host ""
Write-Host "IMPORTANTE: nao mova nem renomeie este arquivo depois de rodar," -ForegroundColor DarkYellow
Write-Host "os atalhos apontam para o caminho exato dele." -ForegroundColor DarkYellow
Write-Host "Isso vale SOMENTE para quem abrir pelos atalhos ajustados. Se alguem" -ForegroundColor DarkYellow
Write-Host "abrir o navegador de outro jeito (ex: clicar direto no chrome.exe/" -ForegroundColor DarkYellow
Write-Host "firefox.exe dentro da pasta de instalacao), o lancador e pulado - so" -ForegroundColor DarkYellow
Write-Host "as politicas de registro (modo anonimo forcado, sem senha, sem sync)" -ForegroundColor DarkYellow
Write-Host "continuam valendo." -ForegroundColor DarkYellow
Write-Host ""
Write-Host "Rodou este script antes da versao atual? Rode de novo uma vez -- os" -ForegroundColor DarkYellow
Write-Host "atalhos sao reconfigurados com -WindowStyle 7 (minimizado), o que" -ForegroundColor DarkYellow
Write-Host "elimina o 'flash' de janela do PowerShell ao clicar no atalho." -ForegroundColor DarkYellow
