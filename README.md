# INDIA 2027 – The Blue Army Squad Lab
1. `npm install`
2. `npm run dev` → http://localhost:5173

## How submit works (no server, no EmailJS, no Netlify)
After the fan enters name, email and phone, the site writes the full email (their 15, C / VC / WK, fan totals, their email and phone) and:
1. opens the email app on the device (`mailto:`);
2. if no app takes over, opens Gmail in the browser;
3. if the browser blocks that tab, the dialog shows "Open in Gmail" and "Copy email" buttons.
The fan presses Send. A website cannot send mail silently without a server.
Recipient: `BCCI_EMAIL` in `src/utils/emailService.js` (office@bcci.tv; change it there).

Fan totals and analytics are stored in each visitor's own browser (localStorage). To count everyone together you need a backend.
Add real avg / SR / economy per player in `src/data/players.js`.

## Player stats (ODI career, checked Sep–Oct 2026)
Cricinfo profiles (Rohit, Kuldeep, Axar, Jaiswal, Surya), BCCI.tv ODI stats (Iyer, Rahul, Hardik), Wikipedia (Gill, Kohli, Bumrah, Siraj, Arshdeep, Prasidh, Shami, Jadeja), myKhel (Jadeja SR/econ), Sportskeeda (Siraj econ), CricTracker (Gill). Shami's economy is runs ÷ overs from Wikipedia's ODI records table.
Some snapshots are a few months old (Axar, Jadeja, Rahul, Iyer, Hardik). Jaiswal's 71.25 is from only 6 ODIs. Players with no figures have none shown; add them in `src/data/players.js`.

## Android APK (GitHub Actions)
Push this project to GitHub (branch `main`). The workflow `.github/workflows/build-apk.yml` builds the web app, wraps it with Capacitor and produces a debug APK.
Download it from the repo's **Actions** tab, open the latest run, then **Artifacts → india-2027-squad-apk**. You can also start it by hand with **Run workflow**.
A debug APK installs directly on a phone (allow "install unknown apps"). For the Play Store you would add a signed release build.
App vs web: it is the same code. `base: "./"` in `vite.config.js`, `viewport-fit=cover` and the safe-area padding in `index.css` are what make it work in the app. The email step uses the phone's mail app (`mailto:`) and falls back to Gmail in the browser.

## Notes (phone app)
- Submit shows two buttons: open your email app, or open Gmail in the browser. Nothing opens by itself.
- Submitted squads are stored on the phone (localStorage + native Preferences) and survive restarts. They are per device: uninstalling the app erases them, and other people's phones are separate. A shared backend (Firebase or Google Sheets) is needed to combine everyone's squads.

## Accounts server (Supabase) – needed for login, remembered squads and the shared fan count
Accounts, squads and the "N fans have submitted" number are stored on a server, so they survive uninstall / cleared storage and are shared by every phone.
1. Create a free project at supabase.com.
2. Supabase > SQL Editor > New query: paste all of `supabase/setup.sql` > Run.
3. Supabase > Project Settings > API: copy the Project URL and the `anon` public key into `src/config.js`.
4. Commit; the APK workflow rebuilds. Until step 3 is done the app shows "The server is not set up yet" on login.
Login rule: phone must match exactly; the name ignores capitals/extra spaces and may be the first word(s) of the registered name ("saani" matches "Saani Alam Choudhury", "alam" does not).
Each account holds one squad; submitting again replaces it. Tables are locked: the app can only call the four functions in the SQL file.

## Desktop app (Windows .exe, Mac, Linux)
Same code and features as the Android app, wrapped with Electron (`desktop/`).
Workflow `.github/workflows/build-desktop.yml` builds it on GitHub: Actions > "Build Desktop App" > latest run > Artifacts:
- `india-2027-squad-windows-exe`: an installer (`...Setup.exe`) and a portable `.exe` (no install needed)
- `india-2027-squad-mac` (.dmg) and `india-2027-squad-linux` (.AppImage)
Windows may show "Windows protected your PC" because the app is not code-signed: More info > Run anyway.
Run locally: `npm install && npx vite build --base=./`, copy `dist` to `desktop/app`, then in `desktop/`: `npm install && npm start`.
Remember to fill `src/config.js` (Supabase) first; accounts and squads are shared with the phone app.
