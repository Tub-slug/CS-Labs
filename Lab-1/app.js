// ============================================================
// Lab 1 — Monolith App  (Node.js + SQLite → later MySQL/RDS)
// ============================================================
// Phase 1: runs with local SQLite  (no env vars needed)
// Phase 2: set DB_HOST / DB_USER / DB_PASS / DB_NAME to use RDS
// ============================================================

const express = require('express');
const os      = require('os');
const app     = express();

app.use(express.json());
app.use(express.urlencoded({ extended: true }));

// ── Database factory ─────────────────────────────────────────
// If DB_HOST is set  → MySQL (Phase 2, RDS)
// Otherwise          → SQLite (Phase 1, local monolith)
let db;

if (process.env.DB_HOST) {
  // ── Phase 2: MySQL / Amazon RDS ──────────────────────────
  const mysql = require('mysql2/promise');
  const pool  = mysql.createPool({
    host    : process.env.DB_HOST,
    user    : process.env.DB_USER    || 'admin',
    password: process.env.DB_PASS    || '',
    database: process.env.DB_NAME    || 'labdb',
    waitForConnections: true,
    connectionLimit   : 10,
  });

  db = {
    async init() {
      await pool.execute(`CREATE TABLE IF NOT EXISTS customers (
        id         INT AUTO_INCREMENT PRIMARY KEY,
        name       VARCHAR(100) NOT NULL,
        email      VARCHAR(150) NOT NULL UNIQUE,
        created_at DATETIME DEFAULT CURRENT_TIMESTAMP
      )`);
      await pool.execute(`INSERT IGNORE INTO customers (name, email) VALUES
        ('Alice Smith', 'alice@example.com'),
        ('Bob Jones',   'bob@example.com')`);
      console.log('✅ Connected to RDS MySQL at', process.env.DB_HOST);
    },
    async all(sql, params)         { const [rows] = await pool.execute(sql, params); return rows; },
    async run(sql, params)         { await pool.execute(sql, params); },
  };

} else {
  // ── Phase 1: SQLite (local monolith) ─────────────────────
  const fs     = require('fs');
  const sqlite = require('sqlite3').verbose();
  if (!fs.existsSync('./data')) fs.mkdirSync('./data');

  const raw = new sqlite.Database('./data/customers.db');
  db = {
    async init() {
      return new Promise((res, rej) => {
        raw.serialize(() => {
          raw.run(`CREATE TABLE IF NOT EXISTS customers (
            id         INTEGER PRIMARY KEY AUTOINCREMENT,
            name       TEXT NOT NULL,
            email      TEXT NOT NULL UNIQUE,
            created_at DATETIME DEFAULT CURRENT_TIMESTAMP
          )`);
          raw.run(`INSERT OR IGNORE INTO customers (name, email) VALUES
            ('Alice Smith', 'alice@example.com'),
            ('Bob Jones',   'bob@example.com')`, res);
        });
      });
      console.log('✅ Connected to local SQLite');
    },
    all(sql, params) {
      return new Promise((res, rej) =>
        raw.all(sql, params, (err, rows) => err ? rej(err) : res(rows)));
    },
    run(sql, params) {
      return new Promise((res, rej) =>
        raw.run(sql, params, (err) => err ? rej(err) : res()));
    },
  };
}

// ── Routes ───────────────────────────────────────────────────
app.get('/', (req, res) => {
  const dbInfo = process.env.DB_HOST
    ? `☁️  RDS MySQL — <code>${process.env.DB_HOST}</code>`
    : `💾 Local SQLite  (monolith mode)`;
  res.send(`<!DOCTYPE html><html><body style="font-family:Arial;max-width:720px;margin:40px auto;padding:20px">
  <h1>🖥️  AWS Lab 1 — Customer App</h1>
  <table border="1" cellpadding="6" style="border-collapse:collapse;margin-bottom:20px">
    <tr><td><b>Server hostname</b></td><td>${os.hostname()}</td></tr>
    <tr><td><b>Database</b></td><td>${dbInfo}</td></tr>
  </table>
  <h2>Add Customer</h2>
  <form method="POST" action="/customers">
    Name:  <input name="name"  required style="margin:4px"/> &nbsp;
    Email: <input name="email" type="email" required style="margin:4px"/>
    <button type="submit">Add</button>
  </form>
  <h2>Customers &nbsp;<small><a href="/customers">JSON</a></small></h2>
  <p><i>(hit <a href="/customers/html">this link</a> to see the live table)</i></p>
  </body></html>`);
});

app.get('/customers/html', async (req, res) => {
  const rows = await db.all('SELECT * FROM customers ORDER BY created_at DESC', []);
  const rows_html = rows.map(r =>
    `<tr><td>${r.id}</td><td>${r.name}</td><td>${r.email}</td><td>${r.created_at}</td></tr>`
  ).join('');
  res.send(`<!DOCTYPE html><html><body style="font-family:Arial;max-width:720px;margin:40px auto;padding:20px">
  <h2>Customers (served by <code>${os.hostname()}</code>)</h2>
  <table border="1" cellpadding="6" style="border-collapse:collapse">
    <tr><th>ID</th><th>Name</th><th>Email</th><th>Created</th></tr>
    ${rows_html}
  </table>
  <p><a href="/">← Back</a></p>
  </body></html>`);
});

app.get('/customers', async (req, res) => {
  const rows = await db.all('SELECT * FROM customers ORDER BY created_at DESC', []);
  res.json({ server: os.hostname(), db_host: process.env.DB_HOST || 'localhost-sqlite', customers: rows });
});

app.post('/customers', async (req, res) => {
  const { name, email } = req.body;
  try {
    await db.run('INSERT INTO customers (name, email) VALUES (?, ?)', [name, email]);
    res.redirect('/customers/html');
  } catch (err) {
    res.status(400).send('Error: ' + err.message);
  }
});

app.get('/health', (req, res) => res.json({ status: 'ok', hostname: os.hostname() }));

// ── Boot ─────────────────────────────────────────────────────
const PORT = process.env.PORT || 3000;
db.init().then(() => app.listen(PORT, () => console.log(`🚀 App listening on :${PORT}`)));
