# hflow

A personal finance and invoice management app for a self-employed professional based in India.

## Product Scope
- Track income (USD source, INR reporting)
- Manage expenses in INR
- Monitor investments
- Estimate Indian income tax for the current fiscal year (April 1 to March 31)

## Regional Defaults
- **Currency:** Indian Rupee (`₹`)
- **Number Format:** Indian comma system (`₹1,50,000`, `₹1,00,00,000`)
- **Fiscal Year:** April 1 to March 31

## Web Stack
- Frontend: Vanilla HTML/CSS/JavaScript
- Backend/DB: Supabase (PostgreSQL + REST API)
- Charts: Chart.js
- AI: OpenAI GPT-4o API
- Auth: Username/password from `config.js`
- Offline: PWA Service Worker

## Authentication Flow
1. Check `localStorage.isLoggedIn` on app open.
2. Redirect unauthenticated users to login.
3. Validate username/password against `config.js`.
4. Store `isLoggedIn`, `username`, `loginTime`, and `lastActivity` after successful login.
5. Auto-logout after 30 minutes of inactivity.

## Detailed Spec
See [`docs/WEB_APP_SPEC.md`](docs/WEB_APP_SPEC.md) for full implementation guidance.
