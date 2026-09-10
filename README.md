# Aviator (Flutter + Firebase)

A real-time, online crash game built in Flutter. Uses Firebase Authentication,
Firebase Realtime Database, and an authoritative Node.js game server.
Currency is **PKR** with a **16 PKR minimum** and **300,000 PKR maximum** bet.

## Features

- Firebase email/password **login, register, and password reset**.
- Real-time synchronized rounds across all devices.
- **PKR** wallet, server-managed balances and ledger.
- Two independent bet panels (manual + auto bet / auto cash-out).
- Live **All Bets** list and **My Bets** history.
- Recent crash multipliers shown identically on every device.
- **Provably fair** crash point: server seed committed as a SHA-256 hash before
  each round, 3 client seeds, SHA-512 combined hash → 52-bit crash formula with
  ~3% house edge.
- Flight scene with curved path, animated plane, and crash banner.

## Project setup

1. Make sure Flutter, `firebase-tools`, and Node.js ≥ 18 are installed.
2. In the Firebase Console, create a new project and enable:
   - **Authentication → Email/Password** provider.
   - **Realtime Database** in a region close to your players.
3. Add Android and iOS Flutter apps in the Firebase Console.
4. Generate `lib/firebase_options.dart`:

   ```bash
   flutter pub add firebase_core firebase_auth firebase_database
   flutterfire configure
   ```

5. Set Android `minSdkVersion` to 23 (`android/app/build.gradle.kts`).
6. Download the `google-services.json` and place it in `android/app/`.

## Game server setup

The server runs the authoritative round loop and settles all bets.

1. Go to `server/`:

   ```bash
   cd server
   npm install
   ```

2. Create a service account and download the private key JSON:

   Firebase Console → Project settings → Service accounts →
   **Generate new private key**.

3. Copy the example environment file and fill it in:

   ```bash
   cp .env.example .env
   ```

   ```env
   GOOGLE_APPLICATION_CREDENTIALS=/full/path/to/serviceAccountKey.json
   FIREBASE_DATABASE_URL=https://your-project-default-rtdb.firebaseio.com/
   SIGNUP_BONUS=3000
   ```

4. Import the Realtime Database rules from `database.rules.json`:

   ```bash
   firebase deploy --only database
   ```

   or paste `database.rules.json` into the Firebase Console rules editor.

5. Start the server:

   ```bash
   npm start
   ```

## Run the app

```bash
flutter pub get
flutter run
```

## Test

```bash
flutter analyze
flutter test
```

## Structure

- `lib/game/fair.dart` – shared game constants and provably-fair formula.
- `lib/game/models.dart` – shared data models.
- `lib/game/game_client.dart` – RTDB-backed client state and player actions.
- `lib/services/auth_service.dart` – Firebase Authentication wrapper.
- `lib/auth/auth_screen.dart` – login/register UI.
- `lib/game_page.dart` – main game page.
- `lib/main.dart` – Firebase init, auth gate, and app shell.
- `lib/widgets/` – header, flight area, bet panels, bets list, history, dialogs.
- `server/index.js` – authoritative game loop and wallet settlement.
- `database.rules.json` – RTDB security rules.
- `test/` – widget smoke tests and unit tests.

## Wallet / deposits

Users get a server-credited signup bonus if `SIGNUP_BONUS` is set. Real money
deposits are recorded under the `deposits/{id}` node with status `pending`.
When your payment provider marks a deposit `approved`, the game server credits
the user's wallet once.

## License

This project is intended for demonstration and educational purposes only. Real
money gambling is regulated and requires appropriate licensing in your
jurisdiction.
