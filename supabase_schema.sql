-- ================================================================
-- MEDIAMART WARRANTY DASHBOARD – SUPABASE SCHEMA
-- Chạy toàn bộ script này trong Supabase → SQL Editor → Run
-- ================================================================

-- Bảng chính: gộp cả PENDING + FINISHED (phân biệt qua cột "source_file")
CREATE TABLE IF NOT EXISTS warranty_tickets (
  id                          BIGSERIAL PRIMARY KEY,
  source_file                 TEXT NOT NULL,          -- 'PENDING' hoặc 'FINISHED'
  uploaded_at                 TIMESTAMPTZ DEFAULT NOW(),

  -- ── NHÓM: Mã phiếu & Phân loại ──
  code_tiep_nhan              TEXT,
  code_sua_chua               TEXT,
  code_vi_tri_ton             TEXT,
  city                        TEXT,
  phan_loai_loi               TEXT,
  qua_trinh_xu_ly_phieu       TEXT,
  trang_thai_phieu            TEXT,
  status                      TEXT,
  nhom_hang                   TEXT,
  nhom_sp                     TEXT,
  item_category_name          TEXT,
  y_w_tao_phieu               BIGINT,
  week_tao_phieu              INTEGER,
  y_m_tao_phieu               BIGINT,
  xong_month                  TEXT,
  xong_year                   TEXT,
  ngay_tiep_nhan              TEXT,
  loai_kho                    TEXT,
  dem_ngay_finished           INTEGER,
  dem_ngay_tuan_thang         TEXT,
  phi_di_chuyen_van_chuyen    TEXT,
  phi_nhan_cong               TEXT,
  tinh_toan_xet_thuong        TEXT,
  kpi_thang                   TEXT,
  lk_su_dung                  TEXT,

  -- ── NHÓM: Thông tin phiếu ──
  no_                         INTEGER,
  ngay_tao_phieu              TEXT,
  tg_tao_phieu                TEXT,
  nguoi_tao_phieu             TEXT,
  ma_phieu_bh                 TEXT,
  model_sp_description        TEXT,
  ma_sp_item_no               TEXT,
  ten_hang                    TEXT,
  ma_nhom_sp_product_group_code TEXT,
  serial_no                   TEXT,
  ma_phieu_ban_hang           TEXT,
  customer_name               TEXT,
  phone                       TEXT,
  mobile_phone                TEXT,
  dia_chi                     TEXT,
  sale_date                   TEXT,
  noi_mua                     TEXT,
  hinh_anh_link               TEXT,
  phu_kien_kem_theo           TEXT,
  tinh_trang_sp_mo_ta         TEXT,
  trang_thai_phieu_bh         TEXT,
  vi_tri                      TEXT,
  phan_loai_phieu_bh          TEXT,
  ket_qua                     TEXT,
  mo_ta_ky_thuat              TEXT,
  id_tao_phieu_bh             TEXT,
  tram_tao_phieu              TEXT,
  tram_sua_chua               TEXT,
  id_truong_tram              TEXT,
  id_ktv_sua_chua             TEXT,
  ho_ten_ktv                  TEXT,
  ngay_ktv_phan_phieu         TEXT,
  ngay_ktv_nhan_viec          TEXT,
  ngay_ktv_de_xuat_lk         TEXT,
  ngay_ktv_sua_xong           TEXT,
  so_ngay_sua_chua_ktv        TEXT,
  lan_sp_quay_lai_bh          INTEGER,

  -- ── NHÓM: Lỗi ──
  ma_loi_1                    TEXT,
  ma_loi_2                    TEXT,
  ma_loi_3                    TEXT,

  -- ── NHÓM: Linh kiện ──
  ma_linh_kien_1              TEXT,
  linh_kien_1                 TEXT,
  sl_linh_kien_1              INTEGER,
  ma_linh_kien_2              TEXT,
  linh_kien_2                 TEXT,
  sl_linh_kien_2              INTEGER,
  ma_linh_kien_3              TEXT,
  linh_kien_3                 TEXT,
  sl_linh_kien_3              INTEGER,
  ma_linh_kien_4              TEXT,
  linh_kien_4                 TEXT,
  sl_linh_kien_4              INTEGER,
  ma_linh_kien_5              TEXT,
  linh_kien_5                 TEXT,
  sl_linh_kien_5              INTEGER,

  -- ── NHÓM: Tài chính ──
  tien_linh_kien              TEXT,
  tien_linh_kien_pct          TEXT,
  tien_linh_kien_tong         TEXT,
  km                          TEXT,
  phi_di_chuyen               TEXT,
  phi_dich_vu                 TEXT,
  phi_dv_tai_nha              TEXT,

  -- ── NHÓM: Ngày tháng ──
  ngay_hen_tra                TEXT,
  ngay_thanh_toan             TEXT,
  id_ke_toan                  TEXT,
  ngay_hoan_thanh_phieu       TEXT,
  thoi_gian_hoan_thanh        TEXT,
  so_ngay_thuc_hien           TEXT,
  kpi_ok                      TEXT,
  ngay_chuyen_tram            TEXT,
  ngay_ban_giao_di            TEXT,
  ngay_ban_giao_ve            TEXT,
  ngay_dem_ve_tram            TEXT,
  ngay_ban_giao_hoan_thanh    TEXT,
  ngay_xac_nhan_bg            TEXT,
  document_no                 TEXT,
  phan_loai                   TEXT,
  vi_tri2                     TEXT,
  ma_phieu_xuat               TEXT,
  nhu_cau_lk                  TEXT,
  ngay_gui_lk                 TEXT,
  ngay_nhan_lk                TEXT,
  km_van_chuyen               TEXT,
  phi_van_chuyen              TEXT
);

-- ── INDEX để query nhanh ──
CREATE INDEX IF NOT EXISTS idx_wt_status      ON warranty_tickets(status);
CREATE INDEX IF NOT EXISTS idx_wt_loai_kho    ON warranty_tickets(loai_kho);
CREATE INDEX IF NOT EXISTS idx_wt_city        ON warranty_tickets(city);
CREATE INDEX IF NOT EXISTS idx_wt_nhom_hang   ON warranty_tickets(nhom_hang);
CREATE INDEX IF NOT EXISTS idx_wt_nhom_sp     ON warranty_tickets(nhom_sp);
CREATE INDEX IF NOT EXISTS idx_wt_source      ON warranty_tickets(source_file);
CREATE INDEX IF NOT EXISTS idx_wt_tao_phieu   ON warranty_tickets(ngay_tao_phieu);
CREATE INDEX IF NOT EXISTS idx_wt_y_m         ON warranty_tickets(y_m_tao_phieu);
CREATE INDEX IF NOT EXISTS idx_wt_y_w         ON warranty_tickets(y_w_tao_phieu);
CREATE INDEX IF NOT EXISTS idx_wt_uploaded    ON warranty_tickets(uploaded_at);

-- ── Bảng theo dõi lịch sử upload ──
CREATE TABLE IF NOT EXISTS upload_log (
  id            BIGSERIAL PRIMARY KEY,
  file_name     TEXT NOT NULL,
  row_count     INTEGER,
  uploaded_at   TIMESTAMPTZ DEFAULT NOW(),
  uploaded_by   TEXT DEFAULT 'manual',
  notes         TEXT
);

-- ── Row Level Security: cho phép đọc public (dashboard), 
--    chỉ service_role mới insert/delete ──
ALTER TABLE warranty_tickets ENABLE ROW LEVEL SECURITY;
ALTER TABLE upload_log ENABLE ROW LEVEL SECURITY;

-- Cho phép anon/authenticated đọc (dashboard sẽ dùng anon key)
CREATE POLICY "allow_read_all" ON warranty_tickets
  FOR SELECT USING (true);

CREATE POLICY "allow_read_log" ON upload_log
  FOR SELECT USING (true);

-- Cho phép insert với anon key (uploader script)
-- HOẶC nếu muốn bảo mật hơn: dùng service_role key trong script
CREATE POLICY "allow_insert_all" ON warranty_tickets
  FOR INSERT WITH CHECK (true);

CREATE POLICY "allow_delete_all" ON warranty_tickets
  FOR DELETE USING (true);

CREATE POLICY "allow_insert_log" ON upload_log
  FOR INSERT WITH CHECK (true);

-- ── View tiện lợi cho dashboard ──
CREATE OR REPLACE VIEW v_dashboard AS
SELECT
  id, source_file, uploaded_at,
  city, status, loai_kho, nhom_hang, nhom_sp,
  phan_loai_loi, qua_trinh_xu_ly_phieu, trang_thai_phieu,
  phan_loai_phieu_bh, trang_thai_phieu_bh,
  y_w_tao_phieu, week_tao_phieu, y_m_tao_phieu,
  ngay_tao_phieu, ngay_tiep_nhan, ngay_ktv_sua_xong,
  ten_hang, model_sp_description, serial_no,
  ho_ten_ktv, tram_tao_phieu, tram_sua_chua,
  ma_loi_1, ma_loi_2, ma_loi_3,
  linh_kien_1, sl_linh_kien_1,
  linh_kien_2, sl_linh_kien_2,
  linh_kien_3, sl_linh_kien_3,
  linh_kien_4, sl_linh_kien_4,
  linh_kien_5, sl_linh_kien_5,
  kpi_ok, so_ngay_thuc_hien,
  ngay_hoan_thanh_phieu,
  ma_phieu_bh, code_tiep_nhan
FROM warranty_tickets;
