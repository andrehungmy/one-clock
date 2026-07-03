# One Clock — Lean PRD v0.2 Update

**更新日期：** 2026-07-03  
**更新範圍：** Timer alert、New Sprint、時間上限、浮動視窗、操作名稱與圖示

---

# 1. 操作名稱與圖示定義

One Clock 使用兩種不同的計時控制：

## Pause／Resume

Pause 代表暫時停止計時，但保留目前 Focus Sprint。

建議圖示：

```text
Pause：Ⅱ
Resume：▶
```

Pause 後：

- Remaining Time 停止倒數。
- 目前任務與完成目標保留。
- 使用者仍可 `+5 min` 或 `−5 min`。
- 使用者可以 Resume，繼續原本的 Focus Sprint。
- Pause 不進入 Result Screen。

## Finish

Finish 代表正式結束本次 Focus Sprint。

建議圖示：

```text
Finish：■
```

Finish 後：

- 本次 Focus Sprint 結束。
- 系統停止所有計時。
- 使用者進入 Result Screen。
- 已進入 Result Screen 的 Sprint 不可再恢復或延長。

MVP 不再使用 `Stop` 作為產品操作名稱，以避免與 Pause 語意混淆。

---

# 2. 更新後的核心操作

## Running State

提供：

```text
[Ⅱ Pause]  [+5]  [−5]  [■ Finish]
```

## Paused State

提供：

```text
[▶ Resume]  [+5]  [−5]  [■ Finish]
```

## Overtime State

提供：

```text
[Ⅱ Pause]  [+5]  [■ Finish]
```

使用者不需要按下「Continue Overtime」。

未執行任何操作時，Overtime 自動持續正向累計。

## Paused Overtime State

提供：

```text
[▶ Resume]  [+5]  [■ Finish]
```

---

# 3. 更新後的 State Transition

| Current State | Action | Next State |
|---|---|---|
| Setup | Start | Running |
| Running | Pause | Paused |
| Paused | Resume | Running |
| Running | Finish | Result |
| Paused | Finish | Result |
| Running | Remaining Time 到達 00:00 | Overtime |
| Overtime | Pause | Paused Overtime |
| Paused Overtime | Resume | Overtime |
| Overtime | +5 min | Running，Remaining Time = 05:00 |
| Paused Overtime | +5 min | Paused，Remaining Time = 05:00 |
| Overtime | Finish | Result |
| Paused Overtime | Finish | Result |
| Result | New Sprint | Setup，保留上一輪設定 |
| Result | Done | 結束操作流程 |

---

# 4. 時間到達 00:00 的提醒

當 Running 狀態的 Remaining Time 到達 `00:00` 時，系統應同時執行：

1. 播放提示聲音。
2. 發送 macOS Notification。
3. 在浮動視窗執行狀態轉換動畫。
4. 將狀態切換為 Overtime。
5. 從 `00:00` 開始正向累計 Overtime。

## 視窗動畫目的

動畫用來讓使用者注意到原設定時間已結束，但不應阻止或強制中斷使用者目前的工作。

動畫應：

- 短暫。
- 清楚但不過度劇烈。
- 不改變視窗位置。
- 不要求使用者立即回應。
- 動畫結束後保持 Overtime 狀態。

具體動畫形式於 Wireframe／Visual Design 階段決定。

可能形式包括：

- 輕微放大後恢復。
- 邊框短暫閃動。
- 狀態文字由 Running 轉換為 Overtime。
- 背景或進度元素短暫變化。

## macOS Notification 行為

若使用者已允許通知，系統應發出本機通知。

若使用者拒絕通知權限：

- Focus Sprint 仍正常進入 Overtime。
- 聲音與浮動視窗動畫仍應正常運作。
- 不得因缺少通知權限而造成計時錯誤。

通知內容至少包含：

- 時間已到
- 目前任務名稱

---

# 5. New Sprint 預設值

使用者在 Result Screen 按下 `New Sprint` 後，回到 Setup Screen。

Setup Screen 預設保留上一輪的：

- Planned Duration
- 目前任務
- 選填完成目標

使用者可以直接修改任何欄位並開始下一輪。

## Reset

Setup Screen 應提供 Reset 操作。

按下 Reset 後：

- 時間清空或恢復初始預設值。
- 目前任務清空。
- 完成目標清空。
- 不影響已經結束的 Result 資訊。
- 不會自動開始新的 Focus Sprint。

Reset 的具體圖示與位置於 Wireframe 階段決定。

---

# 6. 時間上限

以下時間皆不得超過：

```text
99:59
```

適用範圍包括：

- Setup Screen 的初始設定時間。
- Running 狀態的 Remaining Time。
- Paused 狀態的 Remaining Time。
- 連續按下 `+5 min` 後的 Remaining Time。

例如，目前 Remaining Time 為：

```text
98:00
```

使用者按下 `+5 min` 後，最大只能顯示：

```text
99:59
```

不得顯示：

```text
103:00
```

當 Remaining Time 已經是 `99:59` 時：

- `+5 min` 不再增加時間。
- 系統不得發生時間溢位。
- 是否將按鈕設為 Disabled，於 Interaction Design 階段決定。

Overtime 為正向累計時間，不受 `99:59` 的 Remaining Time 上限規則限制。Overtime 的長時間顯示格式應在 Technical Spec 中定義。

---

# 7. 浮動視窗規格

## 7.1 視窗性質

Active Focus Sprint 使用小型 Always-on-top 浮動視窗。

視窗應：

- 保持在一般 App 視窗上方。
- 不佔用過多桌面空間。
- 適合放置於螢幕四角或邊緣。
- 能持續顯示時間與目前任務。

## 7.2 尺寸單位

macOS 介面規格應使用 **points（pt）**，而不是直接使用實體像素。

**專業說法：Points。**  
**白話解釋：**macOS 用來描述介面尺寸的邏輯單位，系統會依 Retina 螢幕自動換算實際像素。

視窗的精確寬度與高度不在本 PRD 中鎖定，應在 Low-fidelity Wireframe 與實機測試後決定。

初步設計方向：

- Expanded：能完整顯示時間、任務、選填目標與控制按鈕。
- Collapsed：只保留最重要的計時與任務提示。
- 視窗不得大到明顯遮擋主要工作內容。

## 7.3 拖曳位置

使用者可以拖曳浮動視窗至螢幕上的適合位置。

視窗應：

- 支援自由拖曳。
- 可放置於螢幕角落或邊緣。
- 不強制吸附至特定位置。
- 拖曳後不影響計時狀態。

## 7.4 記住上次位置

App 應記住浮動視窗最後一次的位置。

下一次顯示浮動視窗時：

- 優先顯示於上次位置。
- 若上次位置已不在目前可用螢幕範圍內，系統應將視窗移至可見區域。
- 多螢幕與螢幕移除情境應於 Technical Spec 與 QA 中處理。

## 7.5 收合模式

浮動視窗應支援 Expanded 與 Collapsed 兩種模式。

### Expanded

至少顯示：

- Status
- Remaining Time 或 Overtime
- 目前任務
- 選填完成目標
- 計時控制

### Collapsed

至少顯示：

- Remaining Time 或 Overtime
- 目前狀態
- 展開控制

是否同時顯示縮短後的任務名稱，於 Wireframe 階段決定。

切換收合模式時：

- 不得改變計時狀態。
- 不得重設時間。
- 不得清除任務資料。

## 7.6 秒數顯示

所有主要計時狀態皆顯示秒數。

倒數格式：

```text
MM:SS
```

Overtime 格式：

```text
MM:SS
```

秒數應每秒更新。

## 7.7 透明度

使用者可以調整浮動視窗透明度。

透明度設定應：

- 只影響浮動視窗的視覺呈現。
- 不影響按鈕操作。
- 不影響 Always-on-top 行為。
- 儲存在本機。
- 下次開啟時保留上次設定。

可用透明度範圍與調整方式於 Interaction Design 階段定義。

---

# 8. Result Screen 更新

所有 Finish 操作進入相同 Result Screen。

Result Screen 顯示：

- 本次任務。
- 選填完成目標。
- Planned Duration。
- Actual Focus Time。
- `New Sprint`。
- `Done`。

Result Screen 不需要記錄或顯示：

- 使用者是在 Running、Paused 或 Overtime 按下 Finish。
- Focus Sprint 是否提前結束。
- 使用者結束 Sprint 的原因。

## New Sprint

按下 New Sprint：

- 回到 Setup Screen。
- 保留上一輪的所有設定欄位。
- 不延長已結束的 Focus Sprint。

## Done

按下 Done：

- 結束 Result 流程。
- 本次 Focus Sprint 維持已結束狀態。

---

# 9. 新增 Functional Requirements

## FR-022：時間到提醒

Remaining Time 到達 `00:00` 時，系統應播放提示聲、發出 macOS Notification，並執行浮動視窗動畫。

## FR-023：通知權限降級

使用者未授予 Notification 權限時，系統仍須正常播放聲音、執行視窗動畫並進入 Overtime。

## FR-024：New Sprint 保留設定

Result Screen 按下 New Sprint 後，Setup Screen 應保留上一輪時間、任務與完成目標。

## FR-025：Reset

Setup Screen 應提供 Reset，以清除所有上一輪保留的輸入資料。

## FR-026：Remaining Time 上限

任何加時操作不得使 Remaining Time 超過 `99:59`。

## FR-027：視窗拖曳

使用者應能拖曳浮動視窗，且拖曳不應影響 Focus Sprint 狀態。

## FR-028：視窗位置保存

系統應在本機保存浮動視窗最後位置，並於下次顯示時恢復。

## FR-029：收合模式

使用者應能在 Expanded 與 Collapsed 間切換，不影響計時與任務資料。

## FR-030：秒數顯示

Running、Paused、Overtime 與 Paused Overtime 都應顯示秒數。

## FR-031：透明度

使用者應能調整浮動視窗透明度，且設定應在本機保存。

## FR-032：Finish

Running、Paused、Overtime 與 Paused Overtime 狀態皆應提供 Finish 操作，並進入 Result Screen。

---

# 10. 新增 Acceptance Criteria

## AC-013：時間到提醒

**Given** Focus Sprint 處於 Running  
**And** Remaining Time 為 `00:01`  
**When** 一秒經過  
**Then** 系統進入 Overtime  
**And** 播放提示聲音  
**And** 發出 macOS Notification（若已取得權限）  
**And** 執行浮動視窗動畫

## AC-014：New Sprint 保留資料

**Given** 使用者已完成一個 Focus Sprint  
**When** 使用者在 Result Screen 按 New Sprint  
**Then** Setup Screen 顯示上一輪 Planned Duration  
**And** 顯示上一輪目前任務  
**And** 顯示上一輪完成目標

## AC-015：Reset

**Given** Setup Screen 保留上一輪資料  
**When** 使用者按 Reset  
**Then** 所有設定欄位被清除或恢復初始預設值  
**And** 不會自動開始 Focus Sprint

## AC-016：加時上限

**Given** Remaining Time 為 `98:00`  
**When** 使用者按 `+5 min`  
**Then** Remaining Time 不得超過 `99:59`

## AC-017：拖曳視窗

**Given** Focus Sprint 正在計時  
**When** 使用者拖曳浮動視窗  
**Then** 視窗移至新位置  
**And** 計時不中斷  
**And** Focus Sprint 狀態不變

## AC-018：恢復視窗位置

**Given** 使用者曾將浮動視窗移至新位置  
**When** 浮動視窗下次出現  
**Then** 系統應優先恢復上次位置

## AC-019：收合

**Given** 浮動視窗處於 Expanded  
**When** 使用者切換至 Collapsed  
**Then** 視窗縮小  
**And** 計時狀態不變  
**And** 任務資料不被清除

## AC-020：透明度

**Given** 浮動視窗正在顯示  
**When** 使用者調整透明度  
**Then** 視窗呈現對應透明度  
**And** 控制按鈕仍可操作  
**And** 計時不受影響

---

# 11. 已關閉的 Open Decisions

以下項目已完成產品決策：

- Open-01：時間到達 `00:00` 使用聲音、macOS Notification 與浮動視窗動畫提醒。
- Open-02：New Sprint 保留所有上一輪設定，並提供 Reset。
- Open-03：Remaining Time 的加時上限為 `99:59`。
- Open-04：浮動視窗可拖曳、記住位置、支援收合、顯示秒數並可調整透明度。
- Open-05：不再使用 Stop；暫停稱為 Pause，正式結束稱為 Finish。

---

# 12. 仍待 Wireframe 決定的介面細節

以下不是產品需求缺口，而是下一階段的 Interaction／Visual Design 決策：

- Expanded 視窗的實際 pt 尺寸。
- Collapsed 視窗的實際 pt 尺寸。
- Collapsed 是否顯示任務名稱。
- 透明度調整入口與數值範圍。
- 收合／展開按鈕位置。
- Reset 的圖示與位置。
- 時間到達時的動畫形式。
- Notification 的最終文案。
- Finish 是否同時顯示文字與方形圖示。