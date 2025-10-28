Write-Host @"
                                         _______          _        _____                      _                 _           
                                        |__   __|        | |      |  __ \                    | |               | |          
   ___ __ _ _ __ ___  _ __   ___           | | ___   ___ | |      | |  | | _____      ___ __ | | ___   __ _  __| | ___ _ __ 
  / __/ _` | '_ ` _ \| '_ \ / _ \          | |/ _ \ / _ \| |      | |  | |/ _ \ \ /\ / / '_ \| |/ _ \ / _` |/ _` |/ _ \ '__|
 | (_| (_| | | | | | | |_) |  __/          | | (_) | (_) | |      | |__| | (_) \ V  V /| | | | | (_) | (_| | (_| |  __/ |   
  \___\__, |_| |_| |_| .__/ \___|          |_|\___/ \___/|_|      |_____/ \___/ \_/\_/ |_| |_|_|\___/ \__,_|\__,_|\___|_|   
         | |         | |                                                                                                    
         |_|         |_|                                                                                                                                                                               
"@ -ForegroundColor Red                                               

Write-Host @"
WARNING: MAKE SURE U HAVE THE SUSPECTS CONSENT BEFORE RUNNING, 
SCRIPT WILL ADD C:\SCREENSHARE TO ANTIVIRUS EXCLUSIONS. 
"@ -ForegroundColor Red

$currentPrincipal = New-Object Security.Principal.WindowsPrincipal([Security.Principal.WindowsIdentity]::GetCurrent())
if (-not $currentPrincipal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    Write-Host "This script requires Administrator privileges." -ForegroundColor Yellow
    Write-Host "Restarting as Administrator" -ForegroundColor Yellow
    
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = "PowerShell"
    $psi.Arguments = "-NoProfile -ExecutionPolicy Bypass -File `"$($MyInvocation.MyCommand.Path)`""
    $psi.Verb = "RunAs"
    
    try {
        [System.Diagnostics.Process]::Start($psi) | Out-Null
        exit
    }
    catch {
        Write-Host "no admin" -ForegroundColor Red
    }
}

$DownloadPath = "C:\Screenshare"
if (!(Test-Path $DownloadPath)) {
    New-Item -ItemType Directory -Path $DownloadPath -Force | Out-Null
}


function Add-DefenderExclusion {
    Write-Host "`nSetting up antivirus exclusion" -ForegroundColor Cyan
    Write-Host "Adding Windows Defender exclusion for $DownloadPath" -NoNewline
    
    $success = $false
    

    try {
        if (Get-Command Get-MpPreference -ErrorAction SilentlyContinue) {
            $existingExclusions = (Get-MpPreference -ErrorAction Stop).ExclusionPath
            if ($existingExclusions -notcontains $DownloadPath) {
                Add-MpPreference -ExclusionPath $DownloadPath -ErrorAction Stop
            }
            Write-Host " Success" -ForegroundColor Green
            $success = $true
        }
    }
    catch {
      
    }
    
  
    if (-not $success) {
        try {
            $regPath = "HKLM:\SOFTWARE\Microsoft\Windows Defender\Exclusions\Paths"
            if (Test-Path $regPath) {
                $existingValue = Get-ItemProperty -Path $regPath -Name $DownloadPath -ErrorAction SilentlyContinue
                if (-not $existingValue) {
                    New-ItemProperty -Path $regPath -Name $DownloadPath -Value 0 -PropertyType DWORD -Force -ErrorAction Stop | Out-Null
                }
                Write-Host " Success" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
           
        }
    }
    
    
    if (-not $success) {
        try {
            $namespace = "root\Microsoft\Windows\Defender"
            if (Get-WmiObject -Namespace $namespace -List -ErrorAction SilentlyContinue) {
                $defender = Get-WmiObject -Namespace $namespace -Class "MSFT_MpPreference" -ErrorAction Stop
                $defender.AddExclusionPath($DownloadPath)
                Write-Host " Success" -ForegroundColor Green
                $success = $true
            }
        }
        catch {
           
        }
    }
    
    if (-not $success) {
        Write-Host " Failed" -ForegroundColor Red
        
    }
    
    return $success
}


$exclusionAdded = Add-DefenderExclusion

if (-not $exclusionAdded) {
    Write-Host "`nCould not add automatic antivirus exclusion, you are prolly using some 3rd party av." -ForegroundColor Yellow
    Write-Host "`nContinuing with downloads (some might be deleted)" -ForegroundColor Yellow
    Start-Sleep -Seconds 3
} else {
    
}

function Download-File {
    param([string]$Url, [string]$FileName, [string]$ToolName)
    
    try {
        $outputPath = Join-Path $DownloadPath $FileName
        Write-Host "  Downloading $ToolName" -NoNewline
        $ProgressPreference = 'SilentlyContinue'
        Invoke-WebRequest -Uri $Url -OutFile $outputPath -UserAgent "PowerShell" -UseBasicParsing | Out-Null
        
        if ($FileName -like "*.zip") {
            $extractPath = Join-Path $DownloadPath ($FileName -replace '\.zip$', '')
            Expand-Archive -Path $outputPath -DestinationPath $extractPath -Force | Out-Null
            Remove-Item $outputPath -Force | Out-Null
        }
        Write-Host " Done" -ForegroundColor Green
        return $true
    }
    catch {
        Write-Host " Failed" -ForegroundColor Red
        return $false
    }
    finally {
        $ProgressPreference = 'Continue'
    }
}

function Download-Tools {
    param([array]$Tools, [string]$CategoryName)
    
    $successCount = 0
    
    Write-Host "`nDownloading $CategoryName tools" -ForegroundColor Cyan
    foreach ($tool in $Tools) {
        if (Download-File -Url $tool.Url -FileName $tool.File -ToolName $tool.Name) {
            $successCount++
        }
    }
    
    Write-Host ($CategoryName + ": " + $successCount + "/" + $Tools.Count + " tools downloaded successfully") -ForegroundColor Cyan
}

$spowksucksasscheeks = @(
    @{ Name="Kernel Live Dump Analyzer Parser"; Url="https://github.com/spokwn/KernelLiveDumpTool/releases/download/v1.1/KernelLiveDumpTool.exe"; File="KernelLiveDumpTool.exe" },
    @{ Name="BAM Parser"; Url="https://github.com/spokwn/BAM-parser/releases/download/v1.2.9/BAMParser.exe"; File="BAMParser.exe" },
    @{ Name="Paths Parser"; Url="https://github.com/spokwn/PathsParser/releases/download/v1.2/PathsParser.exe"; File="PathsParser.exe" },
    @{ Name="JournalTrace"; Url="https://github.com/spokwn/JournalTrace/releases/download/1.2/JournalTrace.exe"; File="JournalTrace.exe" },
    @{ Name="Tool"; Url="https://github.com/spokwn/Tool/releases/download/v1.1.3/espouken.exe"; File="espouken.exe" },
    @{ Name="PcaSvc Executed"; Url="https://github.com/spokwn/pcasvc-executed/releases/download/v0.8.7/PcaSvcExecuted.exe"; File="PcaSvcExecuted.exe" },
    @{ Name="BAM Deleted Keys"; Url="https://github.com/spokwn/BamDeletedKeys/releases/download/v1.0/BamDeletedKeys.exe"; File="BamDeletedKeys.exe" },
    @{ Name="Prefetch Parser"; Url="https://github.com/spokwn/prefetch-parser/releases/download/v1.5.5/PrefetchParser.exe"; File="PrefetchParser.exe" },
    @{ Name="Activities Cache Parser"; Url="https://github.com/spokwn/ActivitiesCache-execution/releases/download/v0.6.5/ActivitiesCacheParser.exe"; File="ActivitiesCacheParser.exe" }
)

$nirsoftTools = @(
    @{ Name="WinPrefetchView"; Url="https://www.nirsoft.net/utils/winprefetchview-x64.zip"; File="winprefetchview-x64.zip" },
    @{ Name="USBDeview"; Url="https://www.nirsoft.net/utils/usbdeview-x64.zip"; File="usbdeview-x64.zip" },

)

$otherTools = @(
    @{ Name="System Informer"; Url="https://github.com/winsiderss/si-builds/releases/download/3.2.25297.1516/systeminformer-build-canary-setup.exe"; File="systeminformer-build-canary-setup.exe" },
    @{ Name="Everything Search"; Url="https://www.voidtools.com/Everything-1.4.1.1029.x86-Setup.exe"; File="Everything-1.4.1.1029.x86-Setup.exe" },
    @{ Name="FTK Imager"; Url="https://d1kpmuwb7gvu1i.cloudfront.net/AccessData_FTK_Imager_4.7.1.exe"; File="AccessData_FTK_Imager_4.7.1.exe" }
)


}

Write-Host "`nHit up @praiselily if u got ideas for tools to add" -ForegroundColor Cyan
Write-Host "Downloads are located in: $DownloadPath" -ForegroundColor Cyan

