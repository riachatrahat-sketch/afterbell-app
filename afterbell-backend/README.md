# Afterbell app backend (Next.js)

The mobile app talks only to this service. It checks every request, forwards only known fields,
and reads and writes the Afterbell WordPress site (theme 6.1.0 or newer) through its REST API.

    App (Flutter)  ->  this backend (Vercel)  ->  WordPress (afterbellacademy.com)

## Settings (environment variables)

| Name | Needed | What it is |
| --- | --- | --- |
| `WP_URL` | yes | Address of the WordPress site, for example `https://afterbellacademy.com` |
| `WP_APP_KEY` | optional | Same value as "Mobile app key" in WordPress admin > Afterbell > Live classroom. When set, app sign-in and sign-up only work through this backend. |
| `CORS_ORIGIN` | optional | Only if a website in a browser will call this backend. |

## Run on your computer

    npm install
    echo WP_URL=https://afterbellacademy.com > .env.local
    npm run dev                    # http://localhost:3000/api/health

## Deploy to Vercel

1. Put this folder in a GitHub repository.
2. vercel.com > Add New > Project > import the repository. Framework: Next.js (detected automatically).
3. Add `WP_URL` (and `WP_APP_KEY` if you use it) under Environment Variables, then Deploy.
4. Open `https://YOUR-PROJECT.vercel.app/api/health`. It should answer `{"ok":true,...}`.

## API used by the app

| Method | Path | Sign-in |
| --- | --- | --- |
| GET | `/api/home` | no |
| GET | `/api/classes?q=&track=&subj=&age=&format=&page=` | no |
| GET | `/api/class?id=12` | optional |
| GET | `/api/teacher?id=5` | no |
| POST | `/api/auth/login`, `/api/auth/signup` | no |
| POST | `/api/auth/logout` | yes |
| GET | `/api/me` | yes |
| POST | `/api/me/learners`, `/api/me/favorites` | yes |
| GET | `/api/me/favorites`, `/api/classrooms`, `/api/classroom?id=12`, `/api/teaching` | yes |
| POST | `/api/live` (join, poll, act, feedback) | yes |

Signed-in requests send `Authorization: Bearer <token>`; the token comes from login or signup.
Errors always look like `{"error":{"code":"...","message":"..."}}`.

## Tests

    npm test

Runs the router against a stand-in WordPress server (26 checks). Needs Node 22.6 or newer.
