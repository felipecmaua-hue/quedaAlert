# Queda Alert — tutorial (Windows + iPhone, tudo gratuito)

O app recebe "QUEDA" do micro:bit por BLE e dispara uma notificação local. Não precisa mexer no código do micro:bit.

## Estrutura
```
QuedaAlert/
├─ project.yml                  (gera o projeto Xcode automaticamente)
├─ .github/workflows/build.yml  (compila na nuvem do GitHub, num Mac grátis)
├─ README.md
└─ QuedaAlert/
   ├─ QuedaAlertApp.swift       (início do app)
   ├─ BLEManager.swift          (Core Bluetooth: busca, conexão, assinatura, reconexão)
   ├─ NotificationManager.swift (UNUserNotificationCenter)
   └─ ContentView.swift         (tela)
```

## Por que assim?
Compilar app iOS exige Xcode, que só roda em Mac. Sem Mac, o caminho gratuito é:
**GitHub Actions** (Mac virtual grátis) compila → você baixa o .ipa → **Sideloadly** (Windows) assina com seu Apple ID gratuito e instala no iPhone.

## Passo a passo
1. **Conta no GitHub** (github.com, grátis). Crie um repositório **público** (minutos de Mac são ilimitados em repositório público; em privado há uma cota mensal pequena).
2. **Envie os arquivos**: no repositório, "Add file → Upload files" e arraste o conteúdo desta pasta (inclua a pasta oculta `.github`; se o Windows não deixar arrastar, crie o arquivo `.github/workflows/build.yml` pelo botão "Create new file" digitando o caminho e colando o conteúdo).
3. **Compilar**: aba **Actions** → "Build IPA" → **Run workflow**. Espere ~5 min. Se aparecer erro vermelho, abra o log e me mande a mensagem.
4. **Baixar**: abra a execução concluída → **Artifacts** → `QuedaAlert-ipa` (vem em .zip; extraia para obter `QuedaAlert.ipa`).
5. **Instalar o Sideloadly** (sideloadly.io). Ele exige **iTunes e iCloud para Windows baixados do site da Apple** (não da Microsoft Store).
6. Conecte o iPhone por cabo, toque em "Confiar". No Sideloadly: arraste o .ipa, digite seu Apple ID e clique **Start**.
7. No iPhone: **Ajustes → Geral → VPN e Gerenciamento de Dispositivo** → confie no seu Apple ID. Depois, **Ajustes → Privacidade e Segurança → Modo Desenvolvedor** → ligar (reinicia o iPhone).
8. Abra o Queda Alert e **permita Bluetooth e Notificações**.

Limites da conta gratuita: o app expira em **7 dias** (reinstale pelo Sideloadly; os dados ficam), máx. 3 apps por Apple ID. Alternativa equivalente: AltStore (altstore.io), que renova sozinho via computador na mesma rede Wi-Fi.

## Primeiro teste (notificação)
1. Toque em **Enviar notificação de teste** → deve aparecer o banner. Bloqueie a tela e repita para ver na tela de bloqueio.
2. Se não aparecer: Ajustes → Notificações → Queda Alert.

## Conectar ao micro:bit
1. **Feche o BLE Pad** e desconecte o micro:bit de qualquer outro aparelho (ele aceita uma conexão por vez).
2. **Buscar dispositivos** → toque em "BBC micro:bit [xxxxx]".
3. Aparece a lista de características que enviam dados (notify/indicate). Toque em uma e veja o campo **Última mensagem**. Faça o micro:bit enviar QUEDA: a característica correta mostrará o texto.
   - Se o micro:bit usa o serviço UART do MakeCode, o serviço costuma ser `6E400001-B5A3-F393-E0A9-E50E24DCCA9E`; no micro:bit, a característica que ENVIA ao celular costuma ser a `6E400002-…` (notify). Mas o app não presume isso: você escolhe e ele memoriza a escolha.
   - Se o iOS pedir para **parear**, aceite. Se a lista vier vazia, apague o pareamento antigo em Ajustes → Bluetooth ("Esquecer este dispositivo") e tente de novo.
4. Qualquer mensagem que **contenha "QUEDA"** (maiúsculas ou minúsculas, com ou sem quebra de linha) gera a notificação.

## Segundo plano (leia com honestidade)
- O app declara `bluetooth-central`, usa restauração de estado e pede reconexão pendente (o iOS reconecta quando o micro:bit voltar ao alcance). Isso **não está testado por mim** — teste: conecte, bloqueie a tela, espere alguns minutos, faça o micro:bit enviar QUEDA.
- **Não há garantia** com a tela bloqueada: o iOS pode suspender o app para economizar bateria.
- Se você **fechar o app deslizando para cima**, o iOS não o reabre sozinho. Deixe-o aberto/em segundo plano.
- Não há notificação "crítica" (exige conta paga): o iPhone em modo Foco/Não Perturbe pode silenciar o aviso.
- Antes de usar como segurança real, faça testes longos. Este app é um protótipo.

## Se algo falhar
- **Nada aparece na busca**: confirme que o micro:bit está ligado, com Bluetooth ativo no programa, e que o app tem permissão de Bluetooth.
- **Conecta mas não chega texto**: tente as outras características da lista.
- **Notificação só no teste**: o texto recebido pode não conter "QUEDA"; veja o Histórico.
