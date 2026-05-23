#!/usr/bin/env python3
"""
MediaMart Warranty – Excel → Supabase Uploader
================================================
Cách dùng:
  1. Điền SUPABASE_URL và SUPABASE_KEY bên dưới
  2. python upload_to_supabase.py                  # upload cả 2 file
  2. python upload_to_supabase.py --file PENDING   # chỉ PENDING
  3. python upload_to_supabase.py --file FINISHED  # chỉ FINISHED
  4. python upload_to_supabase.py --clear          # xoá hết rồi upload lại
"""

import os, sys, json, math, time, argparse
import pandas as pd
import urllib.request, urllib.error

# ══════════════════════════════════════════════
#  ⚙️  CẤU HÌNH – điền vào đây
# ══════════════════════════════════════════════
SUPABASE_URL = "https://yxfoctieiruyvkoijkbv.supabase.co"     # ← dán URL project
SUPABASE_KEY = "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6Inl4Zm9jdGllaXJ1eXZrb2lqa2J2Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3Nzg3MzkwODUsImV4cCI6MjA5NDMxNTA4NX0.9Tuls6yZPzyr3wOB1VvCRRAx5GHx2JUJGgm2Ai7Hqy0"  # ← dán anon/service key

PENDING_FILE  = "PENDING.xlsx"
FINISHED_FILE = "FINISHED.xlsx"
TABLE         = "warranty_tickets"
BATCH_SIZE    = 500          # số rows mỗi lần gửi lên
# ══════════════════════════════════════════════

# Map tên cột Excel → tên cột Supabase
COL_MAP = {
    "Code Tiếp Nhận": "code_tiep_nhan",
    "Code Sửa chữa": "code_sua_chua",
    "Code Vị trí tồn": "code_vi_tri_ton",
    "City": "city",
    "Phân loại lỗi": "phan_loai_loi",
    "Quá trình xử lý phiếu": "qua_trinh_xu_ly_phieu",
    "Trạng thái phiếu": "trang_thai_phieu",
    "Status": "status",
    "Nhóm hàng": "nhom_hang",
    "Nhóm SP": "nhom_sp",
    "Item Category Name": "item_category_name",
    "Y+W (Tạo Phiếu)": "y_w_tao_phieu",
    "Week (Tạo Phiếu)": "week_tao_phieu",
    "Y+M (Tạo Phiếu)": "y_m_tao_phieu",
    "Xong-Month": "xong_month",
    "Xong-Year": "xong_year",
    "Ngày tiếp nhận": "ngay_tiep_nhan",
    "Loại kho": "loai_kho",
    "Đếm ngày Finished": "dem_ngay_finished",
    "Đếm ngày/tuần/tháng": "dem_ngay_tuan_thang",
    "Phí di chuyển+Vận chuyển": "phi_di_chuyen_van_chuyen",
    "Phí nhân công": "phi_nhan_cong",
    "Tính toán xét thưởng": "tinh_toan_xet_thuong",
    "KPI tháng": "kpi_thang",
    "Lk sử dụng": "lk_su_dung",
    "No.": "no_",
    "Ngày tạo phiếu": "ngay_tao_phieu",
    "TG tạo phiếu": "tg_tao_phieu",
    "Người tạo phiếu": "nguoi_tao_phieu",
    "Mã phiếu BH": "ma_phieu_bh",
    "Model SP (Description)": "model_sp_description",
    "Mã SP (Item No)": "ma_sp_item_no",
    "Tên hãng": "ten_hang",
    "Mã nhóm SP (Product Group Code)": "ma_nhom_sp_product_group_code",
    "Serial No.": "serial_no",
    "Mã phiếu bán hàng": "ma_phieu_ban_hang",
    "Customer Name": "customer_name",
    "Phone": "phone",
    "Mobile Phone": "mobile_phone",
    "Địa chỉ": "dia_chi",
    "Sale Date": "sale_date",
    "Nơi mua": "noi_mua",
    "Hình ảnh (link hình ảnh)": "hinh_anh_link",
    "Phụ kiện kèm theo": "phu_kien_kem_theo",
    "Tình trạng SP (mô tả phần nội dung nhập khi tạo phiếu)": "tinh_trang_sp_mo_ta",
    "Trạng thái phiếu BH": "trang_thai_phieu_bh",
    "Vị trí": "vi_tri",
    "Phân loại phiếu BH": "phan_loai_phieu_bh",
    "Kết quả": "ket_qua",
    "Mô tả của kỹ thuật (ghi chú khác trong phiếu BH)": "mo_ta_ky_thuat",
    "ID tạo phiếu BH": "id_tao_phieu_bh",
    "Trạm tạo phiếu": "tram_tao_phieu",
    "Trạm sửa chữa": "tram_sua_chua",
    "ID Trưởng trạm": "id_truong_tram",
    "ID KTV sửa chữa": "id_ktv_sua_chua",
    "Họ tên KTV": "ho_ten_ktv",
    "Ngày KTV được phân phiếu để sửa": "ngay_ktv_phan_phieu",
    "Ngày KTV nhận việc": "ngay_ktv_nhan_viec",
    "Ngày KTV đề xuất LK": "ngay_ktv_de_xuat_lk",
    "Ngày KTV sửa xong": "ngay_ktv_sua_xong",
    "Số ngày sửa chữa của KTV": "so_ngay_sua_chua_ktv",
    "Lần SP quay lại BH": "lan_sp_quay_lai_bh",
    "Mã lỗi 1": "ma_loi_1",
    "Mã lỗi 2": "ma_loi_2",
    "Mã lỗi 3": "ma_loi_3",
    "Mã Linh kiện 1": "ma_linh_kien_1",
    "Linh kiện 1": "linh_kien_1",
    "SL linh kiện 1": "sl_linh_kien_1",
    "Mã Linh kiện 2": "ma_linh_kien_2",
    "Linh kiện 2": "linh_kien_2",
    "SL linh kiện 2": "sl_linh_kien_2",
    "Mã Linh kiện 3": "ma_linh_kien_3",
    "Linh kiện 3": "linh_kien_3",
    "SL linh kiện 3": "sl_linh_kien_3",
    "Mã Linh kiện 4": "ma_linh_kien_4",
    "Linh kiện 4": "linh_kien_4",
    "SL linh kiện 4": "sl_linh_kien_4",
    "Mã Linh kiện 5": "ma_linh_kien_5",
    "Linh kiện 5": "linh_kien_5",
    "SL linh kiện 5": "sl_linh_kien_5",
    "Tiền linh kiện": "tien_linh_kien",
    "Tiền linh kiện (%)": "tien_linh_kien_pct",
    "Tiền linh kiện (tổng tiền)": "tien_linh_kien_tong",
    "Km": "km",
    "Phí di chuyển": "phi_di_chuyen",
    "Phí dịch vụ": "phi_dich_vu",
    "Phí DV tại nhà": "phi_dv_tai_nha",
    "Ngày hẹn trả": "ngay_hen_tra",
    "Ngày thanh toán": "ngay_thanh_toan",
    "ID Kế toán": "id_ke_toan",
    "Ngày hoàn thành phiếu": "ngay_hoan_thanh_phieu",
    "Thời gian hoàn thành phiếu (hh/mm/ss)": "thoi_gian_hoan_thanh",
    "Số ngày thực hiện (ngày hoàn thành - ngày tạo phiếu)": "so_ngay_thuc_hien",
    "KPI (OK nếu ngày hoàn thành <= ngày hẹn trả)": "kpi_ok",
    "Ngày chuyển trạm (BBBG đi)": "ngay_chuyen_tram",
    "Ngày bàn giao đi (BB bàn giao đi)": "ngay_ban_giao_di",
    "Ngày bàn giao về (BB bàn giao về)": "ngay_ban_giao_ve",
    "Ngày đem về trạm": "ngay_dem_ve_tram",
    "Ngày bàn giao hoàn thành (BBBG về)": "ngay_ban_giao_hoan_thanh",
    "Ngày xác nhận BG hoàn thành": "ngay_xac_nhan_bg",
    "Document No.": "document_no",
    "Phân loại": "phan_loai",
    "Vị trí2": "vi_tri2",
    "Mã phiếu xuất": "ma_phieu_xuat",
    "Nhu cầu LK": "nhu_cau_lk",
    "Ngày gửi LK": "ngay_gui_lk",
    "Ngày nhận LK": "ngay_nhan_lk",
    "KM vận chuyển": "km_van_chuyen",
    "Phí vận chuyển": "phi_van_chuyen",
}

# ── Helpers ──────────────────────────────────────────────────────

def clean_val(v):
    """Chuyển NaN / NaT / Timestamp về kiểu JSON-safe."""
    if v is None:
        return None
    if isinstance(v, float) and math.isnan(v):
        return None
    if hasattr(v, 'isoformat'):          # datetime / Timestamp
        try:
            return v.strftime('%d/%m/%Y') if not pd.isnull(v) else None
        except Exception:
            return None
    if isinstance(v, (int, float)):
        if math.isinf(v):
            return None
        # Trả về int nếu là số nguyên
        if isinstance(v, float) and v == int(v):
            return int(v)
        return v
    s = str(v).strip()
    return None if s in ('', 'nan', 'NaT', 'None') else s


def supabase_request(method, path, payload=None):
    """Gọi Supabase REST API."""
    url = f"{SUPABASE_URL.rstrip('/')}/rest/v1/{path}"
    data = json.dumps(payload).encode('utf-8') if payload is not None else None
    headers = {
        "apikey": SUPABASE_KEY,
        "Authorization": f"Bearer {SUPABASE_KEY}",
        "Content-Type": "application/json",
        "Prefer": "return=minimal",
    }
    req = urllib.request.Request(url, data=data, headers=headers, method=method)
    try:
        with urllib.request.urlopen(req, timeout=30) as resp:
            body = resp.read()
            return resp.status, body.decode('utf-8') if body else ''
    except urllib.error.HTTPError as e:
        body = e.read().decode('utf-8')
        return e.code, body


def delete_source(source_label):
    print(f"  🗑️  Xoá dữ liệu cũ source_file='{source_label}'...")
    status, body = supabase_request('DELETE', f"{TABLE}?source_file=eq.{source_label}")
    if status in (200, 204):
        print(f"  ✅ Đã xoá xong.")
    else:
        print(f"  ⚠️  Xoá trả về {status}: {body[:200]}")


def insert_batch(rows, attempt=1):
    status, body = supabase_request('POST', TABLE, rows)
    if status in (200, 201):
        return True
    if status == 429 and attempt <= 3:          # rate-limit
        print(f"  ⏳ Rate-limit – chờ {attempt*5}s rồi thử lại...")
        time.sleep(attempt * 5)
        return insert_batch(rows, attempt + 1)
    print(f"  ❌ Insert lỗi {status}: {body[:300]}")
    return False


def log_upload(file_name, row_count):
    supabase_request('POST', 'upload_log', {
        "file_name": file_name,
        "row_count": row_count,
        "uploaded_by": "python_script"
    })


# ── Main upload function ──────────────────────────────────────────

def upload_excel(xlsx_path, source_label, do_clear=False):
    if not os.path.exists(xlsx_path):
        print(f"  ❌ Không tìm thấy file: {xlsx_path}")
        return 0

    print(f"\n{'='*55}")
    print(f"📂 Đọc file: {xlsx_path}")
    df = pd.read_excel(xlsx_path, dtype=str)   # đọc tất cả là string, tránh type mismatch
    print(f"   → {len(df):,} dòng | {len(df.columns)} cột")

    if do_clear:
        delete_source(source_label)

    # Đổi tên cột + thêm source_file
    df = df.rename(columns=COL_MAP)
    df['source_file'] = source_label

    # Chỉ giữ cột tồn tại trong COL_MAP (bỏ cột thừa nếu có)
    valid_cols = list(COL_MAP.values()) + ['source_file']
    df = df[[c for c in df.columns if c in valid_cols]]

    # Làm sạch NaN
    records = []
    for _, row in df.iterrows():
        rec = {k: clean_val(v) for k, v in row.items()}
        records.append(rec)

    total  = len(records)
    n_bat  = math.ceil(total / BATCH_SIZE)
    ok_cnt = 0

    print(f"   → Gửi {total:,} dòng trong {n_bat} batch (batch_size={BATCH_SIZE})")
    for i in range(n_bat):
        batch = records[i*BATCH_SIZE : (i+1)*BATCH_SIZE]
        ok = insert_batch(batch)
        if ok:
            ok_cnt += len(batch)
        pct = ok_cnt / total * 100
        bar = ('█' * int(pct//5)).ljust(20)
        print(f"  [{bar}] {pct:5.1f}%  {ok_cnt:,}/{total:,}  (batch {i+1}/{n_bat})",
              end='\r', flush=True)
        time.sleep(0.05)   # tránh rate-limit

    print()
    log_upload(xlsx_path, ok_cnt)
    print(f"  ✅ Hoàn thành: {ok_cnt:,}/{total:,} dòng đã lên Supabase")
    return ok_cnt


# ── Entry point ──────────────────────────────────────────────────

def main():
    if "XXXXXXXXXXXX" in SUPABASE_URL:
        print("❌ Bạn chưa điền SUPABASE_URL và SUPABASE_KEY vào script!")
        print("   Mở file này, sửa 2 dòng đầu trong phần CẤU HÌNH rồi chạy lại.")
        sys.exit(1)

    parser = argparse.ArgumentParser(description='Upload Excel → Supabase')
    parser.add_argument('--file',  choices=['PENDING','FINISHED','ALL'], default='ALL',
                        help='File muốn upload (mặc định: ALL)')
    parser.add_argument('--clear', action='store_true',
                        help='Xoá dữ liệu cũ trước khi upload')
    args = parser.parse_args()

    start = time.time()
    total = 0

    if args.file in ('PENDING','ALL'):
        total += upload_excel(PENDING_FILE,  'PENDING',  do_clear=args.clear)

    if args.file in ('FINISHED','ALL'):
        total += upload_excel(FINISHED_FILE, 'FINISHED', do_clear=args.clear)

    elapsed = time.time() - start
    print(f"\n🏁 Tổng: {total:,} dòng – thời gian: {elapsed:.1f}s")
    print(f"   Dashboard: {SUPABASE_URL.replace('.supabase.co','')}.supabase.co → Table Editor → warranty_tickets")


if __name__ == '__main__':
    main()
