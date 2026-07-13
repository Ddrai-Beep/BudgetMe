## **BudgetMe** 

## Product Requirements Document 

Version 1.0  ·  MVP  ·  iOS  ·  MENA-first Launch 

|**Status**|Draft — for engineering handoff|
|---|---|
|||
|**Platform**|iOS (iPhone)|
|||
|**Launch Region**|MENA (Middle East & North Africa) — primary; global rollout to follow|
|||
|**Monetization**|Freemium — Free tier + Paid subscription (PPP pricing via App Store tiers)|
|||
|**Data source**|Apple Wallet / PassKit (no third-party bank aggregators in MVP)|
|||
|**Credit scoring**|Excluded from MVP — international accessibility priority|
|||
|**Last updated**|June 2026|



## **1. Product Overview** 

BudgetMe is a personal finance iOS app that helps individuals — especially those in the MENA region — track spending, manage budgets, and plan for their financial future. It pulls transaction data automatically from Apple Wallet, removing the dependency on unreliable third-party bank aggregators that fail to support most international banks. 

The UI is inspired by Mint, the most widely beloved personal finance app before its discontinuation in 2024. BudgetMe captures the clarity and warmth of that experience while extending it for an international, mobile-first audience. 

The core thesis: budgeting apps fail because they create friction. BudgetMe reduces friction at every step — automatic data import, automatic categorization, multiple budgeting methodologies, and automatic cash-flow forecasting so users always know where they stand. 

## **2. Problem Statement** 

## **2.1 The data problem** 

Most budgeting apps rely on Plaid or similar aggregators to pull bank transactions. These services cover US banks reasonably well but have poor or no coverage for the majority of banks in the MENA region, making the apps functionally useless for international users. 

## **2.2 The methodology problem** 

Apps like YNAB force users into a single rigid budgeting framework. Users who do not align with that philosophy churn. People have different financial personalities — some want automation, some want control, some are gig workers with irregular income. 

## **2.3 The pricing problem** 

YNAB charges $14.99/month or $99/year — priced for US income levels. For a user in Egypt, Jordan, or Morocco, this is prohibitively expensive. No major competitor offers purchasingpower-adjusted pricing. 

## **2.4 The void left by Mint** 

Mint had 3.6 million active users at its peak. It was shut down in January 2024. Its users — many of whom relied on its free, visually clear interface — have found no adequate replacement. This is a demonstrated market of users actively looking for an alternative. 

## **3. Goals & Success Metrics** 

## **3.1 MVP Goals** 

- Ship a working iOS app that ingests Apple Wallet transactions and categorizes them automatically 

- Offer three budgeting frameworks to accommodate different financial personalities 

- Provide 30/60/90-day cash-flow forecasting with zero manual input required from the user 

- Launch in MENA with PPP pricing built in from day one 

- Replicate the visual clarity and emotional warmth of the Mint UI 

## **3.2 Success Metrics (6 months post-launch)** 

- D30 retention ≥ 35% 

- Free-to-paid conversion ≥ 8% 

- Average session length ≥ 3 minutes 

- Transaction auto-categorization accuracy ≥ 85% 

- Forecasting accuracy within 15% of actual spend for 70%+ of users 

- App Store rating ≥ 4.4 

## **4. User Personas** 

## **Persona 1 — The MENA Professional** 

Layla, 27, Dubai. Marketing manager, paid in AED. Uses Apple Pay for almost everything. Has tried Mint (loved it) and YNAB (found it too rigid and expensive). Wants to know where her money goes without setting up spreadsheets. Needs an app that works with local banks. 

## **Persona 2 — The Gig Worker / Freelancer** 

Khalid, 31, Riyadh. Freelance designer with irregular monthly income. Standard month-based budgeting doesn't work for him. Needs rollover budgets, income smoothing, and cash-flow projections so he can plan when income dips. 

## **Persona 3 — The Post-Mint Migrant** 

Sara, 24, Cairo. Recent graduate. Relied on Mint's free tier for three years. Since Mint shut down she has been using a notes app to track spending. Needs Mint's simplicity and free tier with better international support. 

## **5. Feature Specifications** 

## **5.1 Apple Wallet Integration** 

BudgetMe uses Apple's PassKit and the Wallet transaction APIs to pull spending data directly from the user's device. This is the foundational data layer of the entire app. 

## **Requirements** 

- Request PassKit entitlements and appropriate HealthKit-style privacy permissions on onboarding 

- Poll for new transactions on app open and in background (BGAppRefreshTask) 

- Store transactions locally in CoreData with iCloud sync for cross-device continuity 

- Surface a clear permission explanation screen explaining why this access is needed and what is never shared 

- Handle cases where Apple Wallet has no transactions gracefully — prompt manual entry as fallback 

## **Constraints** 

- Apple Wallet API only surfaces transactions made via Apple Pay — it does not capture bank transfers, cash, or card-present transactions not tokenized in Wallet 

- Users should be made aware of this limitation on onboarding with a clear one-liner 

- Manual transaction entry must be available as a supplement 

## **5.2 Automatic Transaction Categorization** 

Every transaction pulled from Apple Wallet should be automatically tagged with a spending category. The categorization engine should improve over time through user corrections. 

## **Default categories (Mint-inspired)** 

- Food & Dining 

- Shopping 

- Transport 

- Entertainment 

- Bills & Utilities 

- Health & Fitness 

- Travel 

- Education 

- Personal Care 

- Groceries 

- Subscriptions (auto-detected) 

- Uncategorized 

## **Categorization logic** 

- Use merchant name + MCC code (where available via PassKit) as primary signals 

- Maintain a merchant-to-category lookup table, seeded with top MENA merchants (Carrefour, LuLu, Talabat, Noon, Amazon.ae, ADNOC, etc.) 

- When confidence is low, default to Uncategorized and surface a 'Help us categorize this' card 

- User corrections feed back into a local ML model (CoreML) to improve future accuracy 

- Target: 85%+ auto-categorization accuracy at launch 

## **User controls** 

- Tap any transaction to re-categorize 

- Split a transaction across multiple categories 

- Add notes or tags to transactions 

- Create custom categories (Paid tier) 

## **5.3 Budgeting Frameworks** 

Users are not forced into a single budgeting methodology. During onboarding, they choose a framework or create a custom budget. They can switch frameworks at any time. 

## **Framework 1 — 50/30/20 Rule** 

- Allocates 50% of take-home income to needs, 30% to wants, 20% to savings and debt repayment 

- App auto-distributes based on declared monthly income 

- Color-coded dashboard rings show progress within each bucket 

- Available on Free tier 

## **Framework 2 — Zero-Based Budgeting** 

- Every dollar/dirham of income is assigned a job at the start of the month 

- Income minus all category allocations equals zero 

- Users set allocation per category; app tracks actuals vs. allocation in real time 

- Available on Paid tier 

## **Framework 3 — Pay Yourself First** 

- User declares a savings target at the top of the month 

- That amount is 'locked' before any other spending is shown 

- Remaining balance is available for discretionary spending — no categories required 

- Ideal for users who want a hands-off approach 

- Available on Paid tier 

## **Custom Budget** 

- User defines their own categories and monthly limits 

- Available on Paid tier 

- No pre-set structure — fully flexible 

## **5.4 Rollover Budgets** 

Unspent budget in a category rolls over to the next month rather than resetting to zero. This is especially valuable for freelancers and gig workers who have variable income and spending patterns. 

- Rollover is on by default for all budget categories 

- Users can disable rollover per category 

- Dashboard shows 'running total' context — e.g., '+ AED 120 rolled over from last month' 

- Rollover history is visible per category (Paid tier) 

- Available on Paid tier 

## **5.5 Cash-Flow Forecasting** 

The app projects the user's financial position 30, 60, and 90 days into the future based on detected recurring transactions. The goal is zero manual input — the system builds the forecast automatically. 

## **How it works** 

- Scan transaction history for recurring patterns: same merchant, similar amount, regular interval (weekly/monthly/annual) 

- Flag detected recurring items for user confirmation on first detection ('We noticed you pay Spotify AED 34 monthly — include in forecast?') 

- Once confirmed, recurring items feed the forecast engine 

- Forecast view shows: projected income, projected fixed expenses, projected discretionary spend, projected end-of-period balance 

- Users can manually add expected one-time income or expenses (e.g., 'Freelance payment, AED 5,000, July 15') 

## **Forecast views** 

- 30-day view: primary, shown on dashboard 

- 60-day and 90-day views: accessible via toggle on Forecast screen 

- Line chart of projected daily balance over forecast period 

- 'At this rate' alerts: if projected balance goes negative, surface a warning with the date and suggested action 

## **Tier access** 

- Free tier: 15-day forecast only 

- Paid tier: 30/60/90-day forecast + one-time entry + scenario planning 

## **5.6 Subscription Management** 

A dedicated module that detects, surfaces, and helps users manage recurring subscriptions. 

## **Auto-detection** 

- Run subscription detection on every transaction sync 

- Flag transactions that match subscription patterns: recurring, fixed amount, known subscription merchant (Spotify, Netflix, Apple One, Amazon Prime, ChatGPT, Adobe, etc.) 

- Maintain a curated list of known subscription merchants, weighted toward MENA-popular services 

## **Manual entry** 

- Users can manually add subscriptions not transacted through Apple Pay (e.g., direct debit, credit card outside Apple Wallet) 

- Fields: service name, amount, currency, billing cycle, renewal date, category 

## **Dashboard widget** 

- 'Subscriptions this month' summary card on home screen 

- Shows total monthly subscription spend, number of active subscriptions 

- Drill down to full subscription list sorted by cost 

- Flag subscriptions not used in 30+ days (based on absence of related app usage — where inferable — or user self-report) 

## **Alerts** 

- Push notification 3 days before a subscription renews 

- Annual subscription renewal alert 7 days prior 

- 'You haven't used this in 30 days' nudge for flagged subscriptions 

Subscription management is a Paid tier feature. 

## **5.7 Debt Payoff Planner (Visual, No Money Movement)** 

A visual planning tool — not a payment tool. BudgetMe never moves money. The debt planner helps users see and strategize their path to being debt-free. 

## **User inputs** 

- Debt name (e.g., 'Car loan', 'Student loan', 'Credit card — Bank X') 

- Current balance 

- Interest rate (APR) 

- Minimum monthly payment 

- Currency 

## **Payoff strategies** 

- Avalanche method: pay minimums on all debts, put extra toward highest-interest debt first (mathematically optimal — minimizes total interest paid) 

- Snowball method: pay minimums on all, put extra toward smallest balance first (psychologically motivating — faster wins) 

- User can toggle between strategies to compare projected payoff dates and total interest paid 

## **Visual output** 

- Payoff timeline chart: stacked bar or Gantt-style showing when each debt is cleared under each strategy 

- 'Debt-free date' prominently displayed with chosen strategy 

- Interest savings comparison: 'Switching from Snowball to Avalanche saves you AED 2,340 in interest' 

- Progress tracker: as user updates balances monthly, progress bar fills and timeline updates 

Debt Planner is a Paid tier feature. 

## **5.8 Savings Features (Visual)** 

Automated savings features in MVP are visual goal-setters — they help users plan and track, but do not move funds. 

## **Savings goals** 

- User creates a savings goal: name, target amount, currency, target date, optional image/emoji 

- App calculates required monthly contribution to hit target 

- User manually marks contributions ('I saved AED 500 this month toward this goal') 

- Progress ring fills as contributions are logged 

- If user is behind on contributions, app surfaces a recalculation prompt 

## **Pay Yourself First integration** 

- If user is on Pay Yourself First framework, their declared savings target auto-links to a savings goal 

- Contributions are tracked against the goal automatically based on budget allocation 

## **Emergency fund guidance** 

- Surface a one-time prompt for users with no savings goal: 'Financial experts recommend 3–6 months of expenses as an emergency fund. Based on your spending, that's AED X– Y. Want to create a goal?' 

Savings features are available on Paid tier. Pay Yourself First framework with savings goal creation is on Paid tier. 

## **6. Freemium Tier Structure** 

|**Feature**|**Tier**|**Notes**|
|---|---|---|
|Apple Wallet transaction sync|**Free**|Up to 50 transactions logged|
|Auto-categorization|**Free**|Standard categories only|
|50/30/20 budget template|**Free**|1 template, no custom categories|
|15-day cash-flow forecast|**Free**|Auto-generated, read-only|
|Manual transaction entry|**Free**|Unlimited|
|Dashboard (Mint-style)|**Free**|Spending rings, monthly summary|
|Transaction history|**Free**|50 transactions max|
|Unlimited transactions|**Paid**|No cap on logged transactions|
|All budget frameworks|**Paid**|Zero-Based, Pay Yourself First, Custom|
|Rollover budgets|**Paid**|Per-category rollover|
|30/60/90-day forecast|**Paid**|Includes manual income/expense entry|
|Subscription manager|**Paid**|Auto-detect + manual + alerts|
|Debt payoff planner|**Paid**|Avalanche + Snowball strategies|
|Savings goals|**Paid**|Unlimited goals|
|Custom categories|**Paid**|User-defined categories|
|Full transaction history|**Paid**|Unlimited historical data|



Pricing: TBD. Use App Store pricing tiers by country to implement purchase-power-parity pricing. MENA region pricing should be substantially lower than US pricing to address the affordability gap that has alienated international users from competitors like YNAB. 

## **7. UI/UX Design Direction** 

## **7.1 Mint-Inspired Design Language** 

BudgetMe's visual design takes strong cues from Mint's most beloved UI patterns. The objective is for any former Mint user to feel immediately at home. 

## **Key Mint patterns to replicate** 

- Home dashboard with spending summary donut/ring charts per category 

- Color-coded categories — each category has a consistent color used across charts, transaction lists, and budget bars 

- Monthly spending trend bar chart on the home screen (this month vs. last month) 

- Transaction feed: scrollable, grouped by date, with merchant logo, category color tag, and amount 

- Budget bars: horizontal progress bars per category showing spent vs. limit, turning red when over 

- Clean, spacious layout — information density is moderate, not overwhelming 

## **Adaptations for BudgetMe** 

- Mobile-first: all screens designed for iPhone (no web dashboard in MVP) 

- Dark mode support from day one — important for MENA audience preferences 

- Arabic language support in v1.1 (flag for localization, not MVP requirement) 

- Currency flexibility: display amounts in user's local currency, not USD-defaulting 

## **7.2 Core Screens** 

## **Home / Dashboard** 

- Greeting + current month name at top 

- Total spent this month (large, prominent) 

- Spending breakdown ring chart by category 

- Budget status cards: one per active category, with progress bar 

- Subscriptions this month widget (Paid) 

- Cash flow forecast widget (15-day free / 30-day paid) 

- Recent transactions list (last 5) 

## **Transactions** 

- Full transaction feed, date-grouped 

- Search and filter by category, date range, amount 

- Tap to view detail, re-categorize, split, or add note 

## **Budget** 

- Framework selector at top 

- Category budget bars with amount spent / limit 

- Rollover indicator per category (Paid) 

- Month picker to view past months 

## **Forecast** 

- 30/60/90-day toggle (15-day for Free) 

- Line chart of projected daily balance 

- Detected recurring items list with ability to confirm/dismiss 

- Manual income/expense entry (Paid) 

- Alert banner if projected balance goes negative 

## **Subscriptions (Paid)** 

- Cards for each active subscription: logo, name, amount, next renewal date 

- Total monthly spend from subscriptions 

- Manual add button 

- Sort by cost, by renewal date, or by category 

## **Debt Planner (Paid)** 

- Add debt form 

- Payoff timeline chart 

- Strategy toggle: Avalanche vs. Snowball 

- Debt-free date callout 

## **Savings Goals (Paid)** 

- Goal cards with progress ring, target amount, and date 

- Required monthly contribution callout 

- Log contribution button 

## **Settings** 

- Profile and currency preferences 

- Notification preferences 

- Budget framework switcher 

- Manage subscription (upgrade/downgrade) 

- Data export (CSV) 

- Privacy and data deletion 

## **8. Technical Requirements** 

## **8.1 Platform & Stack** 

- iOS 16+ (minimum), Swift / SwiftUI 

- CoreData for local persistence 

- CloudKit / iCloud for cross-device sync 

- PassKit / Wallet APIs for transaction ingestion 

- CoreML for on-device categorization model (privacy-first — no transaction data leaves device) 

- BGAppRefreshTask for background transaction sync 

- StoreKit 2 for in-app purchases and subscription management 

## **8.2 Data Privacy** 

- All transaction data stored on-device and in user's personal iCloud — never on BudgetMe servers 

- No transaction data transmitted to backend for categorization — CoreML runs entirely on-device 

- Backend stores only: user account metadata, subscription status, anonymized analytics 

- App must pass App Store privacy nutrition label requirements — data not linked to user: none 

- Comply with GDPR (EU users), PDPL (Saudi Arabia), and relevant MENA data regulations 

## **8.3 Apple Wallet Constraints** 

- PassKit APIs only surface Apple Pay transactions — not all bank transactions 

- Transaction data available: merchant name, amount, date, MCC code (where provided) 

- No access to account balances via PassKit — balance display would require manual user input 

- Entitlement required: com.apple.developer.pass-type-identifiers 

## **8.4 Monetization Implementation** 

- StoreKit 2 for subscription purchase, renewal, and restoration 

- App Store pricing tiers used to implement PPP — no custom pricing logic needed in app 

- Subscription validation via App Store server notifications 

- Grace period handling: 7-day grace period before downgrading to Free tier on failed renewal 

## **9. Out of Scope (MVP)** 

- Credit score tracking or reporting 

- Bank account balance aggregation (beyond Apple Wallet) 

- Third-party bank aggregator integrations (Plaid, Salt Edge, etc.) 

- Investment portfolio tracking 

- Bill pay or any money movement 

- Web or Android app 

- Arabic language localization (flag for v1.1) 

- Social / shared budgets 

- Tax tracking or filing assistance 

- Cryptocurrency support 

- Automated savings transfers (visual only in MVP) 

## **10. Launch Strategy** 

## **10.1 Geographic Priority** 

MENA is the primary launch region. This is a strategic differentiator — no major budgeting app has launched MENA-first with PPP pricing and Apple Pay-native integration. Key MENA App Store markets to target at launch: 

- Saudi Arabia (SAR) 

- United Arab Emirates (AED) 

- Egypt (EGP) 

- Jordan (JOD) 

- Kuwait (KWD) 

- Qatar (QAR) 

US, UK, and broader international rollout to follow post-MENA validation. 

## **10.2 Positioning** 

- 'The budgeting app built for the rest of the world' 

- Lean into the Mint successor angle — large pool of displaced users actively looking 

- PPP pricing as a headline differentiator in marketing 

- Privacy-first angle: 'Your bank data never leaves your phone' 

## **10.3 App Store** 

- Primary category: Finance 

- Keywords: budget, personal finance, money tracker, expense tracker, Mint alternative, Apple Pay budget 

- Screenshots to lead with the dashboard and the forecast screen — most visually compelling 

## **11. Open Questions & Decisions Pending** 

**Feature Tier Notes** 

|Paid tier pricing (US)|**TBD**|Set monthly and annual price for US market;<br>determine anchor price before setting PPP<br>tiers|
|---|---|---|
|Free tier transaction cap<br>enforcement|**TBD**|How to handle the 51st transaction — block,<br>archive, or prompt upgrade?|
|Balance display|**TBD**|PassKit has no balance API — decide if<br>manual balance entry is surfaced or omitted|
|Arabic localization timeline|**TBD**|v1.1 target, but RTL layout implications should<br>be considered in initial architecture|
|Backend infrastructure|**TBD**|Minimal backend needed (auth, subscription<br>status) — define stack and hosting region<br>(prefer MENA for data residency)|
|Onboarding A/B test|**TBD**|Test framework-first vs. dashboard-first<br>onboarding flow|
|CoreML model training data|**TBD**|Seed categorization model with labeled MENA<br>merchant data — source or create dataset|



## **12. Appendix** 

## **12.1 Competitive Landscape** 

|**Feature**|**Tier**|**Notes**|
|---|---|---|
|Mint (discontinued)|**Free**|Best-in-class UI, no international banks —<br>now dead|
|YNAB|**$14.99/mo**|Best methodology, very rigid, US-centric<br>pricing, no MENA bank support|
|Copilot|**$13/mo**|Beautiful iOS app, US-only, no international<br>support|
|Money Manager|**Free/Paid**|Popular in MENA but manual-entry only, poor<br>UX|
|BudgetMe (us)|**Free + PPP Paid**|Apple Wallet native, MENA-first, multiple<br>frameworks, Mint-inspired UI|



## **12.2 Debt Payoff Method Detail** 

## **Avalanche Method** 

List all debts. Pay minimum on all. Direct any extra payment toward the debt with the highest interest rate. When that debt is cleared, redirect its full payment to the next highest-rate debt. Mathematically minimizes total interest paid over time. 

## **Snowball Method** 

List all debts ordered by balance, smallest first. Pay minimum on all. Direct any extra payment toward the smallest balance. When cleared, redirect to next smallest. Psychologically motivating — delivers quick wins that maintain momentum. May result in more interest paid total vs. Avalanche. 

BudgetMe shows both side by side: payoff date, total interest, and monthly allocation for each. The user picks their preferred strategy. The app does not move any money. 

## **12.3 Cash-Flow Forecasting Logic** 

Recurring detection algorithm (simplified): 

- Group transactions by merchant name 

- For each merchant group, check if transactions appear at consistent intervals (±3 days tolerance for monthly, ±1 day for weekly) 

- If 2+ occurrences match the interval pattern, flag as probable recurring 

- Classify as: weekly, bi-weekly, monthly, quarterly, annual 

- Present to user for confirmation before including in forecast 

- Forecast engine sums all confirmed recurring outflows and income per day across the forecast window 

- Daily projected balance = previous day balance + confirmed income - confirmed outflows 

- • Unconfirmed or irregular transactions use a 'discretionary spend estimate' based on rolling 90-day average daily spend 

BudgetMe PRD v1.0  ·  Confidential  ·  June 2026 

