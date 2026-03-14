# Personal Finance & Invoice Web App Specification (India)

## Product Context
This web app supports a self-employed professional in India who:
- earns revenue in USD,
- tracks expenses in INR,
- manages investments,
- estimates Indian income tax for the active fiscal year.

## Regional Defaults
- **Primary Currency Display:** Indian Rupee (`₹`)
- **Number Formatting:** Indian comma grouping (e.g., `₹1,50,000`, `₹1,00,00,000`)
- **Fiscal Year:** April 1 to March 31

## Web Technology Stack
- **Frontend:** Vanilla HTML, CSS, JavaScript
- **Backend / Database:** Supabase (PostgreSQL + REST API)
- **Charts:** Chart.js
- **AI Assistant:** OpenAI GPT-4o API
- **Authentication:** Username/password validation from `config.js`
- **Offline Support:** PWA Service Worker

## Authentication Flow
1. On app load, check `localStorage.isLoggedIn`.
2. If not logged in, redirect to `login.html`.
3. Validate submitted username/password against values defined in `config.js`.
4. On successful login, store:
   - `isLoggedIn`
   - `username`
   - `loginTime`
   - `lastActivity`
5. Enforce automatic logout after 30 minutes of inactivity.

## Functional Modules
- Dashboard summary (income, expenses, investment snapshot, tax estimate)
- Invoice management (create, list, status tracking)
- Expense tracking (category, date, payment mode, notes)
- Investment tracking (asset class, amount, current value, gains)
- Tax estimation (Indian tax regime assumptions and annualized totals)
- AI assistant for natural-language financial insights

## Data & Currency Behavior
- Persist source currency for income entries (USD) and convert/store INR equivalent for reporting.
- Use INR as the default reporting currency in all dashboards.
- Keep exchange-rate metadata (`rate`, `rate_date`, `provider`) for auditability.

## Security & Session Controls
- Hash credentials before storing in configuration where possible.
- Track `lastActivity` on route changes, clicks, and keyboard input.
- Reset inactivity timer after each user action.
- Clear session keys and redirect to login on timeout.

## PWA Notes
- Cache static shell assets for offline startup.
- Use runtime caching for API responses with clear stale-data indicators.
- Keep sensitive auth/session details out of service-worker cache.

## Suggested Initial File Layout
```txt
web/
  index.html
  login.html
  dashboard.html
  invoices.html
  expenses.html
  investments.html
  tax.html
  css/
    styles.css
  js/
    config.js
    auth.js
    api.js
    dashboard.js
    invoices.js
    expenses.js
    investments.js
    tax.js
    ai.js
    utils.js
  sw.js
```
