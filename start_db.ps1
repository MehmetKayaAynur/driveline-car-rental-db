# Starts the local PostgreSQL 17 server for the DriveLine project.
# The server was set up as a manual cluster (not a Windows service), so it must
# be started after each reboot. Run:  powershell -ExecutionPolicy Bypass -File start_db.ps1
$bin  = "C:\Program Files\PostgreSQL\17\bin"
$data = "C:\Users\mkaya\pgdata"
$log  = "C:\Users\mkaya\pglog.txt"

& "$bin\pg_ctl.exe" -D $data status | Out-Null
if ($LASTEXITCODE -eq 0) {
    Write-Host "PostgreSQL is already running."
} else {
    & "$bin\pg_ctl.exe" -D $data -l $log start
    Write-Host "PostgreSQL started (data dir: $data)."
}
