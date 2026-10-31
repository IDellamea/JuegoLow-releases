#!/bin/sh
# Baja la última versión del juego (latest.json + .pck), verifica el sha256 y arranca el servidor.
set -e
URL="${LATEST_URL:-https://raw.githubusercontent.com/IDellamea/JuegoLow-releases/main/latest.json}"
PORT="${PORT:-7777}"
cd "$HOME"

# El servidor se cierra con el código 42 cuando hay una versión nueva publicada y
# no queda nadie jugando: en ese caso se baja la nueva y se vuelve a arrancar.
set +e
while true; do
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
  godot --headless --main-pack "$HOME/JuegoLow.pck" -- --server --port="$PORT" --auto-update &
  PID=$!
  # Si Coolify/Docker para el contenedor, avisarle al servidor para que cierre bien.
  trap 'kill -TERM $PID 2>/dev/null; wait $PID; exit 0' TERM INT
  wait $PID
  CODE=$?
  trap - TERM INT
  if [ "$CODE" -ne 42 ]; then
    exit "$CODE"
  fi
  echo "[JuegoLow] Hay versión nueva: actualizando..."
done
