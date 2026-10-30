#!/bin/sh
# Baja la última versión del juego (latest.json + .pck), verifica el sha256 y arranca el servidor.
set -e
URL="${LATEST_URL:-https://raw.githubusercontent.com/IDellamea/JuegoLow-releases/main/latest.json}"
PORT="${PORT:-7777}"
cd "$HOME"

echo "[JuegoLow] Buscando la última versión en $URL"
if curl -fsSL "$URL?t=$(date +%s)" -o latest.json; then
  PCK_URL=$(tr -d '\n' < latest.json | sed -n 's/.*"pck_url": *"\([^"]*\)".*/\1/p')
  SHA=$(tr -d '\n' < latest.json | sed -n 's/.*"sha256": *"\([^"]*\)".*/\1/p')
  VERSION=$(tr -d '\n' < latest.json | sed -n 's/.*"version": *"\([^"]*\)".*/\1/p')
  echo "[JuegoLow] Versión $VERSION"
  if curl -fsSL "$PCK_URL" -o JuegoLow.pck.tmp && echo "$SHA  JuegoLow.pck.tmp" | sha256sum -c - > /dev/null; then
    mv JuegoLow.pck.tmp JuegoLow.pck
  else
    echo "[JuegoLow] La descarga falló o vino dañada; uso la versión anterior si existe."
    rm -f JuegoLow.pck.tmp
  fi
else
  echo "[JuegoLow] No se pudo leer latest.json; uso la versión anterior si existe."
fi

if [ ! -f JuegoLow.pck ]; then
  echo "[JuegoLow] No hay ninguna versión del juego descargada. Abortando."
  exit 1
fi

echo "[JuegoLow] Iniciando servidor en el puerto $PORT/udp"
exec godot --headless --main-pack "$HOME/JuegoLow.pck" -- --server --port="$PORT"
