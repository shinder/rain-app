const express = require('express');
const path = require('path');
const app = express();

// 監聽 Cloud Run 提供的 $PORT
const port = process.env.PORT || 8080;

app.get('/rain-api', async (req, res) => {
  const url = 'https://wic.heo.taipei/OpenData/API/Rain/Get?stationNo=&loginId=open_rain&dataKey=85452C1D';

  const r = await fetch(url);
  const data = await r.json();
  res.json(data);
})

// 將 Vue 專案編譯後的 dist 當作靜態檔案
app.use(express.static('dist'));

// 所有路由導向 index.html
app.use((req, res) => {
  res.sendFile(path.join(__dirname, 'dist', 'index.html'));
});

app.listen(port, '0.0.0.0', () => {
  console.log(`Server listening on port ${port}`);
});
