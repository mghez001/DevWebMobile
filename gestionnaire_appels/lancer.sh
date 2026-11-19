#!/usr/bin/env bash
# Lance le serveur Asterisk (en arrière-plan) puis l'appli Flutter.
#
#   ./lancer.sh            -> appli sur http://localhost:8080
#   ./lancer.sh chrome     -> appli dans Chrome (rechargement auto, un seul onglet)
#
# La console Asterisk s'ouvre dans une nouvelle fenêtre. Pour la rouvrir :
#   docker exec -it asterisk asterisk -r     (« core reload », puis « exit »)
#
# Ctrl+C arrête l'appli ET le serveur Asterisk.
set -euo pipefail

DOSSIER="$(cd "$(dirname "$0")" && pwd)"
IMAGE=asterisk16
CONTENEUR=asterisk

# ---------------------------------------------------------------------------
# 1. Serveur Asterisk
# ---------------------------------------------------------------------------
cd "$DOSSIER/serveur_asterisk"

if ! docker image inspect "$IMAGE" >/dev/null 2>&1; then
  echo "==> Première fois : construction de l'image $IMAGE…"
  make build
fi

# Un Asterisk déjà lancé (par ce script ou par « make run ») ?
DEJA_LANCE=$(docker ps -q --filter "ancestor=$IMAGE")
if [ -n "$DEJA_LANCE" ]; then
  echo "==> Asterisk tourne déjà, on le réutilise."
  CIBLE=$(echo "$DEJA_LANCE" | head -n1)
  ARRETER_ASTERISK=0
else
  echo "==> Lancement d'Asterisk…"
  docker rm -f "$CONTENEUR" >/dev/null 2>&1 || true
  docker run --rm -dit --name "$CONTENEUR" \
    -p 8088:8088/tcp \
    -p 8089:8089/tcp \
    -p 5060:5060/udp \
    -p 5060:5060/tcp \
    -p 30000-30100:30000-30100/udp \
    -v "$PWD/configuration:/etc/asterisk" \
    "$IMAGE" >/dev/null
  CIBLE=$CONTENEUR
  ARRETER_ASTERISK=1
fi

arreter() {
  if [ "$ARRETER_ASTERISK" = 1 ]; then
    echo
    echo "==> Arrêt d'Asterisk…"
    docker stop "$CONTENEUR" >/dev/null 2>&1 || true
  fi
}
trap arreter EXIT

# Attendre que le WebSocket SIP (port 8088) réponde.
echo -n "==> Attente d'Asterisk sur le port 8088"
for _ in $(seq 1 30); do
  if (exec 3<>/dev/tcp/127.0.0.1/8088) 2>/dev/null; then
    echo " : prêt."
    break
  fi
  echo -n "."
  sleep 1
done

# Ouvrir la console Asterisk dans une nouvelle fenêtre de terminal.
# Fermer cette fenêtre (ou taper « exit ») n'arrête PAS Asterisk.
CONSOLE="docker exec -it $CIBLE asterisk -rvvvvv; echo; read -rp 'Console fermée. Entrée pour quitter…'"
ouvrir_console() {
  local titre="Asterisk"
  local t
  for t in "${TERMINAL:-}" kitty alacritty foot wezterm ghostty konsole \
           gnome-terminal xfce4-terminal xterm; do
    [ -n "$t" ] && command -v "$t" >/dev/null 2>&1 || continue
    case "$(basename "$t")" in
      kitty)          kitty --title "$titre" bash -c "$CONSOLE" ;;
      alacritty)      alacritty --title "$titre" -e bash -c "$CONSOLE" ;;
      foot)           foot --title "$titre" bash -c "$CONSOLE" ;;
      wezterm)        wezterm start -- bash -c "$CONSOLE" ;;
      ghostty)        ghostty -e bash -c "$CONSOLE" ;;
      konsole)        konsole -e bash -c "$CONSOLE" ;;
      gnome-terminal) gnome-terminal --title "$titre" -- bash -c "$CONSOLE" ;;
      xfce4-terminal) xfce4-terminal --title "$titre" -x bash -c "$CONSOLE" ;;
      xterm)          xterm -T "$titre" -e bash -c "$CONSOLE" ;;
      *)              "$t" -e bash -c "$CONSOLE" ;;
    esac >/dev/null 2>&1 &
    disown
    return 0
  done
  if [ "$(uname)" = Darwin ]; then
    osascript -e "tell application \"Terminal\" to do script \"$CONSOLE\"" >/dev/null
    return 0
  fi
  return 1
}

if ouvrir_console; then
  echo "==> Console Asterisk ouverte dans une nouvelle fenêtre."
else
  echo "==> Pas de terminal graphique trouvé. Console Asterisk :"
  echo "    docker exec -it $CIBLE asterisk -r"
fi

# ---------------------------------------------------------------------------
# 2. Appli Flutter
# ---------------------------------------------------------------------------
cd "$DOSSIER"
flutter pub get

if [ "${1:-}" = "chrome" ]; then
  flutter run -d chrome
else
  echo
  echo "==> Ouvrez deux onglets sur http://localhost:8080 (un par téléphone)."
  echo
  flutter run -d web-server --web-port 8080
fi
