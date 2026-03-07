package main

import (
	"encoding/json"
	"flag"
	"fmt"
	"html"
	"log"
	"net/http"
	"os"
	"path/filepath"
	"strings"
	"sync"
	"time"
)

type entry struct {
	Domain    string    `json:"domain"`
	ExpiresAt time.Time `json:"expires_at"`
}

var (
	mu        sync.Mutex
	entries   []entry
	allowFile string
	blockyAPI string
)

func main() {
	listen := flag.String("listen", ":4001", "listen address")
	flag.StringVar(&allowFile, "allowlist", "/var/lib/blocky-allowlist/allowlist.txt", "path to allowlist file")
	flag.StringVar(&blockyAPI, "blocky-api", "http://localhost:4000", "blocky API base URL")
	flag.Parse()

	// Start with a clean allowlist
	if err := writeAllowlist(); err != nil {
		log.Fatalf("failed to initialize allowlist: %v", err)
	}
	refreshBlocky()

	go reaper()

	http.HandleFunc("/", handleIndex)
	http.HandleFunc("/allow", handleAllow)
	http.HandleFunc("/remove", handleRemove)
	http.HandleFunc("/check", handleCheck)

	log.Printf("listening on %s", *listen)
	log.Fatal(http.ListenAndServe(*listen, nil))
}

// reaper removes expired entries every 30 seconds.
func reaper() {
	for {
		time.Sleep(30 * time.Second)
		mu.Lock()
		changed := false
		now := time.Now()
		kept := entries[:0]
		for _, e := range entries {
			if e.ExpiresAt.After(now) {
				kept = append(kept, e)
			} else {
				changed = true
				log.Printf("expired: %s", e.Domain)
			}
		}
		entries = kept
		mu.Unlock()
		if changed {
			if err := writeAllowlist(); err != nil {
				log.Printf("error writing allowlist: %v", err)
			}
			refreshBlocky()
		}
	}
}

func writeAllowlist() error {
	mu.Lock()
	lines := make([]string, len(entries))
	for i, e := range entries {
		lines[i] = e.Domain
	}
	mu.Unlock()

	dir := filepath.Dir(allowFile)
	tmp, err := os.CreateTemp(dir, ".allowlist-*.tmp")
	if err != nil {
		return fmt.Errorf("create temp: %w", err)
	}
	content := strings.Join(lines, "\n")
	if len(lines) > 0 {
		content += "\n"
	}
	if _, err := tmp.WriteString(content); err != nil {
		tmp.Close()
		os.Remove(tmp.Name())
		return fmt.Errorf("write: %w", err)
	}
	if err := tmp.Close(); err != nil {
		os.Remove(tmp.Name())
		return fmt.Errorf("close: %w", err)
	}
	if err := os.Rename(tmp.Name(), allowFile); err != nil {
		os.Remove(tmp.Name())
		return fmt.Errorf("rename: %w", err)
	}
	return nil
}

func refreshBlocky() {
	resp, err := http.Post(blockyAPI+"/api/lists/refresh", "", nil)
	if err != nil {
		log.Printf("blocky refresh error: %v", err)
		return
	}
	resp.Body.Close()
	if resp.StatusCode != http.StatusOK {
		log.Printf("blocky refresh returned %d", resp.StatusCode)
	}
}

func handleAllow(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	domain := strings.TrimSpace(r.FormValue("domain"))
	durStr := r.FormValue("duration")
	if domain == "" {
		http.Error(w, "domain required", http.StatusBadRequest)
		return
	}
	domain = strings.ToLower(domain)

	dur, err := time.ParseDuration(durStr)
	if err != nil || dur <= 0 || dur > 24*time.Hour {
		http.Error(w, "invalid duration", http.StatusBadRequest)
		return
	}

	mu.Lock()
	// Replace existing entry for same domain
	found := false
	for i, e := range entries {
		if e.Domain == domain {
			entries[i].ExpiresAt = time.Now().Add(dur)
			found = true
			break
		}
	}
	if !found {
		entries = append(entries, entry{Domain: domain, ExpiresAt: time.Now().Add(dur)})
	}
	mu.Unlock()

	log.Printf("allowed: %s for %s", domain, dur)
	if err := writeAllowlist(); err != nil {
		log.Printf("error writing allowlist: %v", err)
		http.Error(w, "internal error", http.StatusInternalServerError)
		return
	}
	refreshBlocky()

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func handleRemove(w http.ResponseWriter, r *http.Request) {
	if r.Method != http.MethodPost {
		http.Error(w, "method not allowed", http.StatusMethodNotAllowed)
		return
	}
	domain := strings.TrimSpace(r.FormValue("domain"))
	if domain == "" {
		http.Error(w, "domain required", http.StatusBadRequest)
		return
	}

	mu.Lock()
	kept := entries[:0]
	for _, e := range entries {
		if e.Domain != domain {
			kept = append(kept, e)
		}
	}
	entries = kept
	mu.Unlock()

	log.Printf("removed: %s", domain)
	if err := writeAllowlist(); err != nil {
		log.Printf("error writing allowlist: %v", err)
	}
	refreshBlocky()

	http.Redirect(w, r, "/", http.StatusSeeOther)
}

func handleCheck(w http.ResponseWriter, r *http.Request) {
	domain := strings.TrimSpace(r.URL.Query().Get("domain"))
	if domain == "" {
		http.Error(w, "domain required", http.StatusBadRequest)
		return
	}

	reqBody := fmt.Sprintf(`{"query":"%s","type":"A"}`, domain)
	resp, err := http.Post(blockyAPI+"/api/query", "application/json", strings.NewReader(reqBody))
	if err != nil {
		http.Error(w, fmt.Sprintf("blocky query error: %v", err), http.StatusBadGateway)
		return
	}
	defer resp.Body.Close()

	var result struct {
		Reason       string `json:"reason"`
		ResponseType string `json:"responseType"`
		Response     string `json:"response"`
	}
	if err := json.NewDecoder(resp.Body).Decode(&result); err != nil {
		http.Error(w, "failed to parse blocky response", http.StatusBadGateway)
		return
	}

	w.Header().Set("Content-Type", "application/json")
	json.NewEncoder(w).Encode(result)
}

func handleIndex(w http.ResponseWriter, r *http.Request) {
	if r.URL.Path != "/" {
		http.NotFound(w, r)
		return
	}

	mu.Lock()
	now := time.Now()
	var rows string
	for _, e := range entries {
		remaining := e.ExpiresAt.Sub(now).Truncate(time.Second)
		rows += fmt.Sprintf(`<tr>
			<td>%s</td>
			<td>%s</td>
			<td><form method="POST" action="/remove" style="margin:0">
				<input type="hidden" name="domain" value="%s">
				<button type="submit" class="btn btn-sm btn-danger">Remove</button>
			</form></td>
		</tr>`, html.EscapeString(e.Domain), remaining, html.EscapeString(e.Domain))
	}
	mu.Unlock()

	w.Header().Set("Content-Type", "text/html; charset=utf-8")
	fmt.Fprintf(w, indexHTML, rows)
}

const indexHTML = `<!DOCTYPE html>
<html lang="en">
<head>
<meta charset="utf-8">
<meta name="viewport" content="width=device-width, initial-scale=1">
<title>Blocky Allowlist</title>
<style>
  :root { --bg: #1a1a2e; --surface: #16213e; --accent: #0f3460; --text: #e0e0e0; --green: #4ecca3; --red: #e74c3c; }
  * { box-sizing: border-box; margin: 0; padding: 0; }
  body { font-family: -apple-system, BlinkMacSystemFont, "Segoe UI", Roboto, sans-serif; background: var(--bg); color: var(--text); padding: 1rem; max-width: 600px; margin: 0 auto; }
  h1 { font-size: 1.3rem; margin-bottom: 1rem; color: var(--green); }
  h2 { font-size: 1.1rem; margin: 1.5rem 0 0.5rem; }
  .card { background: var(--surface); border-radius: 8px; padding: 1rem; margin-bottom: 1rem; }
  input[type=text] { width: 100%%; padding: 0.6rem; border: 1px solid var(--accent); border-radius: 4px; background: var(--bg); color: var(--text); font-size: 1rem; margin-bottom: 0.5rem; }
  select { width: 100%%; padding: 0.6rem; border: 1px solid var(--accent); border-radius: 4px; background: var(--bg); color: var(--text); font-size: 1rem; margin-bottom: 0.5rem; }
  .btn { padding: 0.6rem 1.2rem; border: none; border-radius: 4px; font-size: 1rem; cursor: pointer; color: #fff; }
  .btn-primary { background: var(--green); color: #1a1a2e; font-weight: 600; width: 100%%; }
  .btn-sm { padding: 0.3rem 0.8rem; font-size: 0.85rem; }
  .btn-danger { background: var(--red); }
  .btn-check { background: var(--accent); width: 100%%; }
  table { width: 100%%; border-collapse: collapse; }
  th, td { text-align: left; padding: 0.4rem 0.5rem; border-bottom: 1px solid var(--accent); }
  th { color: var(--green); font-size: 0.85rem; text-transform: uppercase; }
  #check-result { margin-top: 0.5rem; padding: 0.5rem; border-radius: 4px; display: none; font-size: 0.9rem; }
  .blocked { background: rgba(231,76,60,0.2); border: 1px solid var(--red); }
  .not-blocked { background: rgba(78,204,163,0.2); border: 1px solid var(--green); }
</style>
</head>
<body>
<h1>Blocky Allowlist</h1>

<div class="card">
  <h2>Temporarily Allow Domain</h2>
  <form method="POST" action="/allow">
    <input type="text" name="domain" placeholder="example.com" required autocapitalize="none" autocorrect="off">
    <select name="duration">
      <option value="15m">15 minutes</option>
      <option value="1h" selected>1 hour</option>
      <option value="4h">4 hours</option>
      <option value="24h">24 hours</option>
    </select>
    <button type="submit" class="btn btn-primary">Allow</button>
  </form>
</div>

<div class="card">
  <h2>Check Domain</h2>
  <input type="text" id="check-domain" placeholder="example.com" autocapitalize="none" autocorrect="off">
  <button class="btn btn-check" onclick="checkDomain()">Check</button>
  <div id="check-result"></div>
</div>

<div class="card">
  <h2>Active Entries</h2>
  <table>
    <thead><tr><th>Domain</th><th>Expires In</th><th></th></tr></thead>
    <tbody>%s</tbody>
  </table>
</div>

<script>
async function checkDomain() {
  const d = document.getElementById('check-domain').value.trim();
  const el = document.getElementById('check-result');
  if (!d) return;
  el.style.display = 'block';
  el.className = '';
  el.textContent = 'Checking...';
  try {
    const r = await fetch('/check?domain=' + encodeURIComponent(d));
    const j = await r.json();
    if (j.reason === 'BLOCKED') {
      el.className = 'blocked';
      el.textContent = 'BLOCKED: ' + j.reason + ' (' + j.responseType + ')';
    } else {
      el.className = 'not-blocked';
      el.textContent = 'NOT BLOCKED: ' + j.reason;
    }
  } catch(e) {
    el.className = 'blocked';
    el.textContent = 'Error: ' + e.message;
  }
}
</script>
</body>
</html>
`
