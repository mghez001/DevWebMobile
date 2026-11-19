# Routage des messages SIP (MESSAGE) entre extensions

## Modifications

### `configuration/pjsip.conf`
Ajout de `message_context=messages` dans les endpoints 400 et 500
(et 300 pour écrire à Linphone) :

```ini
[400]
type=endpoint
; ... ne change pas
message_context=messages
```

### `configuration/extensions.conf`
Nouveau contexte qui retransmet le message au destinataire :

```ini
[messages]
exten => _[345]XX,1,NoOp(Message de ${MESSAGE(from)} vers ${EXTEN} : ${MESSAGE(body)})
 same => n,MessageSend(pjsip:${EXTEN},${MESSAGE(from)})
 same => n,NoOp(Statut d'envoi : ${MESSAGE_SEND_STATUS})
 same => n,Hangup()
```

### `modules.conf`
Chargement permanent du module PJSIP de messagerie :

```ini
[modules]
load => res_pjsip_messaging.so
```

## Contexte

Pour « rejeter avec un message », l'appli envoie un `MESSAGE` SIP au serveur.
Sans ces réglages, Asterisk répondait `501 Not Implemented` (module non
chargé, aucune route pour les messages).

## Impact

- Redémarrer le conteneur pour prendre en compte `modules.conf`
- Extensions de test : 400/400 et 500/500.

## Vérifier

Dans le CLI Asterisk :

```
module reload res_pjsip.so
dialplan reload
pjsip show endpoint 400      → message_context : messages
dialplan show messages       → l'extension _[345]XX est listée
```

Pour suivre un message : `pjsip set logger on`, puis chercher `MessageSend`
et `SUCCESS` dans la trace.

## Reste à faire

Réception du message et affichage côté appli.
