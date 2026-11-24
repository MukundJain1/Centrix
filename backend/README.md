# Daily Expense API (phase 1: auth + financial baseline)

FastAPI + PostgreSQL (Supabase). The Flutter app talks only to this API;
the database is never exposed to the app directly.

## What it does

| Endpoint | Purpose |
|---|---|
| `POST /v1/auth/otp/send` | text a code to a new number (register step 1) |
| `POST /v1/auth/otp/verify` | check the code, get a short-lived registration token (step 2) |
| `POST /v1/auth/register` | choose a PIN, create the account (step 3) |
| `POST /v1/auth/login` | phone + PIN. 401 `WRONG_PIN`, 423 `PIN_LOCKED` |
| `POST /v1/auth/refresh` / `logout` | rotate / revoke refresh tokens |
| `GET  /v1/auth/me` | who am I + which setup steps are done |
| `GET/PUT /v1/baseline` | Financial Baseline (replace-all save) |
| `PUT /v1/cycle` | payday + balance -> daily budget |

Errors always look like `{"error": {"code": "WRONG_PIN", "message": "...", ...}}`.
Interactive docs: `http://localhost:8000/docs`.

## Run it on your PC (no Supabase needed)

```bash
cd backend
python -m venv .venv
.venv\Scripts\activate            # Windows   (Mac/Linux: source .venv/bin/activate)
pip install -r requirements-dev.txt
copy .env.example .env            # Mac/Linux: cp .env.example .env
set AUTO_CREATE_TABLES=true       # or edit it in .env (already true in .env.example)
uvicorn app.main:app --reload --host 0.0.0.0 --port 8000
```

In dev mode the OTP is always `123456` and is also printed in the server log.
Run the tests: `pytest`

### Testing from your phone over USB / Wi-Fi
- Android emulator: the API is at `http://10.0.2.2:8000`
- Real phone on the same Wi-Fi: `http://<your-PC-IP>:8000` (run `ipconfig`)
- Real phone over USB: `adb reverse tcp:8000 tcp:8000`, then use `http://localhost:8000`

## Put it online for free

1. **Database (Supabase)**
   - supabase.com > New project (pick the Mumbai/`ap-south-1` region). Save the database password.
   - SQL Editor > paste `supabase/schema.sql` > Run.
   - Project Settings > Database > Connection string > **Session pooler** > copy it
     (it looks like `postgresql://postgres.xxxx:[YOUR-PASSWORD]@aws-0-ap-south-1.pooler.supabase.com:5432/postgres`).
     The direct connection is IPv6-only; the pooler works from most hosts.
2. **API (Render)**
   - Push this `backend` folder to a GitHub repo (the `.env` file is git-ignored; keep it that way).
   - Render > New > Web Service > connect the repo > Runtime Python.
     Build: `pip install -r requirements.txt`  Start: `uvicorn app.main:app --host 0.0.0.0 --port $PORT`
   - Environment variables: `ENV=prod`, `DATABASE_URL=<pooler URL>`,
     `JWT_SECRET=<48+ random chars>`, `PIN_PEPPER=<48+ random chars>`.
     Generate each with `python -c "import secrets; print(secrets.token_urlsafe(48))"`.
   - Do **not** change `PIN_PEPPER` later: every PIN would stop working.
3. Open `https://<your-service>.onrender.com/health` - you should see `{"status":"ok"}`.

### Free-tier things to know
- Render's free web service **sleeps after 15 minutes** without traffic; the next
  request takes about a minute. For demos, point a free uptime pinger (e.g.
  cron-job.org) at `/health` every 10 minutes.
- Supabase free projects **pause after a week of inactivity** (restore them from the dashboard).
- Don't use Render's free Postgres (it expires); Supabase is the database.

### SMS in production
`ENV=prod` has **no SMS sender yet** (the API answers `SMS_NOT_CONFIGURED`).
Plug your provider into `app/otp.py > get_otp_sender()` (MSG91, Twilio, ...).
Sending SMS in India needs DLT registration, which can take days. Until then
keep using `ENV=dev` on a private server, or give the app test numbers.

## Security notes
- PINs are stored as argon2id of `HMAC(PIN_PEPPER, user_id:pin)`. The pepper lives
  only in the server's environment, so a leaked database cannot be brute-forced.
- 5 wrong PINs lock the account for 15 minutes. 5 wrong OTP codes void the code.
  Max 5 OTP texts per number per hour.
- All tables have Row Level Security on with no policies, so Supabase's public
  API cannot read them.
- Not done yet: per-IP rate limiting (add `slowapi`, or Cloudflare in front), PIN reset
  ("Forgot PIN" = OTP then new PIN), and removing old OTP/refresh rows.
