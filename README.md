# ShelfSense

A personal grocery price tracker and spending awareness app for iOS. ShelfSense lets you scan grocery receipts to automatically log item prices, track price changes over time, compare costs across stores, and visualise monthly spending trends — entirely on-device with no external accounts or APIs required.

---

## Features

| Feature | Description |
|---|---|
| **Receipt Scanner** | Scan grocery receipts with your camera using VisionKit; items, prices, and store name are extracted automatically |
| **Price History** | Every scanned item is stored with price, date, store, and unit price (price per oz/lb where available) |
| **Price Alerts** | Items flagged automatically when their price has risen more than 10% since last purchase |
| **Store Comparison** | See which store offers the cheapest price for items you buy regularly |
| **Spending Dashboard** | Total spend per trip, month-over-month trend chart, and estimated savings from price awareness |

---

## Tech Stack

| Layer | Technology |
|---|---|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Persistence | SwiftData (iOS 17+) |
| Receipt Scanning | VisionKit + Vision framework |
| Charts | Swift Charts (built-in) |
| Architecture | MVVM |

No external dependencies or paid APIs — everything runs locally on-device.

---

## Requirements

- Xcode 16+
- iOS 17+ deployment target (iOS 26 used during development)
- A physical device or simulator with camera access for receipt scanning

---

## Getting Started

1. Clone or download the repository
2. Open `ShelfSense.xcodeproj` in Xcode
3. Select your target device or simulator
4. Build and run (`Cmd+R`)

No additional setup, package installation, or API keys needed.

---

## Project Structure

```
ShelfSense/
├── Models/
│   ├── Store.swift           # Store entity (name, location)
│   ├── Receipt.swift         # Receipt entity (store, date, total, line items)
│   ├── GroceryItem.swift     # Item entity with computed price-change logic
│   └── PriceEntry.swift      # Individual price record linked to item + receipt
├── ViewModels/
│   └── DashboardViewModel.swift  # Monthly spend, alerts, recent trips
├── Views/
│   ├── DashboardView.swift   # Tab 1 — spending summary and alerts
│   ├── ScanView.swift        # Tab 2 — receipt scanner
│   ├── PriceHistoryView.swift # Tab 3 — searchable item price list
│   └── StoresView.swift      # Tab 4 — store comparison
├── ContentView.swift         # Root TabView
└── ShelfSenseApp.swift       # App entry point + ModelContainer setup
```

---

## Data Model

```
Store ──< Receipt ──< PriceEntry >── GroceryItem
```

- A **Store** has many **Receipts**
- A **Receipt** has many **PriceEntries** (line items), with cascade delete
- Each **PriceEntry** links back to a **GroceryItem**, building its price history
- **GroceryItem** owns its **PriceHistory** (cascade delete) and exposes computed `latestPrice`, `priceChangePercent`, and `isPriceAlert`

---

## Architecture

The app follows MVVM:

- **Models** are plain `@Model` SwiftData classes — they own domain logic (e.g. `isPriceAlert`) as computed properties
- **ViewModels** are `@Observable` classes that receive query results from views and compute derived state (totals, filters, sorted lists)
- **Views** own `@Query` descriptors for live SwiftData updates and delegate display logic to view models

---

## License

MIT
