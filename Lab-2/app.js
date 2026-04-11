// ============================================================
// Lab 2 — Stateless App with Cookie-Based Session
// Demonstrates: server-side statelessness, ALB routing,
//               "Hello [Name]" stored in a cookie (not server RAM)
// ============================================================

const express = require('express');
const cookieParser = require('cookie-parser');
const os = require('os');

const app = express();
app.use(cookieParser());
app.use(express.urlencoded({ extended: true }));

const HOSTNAME = os.hostname();

// ── Routes ───────────────────────────────────────────────────

app.get('/', (req, res) => {
  // The name comes from the COOKIE — not from this server's memory.
  // That's what makes this stateless!
  const name = req.cookies.username || null;

  const welcomeBlock = name
    ? `<div style="background:#d4edda;padding:16px;border-radius:6px;margin:20px 0">
         <h2>👋 Hello, <strong>${name}</strong>!</h2>
         <p>Your name was stored in a <b>cookie</b>, not in server memory.</p>
         <a href="/logout">Log out</a>
       </div>`
    : `<div style="background:#fff3cd;padding:16px;border-radius:6px;margin:20px 0">
         <h2>Who are you?</h2>
         <form method="POST" action="/login">
           Name: <input name="username" required/> <button type="submit">Set Cookie</button>
         </form>
       </div>`;

  res.send(`<!DOCTYPE html><html><body style="font-family:Arial;max-width:720px;margin:40px auto;padding:20px">
    <h1>🍪 Lab 2 — Stateless Session Demo</h1>
    <table border="1" cellpadding="6" style="border-collapse:collapse;margin-bottom:10px">
      <tr><td><b>This request was handled by</b></td><td><code>${HOSTNAME}</code></td></tr>
      <tr><td><b>Cookie present?</b></td>      <td>${name ? '✅ Yes — <code>username=' + name + '</code>' : '❌ No cookie yet'}</td></tr>
    </table>
    ${welcomeBlock}
    <hr/>
    <h3>💡 Experiment</h3>
    <ol>
      <li>Enter your name and click "Set Cookie".</li>
      <li>Refresh this page many times — watch the hostname change as the ALB routes you to different servers.</li>
      <li>Your name persists on EVERY server → the state travels with the <b>client</b>, not the server.</li>
    </ol>
    <p><a href="/refresh-counter">View refresh counter (stored in cookie)</a></p>
  </body></html>`);
});

app.post('/login', (req, res) => {
  const name = req.body.username || 'Stranger';
  res.cookie('username', name, { httpOnly: true, maxAge: 86400000 }); // 1 day
  res.redirect('/');
});

app.get('/logout', (req, res) => {
  res.clearCookie('username');
  res.redirect('/');
});

// Bonus: shows a counter incremented per-client via cookie
app.get('/refresh-counter', (req, res) => {
  const count = parseInt(req.cookies.refreshCount || '0') + 1;
  res.cookie('refreshCount', String(count), { httpOnly: true });
  res.send(`<!DOCTYPE html><html><body style="font-family:Arial;max-width:720px;margin:40px auto;padding:20px">
    <h1>🔄 Refresh Counter</h1>
    <p>You have visited this URL <b>${count}</b> time(s).</p>
    <p>Server handling this request: <code>${HOSTNAME}</code></p>
    <p>The counter is stored in your <b>cookie</b>. The server does not remember it between requests.</p>
    <p><a href="/">← Back</a> | <a href="/refresh-counter">Refresh +1</a></p>
  </body></html>`);
});

app.get('/health', (req, res) => res.json({ status: 'ok', hostname: HOSTNAME }));

const PORT = process.env.PORT || 3000;
app.listen(PORT, () => console.log(`Lab 2 app on :${PORT}  [${HOSTNAME}]`));
