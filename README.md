# InfoWidget Codex Usage

Windows 11 Rainmeter「資訊業務 Widget」的 Codex 用量顯示模組。

目前版本：`v1.0`

## 功能說明

- 顯示 Codex 方案，例如 `PLUS`
- 顯示 5 小時用量視窗剩餘百分比
- 顯示每週用量視窗剩餘百分比
- 顯示 5 小時與每週重置時間
- 顯示完整重置券數量
- 顯示最後更新時間
- 每 60 秒自動更新一次
- 透過 `codex app-server` JSON-RPC 讀取 `account/rateLimits/read`
- Rainmeter Skin 採 Windows 11 深色資訊卡風格

## 畫面資料來源

PowerShell 腳本會自動執行：

1. 尋找本機 `codex.exe`
2. 啟動 `codex app-server`
3. 送出 `initialize`
4. 送出 `initialized`
5. 呼叫 `account/rateLimits/read`
6. 輸出精簡 JSON 到 `@Resources\codex-usage.json`
7. Rainmeter 讀取 JSON 並更新畫面

## 安裝方式

將本專案內容放到 Rainmeter Skin 資料夾：

```text
D:\Documents\Rainmeter\Skins\InfoWidget
```

建議結構：

```text
InfoWidget
├─ CodexUsage.ini
└─ @Resources
   ├─ codex-usage.example.json
   └─ Scripts
      └─ Get-CodexUsage.ps1
```

若從 GitHub 下載整包專案，可在專案資料夾執行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File ".\Install.ps1"
```

Rainmeter 載入：

```text
InfoWidget\CodexUsage.ini
```

## 手動測試

在 PowerShell 執行：

```powershell
powershell.exe -NoProfile -ExecutionPolicy Bypass -File "D:\Documents\Rainmeter\Skins\InfoWidget\@Resources\Scripts\Get-CodexUsage.ps1" -OutputPath "D:\Documents\Rainmeter\Skins\InfoWidget\@Resources\codex-usage.json"
```

成功時會輸出類似：

```json
{
  "ok": true,
  "plan": "PLUS",
  "fiveHour": {
    "used": 18,
    "remaining": 82,
    "resetLabel": "13:42"
  },
  "weekly": {
    "used": 8,
    "remaining": 92,
    "resetLabel": "10/06 16:09"
  },
  "resetCredits": 1,
  "updated": "10:40"
}
```

## 系統需求

- Windows 11
- Rainmeter
- Codex CLI 已安裝並完成登入
- 可執行 `codex app-server`
- PowerShell 5.1 或更新版本

## 注意事項

- Rainmeter 可能吃不到一般終端機的 `PATH`，所以腳本會自動搜尋：

```text
C:\Users\<使用者>\AppData\Local\OpenAI\Codex\bin\*\codex.exe
```

- 若 JSON 顯示 `codex account authentication required to read rate limits`，代表 Codex CLI 尚未在該 Windows 使用者環境完成授權。
- 不建議把更新頻率設得低於 60 秒。

## 版本

目前穩定版：

```text
v1.0
```

後續新增功能時，建議從 GitHub 下載最新 release，再覆蓋 Rainmeter Skin 資料夾。
