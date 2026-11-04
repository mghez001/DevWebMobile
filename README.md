## Test de sip_ua

Cette branche permet de mettre en place par exemple deux instances flutter en se basant sur l'image github suivante:

`https://github.com/flutter-webrtc/dockers`

Après avoir lancé l'image récupéré, naviguer dans `/dockers/asterisk`. Ensuite, effectuer la commande `make`.pour lancer l'image du serveur asterisk.

On peut ensuite lancer deux instances flutter sur deux numéro SIP différents, 400 et 500 par exemple:
`
flutter run -d linux --dart-define=EXT=400 --dart-define=TARGET=500 --dart-define=PASSWORD=400
flutter run -d linux --dart-define=EXT=500 --dart-define=TARGET=400 --dart-define=PASSWORD=500
`
On voit alors les requêtes pour les deux instances flutter sur le serveur.
