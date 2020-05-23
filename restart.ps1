################################
# 引数
################################
Param(
    [int]$apiPort, 
    [bool]$wipe,
    [string]$username,
    [string]$password, 
    [string]$sqlitePath,
    [string]$sqliteBackupDirPath,
    [int]$difficulty, # 0(classic), 1(expert), 2(master), 3(journey)
    [string]$worldNamePrefix,
    [string]$worldDirPath,
    [string]$worldBackupDirPath,
    [string]$vanillaServerDirPath,
    [string]$tshockDirPath
)

Write-Output "Beginning restart the tshock server."

Write-Output  "apiPort:`t$($apiPort)"
Write-Output  "wipe:`t$($wipe)"
Write-Output  "username:`t$($username)"
Write-Output  "password:`t$($password)"
Write-Output  "sqlitePath:`t$($sqlitePath)"
Write-Output  "sqliteBackupDirPath:`t$($sqliteBackupDirPath)"
Write-Output  "difficulty:`t$($difficulty)"
Write-Output  "worldNamePrefix:`t$($worldNamePrefix)"
Write-Output  "worldDirPath:`t$($worldDirPath)"
Write-Output  "worldBackupDirPath:`t$($worldBackupDirPath)"
Write-Output  "vanillaServerDirPath:`t$($vanillaServerDirPath)"
Write-Output  "tshockDirPath:`t$($tshockDirPath)"

################################
# シャットダウン
################################
$rootUrl = "http://localhost:$($apiPort)"
$token = ((Invoke-WebRequest -URI "$($rootUrl)/v2/token/create" -Method GET -Body @{username = $username; password = $password }).Content | ConvertFrom-Json).token
$message = "This server will shut down in {0} minutes."
$broadcastUrl = "$($rootUrl)/v2/server/broadcast"

Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 10) }
Start-Sleep -s 300
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 5) }
Start-Sleep -s 120
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 3) }
Start-Sleep -s 60
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 2) }
Start-Sleep -s 60
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 1) }
Start-Sleep -s 55

$message = "{0}"
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 5) }
Start-Sleep -s 1
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 4) }
Start-Sleep -s 1
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 3) }
Start-Sleep -s 1
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 2) }
Start-Sleep -s 1
Invoke-WebRequest -URI $broadcastUrl -Method GET -Body @{token = $token; msg = [String]::Format($message, 1) }
Start-Sleep -s 1

$message = if ($wipe) {
    'See you in new world a few minutes later!'
}
else {
    'See you in a few minutes later!'
}
Invoke-WebRequest -URI "$($rootUrl)/v2/server/off" -Method GET -Body @{token = $token; confirm = 'true'; message = $message; nosave = 'false' }

Start-Sleep -s 10 # サーバーシャットダウンを待つ

################################
# バックアップ
################################
$dateString = Get-Date -UFormat "%Y-%m-%d %H-%M-%S"

# DB
$sqliteBackupPath = Join-Path $sqliteBackupDirPath $dateString
New-Item $sqliteBackupPath -ItemType Directory
if (![string]::IsNullOrEmpty($sqlitePath)) {
    Write-Output "copy $($sqlitePath) to $($sqliteBackupPath)"
    Copy-Item $sqlitePath $sqliteBackupPath
}

# World 0(classic), 1(expert), 2(master), 3(journey)
$worldName = "$($worldNamePrefix)_$($difficulty)"
$worldFileName = "$($worldName).wld"
$worldPath = Join-Path $worldDirPath $worldFileName
$worldBackupPath = Join-Path  $worldBackupDirPath $dateString
New-Item $worldBackupPath -ItemType Directory
if ($wipe) {
    Write-Output "move $($worldPath) to $($worldBackupPath)"
    Move-Item $worldPath $worldBackupPath
}
else {
    Write-Output "copy $($worldPath) to $($worldBackupPath)"
    Copy-Item $worldPath $worldBackupPath
}


################################
# ワールド再作成
################################
if ($wipe) {
    $vanillaServerPath = Join-Path $vanillaServerDirPath TerrariaServer.exe
    $serverConfigPath = Join-Path $vanillaServerDirPath "serverconfig_$($difficulty).txt"
    $createWorldProcess = Start-Process -FilePath $vanillaServerPath -ArgumentList "-port 9999 -worldname `"$($worldName)`" -world `"$($worldPath)`" -autocreate 3 -config `"$($serverConfigPath)`"" -PassThru
    
    # .wldファイルができるまで最大10分待つ
    for ($i = 0; $i -eq 20; $i++) {
        Start-Sleep -s 30 # 30秒待つ
        if ([System.IO.File]::Exists($worldPath)){
            break
        }
    }

    $createWorldProcess.Kill()
}

################################
# サーバー起動
################################
Set-Location -Path $tshockDirPath
Start-Process -FilePath TerrariaServer.exe -ArgumentList "-world `"$($worldPath)`""