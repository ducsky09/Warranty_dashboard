#!/usr/bin/env python3
"""
diagnose_and_fix.py
Chạy script này để tự động chẩn đoán và fix lỗi "data không có số liệu"
trên Cloudflare D1 + Workers.

Dùng:
  python3 diagnose_and_fix.py
"""

import subprocess, sys, os, json, re, shutil
from pathlib import Path

# ── Màu terminal ──────────────────────────────────────────────────
def R(s): return f"\033[91m{s}\033[0m"   # đỏ
def G(s): return f"\033[92m{s}\033[0m"   # xanh
def Y(s): return f"\033[93m{s}\033[0m"   # vàng
def B(s): return f"\033[94m{s}\033[0m"   # xanh dương
def W(s): return f"\033[1m{s}\033[0m"    # đậm

DB_NAME = "warranty-db"
DB_ID   = "00c1d762-875c-492c-8d6f-66da40dd4b6f"

def run(cmd, capture=True, cwd=None):
    r = subprocess.run(cmd, shell=True, capture_output=capture,
                       text=True, cwd=cwd)
    return r.stdout.strip(), r.stderr.strip(), r.returncode

def section(title):
    print(f"\n{'═'*55}")
    print(f"  {B(title)}")
    print(f"{'═'*55}")

def ok(msg):   print(f"  {G('✓')} {msg}")
def fail(msg): print(f"  {R('✗')} {msg}")
def warn(msg): print(f"  {Y('!')} {msg}")
def info(msg): print(f"  {B('→')} {msg}")

# ══════════════════════════════════════════════════════════════════
print(W("\n  MediaMart D1 – Chẩn đoán & Sửa lỗi 'Data rỗng'"))
print(W("  Database ID: ") + DB_ID)

# ── CHECK 1: Wrangler có cài chưa ─────────────────────────────────
section("CHECK 1: Wrangler CLI")
out, err, rc = run("wrangler --version")
if rc == 0:
    ok(f"Wrangler: {out}")
else:
    fail("Wrangler chưa cài!")
    info("Chạy: npm install -g wrangler")
    sys.exit(1)

# ── CHECK 2: Đăng nhập Cloudflare ─────────────────────────────────
section("CHECK 2: Cloudflare Auth")
out, err, rc = run("wrangler whoami")
if "You are logged in" in out or "@" in out:
    ok(f"Đã đăng nhập: {out.split(chr(10))[0]}")
else:
    fail("Chưa đăng nhập Cloudflare!")
    info("Chạy: wrangler login")
    sys.exit(1)

# ── CHECK 3: Database có tồn tại trên remote không ────────────────
section("CHECK 3: Database tồn tại trên Remote")
out, err, rc = run(f'wrangler d1 list')
if DB_NAME in out:
    ok(f"Database '{DB_NAME}' tồn tại")
else:
    fail(f"Không tìm thấy '{DB_NAME}' trong danh sách!")
    print(f"\n  Danh sách DB hiện có:\n{out}")
    info(f"Tạo DB: wrangler d1 create {DB_NAME}")
    sys.exit(1)

# ── CHECK 4: Đếm số dòng trên REMOTE ──────────────────────────────
section("CHECK 4: Đếm dòng trên REMOTE database")
# Đây là check quan trọng nhất
out, err, rc = run(
    f'wrangler d1 execute {DB_NAME} '
    f'--database-id {DB_ID} '
    f'--command "SELECT COUNT(*) as total FROM warranty;" '
    f'--remote'
)
print(f"  Raw output:\n{out}\n{err}")

total_rows = 0
if "total" in out.lower() or rc == 0:
    nums = re.findall(r'\d+', out)
    if nums:
        total_rows = int(nums[-1])
        if total_rows == 0:
            fail(f"Bảng warranty có 0 dòng trên REMOTE!")
            warn("Nguyên nhân phổ biến:")
            warn("  A) Chạy execute thiếu --remote flag → data vào local thay vì remote")
            warn("  B) Bảng warranty chưa được tạo")
            warn("  C) SQL file bị lỗi → transaction rollback hết")
        else:
            ok(f"Bảng warranty có {total_rows:,} dòng trên remote")
else:
    fail("Không query được / Bảng warranty chưa tồn tại!")

# ── CHECK 5: Schema có đúng không ─────────────────────────────────
section("CHECK 5: Kiểm tra Schema")
out, err, rc = run(
    f'wrangler d1 execute {DB_NAME} '
    f'--database-id {DB_ID} '
    f'--command "SELECT name FROM sqlite_master WHERE type=\'table\';" '
    f'--remote'
)
print(f"  Tables: {out}")
if "warranty" in out.lower():
    ok("Bảng 'warranty' đã tạo")
else:
    fail("Bảng 'warranty' CHƯA tồn tại trên remote!")
    info("→ Cần chạy schema.sql (xem FIX A bên dưới)")

# ── CHECK 6: Workers có bind đúng DB không ────────────────────────
section("CHECK 6: Workers binding")
wtoml = Path("worker/wrangler.toml")
if wtoml.exists():
    content = wtoml.read_text()
    if DB_ID in content:
        ok(f"database_id trong wrangler.toml khớp: {DB_ID}")
    else:
        fail("database_id trong wrangler.toml KHÔNG khớp với DB đang dùng!")
        warn(f"Cần sửa wrangler.toml → database_id = \"{DB_ID}\"")
else:
    warn("Không tìm thấy worker/wrangler.toml – bỏ qua check này")

# ── CHECK 7: file data/ có tồn tại không ──────────────────────────
section("CHECK 7: File data Excel/CSV")
data_dir = Path("data")
pending_found  = list(data_dir.glob("PENDING*"))  if data_dir.exists() else []
finished_found = list(data_dir.glob("FINISHED*")) if data_dir.exists() else []

if pending_found:
    for f in pending_found:
        ok(f"PENDING: {f}  ({f.stat().st_size/1024:.1f} KB)")
else:
    fail("Không tìm thấy data/PENDING.xlsx hoặc data/PENDING.csv!")
    info("→ Copy file Excel vào thư mục data/")

if finished_found:
    for f in finished_found:
        ok(f"FINISHED: {f}  ({f.stat().st_size/1024:.1f} KB)")
else:
    warn("Không tìm thấy data/FINISHED.xlsx – sẽ bỏ qua")

# ══════════════════════════════════════════════════════════════════
section("KẾT QUẢ & HƯỚNG XỬ LÝ")

if total_rows == 0:
    print(f"""
{R('▸ VẤN ĐỀ: Database remote rỗng → cần import data')}

{W('═══ FIX A: Tạo schema (nếu bảng chưa tồn tại) ═══')}

  wrangler d1 execute {DB_NAME} \\
    --database-id {DB_ID} \\
    --file=schema.sql \\
    --remote

{W('═══ FIX B: Convert Excel → SQL ═══')}

  # PENDING
  python3 scripts/excel_to_sql.py \\
    --src PENDING \\
    --mode full \\
    --schema \\
    --out /tmp/pending.sql

  # FINISHED (nếu có)
  python3 scripts/excel_to_sql.py \\
    --src FINISHED \\
    --mode full \\
    --out /tmp/finished.sql

{W('═══ FIX C: Upload lên REMOTE (bắt buộc có --remote) ═══')}

{Y('⚠ LỖI PHỔ BIẾN NHẤT: thiếu --remote → data vào local !')}

  python3 scripts/split_and_execute.py \\
    --file /tmp/pending.sql \\
    --db {DB_NAME} \\
    --db-id {DB_ID}
    
  python3 scripts/split_and_execute.py \\
    --file /tmp/finished.sql \\
    --db {DB_NAME} \\
    --db-id {DB_ID}

{W('═══ FIX D: Verify sau khi import ═══')}

  wrangler d1 execute {DB_NAME} \\
    --database-id {DB_ID} \\
    --command "SELECT src, COUNT(*) as n FROM warranty GROUP BY src;" \\
    --remote

{W('═══ FIX E: Redeploy Workers sau khi data có ═══')}

  cd worker && wrangler deploy

{W('═══ TEST API sau khi xong ═══')}

  curl https://warranty-api.thienduc23.workers.dev/health
  curl "https://warranty-api.thienduc23.workers.dev/api/counts"
""")
else:
    print(f"""
{G('▸ Database có dữ liệu ({total_rows:,} dòng)')}

Nếu API vẫn không trả data, kiểm tra:

{W('1. Workers có deploy sau khi có data chưa?')}
   cd worker && wrangler deploy

{W('2. Test trực tiếp API:')}
   curl https://warranty-api.thienduc23.workers.dev/health
   curl https://warranty-api.thienduc23.workers.dev/api/counts
   curl "https://warranty-api.thienduc23.workers.dev/api/all?limit=5"

{W('3. Kiểm tra wrangler.toml binding:')}
   database_id = "{DB_ID}"

{W('4. Xem Workers logs:')}
   cd worker && wrangler tail
""")
