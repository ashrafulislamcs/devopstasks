const express = require('express');
const path = require('path');
const app = express();
const PORT = process.env.PORT || 3000;

// In k8s this points at the backend ClusterIP Service DNS name, e.g. http://backend:8080
const BACKEND_URL = process.env.BACKEND_URL || 'http://localhost:8080';

app.use(express.static(path.join(__dirname, 'public')));

// Frontend server proxies the call so the browser never needs backend network access directly
app.get('/api/backend-status', async (req, res) => {
  try {
    const response = await fetch(`${BACKEND_URL}/health`);
    const data = await response.json();
    res.status(200).json({ backend: data, backendUrl: BACKEND_URL });
  } catch (err) {
    res.status(502).json({ error: 'Could not reach backend', backendUrl: BACKEND_URL });
  }
});

app.get('/health', (req, res) => {
  res.status(200).json({ status: 'ok' });
});

app.listen(PORT, () => {
  console.log(`Frontend listening on port ${PORT}, backend at ${BACKEND_URL}`);
});
