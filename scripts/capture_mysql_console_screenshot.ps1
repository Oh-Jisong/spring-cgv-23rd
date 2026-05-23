param(
    [Parameter(Mandatory = $true)]
    [string]$Title,

    [Parameter(Mandatory = $true)]
    [string]$SqlFilePath,

    [Parameter(Mandatory = $true)]
    [string]$OutputPath,

    [string]$DatabaseName = "cgv_index_lab",
    [string]$MysqlPassword = "2562",
    [int]$Cols = 180,
    [int]$Lines = 42,
    [int]$WaitSeconds = 4
)

Add-Type -AssemblyName System.Windows.Forms
Add-Type -AssemblyName System.Drawing
Add-Type @"
using System;
using System.Runtime.InteropServices;
public static class Win32 {
    [DllImport("user32.dll")]
    public static extern bool SetForegroundWindow(IntPtr hWnd);

    [DllImport("user32.dll")]
    public static extern bool ShowWindow(IntPtr hWnd, int nCmdShow);

    [DllImport("user32.dll")]
    public static extern bool MoveWindow(IntPtr hWnd, int X, int Y, int nWidth, int nHeight, bool bRepaint);

    [DllImport("user32.dll")]
    public static extern bool GetWindowRect(IntPtr hWnd, out RECT rect);

    public struct RECT {
        public int Left;
        public int Top;
        public int Right;
        public int Bottom;
    }
}
"@

$mysqlExe = "C:\Program Files\MySQL\MySQL Server 8.0\bin\mysql.exe"
$sqlFile = (Resolve-Path $SqlFilePath).Path
$outputFile = [System.IO.Path]::GetFullPath($OutputPath)
$outputDir = Split-Path -Parent $outputFile
New-Item -ItemType Directory -Force -Path $outputDir | Out-Null

$batchFile = Join-Path $env:TEMP ("capture_mysql_" + [guid]::NewGuid().ToString() + ".cmd")

$batchContent = @"
@echo off
mode con: cols=$Cols lines=$Lines
title $Title
set MYSQL_PWD=$MysqlPassword
echo mysql^> source $sqlFile
cmd /c ""$mysqlExe" -E -uroot $DatabaseName < "$sqlFile""
echo.
echo Press any key to close...
pause >nul
"@

Set-Content -LiteralPath $batchFile -Value $batchContent -Encoding ASCII

$process = Start-Process cmd.exe -ArgumentList "/k", $batchFile -PassThru -WindowStyle Normal

try {
    Start-Sleep -Seconds $WaitSeconds

    $windowProcess = $null
    for ($i = 0; $i -lt 15; $i++) {
        $windowProcess = Get-Process | Where-Object { $_.MainWindowTitle -eq $Title } | Select-Object -First 1
        if ($null -ne $windowProcess) {
            break
        }
        Start-Sleep -Milliseconds 500
    }

    if ($null -eq $windowProcess) {
        throw "Could not find console window with title '$Title'."
    }

    [Win32]::ShowWindow($windowProcess.MainWindowHandle, 5) | Out-Null
    [Win32]::MoveWindow($windowProcess.MainWindowHandle, 20, 20, 1850, 980, $true) | Out-Null
    [Win32]::SetForegroundWindow($windowProcess.MainWindowHandle) | Out-Null

    Start-Sleep -Milliseconds 700

    $rect = New-Object Win32+RECT
    [Win32]::GetWindowRect($windowProcess.MainWindowHandle, [ref]$rect) | Out-Null

    $width = $rect.Right - $rect.Left
    $height = $rect.Bottom - $rect.Top

    $bitmap = New-Object System.Drawing.Bitmap $width, $height
    $graphics = [System.Drawing.Graphics]::FromImage($bitmap)
    $graphics.CopyFromScreen($rect.Left, $rect.Top, 0, 0, $bitmap.Size)
    $bitmap.Save($outputFile, [System.Drawing.Imaging.ImageFormat]::Png)
    $graphics.Dispose()
    $bitmap.Dispose()
}
finally {
    if ($null -ne $windowProcess) {
        Stop-Process -Id $windowProcess.Id -Force -ErrorAction SilentlyContinue
    }
    elseif ($null -ne $process) {
        Stop-Process -Id $process.Id -Force -ErrorAction SilentlyContinue
    }

    Remove-Item -LiteralPath $batchFile -Force -ErrorAction SilentlyContinue
}
