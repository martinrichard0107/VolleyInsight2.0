1. 在 backend 資料夾執行：
   npm install
   cp .env.example .env
   node server.js

2. 先把 schema.sql 匯入你的 MySQL。

3. Flutter 端 api_service.dart 的 baseUrl 要照你的環境改：
   - Android Emulator: http://10.0.2.2:3000/api
   - iOS Simulator / mac 本機: http://127.0.0.1:3000/api
   - 手機實機: http://你的電腦IP:3000/api

4. 這套 API 流程：
   - 開始比賽：POST /api/matches/start
   - 儲存 lineup：POST /api/lineups/batch
   - 每一球：POST /api/events
   - Undo：DELETE /api/events/:id
   - 結束比賽：PATCH /api/matches/:id/finish
   - 報表：GET /api/matches/:id/dashboard
