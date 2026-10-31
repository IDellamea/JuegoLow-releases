#!/bin/sh
# Instala el servidor de JuegoLow en una VM Linux (Oracle Cloud u otra), sin Docker.
# Se usa como "cloud-init" al crear la VM, o a mano: curl -fsSL <raw>/server/instalar_vm.sh | sudo sh
# - Abre el puerto 7777/udp en el firewall de la VM (las imágenes de Oracle bloquean todo menos SSH).
# - Baja Godot (x86_64 o arm64 según la máquina).
# - Crea el servicio "juegolow" que corre server/entrypoint.sh: baja la última versión,
#   arranca el servidor y se actualiza solo cuando no queda nadie jugando.
set -e
RAW="https://raw.githubusercontent.com/IDellamea/JuegoLow-releases/main"
GODOT_VERSION="4.7.2"
PORT="${PORT:-7777}"

echo "[instalar] Paquetes"
export DEBIAN_FRONTEND=noninteractive
if command -v apt-get >/dev/null; then
  apt-get update -q
  apt-get install -y -q curl unzip ca-certificates
else
  dnf install -y curl unzip ca-certificates || yum install -y curl unzip ca-certificates
fi

echo "[instalar] Firewall: abrir $PORT/udp"
if command -v iptables >/dev/null; then
  iptables -C INPUT -p udp --dport "$PORT" -j ACCEPT 2>/dev/null || iptables -I INPUT 1 -p udp --dport "$PORT" -j ACCEPT
  if command -v netfilter-persistent >/dev/null; then netfilter-persistent save || true; fi
  if [ -d /etc/iptables ]; then iptables-save > /etc/iptables/rules.v4 || true; fi
fi
if command -v firewall-cmd >/dev/null; then
  firewall-cmd --permanent --add-port="$PORT"/udp && firewall-cmd --reload || true
fi

echo "[instalar] Godot $GODOT_VERSION"
case "$(uname -m)" in
  aarch64|arm64) ARCH=arm64 ;;
  *) ARCH=x86_64 ;;
esac
NAME="Godot_v${GODOT_VERSION}-stable_linux.${ARCH}"
curl -fsSL -o /tmp/godot.zip "https://github.com/godotengine/godot/releases/download/${GODOT_VERSION}-stable/${NAME}.zip"
unzip -o -q /tmp/godot.zip -d /tmp
install -m 755 "/tmp/${NAME}" /usr/local/bin/godot
rm -f /tmp/godot.zip "/tmp/${NAME}"

echo "[instalar] Usuario y servicio"
id juego >/dev/null 2>&1 || useradd --create-home --shell /usr/sbin/nologin juego
mkdir -p /opt/juegolow
curl -fsSL -o /opt/juegolow/entrypoint.sh "$RAW/server/entrypoint.sh"
cat > /etc/systemd/system/juegolow.service <<EOF
[Unit]
Description=Servidor JuegoLow
After=network-online.target
Wants=network-online.target

[Service]
User=juego
Environment=HOME=/home/juego
Environment=PORT=$PORT
# Antes de cada arranque, traer la última versión del script de arranque.
ExecStartPre=+/bin/sh -c 'curl -fsSL -o /opt/juegolow/entrypoint.sh.new $RAW/server/entrypoint.sh && mv /opt/juegolow/entrypoint.sh.new /opt/juegolow/entrypoint.sh || true'
ExecStart=/bin/sh /opt/juegolow/entrypoint.sh
Restart=always
RestartSec=5

[Install]
WantedBy=multi-user.target
EOF
systemctl daemon-reload
systemctl enable --now juegolow
echo "[instalar] Listo: servidor JuegoLow en el puerto $PORT/udp"
