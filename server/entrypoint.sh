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
  # Primero la API de GitHub (sin caché); si falla, la dirección raw (caché de hasta 5 min).
  if { [ -z "$LATEST_URL" ] && curl -fsSL -H "Accept: application/vnd.github.raw+json" -H "User-Agent: JuegoLow-servidor" \
         "https://api.github.com/repos/IDellamea/JuegoLow-releases/contents/latest.json?ref=main" -o latest.json; } \
     || curl -fsSL "$URL?t=$(date +%s)" -o latest.json; then
    J=$(tr -d '\n' < latest.json)
    campo() { printf '%s' "$J" | sed -n "s/.*\"$1\": *\"\([^\"]*\)\".*/\1/p"; }
    # El servidor usa su propia versión (server_*); si no existe, la del cliente.
    PCK_URL=$(campo server_pck_url); [ -n "$PCK_URL" ] || PCK_URL=$(campo pck_url)
    SHA=$(campo server_sha256); [ -n "$SHA" ] || SHA=$(campo sha256)
    VERSION=$(campo server_version); [ -n "$VERSION" ] || VERSION=$(campo version)
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
