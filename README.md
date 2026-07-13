# BudgetMe

Personal finance iOS app for the MENA region. Track spending, pick a budgeting style, and forecast where you're headed — with region-appropriate pricing. Mint-inspired UI.

**Status:** MVP iteration 1 — free-tier core loop (runnable in Xcode with sample data).

---

## What's in this iteration

- **Dashboard** — monthly spend, category donut, 50/30/20 budget cards, 15-day forecast widget, recent transactions.
- **Transactions** — date-grouped feed, search, manual add, tap to re-categorize / delete, CSV export.
- **Budget** — 50/30/20 framework (free). Paid frameworks visible but locked.
- **Forecast** — recurring-transaction detection + projected net-change line chart. 15-day (free); 30/60/90 gated.
- **Apple Pay auto-tracking** — via an iOS Shortcuts personal automation → an App Intent (`AddTransactionIntent`). Setup guide in Settings.
- **Settings** — profile, currency, framework, plan (dev toggle to preview Paid), data export, delete all data.

Persistence is a local JSON store behind a small interface, so it swaps cleanly to CoreData + CloudKit later. Categorization is a seeded MENA merchant lookup that learns from corrections — CoreML can replace it behind the same interface.

## Not yet built (next iterations)

- Minimal backend (auth + StoreKit 2 subscription-status validation).
- Paid features: Zero-Based / Pay Yourself First / Custom frameworks, rollover budgets, subscription manager, debt planner, savings goals.
- CoreData + CloudKit persistence; on-device CoreML categorization.
- Arabic / RTL localization (v1.1).
- **Unified recurring-confirmation flow.** Today income is auto-assumed monthly (toggle in Settings). Replace this with the same "we noticed this — is it recurring?" confirmation that expenses should use, so both income and expenses are user-confirmed rather than assumed.

---

## Build & run

This project uses [XcodeGen](https://github.com/yonaskolb/XcodeGen) so the `.xcodeproj` isn't committed (regenerate it locally).

```bash
brew install xcodegen        # once
cd ~/Desktop/BudgetMe
xcodegen generate            # creates BudgetMe.xcodeproj
open BudgetMe.xcodeproj
```

In Xcode: select a Signing Team (Signing & Capabilities), pick an iOS 16+ simulator, and Run. The app launches into onboarding, then the dashboard is pre-seeded with MENA sample data.

**Requirements:** Xcode 15+, iOS 16.0+ deployment target.

---

## Apple Pay auto-tracking (the real data layer)

Apple does **not** expose Apple Pay transaction history to third-party apps via PassKit, and FinanceKit is US/UK-only — so BudgetMe uses the **iOS Shortcuts Transaction automation** instead (the same technique TravelSpend and Skwad use). One-time setup per user:

1. Shortcuts app → **Automation** → **+** → **Create Personal Automation**
2. Choose **Transaction** → select your Apple Wallet cards → keep all categories on
3. Add action **"Log a Transaction in BudgetMe"** → map **Merchant → Merchant**, **Amount → Amount**
4. Enable **Run Immediately**, disable **Notify When Run**

Every Apple Pay tap then logs into BudgetMe automatically. Limits: Apple Pay (NFC) only — no cash, transfers, or non-Wallet cards (add those manually); amount arrives as a formatted string (parsed in `AddTransactionIntent`); no MCC code, so categorization is merchant-name based.

---

## Push to GitHub

The project files are ready. Create an **empty** repo named `BudgetMe` on github.com (no README/gitignore — they're already here), then from your Mac:

```bash
cd ~/Desktop/BudgetMe
git init
git add .
git commit -m "Iteration 1: free-tier core loop (dashboard, transactions, 50/30/20, forecast, Shortcuts ingestion)"
git branch -M main
git remote add origin https://github.com/<your-username>/BudgetMe.git
git push -u origin main
```

Replace `<your-username>`. Your Mac's saved GitHub login handles auth — no token needed.
