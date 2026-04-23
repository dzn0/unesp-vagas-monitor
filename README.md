# UNESP Vagas Monitor — Ciência da Computação, Pres. Prudente

Monitor diário (2× por dia) que checa a página oficial de transferências da UNESP e avisa no seu WhatsApp se aparecer um processo de **Transferência Externa**. Roda no GitHub Actions — não depende do seu PC nem de assinatura paga.

- Página monitorada: <https://sistemas.unesp.br/academico/publico/transferencia.action>
- Horários: 09:07 BRT e 20:07 BRT (todos os dias)
- Notificação: WhatsApp via [CallMeBot](https://www.callmebot.com/blog/free-api-whatsapp-messages/)

## Setup (uma vez só)

### 1. CallMeBot — pegar sua API key

1. Adicione **+34 644 51 95 23** aos contatos do seu WhatsApp como `CallMeBot`.
2. Mande para esse contato a mensagem exata: `I allow callmebot to send me messages`
3. Aguarde a resposta com sua **API key** (pode levar até alguns minutos).
4. Anote:
   - **Telefone** com código do país, sem `+` nem espaços (ex.: `5518999998888`).
   - **API key** (número de ~7 dígitos).

### 2. Subir este código para um repo no GitHub

```bash
cd D:/Claude-Code/unesp
git init
git add .
git commit -m "Monitor de vagas UNESP CC Pres. Prudente"
gh repo create unesp-vagas-monitor --public --source=. --push
```

(Ou crie o repo manualmente em <https://github.com/new> e faça `git remote add origin … && git push`.)

### 3. Configurar os secrets

No GitHub: **Settings → Secrets and variables → Actions → New repository secret**. Crie dois:

| Nome | Valor |
|------|-------|
| `CALLMEBOT_PHONE` | seu telefone (ex.: `5518999998888`) |
| `CALLMEBOT_APIKEY` | a API key que o CallMeBot te mandou |

### 4. Testar

Vá em **Actions → "Checar vagas UNESP CC Pres. Prudente" → Run workflow** (botão à direita). Em ~30s você deve receber uma mensagem no WhatsApp tipo:

> UNESP CC PP: sem Transferência Externa hoje. Checado às 22/04 21:15 BRT.

Se receber: pronto, está rodando. Daí em diante, **2 mensagens por dia**, automaticamente.

## Como funciona

- [`.github/workflows/check-vagas.yml`](.github/workflows/check-vagas.yml) — agenda cron 2× ao dia + botão manual.
- [`check.sh`](check.sh) — baixa o HTML da página, normaliza (minúsculas + sem acento), faz `grep` por `"transferencia externa"`. Monta a mensagem e dispara para o CallMeBot.

## Personalização rápida

- **Mudar horário**: edite os `cron:` no workflow. Lembre que GitHub Actions usa **UTC** (BRT + 3). Tabela: 09:07 BRT → `7 12 * * *`, 20:07 BRT → `7 23 * * *`.
- **Só notificar quando tem vaga** (sem o ping diário): no `check.sh`, troque o `else` por `exit 0` em vez de mandar mensagem.
- **Filtrar especificamente CC + Pres. Prudente**: hoje o filtro só vê se `"Transferência Externa"` aparece (zero falsos negativos). Quando o primeiro edital existir, dá para inspecionar a estrutura HTML do edital e refinar.

## Troubleshooting

- **Não recebi mensagem**: olhe o log da execução em **Actions** no GitHub. O `check.sh` imprime a resposta do CallMeBot — geralmente é "número não autorizado" (refazer o passo 1) ou "API key inválida" (conferir o secret).
- **GitHub Actions não disparou no horário**: cron do GH pode atrasar até ~10 min em horários cheios; é normal. Se atrasar mais, considere mover o off-minute (`7`) para outro valor.
- **CallMeBot fora do ar**: a API é grátis e ocasionalmente cai. O job vai falhar e o GitHub te manda e-mail automaticamente — daí é só aguardar e re-rodar.
