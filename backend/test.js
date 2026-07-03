// Minimal smoke test - no external test framework required, used by CI
const http = require('http');
const { spawn } = require('child_process');

const server = spawn('node', ['server.js'], { env: { ...process.env, PORT: 8081 } });

function check(path, expectedStatus) {
  return new Promise((resolve, reject) => {
    http.get(`http://localhost:8081${path}`, (res) => {
      if (res.statusCode === expectedStatus) resolve();
      else reject(new Error(`${path} returned ${res.statusCode}, expected ${expectedStatus}`));
    }).on('error', reject);
  });
}

setTimeout(async () => {
  try {
    await check('/', 200);
    await check('/health', 200);
    console.log('All tests passed');
    server.kill();
    process.exit(0);
  } catch (err) {
    console.error('Test failed:', err.message);
    server.kill();
    process.exit(1);
  }
}, 1000);
