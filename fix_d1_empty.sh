#!/bin/bash
# ═══════════════════════════════════════════════════════════════════
#  fix_d1_empty.sh
#  Chạy từng bước để fix "D1 data rỗng"
#  
#  Dùng: bash fix_d1_empty.sh
# ═══════════════════════════════════════════════════════════════════

DB_NAME="warranty-db"
DB_ID="00c1d762-875c-492c-8d6f-66da40dd4b6f"
WORKERS_URL="https://warranty-api.thienduc23.workers.dev"

RED='\033[0;31m'; GREEN='\033[0;32m'; YELLOW='\033[1;33m'
BLUE='\033[0;34m'; BOLD='\033[1m'; NC='\033[0m'

ok()   { echo -e "${GREEN}✓ $1${NC}"; }
fail() { echo -e "${RED}✗ $1${NC}"; }
warn() { echo -e "${YELLOW}! $1${NC}"; }
info() { echo -e "${BLUE}→ $1${NC}"; }
sep()  { echo -e "\n${BOLD}══════════════════════════════════════════════${NC}"; }
step() { echo -e "\n${BOLD}${BLUE}[$1] $2${NC}"; }

# ── STEP 1: Kiểm tra auth ─────────────────────────────────────────
sep
step "1/8" "Kiểm tra Wrangler & Auth"

if ! command -v wrangler &> /dev/null; then
    fail "Wrangler chưa cài"
    info "Chạy: npm install -g wrangler"
    exit 1
fi
ok "Wrangler: $(wrangler --version 2>&1 | head -1)"

WHO=$(wrangler whoami 2>&1)
if echo "$WHO" | grep -q "logged in\|@"; then
    ok "Đã đăng nhập Cloudflare"
else
    fail "Chưa đăng nhập!"
    info "Chạy: wrangler login"
    exit 1
fi

# ── STEP 2: Kiểm tra database list ───────────────────────────────
sep
step "2/8" "Xác nhận Database tồn tại"

DB_LIST=$(wrangler d1 list 2>&1)
if echo "$DB_LIST" | grep -q "$DB_NAME"; then
    ok "Database '$DB_NAME' tồn tại"
else
    warn "Không thấy '$DB_NAME' trong list:"
    echo "$DB_LIST"
    info "Tạo DB: wrangler d1 create $DB_NAME"
    exit 1
fi

# ── STEP 3: Đếm dòng trên REMOTE ─────────────────────────────────
sep
step "3/8" "Đếm dòng trên REMOTE database"

echo "  Đang query remote..."
COUNT_OUT=$(wrangler d1 execute "$DB_NAME" \
    --database-id "$DB_ID" \
    --command "SELECT COUNT(*) as total FROM warranty;" \
    --remote 2>&1)

echo "  Output: $COUNT_OUT"

# Lấy số từ output
ROWS=$(echo "$COUNT_OUT" | grep -oP '\d+' | tail -1)
ROWS=${ROWS:-0}

if [ "$ROWS" -gt 0 ] 2>/dev/null; then
    ok "REMOTE có ${ROWS} dòng"
    NEED_IMPORT=false
else
    warn "REMOTE có 0 dòng hoặc bảng chưa tồn tại"
    warn "==> Nguyên nhân: Trước đây chạy thiếu --remote flag!"
    NEED_IMPORT=true
fi

# ── STEP 4: Tạo/xác nhận schema ──────────────────────────────────
sep
step "4/8" "Tạo Schema (nếu chưa có)"

TABLES=$(wrangler d1 execute "$DB_NAME" \
    --database-id "$DB_ID" \
    --command "SELECT name FROM sqlite_master WHERE type='table';" \
    --remote 2>&1)

if echo "$TABLES" | grep -qi "warranty"; then
    ok "Bảng 'warranty' đã tồn tại"
else
    warn "Bảng 'warranty' chưa tồn tại → tạo schema"
    if [ -f "schema.sql" ]; then
        wrangler d1 execute "$DB_NAME" \
            --database-id "$DB_ID" \
            --file=schema.sql \
            --remote
        ok "Schema đã tạo"
    else
        fail "Không tìm thấy schema.sql"
        info "Tạo file schema.sql từ nội dung bên dưới rồi chạy lại"
        cat << 'SCHEMA'
-- Tạo file schema.sql với nội dung:
CREATE TABLE IF NOT EXISTS warranty (
  id INTEGER PRIMARY KEY AUTOINCREMENT,
  src TEXT NOT NULL,
  status TEXT, loai_kho TEXT, city TEXT,
  nhom_hang TEXT, nhom_sp TEXT, trang_thai TEXT,
  qua_trinh TEXT, phan_loai_bh TEXT, phan_loai_loi TEXT,
  ngay_tao TEXT, ngay_xong TEXT, ten_ktv TEXT,
  ten_hang TEXT, ym_tao TEXT, yw_tao TEXT,
  data_json TEXT NOT NULL,
  synced_at TEXT DEFAULT (datetime('now'))
);
CREATE INDEX IF NOT EXISTS idx_src ON warranty(src);
CREATE INDEX IF NOT EXISTS idx_status ON warranty(status);
CREATE INDEX IF NOT EXISTS idx_city ON warranty(city);
CREATE INDEX IF NOT EXISTS idx_src_status ON warranty(src, status);
SCHEMA
        exit 1
    fi
fi

# ── STEP 5: Convert Excel → SQL ───────────────────────────────────
sep
step "5/8" "Convert Excel → SQL"

if [ "$NEED_IMPORT" = true ]; then
    # Kiểm tra Python deps
    python3 -c "import pandas; import openpyxl" 2>/dev/null
    if [ $? -ne 0 ]; then
        warn "Thiếu pandas/openpyxl"
        info "Chạy: pip install pandas openpyxl"
        exit 1
    fi

    # Convert PENDING
    if ls data/PENDING.xlsx data/PENDING.xls data/PENDING.csv 2>/dev/null | head -1 | grep -q .; then
        echo "  Converting PENDING..."
        python3 scripts/excel_to_sql.py \
            --src PENDING \
            --mode full \
            --out /tmp/pending_fix.sql
        if [ $? -eq 0 ]; then
            ok "PENDING converted: $(wc -l < /tmp/pending_fix.sql) lines"
        else
            fail "Convert PENDING thất bại"
            exit 1
        fi
    else
        fail "Không tìm thấy data/PENDING.xlsx"
        info "Copy file vào: data/PENDING.xlsx"
        exit 1
    fi

    # Convert FINISHED (optional)
    if ls data/FINISHED.xlsx data/FINISHED.xls data/FINISHED.csv 2>/dev/null | head -1 | grep -q .; then
        echo "  Converting FINISHED..."
        python3 scripts/excel_to_sql.py \
            --src FINISHED \
            --mode full \
            --out /tmp/finished_fix.sql
        ok "FINISHED converted: $(wc -l < /tmp/finished_fix.sql) lines"
    else
        warn "Không có data/FINISHED.xlsx – bỏ qua"
    fi
else
    ok "Data đã có – bỏ qua bước convert"
fi

# ── STEP 6: Upload lên REMOTE ─────────────────────────────────────
sep
step "6/8" "Upload SQL lên REMOTE D1"

if [ "$NEED_IMPORT" = true ]; then
    echo ""
    warn "═══ QUAN TRỌNG: Phải có --remote ═══"
    warn "Lệnh split_and_execute.py đã bao gồm --remote tự động"
    echo ""

    if [ -f "/tmp/pending_fix.sql" ]; then
        echo "  Uploading PENDING..."
        python3 scripts/split_and_execute.py \
            --file /tmp/pending_fix.sql \
            --db "$DB_NAME" \
            --db-id "$DB_ID"
        if [ $? -eq 0 ]; then
            ok "PENDING uploaded"
        else
            fail "PENDING upload thất bại"
            echo ""
            warn "Thử lệnh thủ công:"
            echo "  wrangler d1 execute $DB_NAME \\"
            echo "    --database-id $DB_ID \\"
            echo "    --file=/tmp/pending_fix.sql \\"
            echo "    --remote"
        fi
    fi

    if [ -f "/tmp/finished_fix.sql" ]; then
        echo "  Uploading FINISHED..."
        python3 scripts/split_and_execute.py \
            --file /tmp/finished_fix.sql \
            --db "$DB_NAME" \
            --db-id "$DB_ID"
        [ $? -eq 0 ] && ok "FINISHED uploaded"
    fi
else
    ok "Data đã có – bỏ qua bước upload"
fi

# ── STEP 7: Verify dữ liệu ───────────────────────────────────────
sep
step "7/8" "Xác nhận dữ liệu trên Remote"

echo "  Đang đếm dữ liệu..."
wrangler d1 execute "$DB_NAME" \
    --database-id "$DB_ID" \
    --command "SELECT src, COUNT(*) as total FROM warranty GROUP BY src;" \
    --remote

echo ""
echo "  Sample 2 dòng đầu:"
wrangler d1 execute "$DB_NAME" \
    --database-id "$DB_ID" \
    --command "SELECT id, src, status, city FROM warranty LIMIT 2;" \
    --remote

# ── STEP 8: Redeploy Workers & test API ──────────────────────────
sep
step "8/8" "Redeploy Workers & Test API"

if [ -d "worker" ]; then
    echo "  Deploying Workers..."
    (cd worker && wrangler deploy 2>&1)
    ok "Workers deployed"
else
    warn "Không tìm thấy thư mục worker/ – bỏ qua deploy"
fi

echo ""
info "Test API ngay:"
echo ""

# Test /health
echo -e "  ${BOLD}GET /health${NC}"
curl -s "$WORKERS_URL/health" | python3 -m json.tool 2>/dev/null || \
curl -s "$WORKERS_URL/health"

echo ""
# Test /api/counts
echo -e "  ${BOLD}GET /api/counts${NC}"
curl -s "$WORKERS_URL/api/counts" | python3 -m json.tool 2>/dev/null || \
curl -s "$WORKERS_URL/api/counts"

echo ""
# Test /api/all?limit=3
echo -e "  ${BOLD}GET /api/all?limit=3${NC}"
curl -s "$WORKERS_URL/api/all?limit=3" | python3 -c "
import json,sys
d=json.load(sys.stdin)
print(f'  total={d.get(\"total\",\"?\")} | rows trả về={len(d.get(\"rows\",[]))} | has_more={d.get(\"has_more\")}')
" 2>/dev/null

sep
echo -e "${BOLD}Hoàn tất chẩn đoán & fix!${NC}"
echo ""
echo "  Nếu API vẫn rỗng, chạy:"
echo "    cd worker && wrangler tail"
echo "  để xem realtime log lỗi từ Workers."
echo ""
