# Ascensore — Multiplayer Card Game (Flutter Client)

Real-time multiplayer client for **Ascensore**, a traditional Italian trick-taking card game, built with **Flutter** and talking to a **Java / Spring Boot** game server over **WebSockets**.

<p align="center">
  <a href="https://andreasacconi7.github.io/Ascensore_Card_Game/">
    <img src="https://img.shields.io/badge/%E2%96%B6%20Play%20now-in%20the%20browser-F5C451?style=for-the-badge&labelColor=1B2257" alt="Play now in the browser">
  </a>
</p>

<p align="center">
  <b><a href="https://andreasacconi7.github.io/Ascensore_Card_Game/">andreasacconi7.github.io/Ascensore_Card_Game</a></b><br>
  No sign-up: pick a nickname and play online with 2–4 players, or play offline against the computer.<br>
  Works on desktop and mobile browsers; the interface is in Italian.
</p>

<p align="center">
  <img src="docs/screenshots/menu.jpg" width="200" alt="Main menu">
  <img src="docs/screenshots/bet.jpg" width="200" alt="Betting">
  <img src="docs/screenshots/play.jpg" width="200" alt="Four-player trick">
  <img src="docs/screenshots/trick.jpg" width="200" alt="Trick won">
</p>

## The game

Played with a 40-card Italian deck by 2–4 players. The hand size goes **up from 1 to 10 cards and back down to 1** — like an elevator (*ascensore*), 19 sets in total.
At the start of every set each player **bets exactly how many tricks they will take**; the last player to bet cannot make the bets add up to the number of tricks, so someone always misses. The trump suit (*briscola*) changes every set.

## Features

- **Real-time multiplayer** over a persistent WebSocket connection; runs on Android, iOS and the web
- **No sign-up** — like most mobile games, the first online match creates an anonymous Supabase profile tied to the device and the player only picks a nickname; the access token is sent to the game server, which verifies it independently. Email accounts (for saving a profile across devices) are implemented but switched off for now (`lib/config.dart`)
- **2, 3 or 4 players** — pick the match size in the menu; a waiting room shows who has joined and the free seats, and you can leave the queue
- **Offline against bots** — 1 to 3 computer opponents, no connection or account needed: a local engine with the same rules speaks the server's protocol, so the whole client (state, queue, screens) runs unchanged
- **Turn timer** — a ring around the player on turn empties as their time runs out (red in the last 10 s); when it expires the server plays for them
- **One device per account** — opening the game elsewhere disconnects this device, which then offers to play here again
- **Leave at any time** — after a confirmation; the others play on without you (with two players, the other one wins)
- **Public nicknames** — unique, chosen on the first online match; nothing else about the player is shown to others
- **Automatic login** — the profile is restored and refreshed when the game opens
- **Reconnection** — a dropped connection is retried with backoff while a banner shows the state; the server keeps the seat for 60 seconds and replays the table (hand, briscola, bets, tricks, cards on the table, whose turn it is)
- **Server-authoritative state** — the client never changes game state optimistically; it validates moves locally for instant feedback (must follow suit, last-bidder constraint) and applies only what the server confirms
- **Elevator floor indicator** — the current hand size with its direction of travel and the set number (e.g. *5 ▲, 5/19*)
- Tap-to-lift or drag-and-drop cards; cards you may not play (you must follow the lead seed) are dimmed
- Betting happens on the table itself, with your hand in view below; the one bet the last player may not make is crossed out
- The trick winner's card glows before the table is cleared; points won or lost pop up at the end of each set
- Rules sheet in-app; responsive layout for phones, tablets and desktop browsers

## Roadmap

- **Special abilities** *(planned)* — power-up cards that let players make special moves during a game:
  - **Swap** *(Uno-style reverse card)* — exchange your hand with another player's
  - **Joker** — play a card with a value of your choice

## Architecture

```mermaid
flowchart LR
    UI["Flutter UI<br/>(pages + widgets)"] -- "screen" --> APP["AppController"]
    UI -- "Provider / Selector" --> SE["SessionController<br/>account · nickname · connection"]
    UI -- "Provider / Selector" --> MA["MatchController<br/>matchmaking · table · moves"]
    SE -- "sign in / refresh" --> A["AuthService<br/>(Supabase Auth)"]
    SE --> L["ServerLink<br/>reconnect + heartbeat"]
    L <--> S["Spring Boot server"]
    L -- "Message (JSON)" --> Q[["MessageInbox<br/>ordered, with pauses"]]
    LM["LocalMatch + bots<br/>(offline)"] -- "Message (JSON)" --> Q
    Q --> SE
    Q --> MA
    MA -- "Command (JSON)" --> L
    MA -- "Command (JSON)" --> LM
```

- **State split by concern** — `SessionController` owns who the player is and the connection; `MatchController` owns matchmaking, the table and the moves, online or offline; `MessageInbox` applies server messages to them in order. `AppController` wires them together and derives the screen from where the session and the match are, instead of every handler setting it. Pages watch only the part they show, so a card played does not rebuild the menu or the login page.

- **Ordered message queue** — server messages are applied strictly in arrival order. After a trick or a set the queue pauses for a few seconds so players can see the cards; messages that arrive meanwhile wait instead of being applied early or out of order, and logging out cancels the pause cleanly.
- **Connection is not session** — `ServerLink` owns the socket and reconnects with backoff when it drops; every new connection identifies the player again, which is also how the server resumes a match. A heartbeat detects connections that died without notice. Only an explicit logout (or a refused token) signs the player out.
- **Offline engine** — `lib/offline/local_match.dart` runs a match on the device and `bot.dart` plays the computer opponents (bet from the likely tricks in hand; win cheaply when a trick is needed, otherwise dump strong cards that lose). `MatchController` sends commands to it instead of the server; tests play complete 19-set matches against 1, 2 and 3 bots.
- **Command / message protocol** — the client sends intentions (`SET_BET`, `PUT_CARD`, …) with no player name in them (the server knows who is on the socket); every server event is decoded by a registry in `server_message.dart` into a class that applies itself to the state. The wire format is documented in the server repository (`docs/protocol.md`).
- **Testable seams** — the socket (`GameConnection`) and Supabase (`AuthService`) sit behind interfaces, so the whole client state (`AppController`) is tested with fakes in fake time: login and nicknames, trick and set pauses, reconnection mid-match, logout during a pause.
- **Contract test against the real server** — `test/fixtures/real_match.jsonl` holds every message the real server sent to two players during a full match, including a dropped connection and the reconnection; both players' clients replay it and must end on the server's final scores.

- **Design system** — colours, radii and component themes live in `lib/ui/theme.dart`; reusable pieces (glass panels, buttons, avatars, cards, the floor indicator) in `lib/ui/`. The game screen is split into small widgets under `lib/pages/game/`.

```
lib/
├── state/     # AppController, SessionController, MatchController, MessageInbox
├── ui/        # theme and shared components
├── auth/      # AuthService (Supabase)
├── network/   # GameConnection (WebSocket), ServerLink (reconnection, heartbeat)
├── offline/   # local match engine and bots
├── command/   # client → server commands
├── message/   # server → client messages and their decoders
├── model/     # game state, players, cards, rules
└── pages/     # screens (the game screen's parts in pages/game/)
```

## Running

```bash
flutter run --dart-define=SERVER_URL=wss://your-server/ws
```

Without `SERVER_URL` the app connects to a local server (`ws://localhost:8080/ws` on the web, `ws://10.0.2.2:8080/ws` from the Android emulator).

**Web deployment** — every push to `main` runs `.github/workflows/deploy-web.yml`: analysis, tests, a release build against the production server (`wss://ascensore-server.fly.dev/ws`) and publication on GitHub Pages. Sign-up confirmation links lead back to the page the player signed up from, so that address must be listed among the Supabase project's redirect URLs.

```bash
flutter test
```

**Design preview** — every screen with scripted data, no server or account needed (the screenshots above come from it):

```bash
flutter run -d chrome -t tool/design_preview.dart
```

Pick a screen with the `s` query parameter: `?s=welcome`, `login`, `nickname`, `menu`, `waiting`, `bet`, `bet10`, `play`, `left`, `trick`, `peak`, `setresult`, `gameover`, `offline`, `replaced`, `reconnecting`.

## Known limitations

- The interface is in Italian only; it is not localized yet.

## Tech stack

- **Client:** Flutter · Dart · Provider · WebSockets · Supabase Auth
- **Server** (separate repository): Java 17 · Spring Boot · PostgreSQL (Supabase)
