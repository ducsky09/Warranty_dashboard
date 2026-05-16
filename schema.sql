-- ═══════════════════════════════════════════════════════════════════
--  MediaMart Warranty – D1 Schema
--  Chạy 1 lần duy nhất khi setup:
--    wrangler d1 execute warranty-db --file=schema.sql --remote
-- ═══════════════════════════════════════════════════════════════════

-- Bảng chính
CREATE TABLE IF NOT EXISTS warranty (
  id           INTEGER PRIMARY KEY AUTOINCREMENT,
  src          TEXT NOT NULL,              -- 'PENDING' hoặc 'FINISHED'
  status       TEXT,                       -- Pending / Xong
  loai_kho     TEXT,                       -- Hàng khách / Hàng kho
  city         TEXT,
  nhom_hang    TEXT,                       -- Gia Dụng / Điện Lạnh / Điện Tử
  nhom_sp      TEXT,                       -- Nhóm sản phẩm
  trang_thai   TEXT,                       -- Trạng thái phiếu
  qua_trinh    TEXT,                       -- Quá trình xử lý phiếu
  phan_loai_bh TEXT,                       -- Phân loại phiếu BH
  phan_loai_loi TEXT,                      -- Phân loại lỗi
  ngay_tao     TEXT,                       -- dd/MM/yyyy
  ngay_xong    TEXT,                       -- Ngày KTV sửa xong
  ten_ktv      TEXT,                       -- Họ tên KTV
  ten_hang     TEXT,                       -- Tên hãng
  ym_tao       TEXT,                       -- Y+M tạo phiếu
  yw_tao       TEXT,                       -- Y+W tạo phiếu
  data_json    TEXT NOT NULL,              -- Toàn bộ row gốc (JSON)
  synced_at    TEXT DEFAULT (datetime('now'))
);

-- ── Indexes (tăng tốc query filter) ──────────────────────────────
CREATE INDEX IF NOT EXISTS idx_src         ON warranty(src);
CREATE INDEX IF NOT EXISTS idx_status      ON warranty(status);
CREATE INDEX IF NOT EXISTS idx_loai_kho    ON warranty(loai_kho);
CREATE INDEX IF NOT EXISTS idx_city        ON warranty(city);
CREATE INDEX IF NOT EXISTS idx_nhom_hang   ON warranty(nhom_hang);
CREATE INDEX IF NOT EXISTS idx_nhom_sp     ON warranty(nhom_sp);
CREATE INDEX IF NOT EXISTS idx_ngay_tao    ON warranty(ngay_tao);
CREATE INDEX IF NOT EXISTS idx_ten_ktv     ON warranty(ten_ktv);
-- Composite index cho query phổ biến nhất: src + status
CREATE INDEX IF NOT EXISTS idx_src_status  ON warranty(src, status);
-- Composite index cho query thành phố + status
CREATE INDEX IF NOT EXISTS idx_city_status ON warranty(city, status);

-- ── Verify ────────────────────────────────────────────────────────
-- Sau khi chạy schema, kiểm tra bằng:
--   wrangler d1 execute warranty-db --command="SELECT name FROM sqlite_master WHERE type='table';" --remote
