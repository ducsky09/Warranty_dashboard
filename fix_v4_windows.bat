@echo off
setlocal

set DB=warranty-db
set API=https://warranty-api.thienduc23.workers.dev

cd /d "%~dp0"

echo.
echo ==================================================
echo   MediaMart D1 Fix - Wrangler v4 - Windows
echo ==================================================
echo.

echo [1/5] Wrangler version:
wrangler --version
echo.

echo [2/5] Dem dong tren REMOTE:
wrangler d1 execute %DB% --command "SELECT COUNT(*) as n FROM warranty;" --remote
echo.

echo [3/5] Tao schema...
if exist schema.sql (
    wrangler d1 execute %DB% --file=schema.sql --remote -y
    echo   OK: schema.sql chay xong
) else (
    wrangler d1 execute %DB% --command "CREATE TABLE IF NOT EXISTS warranty (id INTEGER PRIMARY KEY AUTOINCREMENT, src TEXT NOT NULL, status TEXT, loai_kho TEXT, city TEXT, nhom_hang TEXT, nhom_sp TEXT, trang_thai TEXT, qua_trinh TEXT, phan_loai_bh TEXT, phan_loai_loi TEXT, ngay_tao TEXT, ngay_xong TEXT, ten_ktv TEXT, ten_hang TEXT, ym_tao TEXT, yw_tao TEXT, data_json TEXT NOT NULL);" --remote -y
    echo   OK: Tao bang inline xong
)
echo.

echo [4/5] Convert va Upload...
python -c "import pandas" 2>nul || pip install pandas openpyxl

if not exist "scripts\split_and_execute_v2.py" (
    echo   LOI: Khong thay scripts\split_and_execute_v2.py
    echo   Hay copy file do vao thu muc scripts\
    pause
    exit /b 1
)

if exist "data\PENDING.xlsx" (
    echo   Converting PENDING...
    python scripts\excel_to_sql.py --src PENDING --mode full --out pending_upload.sql
    echo   Uploading PENDING...
    python scripts\split_and_execute_v2.py --file pending_upload.sql --db %DB%
) else (
    echo   Khong co data\PENDING.xlsx
)

if exist "data\FINISHED.xlsx" (
    echo   Converting FINISHED...
    python scripts\excel_to_sql.py --src FINISHED --mode full --out finished_upload.sql
    echo   Uploading FINISHED...
    python scripts\split_and_execute_v2.py --file finished_upload.sql --db %DB%
) else (
    echo   Khong co data\FINISHED.xlsx - bo qua
)

echo.
echo Kiem tra so dong sau upload:
wrangler d1 execute %DB% --command "SELECT src, COUNT(*) as total FROM warranty GROUP BY src;" --remote
echo.

echo [5/5] Deploy Workers...
cd worker
wrangler deploy
cd ..
echo.

echo ==================================================
echo   XONG! Kiem tra API:
echo   %API%/health
echo   %API%/api/counts
echo ==================================================
echo.
start "" "%API%/health"
start "" "%API%/api/counts"
pause
