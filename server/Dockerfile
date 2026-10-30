# Servidor dedicado de JuegoLow (para Coolify / Docker).
# Al arrancar baja la última versión del juego desde este mismo repo,
# así que para actualizar el servidor alcanza con reiniciar el contenedor.
FROM debian:bookworm-slim

ARG GODOT_VERSION=4.7.2
RUN apt-get update \
 && apt-get install -y --no-install-recommends ca-certificates curl unzip \
 && rm -rf /var/lib/apt/lists/* \
 && curl -fsSL -o /tmp/godot.zip \
    "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/Godot_v${GODOT_VERSION}-stable_linux.x86_64.zip" \
 && unzip -q /tmp/godot.zip -d /tmp \
 && install -m 755 /tmp/Godot_v${GODOT_VERSION}-stable_linux.x86_64 /usr/local/bin/godot \
 && rm -f /tmp/godot.zip /tmp/Godot_v*

RUN useradd --create-home juego
COPY entrypoint.sh /entrypoint.sh
USER juego
WORKDIR /home/juego
ENV PORT=7777
EXPOSE 7777/udp
ENTRYPOINT ["/bin/sh", "/entrypoint.sh"]
