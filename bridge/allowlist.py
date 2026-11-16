"""Zugangsprüfung für eingehende Telegram-Updates.

Bewusst eine reine Funktion ohne Netzwerk: So lässt sie sich mit erfundenen
Updates vollständig durchtesten — auch in Fällen, die man live kaum
herstellen kann (Gruppennachricht, Knopfdruck eines Fremden).

Siehe README.md in diesem Verzeichnis für die Begründung der Regeln.
"""

from __future__ import annotations

# Update-Arten, die einen Absender tragen und deshalb geprüft werden müssen.
# `callback_query` ist der wichtigste: Freigabe-Knöpfe kommen als Callback,
# nicht als Nachricht. Wer nur `message` absichert, lässt die Freigaben offen.
BEARING_SENDER = (
    "message",
    "edited_message",
    "channel_post",
    "edited_channel_post",
    "callback_query",
)


def _ids(raw: str | None) -> frozenset[str]:
    """Kommagetrennte Liste aus .env in eine Menge von Strings.

    Alles wird als String verglichen. Telegram liefert IDs als Zahlen,
    .env liefert Text — ein Vergleich über Typgrenzen hinweg schlägt sonst
    still fehl, und zwar in die unsichere Richtung, wenn jemand die Seiten
    vertauscht.
    """
    if not raw:
        return frozenset()
    return frozenset(p.strip() for p in raw.split(",") if p.strip())


def check(update: dict, allowed_user_ids: str, allowed_chat_ids: str) -> tuple[bool, str]:
    """Prüft ein Telegram-Update.

    Rückgabe: (erlaubt, Begründung). Die Begründung ist fürs Protokoll,
    nicht für eine Antwort an den Absender — abgewiesen wird schweigend.
    """
    users = _ids(allowed_user_ids)
    chats = _ids(allowed_chat_ids)

    # Leere Allowlist sperrt alles. Der umgekehrte Default — leer heisst
    # offen — wäre der klassische Weg, sich versehentlich zu öffnen, etwa
    # wenn .env beim Deploy nicht mitkommt.
    if not users or not chats:
        return False, "allowlist_leer"

    payload = None
    kind = None
    for key in BEARING_SENDER:
        if isinstance(update.get(key), dict):
            payload, kind = update[key], key
            break

    if payload is None:
        return False, "kein_pruefbarer_absender"

    sender = payload.get("from") or {}
    user_id = sender.get("id")
    if user_id is None:
        return False, f"{kind}_ohne_absender"

    # Beim Callback steckt der Chat eine Ebene tiefer, in der Nachricht,
    # an der der Knopf hängt.
    if kind == "callback_query":
        chat = ((payload.get("message") or {}).get("chat")) or {}
    else:
        chat = payload.get("chat") or {}
    chat_id = chat.get("id")
    if chat_id is None:
        return False, f"{kind}_ohne_chat"

    if str(user_id) not in users:
        return False, f"absender_nicht_erlaubt:{user_id}"

    # Auch bei erlaubtem Absender: Im Gruppenchat wäre der Chat ein anderer,
    # und dort lesen Fremde mit.
    if str(chat_id) not in chats:
        return False, f"chat_nicht_erlaubt:{chat_id}"

    return True, kind
