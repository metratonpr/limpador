# Limpador de Navegadores

Um unico arquivo (`LimparNavegadores.ps1`) que:

1. Fecha Chrome, Firefox, Brave e Opera; apaga historico, cache, cookies e
   senhas salvas.
2. Trava os navegadores por politica (modo anonimo forcado, sem
   gerenciador de senha/autofill, sem login/sincronizacao de conta).
3. Reaponta os atalhos (Area de trabalho, Menu Iniciar, barra de tarefas)
   para chamar **este mesmo arquivo** em "modo lancador": apaga a pasta de
   perfil inteira antes de abrir o navegador e de novo quando ele fechar —
   ou seja, cada abertura pelos atalhos se comporta como uma **instalacao
   nova**.
4. Deixa so **1 atalho oficial por navegador** na Area de trabalho,
   removendo duplicados.

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
- Os atalhos de Chrome, Brave, Opera e Firefox passam a chamar
  `powershell.exe -File LimparNavegadores.ps1 -Lancar ...` em vez do
  `.exe` do navegador direto. Esse "modo lancador" (interno, nao precisa
  chamar manualmente):
  1. apaga a pasta de perfil inteira **antes** de abrir;
  2. abre o navegador em modo anonimo/privado;
  3. apaga a pasta de perfil inteira de novo **quando o navegador fechar**.
- A partir da primeira execucao, **todo uso seguinte comeca do zero** —
  sem historico, sem senha salva, sem favoritos, sem extensoes, como se
  fosse uma instalacao nova.
- Na Area de trabalho fica **apenas um atalho oficial por navegador**
  (`Google Chrome.lnk`, `Brave.lnk`, `Opera.lnk`, `Mozilla Firefox.lnk`).

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
- Rode como o usuario que normalmente usa o computador (nao precisa ser
  administrador — tudo e feito em `HKCU` e nas pastas do perfil do
  usuario atual).
