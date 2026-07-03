# One Clock — Technical Specification v0.1

**Status:** Draft for Codex handoff  
**Date:** 2026-07-03  
**Product stage:** Personal MVP / Technical Planning  
**Primary platform:** macOS  
**Related artifacts:**

- `One Clock — Lean PRD v0.2`
- `Mac Focus Time Research.txt`
- `one-clock-mock-up-setup.png`
- `one-clock-mock-up-running.png`
- `one-clock-mock-up-finish.png`

> 本文件定義 MVP 的技術邊界、狀態與驗收規則。視覺稿是方向參考，不要求 Codex 逐像素複製；未確認之處以 `TBD` 標示，不應由 Coding Agent 自行擴充需求。

---

## 1. Technical Goal

建立一款 **macOS 原生、menu bar-only、local-first** 的浮動 Focus Timer。

使用者可：

1. 輸入目前任務。
2. 設定一段 Focus Sprint。
3. 在 Always-on-top 浮動視窗中持續看到任務與時間。
4. 暫停、恢復、增加或減少五分鐘。
5. 倒數歸零後進入 Overtime，而非自動結束。
6. 主動完成 Sprint，查看實際投入的 Focused Time。
7. 隱藏浮動視窗後，讓 Sprint 繼續在背景執行。
8. App 退出或異常關閉後，在下次啟動時恢復未完成 Sprint。

---

## 2. Confirmed Product and Technical Decisions

### 2.1 Platform and stack

- macOS 原生 App。
- Swift 作為主要程式語言。
- SwiftUI 負責畫面與一般互動。
- AppKit 負責特殊視窗生命週期與 Always-on-top 行為。
- 使用 `NSPanel` 或以 `NSWindow` 為基礎的自訂浮動視窗；最終選擇先由 technical spike 驗證。
- 第一版為單一使用者、單一裝置、單一 active Sprint。

### 2.2 App form

- App 為 **menu bar-only**。
- App 執行時不顯示 Dock icon。
- 以 macOS agent app 方式執行，暫定設定 `LSUIElement = YES`。
- Menu bar 提供顯示／隱藏視窗、Pause／Resume、Done 與 Quit 等主要操作。

### 2.3 Window close behavior

- 關閉或隱藏浮動視窗，不等於結束 Sprint。
- 視窗隱藏時：
  - App 繼續在背景執行。
  - Running Sprint 繼續計時。
  - Paused Sprint 保持暫停。
  - 到期事件仍須觸發。
- 使用者可從 menu bar 重新顯示視窗。

### 2.4 App quit and recovery

- 使用者選擇 `Quit One Clock` 時，不顯示確認視窗。
- App 必須先保存未完成 Sprint，再退出。
- App crash、強制關閉或 Mac 重啟後，應盡可能恢復最近的有效 snapshot。
- App 再次啟動時：
  - 沒有未完成 Sprint：顯示 Setup。
  - 有未完成 Sprint：顯示已恢復的 Paused 畫面。
- App 未執行期間：
  - 不扣除 Remaining Time。
  - 不增加 Focused Time。
  - 不增加 Overtime。
- 若退出前已進入 Overtime，下次啟動時恢復為 **Paused Overtime**。
- 使用者必須手動按 `Resume` 才重新開始計時。

---

## 3. Scope

### 3.1 In scope

- Menu bar-only app lifecycle。
- Always-on-top 浮動視窗。
- Setup、Running、Paused、Overtime、Result。
- Expanded、Collapsed、Hidden 三種視窗呈現狀態。
- 任務名稱輸入與清除。
- 自訂時間與 `-5`／`+5` 分鐘。
- Pause／Resume。
- Done。
- Focused Time 計算。
- Overtime 計算。
- 視窗位置與收合狀態保存。
- 未完成 Sprint 恢復。
- macOS notification、完成聲音與視窗動畫。
- 本機資料保存。
- Timer engine unit tests 與基本 manual QA。

### 3.2 Out of scope

- 使用者帳號與登入。
- Cloud sync 或跨裝置同步。
- iPhone、iPad、Windows、Web 版本。
- 多個同時計時器。
- 完整 task manager、project、tag 或 subtask。
- Calendar／Todo app 整合。
- App／網站 blocking。
- AI 功能或自動分析螢幕內容。
- 自動偵測 context switching。
- 歷史分析 dashboard、productivity score、streak。
- 團隊協作。
- App Store 上架、自動更新、付費功能。
- Launch at Login。
- 複雜設定頁。

---

## 4. Architecture

MVP 採用小型、可測試的職責分離，不建立企業級 abstraction。

```text
OneClockApp
├── App
│   ├── OneClockApp.swift
│   ├── AppDelegate.swift                     # App lifecycle / termination hooks
│   └── MenuBarContent.swift                  # Menu bar actions
│
├── Domain
│   ├── SprintState.swift                     # State enums and value types
│   ├── SprintSnapshot.swift                  # Codable persisted snapshot
│   └── SprintEngine.swift                    # Pure timer and transition logic
│
├── State
│   └── AppState.swift                        # Single source of truth
│
├── Views
│   ├── SetupView.swift
│   ├── RunningView.swift
│   ├── PausedView.swift
│   ├── OvertimeView.swift
│   ├── ResultView.swift
│   └── CollapsedView.swift
│
├── Window
│   ├── FloatingPanel.swift                   # NSPanel / NSWindow subclass
│   └── FloatingWindowController.swift        # Show, hide, resize, position
│
├── Services
│   ├── PersistenceStore.swift
│   ├── NotificationService.swift
│   └── SoundService.swift
│
└── Tests
    ├── SprintEngineTests.swift
    ├── SprintRecoveryTests.swift
    └── PersistenceStoreTests.swift
```

### Architecture constraints

- Timer 計算不可直接寫在 SwiftUI View 中。
- View 不可直接存取 `UserDefaults`。
- View 不可負責建立、關閉或調整 `NSPanel`。
- `SprintEngine` 應盡可能是純邏輯，以便 unit test。
- 不引入 Core Data、SwiftData、第三方 state-management framework 或 dependency-injection framework。
- 不為未驗證功能預建 plugin、sync 或 analytics 架構。

---

## 5. State Model

Sprint 狀態與視窗狀態必須分開管理。

### 5.1 Sprint phase

```swift
enum SprintPhase: String, Codable {
    case setup
    case running
    case paused
    case overtimeRunning
    case overtimePaused
    case completed
}
```

### 5.2 Window presentation

```swift
enum WindowPresentation: String, Codable {
    case expanded
    case collapsed
    case hidden
}
```

### 5.3 State transition rules

```text
Setup
  └── Start ───────────────────────────────→ Running

Running
  ├── Pause ───────────────────────────────→ Paused
  ├── Remaining reaches 00:00 ─────────────→ Overtime Running
  └── Done ────────────────────────────────→ Completed / Result

Paused
  ├── Resume ──────────────────────────────→ Running
  └── Done ────────────────────────────────→ Completed / Result

Overtime Running
  ├── Pause ───────────────────────────────→ Overtime Paused
  └── Done ────────────────────────────────→ Completed / Result

Overtime Paused
  ├── Resume ──────────────────────────────→ Overtime Running
  └── Done ────────────────────────────────→ Completed / Result

Completed / Result
  ├── New Sprint ──────────────────────────→ Setup（保留上一輪資料）
  └── Reset ───────────────────────────────→ Setup（清除資料）
```

### 5.4 Window transitions

Expanded、Collapsed、Hidden 不得改變 Sprint phase。

```text
Expanded ↔ Collapsed
Expanded → Hidden
Collapsed → Hidden
Hidden → Expanded or previous visible presentation
```

---

## 6. Timer Semantics

### 6.1 General rule

UI 每秒刷新僅用於顯示，不可依賴「每秒減一」作為時間來源。

Running segment 應以時間點計算：

```text
elapsed = currentDate - activeSegmentStartedAt
remaining = remainingAtSegmentStart - elapsed
```

Paused 時保存當下結果並清除 active segment start time。

此方式可避免：

- UI timer 被系統延遲造成 drift。
- 視窗隱藏時停止更新。
- App 失去焦點後時間不準。

### 6.2 Planned duration

- 預設時間：`25:00`。
- 顯示格式：`MM:SS`。
- 上限：`99:59`。
- 使用者可透過時間欄位直接輸入四位數字。
- 例如 `0500` 解析為 `05:00`。
- `+5` 每次增加五分鐘。
- `-5` 每次減少五分鐘。
- 所有調整都不得超過 `99:59`。

### 6.3 Running and pause

- Running 時增加 Focused Time，並減少 Remaining Time。
- Paused 時：
  - Remaining Time 不變。
  - Focused Time 不增加。
  - Overtime 不增加。
- Resume 後建立新的 active timing segment。

### 6.4 Overtime

- Remaining Time 到達 `00:00` 時：
  - 不自動完成 Sprint。
  - phase 轉為 `overtimeRunning`。
  - Overtime 從 `00:00` 開始向上計時。
  - Focused Time持續累加。
- 顯示建議：`+00:01`、`+00:02`。
- Overtime 狀態仍可 Pause、Resume、`+5` 與 Done。
- `+5` 在 Overtime 時，應將計時重新帶回 Remaining Time 或減少已產生 Overtime；具體演算法見 TBD-04。

### 6.5 Focused Time

Result 只顯示 **Focused Time**。

```text
Focused Time =
所有 Running segment 的總和
+ 所有 Overtime Running segment 的總和
```

Focused Time 不包含：

- Paused 時間。
- App 未執行期間。
- App 恢復後等待使用者 Resume 的時間。

### 6.6 Progress

Running 狀態的進度：

```text
progress = focusedBeforeOvertime / configuredDuration
```

- 值限制於 `0...1`。
- Overtime 後 progress 固定為 `1`，改以 Overtime 視覺狀態區分。
- `+5`／`-5` 改變 configured duration 時，progress 需重新計算。

---

## 7. Persistence and Recovery

### 7.1 Storage choice

MVP 暫定：

- `UserDefaults`：偏好與簡單設定。
- Codable JSON snapshot：未完成 Sprint。
- 不使用資料庫。

可將 Codable `Data` 存入 `UserDefaults`，或存於 Application Support；由 implementation spike 選擇較簡單且可測試的方式。

### 7.2 Persisted settings

```text
lastTaskTitle
lastConfiguredDurationSeconds
lastWindowPresentation
lastWindowFrame
notificationPermissionPrompted
```

### 7.3 Active Sprint snapshot

最低欄位：

```swift
struct SprintSnapshot: Codable {
    var schemaVersion: Int

    var taskTitle: String
    var configuredDurationSeconds: TimeInterval

    var phase: SprintPhase
    var remainingSecondsAtSnapshot: TimeInterval
    var focusedSecondsAtSnapshot: TimeInterval
    var overtimeSecondsAtSnapshot: TimeInterval

    var wasRunningAtSnapshot: Bool
    var lastHeartbeatAt: Date

    var windowPresentation: WindowPresentation
    var windowFrame: CodableWindowFrame?
}
```

實際命名可調整，但語意不得遺失。

### 7.4 Save triggers

立即保存：

- Start。
- Pause。
- Resume。
- `+5`／`-5`。
- 進入 Overtime。
- Done。
- New Sprint。
- Reset。
- 視窗 Expanded／Collapsed／Hidden。
- 視窗拖曳結束。
- 正常 Quit。
- App 即將終止。

Running 時另建立輕量 heartbeat，暫定每 **5 秒** 更新 snapshot。

原因：正常 Quit 可以精確保存，但 crash 不一定會執行 termination callback。Heartbeat 讓 crash recovery 的最大誤差控制在約五秒。

### 7.5 Recovery algorithm

App launch 時：

1. 讀取 active Sprint snapshot。
2. 若不存在 active snapshot：
   - 讀取上一輪設定。
   - 顯示 Setup。
3. 若存在且 phase 為 Running：
   - 使用 snapshot 中的數值。
   - 轉為 Paused。
   - 不計算 `now - lastHeartbeatAt`。
4. 若存在且 phase 為 Overtime Running：
   - 轉為 Overtime Paused。
   - 不增加離線 Overtime。
5. 若原本為 Paused：
   - 保持 Paused。
6. 自動顯示浮動視窗。
7. 使用者手動 Resume 後才繼續。

Done 後清除 active Sprint snapshot，但保留 last task、last duration 與 window preferences。

---

## 8. Window and Menu Bar Behavior

### 8.1 Menu bar

優先使用 SwiftUI `MenuBarExtra`。若 technical spike 發現無法滿足互動或生命週期，再改用 AppKit `NSStatusItem`。

建議 menu items：

#### Setup / no active Sprint

```text
Show / Hide One Clock
New Sprint
────────────
Quit One Clock
```

#### Running

```text
Show / Hide One Clock
Pause
Done
────────────
Quit One Clock
```

#### Paused

```text
Show / Hide One Clock
Resume
Done
────────────
Quit One Clock
```

#### Overtime

```text
Show / Hide One Clock
Pause / Resume
Done
────────────
Quit One Clock
```

### 8.2 Floating panel requirements

- 無標準 macOS title bar。
- Always-on-top。
- 可拖曳。
- 不允許使用者自由 resize；由 Expanded／Collapsed 狀態控制尺寸。
- 視窗位置需保存。
- 再次顯示時恢復先前位置。
- 若原本位置已不在任何可見螢幕範圍，將視窗移回目前主要螢幕可見區。
- 需測試：
  - 多螢幕。
  - 拔除外接螢幕。
  - Spaces。
  - Full Screen app。
  - App deactivation。
- 技術候選：
  - `NSPanel`
  - `isFloatingPanel = true`
  - `level = .floating`
  - 適當的 `collectionBehavior`
- 具體 flags 應由 spike 實測，不要只依照文件假設。

### 8.3 Hide behavior

- 視窗上的 close／hide action只呼叫 `orderOut` 或等效隱藏行為。
- 不銷毀 `AppState`。
- 不停止 timer。
- 不 terminate App。
- Menu bar 的 Show action重新顯示同一個 panel。

### 8.4 Launch behavior

- App 啟動後自動顯示 panel。
- 無 active Sprint：Setup。
- 有 active Sprint：Recovered Paused。
- App 不出現在 Dock。

---

## 9. UI Requirements

Mockups 定義資訊層級與主要控制；尺寸、材質、陰影與動畫可在實作中微調。

### 9.1 Setup

顯示：

- Task title text field。
- 清除 task title 的 `×`。
- 可直接編輯的 `MM:SS`。
- `-5`。
- `+5`。
- `Start`。

行為：

- Start 建立 active Sprint 並進入 Running。
- `+5`／`-5` 更新 planned duration。
- 重複按 `+5` 不可超過 `99:59`。
- New Sprint 後保留上一輪的 task 與 duration。
- Reset 清除 task 並將時間恢復為預設值；預設值仍列為 TBD-03。

### 9.2 Running

顯示：

- Task title。
- Remaining Time。
- Progress indicator。
- Collapse control。
- `-5`。
- Pause。
- `+5`。
- Done action。

行為：

- Task title 在 Running 中預設不可直接編輯。
- Pause 進入 Paused。
- Done 立即停止計時並進入 Result。
- Collapse 不影響 Running。

> 靜態 mockup 未完整呈現 Done；實作時仍必須提供可發現的 Done action，可放於 hover control、secondary button 或 menu bar。不可只存在於隱藏快捷鍵。

### 9.3 Paused

顯示：

- Task title。
- Frozen Remaining Time 或 Frozen Overtime。
- Paused status。
- Resume。
- `-5`／`+5`。
- Done。
- Collapse control。

### 9.4 Overtime

顯示：

- Task title。
- 明確 Overtime 狀態。
- 向上累計的 Overtime。
- Pause／Resume。
- `+5`。
- Done。
- 不自動跳到 Result。

### 9.5 Collapsed

最低資訊：

- Task title，單行截斷。
- Remaining Time 或 Overtime。
- Running／Paused 的簡單狀態。
- Expand control。

Collapsed 不顯示所有操作；Pause／Resume、Done 可從 menu bar 使用。

### 9.6 Result

顯示：

- `Sprint complete`。
- Task title。
- Focused Time。
- `New Sprint`。
- Close／hide action。

限制：

- Result 只顯示投入時間，不加入 productivity score、interruption count 或複雜分析。
- New Sprint 回到 Setup，不直接開始下一輪。
- New Sprint 保留上一輪設定。
- Reset 應可從 Setup 或 menu bar 執行。

---

## 10. Completion Event

Remaining Time 首次到達 `00:00` 時：

1. phase 轉為 Overtime Running。
2. 播放一次完成聲音。
3. 發送一次 macOS local notification。
4. 若 panel 可見，執行一次輕量視窗動畫。
5. 不自動停止 timer。
6. 不自動進入 Result。
7. 不自動開始新的 Sprint。
8. 此事件不得因每秒刷新而重複觸發。

### Notification permission

- 不在首次啟動時直接要求通知權限。
- 建議在第一次 Start Sprint 時，以有脈絡的方式請求。
- 若 permission denied：
  - App 不反覆要求。
  - Timer 與 Overtime 仍正常運作。
  - 可保留 in-app animation 與 app sound。
- Notification service 必須可單獨測試或 mock。

---

## 11. Error and Edge-case Handling

- 無效時間輸入不得 crash。
- 超過 `99:59` 時 clamp 至 `99:59`。
- 負數不得出現在 Setup。
- 快速連按 Pause／Resume 不得重複累加 segment。
- 完成事件只觸發一次。
- Done 後 timer 必須停止。
- 已 completed 的 Sprint 不可因舊 timer callback 再度更新。
- App 隱藏後 timer 仍準確。
- Menu bar action 與 panel action 必須作用於同一份 `AppState`。
- 多次 Show 不得建立多個 panel。
- 多次 Start 不得建立多個 active Sprint。
- Persistence decode 失敗時：
  - 不 crash。
  - 將損壞 snapshot 備份或清除。
  - 回到 Setup。
- Schema version 不相容時採安全 fallback。
- 外接螢幕拔除後視窗不可留在不可見座標。
- 正常 Quit 不顯示確認 dialog。

---

## 12. Testing Requirements

### 12.1 Unit tests — SprintEngine

至少涵蓋：

1. Start 從 Setup 進入 Running。
2. Running elapsed time 正確扣除 Remaining。
3. Running elapsed time 正確累加 Focused。
4. Pause 後時間停止。
5. Resume 不重複計算舊 segment。
6. 倒數到零進入 Overtime。
7. Overtime 正確累加。
8. Overtime Pause／Resume。
9. `+5`／`-5` 上限與下限。
10. Done 產生正確 Focused Time。
11. Completion event 只觸發一次。
12. New Sprint 保留上一輪設定。
13. Reset 清除資料。

### 12.2 Recovery tests

1. Running snapshot 啟動後恢復為 Paused。
2. Overtime Running snapshot 恢復為 Overtime Paused。
3. App 離線期間不增加 Focused Time。
4. App 離線期間不扣除 Remaining Time。
5. Paused snapshot 維持 Paused。
6. Done 後不再恢復 active Sprint。
7. Corrupted snapshot 安全 fallback。

### 12.3 Manual QA

- App 不出現在 Dock。
- Menu bar icon 存在且可操作。
- Panel Always-on-top。
- Hide 後 Sprint 繼續。
- Quit 後重新啟動，Sprint 以 Paused 恢復。
- 多螢幕拖曳與位置恢復。
- 拔除外接螢幕。
- Expanded／Collapsed。
- Notification authorized／denied。
- Panel hidden 時倒數到零。
- Mac sleep／wake，依 TBD-01 最終規則驗證。
- CPU 與 memory 不因每秒更新持續異常上升。

---

## 13. Technical Spike Before Full Build

先建立一個 bounded spike，不實作完整視覺。

### Spike objective

驗證 SwiftUI + AppKit 是否能可靠支援 One Clock 的核心桌面生命週期。

### Spike scope

- 建立 menu bar-only macOS app。
- 不顯示 Dock icon。
- 建立一個 SwiftUI content host 的浮動 panel。
- Panel Always-on-top。
- Show／Hide。
- Expanded／Collapsed。
- 拖曳並保存位置。
- 背景 timer。
- 正常 Quit 保存。
- Relaunch 恢復為 Paused。
- 倒數到零觸發 notification、sound 與簡單 animation。

### Spike out of scope

- 完整 glass visual。
- 完整 Setup／Result UI。
- Pixel-perfect layout。
- History、analytics、settings。
- App Store packaging。

### Spike acceptance criteria

- 不建立重複 panel。
- 隱藏 panel 後 timer 持續正確。
- Quit 與 relaunch 後資料恢復正確。
- Always-on-top 在一般 app、不同 Spaces 與至少一個 Full Screen 情境完成測試並記錄限制。
- 產出一份 `docs/spike-floating-window-findings.md`，記錄：
  - 採用 `NSPanel` 或 `NSWindow`。
  - 使用的 window flags。
  - 已知 macOS 限制。
  - 未通過項目。
  - 對正式架構的建議。

---

## 14. Recommended Implementation Order

```text
Issue 1  Project scaffold and floating-window lifecycle spike
Issue 2  Sprint domain model and timer engine with tests
Issue 3  Persistence and paused recovery
Issue 4  Menu bar actions and window controller
Issue 5  Setup screen
Issue 6  Running, Paused, and Collapsed states
Issue 7  Overtime and completion event
Issue 8  Result and New Sprint flow
Issue 9  Notifications, sound, and animation
Issue 10 Manual QA, edge cases, and visual refinement
```

每個 Issue 應限制在可獨立驗收的 scope，並使用獨立 branch。不要要求 Codex 一次完成整個 App。

---

## 15. Open Decisions / TBD

下列項目尚未由產品負責人正式確認，Codex 不得自行擴充或隱藏處理。

### TBD-01 — Mac sleep / wake

**建議：**Mac 進入 sleep 時自動保存並 Pause；wake 後維持 Paused，等待使用者 Resume。  
理由：睡眠期間通常不應算成 Focused Time，也可避免長時間 Overtime 失真。

### TBD-02 — Empty task title

**建議：**Task title 為必填；空白時 Start disabled。  
理由：產品核心是持續保存目前任務脈絡，而非純 timer。

### TBD-03 — Reset target

**建議：**Reset 後 task title 為空，duration 回到 `25:00`。  
需確認「清空」是否代表 `00:00` 或恢復預設時間。

### TBD-04 — `-5` and `+5` around zero

**建議：**

- Setup：`-5` 最低 clamp 至 `00:00`，`00:00` 時不可 Start。
- Running：若 `-5` 使 planned end 早於目前時間，立即進入相應 Overtime。
- Overtime：`+5` 先抵銷 Overtime；若尚有餘額，回到 Running Remaining Time。

需由產品負責人確認。

### TBD-05 — Minimum supported macOS

**技術假設：**先以 macOS 14+ 開發，以降低 SwiftUI state 與 Observation 實作成本。  
正式建立 Xcode project 前確認 deployment target。

### TBD-06 — Hidden panel at completion

**建議：**使用者主動隱藏 panel 後，倒數到零不強制把 panel 彈回前景；只發 notification、sound，menu bar icon 可顯示狀態。  
理由：避免隱藏行為被完成事件違反。

---

## 16. Definition of Done for MVP

MVP 可視為技術完成，需同時滿足：

- 可建立、開始、Pause、Resume、調整與完成 Sprint。
- Timer 在視窗顯示、收合、隱藏及 App 失焦時保持準確。
- 到零後進入 Overtime，不自動結束。
- Result 顯示正確 Focused Time。
- New Sprint 保留上一輪設定。
- Menu bar-only，無 Dock icon。
- 視窗可拖曳、收合並記住位置。
- Quit 不確認，未完成 Sprint 可恢復。
- Relaunch 一律以 Paused／Overtime Paused 恢復。
- App 未執行期間不計時。
- Notification permission denied 時 App 仍可正常使用。
- Timer engine 與 recovery 主要規則有 unit tests。
- Manual QA 未發現 blocking crash、重複 timer 或資料遺失問題。

---

## 17. Primary Technical References

- Apple — MenuBarExtra  
  https://developer.apple.com/documentation/swiftui/menubarextra
- Apple — LSUIElement  
  https://developer.apple.com/documentation/bundleresources/information-property-list/lsuielement
- Apple — NSPanel  
  https://developer.apple.com/documentation/appkit/nspanel
- Apple — Asking permission to use notifications  
  https://developer.apple.com/documentation/usernotifications/asking-permission-to-use-notifications
