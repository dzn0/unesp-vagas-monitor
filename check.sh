#!/usr/bin/env bash
set -euo pipefail

URL="https://sistemas.unesp.br/academico/publico/transferencia.action"

if [[ -z "${CALLMEBOT_PHONE:-}" || -z "${CALLMEBOT_APIKEY:-}" ]]; then
  echo "ERRO: secrets CALLMEBOT_PHONE e CALLMEBOT_APIKEY não estão definidos." >&2
  exit 1
fi

# Lista de destinatários: primeiro é obrigatório; o _2 é opcional.
RECIPIENTS=("${CALLMEBOT_PHONE}:${CALLMEBOT_APIKEY}")
if [[ -n "${CALLMEBOT_PHONE_2:-}" && -n "${CALLMEBOT_APIKEY_2:-}" ]]; then
  RECIPIENTS+=("${CALLMEBOT_PHONE_2}:${CALLMEBOT_APIKEY_2}")
fi

HTML=$(curl -sSL --max-time 30 \
  -H "User-Agent: Mozilla/5.0 (compatible; unesp-vagas-monitor/1.0)" \
  "$URL")

if [[ -z "$HTML" ]]; then
  echo "ERRO: resposta vazia da UNESP." >&2
  exit 1
fi

# Normaliza: minúsculas, remove acentos via iconv para casar variantes.
NORMALIZED=$(printf '%s' "$HTML" | iconv -f utf-8 -t ascii//TRANSLIT 2>/dev/null | tr '[:upper:]' '[:lower:]')

NOW_BRT=$(TZ=America/Sao_Paulo date '+%d/%m %H:%M')

if grep -q "transferencia externa" <<< "$NORMALIZED"; then
  MSG="🎯 VAGA UNESP! Apareceu Transferência Externa na página. Verifique se inclui Ciência da Computação em Pres. Prudente: ${URL} (checado às ${NOW_BRT} BRT)"
else
  MSG="UNESP CC PP: sem Transferência Externa hoje. Checado às ${NOW_BRT} BRT."
fi

echo "Mensagem: $MSG"

# URL-encode usando jq (vem pré-instalado no ubuntu-latest do GitHub Actions).
ENCODED=$(jq -rn --arg s "$MSG" '$s|@uri')

FAILED=0
for entry in "${RECIPIENTS[@]}"; do
  PHONE="${entry%%:*}"
  APIKEY="${entry#*:}"
  OUT="/tmp/callmebot.${PHONE}.out"

  ENDPOINT="https://api.callmebot.com/whatsapp.php?phone=${PHONE}&text=${ENCODED}&apikey=${APIKEY}"

  HTTP_CODE=$(curl -sS -o "$OUT" -w '%{http_code}' --max-time 30 "$ENDPOINT")

  echo "---"
  echo "Destinatário $PHONE — CallMeBot HTTP $HTTP_CODE:"
  cat "$OUT"
  echo

  # CallMeBot retorna 200 ou 203 no caminho feliz; tratamos qualquer 2xx
  # como sucesso de transporte e validamos o resultado pelo corpo abaixo.
  if [[ ! "$HTTP_CODE" =~ ^2[0-9][0-9]$ ]]; then
    echo "ERRO: CallMeBot retornou status $HTTP_CODE para $PHONE." >&2
    FAILED=1
    continue
  fi

  # CallMeBot retorna HTML com "Message queued" no sucesso. Falhas comuns
  # (API key errada, número não autorizado) também voltam HTTP 200, então
  # checamos o conteúdo da resposta.
  if grep -qiE "(error|invalid|not registered|api key)" "$OUT"; then
    echo "ERRO: CallMeBot relatou problema na resposta para $PHONE." >&2
    FAILED=1
    continue
  fi

  echo "OK — mensagem entregue para $PHONE."
done

if [[ "$FAILED" -ne 0 ]]; then
  exit 1
fi
