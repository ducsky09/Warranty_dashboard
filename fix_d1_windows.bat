@echo off
setlocal

set DB_NAME=warranty-db
set DB_ID=00c1d762-875c-492c-8d6f-66da40dd4b6f
set API=https://warranty-api.thienduc23.workers.dev

cd /d "%~dp0"

echo.
echo ==================================================
echo   MediaMart D1 - Fix Data Rong - Windows
echo ==================================================
echo   Thu muc: %CD%
echo.

REM -- STEP 1: Wrangler --
echo [1/6] Kiem tra Wrangler...
wrangler --version >nul 2>&1
if errorlevel 1 (
    echo   LOI: Wrangler chua cai
    echo   Chay lenh: npm install -g wrangler
    pause
    exit /b 1
)
echo   OK: Wrangler da cai

REM -- STEP 2: Login --
echo.
echo [2/6] Kiem tra dang nhap Cloudflare...
wrangler whoami 2>&1 | findstr /i "logged\|@\|email" >nul
if errorlevel 1 (
    echo   Chua dang nhap - mo browser de login...
    wrangler login
)
echo   OK: Da dang nhap

REM -- STEP 3: Dem dong remote --
echo.
echo [3/6] Dem dong tren REMOTE database...
echo   (Neu thay 0 = chua co data, can import)
echo.
wrangler d1 execute %DB_NAME% --database-id %DB_ID% --command "SELECT COUNT(*) as n FROM warranty;" --remote
echo.

REM -- STEP 4: Hoi import khong --
echo ==================================================
set /p ANS=Can import data khong? (Y=Co / N=Bo qua): 
echo ==================================================

if /i not "%ANS%"=="Y" goto :step_deploy

REM -- STEP 4A: Tao schema --
echo.
echo [4A] Tao schema tren Remote...
if exist schema.sql (
    wrangler d1 execute %DB_NAME% --database-id %DB_ID% --file=schema.sql --remote
    echo   OK: schema.sql da chay
) else (
    echo   Khong co schema.sql - tao bang inline...
    wrangler d1 execute %DB_NAME% --database-id %DB_ID% --command "CREATE TABLE IF NOT EXISTS warranty (id INTEGER PRIMARY KEY AUTOINCREMENT, src TEXT NOT NULL, status TEXT, loai_kho TEXT, city TEXT, nhom_hang TEXT, nhom_sp TEXT, trang_thai TEXT, qua_trinh TEXT, phan_loai_bh TEXT, phan_loai_loi TEXT, ngay_tao TEXT, ngay_xong TEXT, ten_ktv TEXT, ten_hang TEXT, ym_tao TEXT, yw_tao TEXT, data_json TEXT NOT NULL, synced_at TEXT DEFAULT (datetime('now')));" --remote
    echo   OK: Tao bang xong
)

REM -- STEP 4B: Kiem tra Python --
echo.
echo [4B] Kiem tra Python...
python --version >nul 2>&1
if errorlevel 1 (
    echo   LOI: Python chua cai
    echo   Tai tai: https://python.org/downloads
    pause
    exit /b 1
)
python -c "import pandas" >nul 2>&1
if errorlevel 1 (
    echo   Cai pandas + openpyxl...
    pip install pandas openpyxl
)
echo   OK: Python san sang

REM -- STEP 4C: Convert PENDING --
echo.
echo [4C] Convert PENDING.xlsx sang SQL...
if exist "data\PENDING.xlsx" (
    python scripts\excel_to_sql.py --src PENDING --mode full --out pending_upload.sql
    if errorlevel 1 (
        echo   LOI: Convert PENDING that bai
        pause
        exit /b 1
    )
    echo   OK: pending_upload.sql da tao
) else (
    echo   LOI: Khong tim thay data\PENDING.xlsx
    echo   Copy file vao: %CD%\data\PENDING.xlsx
    pause
    exit /b 1
)

REM -- STEP 4D: Convert FINISHED --
if exist "data\FINISHED.xlsx" (
    echo.
    echo [4D] Convert FINISHED.xlsx sang SQL...
    python scripts\excel_to_sql.py --src FINISHED --mode full --out finished_upload.sql
    echo   OK: finished_upload.sql da tao
) else (
    echo   Khong co FINISHED.xlsx - bo qua
)

REM -- STEP 4E: Upload PENDING --
echo.
echo [4E] Upload PENDING len Remote D1...
python scripts\split_and_execute.py --file pending_upload.sql --db %DB_NAME% --db-id %DB_ID%
if errorlevel 1 (
    echo   Thu upload truc tiep...
    wrangler d1 execute %DB_NAME% --database-id %DB_ID% --file=pending_upload.sql --remote
)
echo   OK: PENDING upload xong

REM -- STEP 4F: Upload FINISHED --
if exist finished_upload.sql (
    echo.
    echo [4F] Upload FINISHED len Remote D1...
    python scripts\split_and_execute.py --file finished_upload.sql --db %DB_NAME% --db-id %DB_ID%
    if errorlevel 1 (
        wrangler d1 execute %DB_NAME% --database-id %DB_ID% --file=finished_upload.sql --remote
    )
    echo   OK: FINISHED upload xong
)

REM -- Kiem tra lai --
echo.
echo [4G] Kiem tra data sau upload...
wrangler d1 execute %DB_NAME% --database-id %DB_ID% --command "SELECT src, COUNT(*) as total FROM warranty GROUP BY src;" --remote

:step_deploy
REM -- STEP 5: Kiem tra wrangler.toml --
echo.
echo [5/6] Kiem tra wrangler.toml...
if exist worker\wrangler.toml (
    findstr /c:"%DB_ID%" worker\wrangler.toml >nul
    if errorlevel 1 (
        echo   CANH BAO: database_id trong worker\wrangler.toml co the SAI
        echo   Mo file worker\wrangler.toml va sua thanh:
        echo   database_id = "%DB_ID%"
        echo.
        type worker\wrangler.toml
        echo.
        pause
    ) else (
        echo   OK: database_id trong wrangler.toml chinh xac
    )
) else (
    echo   CANH BAO: Khong tim thay worker\wrangler.toml
)

REM -- STEP 6: Deploy Workers --
echo.
echo [6/6] Deploy Cloudflare Workers...
if exist worker\wrangler.toml (
    cd worker
    wrangler deploy
    cd ..
    echo   OK: Deploy xong
) else (
    echo   Bo qua deploy - khong co worker\wrangler.toml
)

REM -- Test API --
echo.
echo ==================================================
echo   HOAN TAT! Mo browser kiem tra API:
echo ==================================================
echo.
echo   %API%/health
echo   %API%/api/counts
echo.
start "" "%API%/health"
timeout /t 2 /nobreak >nul
start "" "%API%/api/counts"

echo.
echo Neu health tra ve total_rows ^> 0: THANH CONG!
echo Neu van rong: chay lenh trong CMD:
echo   cd worker
echo   wrangler tail
echo.
pause
