# ShelfSense — Development Roadmap

Track feature progress phase by phase. Update the status column as work completes.

**Status key:** `✅ Done` · `🚧 In Progress` · `⬜ Pending`

---

## Phase 1 — Foundation & Data Models `✅ Done`

> Goal: Project skeleton, SwiftData schema, and tab navigation in place.

| Task | Status | Notes |
|---|---|---|
| SwiftData models: `Store`, `Receipt`, `GroceryItem`, `PriceEntry` | ✅ Done | Bidirectional relationships with cascade-delete rules |
| `GroceryItem` computed properties (`latestPrice`, `priceChangePercent`, `isPriceAlert`) | ✅ Done | 10% threshold for price alerts |
| `ShelfSenseApp` — `ModelContainer` wired up with all 4 models | ✅ Done | |
| 4-tab `ContentView` (Dashboard, Scan, Prices, Stores) | ✅ Done | |
| `DashboardView` — monthly spend card, price alert rows, recent trips | ✅ Done | Placeholder data via preview container |
| `ScanView` — placeholder with camera button | ✅ Done | Shell ready for Phase 2 |
| `PriceHistoryView` — searchable item list with price indicators | ✅ Done | |
| `StoresView` — store list with trip count and total spend | ✅ Done | |
| `DashboardViewModel` — `@Observable`, drives monthly/alert/recent state | ✅ Done | |
| Accessibility labels on all interactive elements | ✅ Done | |
| Preview providers for every view with sample data | ✅ Done | |

---

## Phase 2 — Receipt Scanner `✅ Done`

> Goal: Users can point their camera at a receipt and have items + prices extracted automatically.

| Task | Status | Notes |
|---|---|---|
| Wrap `VNDocumentCameraViewController` in a `UIViewControllerRepresentable` | ✅ Done | `DocumentCameraView.swift` — VisionKit |
| `VNRecognizeTextRequest` pipeline to extract raw text from scanned image | ✅ Done | `ReceiptParser.recognizeText()` — Vision framework, `nonisolated` for background |
| Regex parser — extract line items (name + price) from receipt text | ✅ Done | `ReceiptParser.parseItem()` — Swift Regex literals |
| Regex parser — detect store name from receipt header | ✅ Done | Detected from first non-empty lines |
| Regex parser — detect totals, subtotals, and tax lines (exclude from items) | ✅ Done | Keyword filter in `parseLines()` |
| Unit price detection — parse "2 / $5.00", "per oz", "per lb" patterns | ✅ Done | `unitPrice` + `unitType` on `PriceEntry` |
| Review screen — show parsed items before saving, allow edits | ✅ Done | `ReviewReceiptView.swift` with editable list |
| Save parsed receipt + items into SwiftData (`Receipt`, `PriceEntry`, `GroceryItem`) | ✅ Done | `ScanViewModel.saveReceipt()` with find-or-create |
| Manual entry fallback — form to add items without scanning | ✅ Done | "Add Manually" button in `ScanView` |
| `ScanViewModel` — owns camera session state and parsed results | ✅ Done | `@Observable`, `processScannedImages()` via `Task` |
| NSCameraUsageDescription in Info.plist | ✅ Done | Set via `INFOPLIST_KEY_NSCameraUsageDescription` in build settings |

---

## Phase 3 — Price Alerts & History Detail `✅ Done`

> Goal: Users can see full price history for any item and get meaningful alert context.

| Task | Status | Notes |
|---|---|---|
| Item detail view — price history list sorted by date | ✅ Done | `ItemDetailView` with sorted `PriceEntry` list |
| Sparkline / mini line chart per item (Swift Charts) | ✅ Done | Line + area + point marks, color-coded by direction |
| Alert badge on Dashboard tab when new alerts exist | ✅ Done | `.badge()` on tab item driven by `@Query` count |
| Alert detail — show previous vs current price, store, and date | ✅ Done | Header in `ItemDetailView` shows change % and alert banner |
| Dismiss / snooze individual price alerts | ✅ Done | `lastAlertDismissedDate` on `GroceryItem`; toolbar button in detail view |
| Item name normalisation — merge "Org. Milk" and "Organic Milk" as same item | ✅ Done | `ItemMatcher` — abbreviation expansion + token sorting + bigram Jaccard (0.72 threshold) |
| Category auto-tagging based on item name keywords | ✅ Done | `CategoryTagger` service with keyword rules for 8 categories |

---

## Phase 4 — Store Comparison `✅ Done`

> Goal: Users can see which store is cheapest for items they buy regularly.

| Task | Status | Notes |
|---|---|---|
| Store detail view — list of receipts per store | ✅ Done | `StoreDetailView` with trip stats (count, total, avg) and receipt history |
| Per-item store comparison — cheapest store highlighted | ✅ Done | `StoresViewModel.buildComparison` groups latest price per store |
| "Frequently bought" item list — items appearing on 3+ receipts | ✅ Done | Items with 2+ price entries shown in "Best Deals" section |
| Estimated savings card — potential savings if buying cheapest store | ✅ Done | Savings card at top of `StoresView` |
| Store edit — allow renaming / merging duplicate store names | ✅ Done | Rename alert in `StoreDetailView`, cascades to all receipts |

---

## Phase 5 — Spending Dashboard (Charts) `✅ Done`

> Goal: Visual spending trends using Swift Charts.

| Task | Status | Notes |
|---|---|---|
| Monthly bar chart — spend per month, last 6 months | ✅ Done | `BarMark` in `DashboardView`, current month highlighted |
| Per-store spend breakdown — donut or bar chart | ✅ Done | `SectorMark` donut chart, top 5 stores with legend |
| Category spend breakdown (Dairy, Produce, Pantry…) | ✅ Done | Horizontal `BarMark` chart, driven by `PriceEntry` history |
| Savings counter — total estimated savings from buying cheaper stores | ✅ Done | Savings card in `DashboardView`, computed in `DashboardViewModel` |
| Export data — CSV export of all receipts and prices | ✅ Done | `CSVExporter` + `ShareSheet` (UIActivityViewController) |

---

## Post-MVP Ideas

These are not scheduled but worth tracking for later consideration.

| Idea | Notes |
|---|---|
| iCloud sync via SwiftData's CloudKit backend | Share data across devices |
| Widgets — "This week's spend" home-screen widget | WidgetKit |
| Barcode scanning — look up product by barcode for quick manual entry | AVFoundation |
| Push notifications for price spike alerts | UserNotifications |
| Shopping list — build a list from tracked items with cheapest-store hints | |
| Unit price normalisation — compare price per 100g across pack sizes | |
| Multi-currency support | For users outside the US |

---

*Last updated: All 5 MVP phases complete — May 2026*
