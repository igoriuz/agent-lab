"""Tabellengetriebene Prüfung der Zugangskontrolle.

Braucht kein Telegram und keinen zweiten Account: Die Updates sind erfunden.
Damit lassen sich genau die Fälle prüfen, die man live kaum herstellen kann.

    python3 bridge/test_allowlist.py
"""

import sys

from allowlist import check

ME = "123456789"          # erlaubt
FREMD = "999999999"       # nicht erlaubt
GRUPPE = "-1001234567890" # Gruppen-IDs sind negativ


def msg(user, chat, kind="message"):
    return {kind: {"from": {"id": user}, "chat": {"id": chat}, "text": "hallo"}}


def callback(user, chat):
    """Knopfdruck — hängt an einer Nachricht, Chat liegt eine Ebene tiefer."""
    return {"callback_query": {
        "from": {"id": user},
        "data": "approve:task-1",
        "message": {"chat": {"id": chat}},
    }}


CASES = [
    # (Name, Update, erwartet_erlaubt)
    ("eigene Nachricht",                    msg(int(ME), int(ME)),            True),
    ("eigene Nachricht, IDs als Text",      msg(ME, ME),                      True),
    ("eigener Knopfdruck",                  callback(int(ME), int(ME)),       True),
    ("bearbeitete eigene Nachricht",        msg(int(ME), int(ME), "edited_message"), True),

    ("fremder Absender",                    msg(int(FREMD), int(FREMD)),      False),
    ("fremder Knopfdruck",                  callback(int(FREMD), int(FREMD)), False),
    # Der Fall, der eine reine chat.id-Pruefung aushebeln wuerde:
    ("Fremder in erlaubtem Chat",           msg(int(FREMD), int(ME)),         False),
    # Der Fall, der eine reine from.id-Pruefung aushebeln wuerde:
    ("ich selbst, aber in einer Gruppe",    msg(int(ME), GRUPPE),             False),
    ("fremde bearbeitete Nachricht",        msg(int(FREMD), int(FREMD), "edited_message"), False),
    ("Kanalbeitrag eines Fremden",          msg(int(FREMD), int(FREMD), "channel_post"), False),

    ("Update ohne Absender",                {"poll": {"id": "1"}},            False),
    ("Nachricht ohne from",                 {"message": {"chat": {"id": int(ME)}}}, False),
    ("Nachricht ohne chat",                 {"message": {"from": {"id": int(ME)}}}, False),
]


def main() -> int:
    fails = []

    for name, update, expected in CASES:
        got, reason = check(update, ME, ME)
        ok = got == expected
        if not ok:
            fails.append((name, expected, got, reason))
        print(f"  {'ok  ' if ok else 'FEHL'}  {name:<34} → {'erlaubt' if got else 'verworfen'} ({reason})")

    # Leere Allowlist muss alles sperren. Wäre der Default umgekehrt, würde
    # eine beim Deploy vergessene .env den Bot lautlos öffnen.
    print()
    for label, u, c in [("beide leer", "", ""), ("nur user", ME, ""), ("nur chat", "", ME)]:
        got, reason = check(msg(int(ME), int(ME)), u, c)
        ok = got is False
        if not ok:
            fails.append((f"leere Allowlist ({label})", False, got, reason))
        print(f"  {'ok  ' if ok else 'FEHL'}  leere Allowlist, {label:<12} → {'erlaubt' if got else 'verworfen'} ({reason})")

    print()
    if fails:
        print(f"{len(fails)} Fall/Fälle fehlgeschlagen:")
        for name, exp, got, reason in fails:
            print(f"  {name}: erwartet {exp}, bekommen {got} ({reason})")
        return 1
    print(f"Alle {len(CASES) + 3} Fälle bestanden.")
    return 0


if __name__ == "__main__":
    sys.exit(main())
