# Limpador de Navegadores

Um unico arquivo (`LimparNavegadores.ps1`) que:

1. Fecha Chrome, Firefox, Brave, Opera, Edge e Internet Explorer; apaga
   historico, cache, cookies e senhas salvas.
2. Trava os navegadores por politica (modo anonimo/InPrivate forcado onde
   suportado, sem gerenciador de senha/autofill, sem login/sincronizacao
   de conta).
3. Reaponta os atalhos (Area de trabalho, Menu Iniciar, barra de tarefas)
   para chamar **este mesmo arquivo** em "modo lancador": apaga a pasta de
   perfil inteira antes de abrir o navegador e de novo quando ele fechar —
   ou seja, cada abertura pelos atalhos se comporta como uma **instalacao
   nova**.
4. Deixa so **1 atalho oficial por navegador** na Area de trabalho,
   removendo duplicados.
5. Fixa a **pagina inicial** de todos os navegadores em
   `https://www.pr.senac.br/principal/` (site oficial da empresa, sem
   parametros de campanha/anuncio).

## Como executar

1. Mantenha `LimparNavegadores.ps1` na pasta onde ele deve ficar
   permanentemente — os atalhos vao apontar para o caminho exato desse
   arquivo, entao **nao mova nem renomeie** depois de rodar.
2. Abra o **PowerShell** nessa pasta:
   - No Explorador de Arquivos, entre na pasta, clique com o botao direito
     em um espaco vazio segurando **Shift** e escolha **"Abrir janela do
     PowerShell aqui"** (ou **"Abrir no Terminal"**, dependendo da versao
     do Windows).
3. Rode:

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1
   ```

   Ele vai pedir para digitar `CONFIRMAR` antes de fazer qualquer coisa.

   Para rodar sem essa confirmacao (ex: uso automatizado):

   ```powershell
   powershell -ExecutionPolicy Bypass -File .\LimparNavegadores.ps1 -Silencioso
   ```

> Se aparecer um aviso de "politica de execucao", e por isso que o comando
> acima usa `-ExecutionPolicy Bypass` — ele libera so para essa execucao,
> sem alterar nenhuma configuracao permanente do Windows.

## O que acontece depois de rodar

- Historico, cache, cookies e senhas salvas de todos os navegadores
  encontrados sao apagados **na hora** (sem backup, e permanente).
- Os atalhos de Chrome, Brave, Opera, Edge e Firefox passam a chamar
  `powershell.exe -File LimparNavegadores.ps1 -Lancar ...` em vez do
  `.exe` do navegador direto (janela minimizada, sem "flash" de console).
  Esse "modo lancador" (interno, nao precisa chamar manualmente):
  1. apaga a pasta de perfil inteira **antes** de abrir;
  2. abre o navegador em modo anonimo/privado/InPrivate;
  3. apaga a pasta de perfil inteira de novo **quando o navegador fechar**.
- O atalho do **Internet Explorer** usa o mesmo esquema, mas como o IE nao
  guarda os dados numa pasta de perfil (usa WinINet + Credential Manager
  do Windows), a limpeza e feita via `RunDll32 InetCpl.cpl` antes e depois
  de abrir, em vez de apagar uma pasta.
- A partir da primeira execucao, **todo uso seguinte comeca do zero** —
  sem historico, sem senha salva, sem favoritos, sem extensoes, como se
  fosse uma instalacao nova.
- Na Area de trabalho fica **apenas um atalho oficial por navegador**
  (`Google Chrome.lnk`, `Brave.lnk`, `Opera.lnk`, `Mozilla Firefox.lnk`,
  `Microsoft Edge.lnk`, `Internet Explorer.lnk`).
- Todo navegador abre com `https://www.pr.senac.br/principal/` como pagina
  inicial. No Chrome/Brave/Opera/Edge isso e por politica de registro (nao
  depende do perfil, sobrevive a limpeza). No Firefox, como a pasta inteira
  e apagada a cada uso, o **lancador recria um perfil ja com a homepage e
  as travas de privacidade configuradas** antes de abrir o navegador.

## Limitacoes

- **Nao mova nem renomeie** `LimparNavegadores.ps1` depois de rodar — os
  atalhos gravam o caminho exato do arquivo.
- So funciona para quem abrir o navegador pelos atalhos ajustados. Abrir o
  `.exe` direto de dentro da pasta de instalacao pula o modo lancador (mas
  as politicas de registro/preferencia — modo anonimo forcado, sem
  gerenciador de senha, sem sync — continuam valendo mesmo assim).
- Gerenciadores de senha de terceiros (Bitwarden, 1Password etc.) nao sao
  afetados, so o armazenamento nativo do navegador.
- O Opera nao documenta oficialmente suporte total as politicas de
  Chromium; a maior parte deve funcionar, mas sem garantia em toda versao.
- O Edge nao tem uma politica de "forcar" InPrivate como o Chrome (so
  permitir/desativar); o modo privado fica garantido pelo lancador dos
  atalhos, nao pela politica de registro.
- Menu Iniciar e itens fixados na barra de tarefas ("Acesso Rapido"/Quick
  Launch) sao ajustados so para o usuario que roda o script. Para cobrir
  outras contas do Windows na mesma maquina seria preciso rodar como
  Administrador e adaptar o script para percorrer `C:\Users\*`.
- Rode como o usuario que normalmente usa o computador (nao precisa ser
  administrador — tudo e feito em `HKCU` e nas pastas do perfil do
  usuario atual).
