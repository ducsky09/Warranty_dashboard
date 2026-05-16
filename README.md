# MediaMart Warranty – Cloudflare D1 + Workers + GitHub Actions

## Cấu trúc project

```
warranty-system/
├── .github/
│   └── workflows/
│       └── sync-to-d1.yml       ← GitHub Actions tự động sync
├── data/
│   ├── PENDING.xlsx             ← File data (commit lên đây để trigger sync)
│   └── FINISHED.xlsx
├── scripts/
│   ├── excel_to_sql.py          ← Convert Excel → SQL
│   └── split_and_execute.py     ← Cắt SQL lớn & execute lên D1
├── worker/
│   ├── src/index.js             ← Cloudflare Workers API
│   └── wrangler.toml            ← Config Workers
├── schema.sql                   ← Database schema
└── README.md
```

---

## Bước 1 — Tạo Cloudflare account và cài Wrangler

```bash
# Đăng ký free tại cloudflare.com (không cần thẻ tín dụng)
npm install -g wrangler
wrangler login
```

---

## Bước 2 — Tạo D1 database

```bash
wrangler d1 create warranty-db
```

Output sẽ có dạng:
```
✅ Successfully created DB 'warranty-db'
database_id = "xxxxxxxx-xxxx-xxxx-xxxx-xxxxxxxxxxxx"
```

Copy `database_id` và dán vào `worker/wrangler.toml` thay `YOUR_DB_ID`.

---

## Bước 3 — Tạo schema

```bash
wrangler d1 execute warranty-db --file=schema.sql --remote
```

Kiểm tra:
```bash
wrangler d1 execute warranty-db \
  --command="SELECT name FROM sqlite_master WHERE type='table';" \
  --remote
```

---

## Bước 4 — Import data lần đầu (local)

```bash
pip install pandas openpyxl

# Convert Excel → SQL
python3 scripts/excel_to_sql.py --src PENDING  --mode full --schema --out /tmp/pending.sql
python3 scripts/excel_to_sql.py --src FINISHED --mode full          --out /tmp/finished.sql

# Upload lên D1
python3 scripts/split_and_execute.py --file /tmp/pending.sql  --db warranty-db
python3 scripts/split_and_execute.py --file /tmp/finished.sql --db warranty-db

# Kiểm tra
wrangler d1 execute warranty-db \
  --command="SELECT src, COUNT(*) as total FROM warranty GROUP BY src;" \
  --remote
```

---

## Bước 5 — Deploy Cloudflare Workers API

```bash
cd worker
wrangler deploy
```

Output:
```
✅  Deployed warranty-api
    https://warranty-api.YOUR_SUBDOMAIN.workers.dev
```

Test API:
```bash
curl https://warranty-api.YOUR_SUBDOMAIN.workers.dev/health
curl "https://warranty-api.YOUR_SUBDOMAIN.workers.dev/api/counts"
curl "https://warranty-api.YOUR_SUBDOMAIN.workers.dev/api/all?limit=10"
```

---

## Bước 6 — Setup GitHub Actions

### 6.1 Tạo Cloudflare API Token

Vào **Cloudflare Dashboard → My Profile → API Tokens → Create Token**:
- Template: **Edit Cloudflare Workers**
- Thêm permission: **D1 → Edit**
- Copy token

### 6.2 Thêm GitHub Secrets

Vào repo GitHub → **Settings → Secrets and variables → Actions → New repository secret**:

| Secret name | Giá trị |
|---|---|
| `CF_API_TOKEN` | Cloudflare API token vừa tạo |
| `CF_ACCOUNT_ID` | Account ID (Cloudflare Dashboard → sidebar phải) |
| `D1_DATABASE_ID` | Database ID từ bước 2 |

### 6.3 Commit data lên repo

```bash
git init
git add .
git commit -m "Initial setup"
git push origin main

# Lần sau muốn sync data mới:
cp /path/to/PENDING_new.xlsx data/PENDING.xlsx
git add data/PENDING.xlsx
git commit -m "Update PENDING data"
git push
# → GitHub Actions tự động chạy sync!
```

---

## Bước 7 — Kết nối Dashboard HTML

Thêm đoạn sau vào `index.html` (phần GSheet pane):

```html
<!-- Trong phần src-gsheet, thêm nút Workers -->
<div style="border-top:1px solid var(--bd);margin:12px 0 9px"></div>
<div style="font-size:.7rem;font-weight:700;color:var(--mu);margin-bottom:5px">
  CLOUDFLARE WORKERS URL
</div>
<input class="gs-url-input" id="cf-url-input"
  placeholder="https://warranty-api.YOUR_SUBDOMAIN.workers.dev"
  value="">
<button class="btn-gs" onclick="connectWorkers()"
  style="background:linear-gradient(135deg,#f38020,#e05c0a)">
  ☁️ Kết nối Cloudflare D1
</button>
<div class="gs-status" id="cf-status"></div>
```

```javascript
// Thêm vào phần <script> của index.html
const CF_PAGE_SIZE = 5000;

async function connectWorkers() {
  const base = (document.getElementById('cf-url-input')?.value || '').trim()
               .replace(/\/$/, '');
  if (!base) { showSt('cf-status', '⚠ Nhập URL Workers', 'err'); return; }

  showSt('cf-status', '⏳ Đang kết nối Cloudflare D1...', 'loading');

  try {
    // Kiểm tra health và lấy tổng số dòng trước
    const hRes  = await fetch(`${base}/health`);
    const hData = await hRes.json();
    const total = hData.total_rows || 0;

    showSt('cf-status', `⏳ Tải ${fmt(total)} dòng...`, 'loading');

    // Tải song song PENDING và FINISHED theo từng page
    const fetchSrc = async (src) => {
      let all = [], offset = 0;
      while (true) {
        const r = await fetch(
          `${base}/api/all?src=${src}&limit=${CF_PAGE_SIZE}&offset=${offset}`
        );
        const j = await r.json();
        all = all.concat(j.rows || []);
        if (!j.has_more) break;
        offset += CF_PAGE_SIZE;
        showSt('cf-status',
          `⏳ ${src}: ${fmt(all.length)}/${fmt(j.total)}...`, 'loading');
      }
      return all;
    };

    const [pending, finished] = await Promise.all([
      fetchSrc('PENDING'),
      fetchSrc('FINISHED'),
    ]);

    const rows = mergeRows(pending, finished);
    GS_MODE = true;
    GS_URL  = `CF:${base}`;

    showSt('cf-status',
      `✅ PENDING: ${fmt(pending.length)} · FINISHED: ${fmt(finished.length)} · Tổng: ${fmt(rows.length)}`,
      'ok');
    setTimeout(() => launchDashboard(rows, 'Cloudflare D1 · PENDING+FINISHED'), 400);

  } catch (e) {
    showSt('cf-status', '❌ ' + e.message, 'err');
  }
}
```

Cập nhật `silentRefresh()` để nhận biết nguồn CF:
```javascript
// Thêm vào đầu hàm silentRefresh(), trước block GS_URL.startsWith('CSV:')
if (GS_URL.startsWith('CF:')) {
  const base = GS_URL.slice(3);
  const fetchSrc = async (src) => {
    let all = [], offset = 0;
    while (true) {
      const r = await fetch(`${base}/api/all?src=${src}&limit=${CF_PAGE_SIZE}&offset=${offset}`);
      const j = await r.json();
      all = all.concat(j.rows || []);
      if (!j.has_more) break;
      offset += CF_PAGE_SIZE;
    }
    return all;
  };
  const [p, f] = await Promise.all([fetchSrc('PENDING'), fetchSrc('FINISHED')]);
  rows = mergeRows(p, f);
}
```

---

## Khi cần update data

### Cách 1 — Tự động qua GitHub (khuyên dùng)
```bash
cp /path/to/new_PENDING.xlsx data/PENDING.xlsx
git add data/PENDING.xlsx
git commit -m "Update PENDING $(date +%d/%m/%Y)"
git push
# Xong! Actions tự chạy trong ~2-5 phút
```

### Cách 2 — Thủ công từ máy local
```bash
python3 scripts/excel_to_sql.py --src PENDING --mode incremental --out /tmp/p.sql
python3 scripts/split_and_execute.py --file /tmp/p.sql --db warranty-db
```

### Cách 3 — Trigger manual từ GitHub Actions UI
Actions tab → **Sync Excel → Cloudflare D1** → **Run workflow** → chọn mode + target

---

## API Reference

| Endpoint | Mô tả |
|---|---|
| `GET /health` | Kiểm tra kết nối, trả tổng số dòng |
| `GET /api/counts` | Đếm nhanh PENDING / FINISHED |
| `GET /api/stats` | Aggregated KPIs theo city, nhóm hàng, status |
| `GET /api/all` | Toàn bộ data (phân trang) |
| `GET /api/pending` | Chỉ PENDING |
| `GET /api/finished` | Chỉ FINISHED |

Query params: `limit`, `offset`, `src`, `city`, `status`, `nhom_hang`

---

## Free tier limits (Cloudflare)

| Service | Giới hạn free |
|---|---|
| Workers | 100,000 request/ngày |
| D1 Reads | 25,000,000 rows/ngày |
| D1 Storage | 5 GB |
| D1 Writes | 100,000 rows/ngày |
| Pages | Host HTML miễn phí |

→ Cho dashboard nội bộ (~vài chục user): **hoàn toàn đủ dùng**.
