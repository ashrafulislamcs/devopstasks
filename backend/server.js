const express = require('express');
const app = express();
const PORT = process.env.PORT || 8080;

// DB config comes from ConfigMap (non-sensitive) + Secret (password) via env vars
const dbConfig = {
  host: process.env.DB_HOST || 'not-configured',
  name: process.env.DB_NAME || 'not-configured',
  user: process.env.DB_USER || 'not-configured'
  // DB_PASSWORD is intentionally never read into a variable that gets logged
};

app.get('/', (req, res) => {
  res.status(200).send('Application is running');
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

// Used by the frontend to prove frontend -> backend connectivity
app.get('/api/info', (req, res) => {
  res.status(200).json({
    service: 'backend',
    dbHost: dbConfig.host,
    timestamp: new Date().toISOString()
  });
});

app.listen(PORT, () => {
  console.log(`Backend listening on port ${PORT}`);
});

module.exports = app;
