# Suppress progress messages globally
$ProgressPreference = 'SilentlyContinue'

# Define the log file path
$logFile = "C:\Windows\Temp\elastic-agent-install.log"

# Log function
function Log {
    param ([string]$message)
    $timestamp = Get-Date -Format "yyyy-MM-dd HH:mm:ss"
    $logMessage = "[$timestamp] $message"
    $logMessage | Out-File -FilePath $logFile -Append
}

# Check if Elastic Agent is running
$agentProcess = Get-Process -Name "elastic-agent" -ErrorAction SilentlyContinue
if ($agentProcess) {
    Log "Elastic Agent is currently running. Please uninstall it before running this script."
    Write-Host "Elastic Agent is currently running. Please uninstall it before running this script."
    exit -1
}

# Define the URL of the text file containing the version number
$versionFileUrl = "https://repo.cyber.tamus.edu/elastic_agent_version.txt"

# Define the base URL for downloading Elastic Agent
$baseUrl = "https://artifacts.elastic.co/downloads/beats/elastic-agent/"

# Function to get the version number from the text file
function Get-VersionNumber {
    Log "Fetching version number from $versionFileUrl"
    $webClient = New-Object System.Net.WebClient
    $version = $webClient.DownloadString($versionFileUrl)
    Log "Fetched version number: $version"
    return $version.Trim()
}

# Function to download and install Elastic Agent
function Install-ElasticAgent {
    param (
        [string]$version,
        [string]$enrollmentToken
    )

    $zipFileName = "elastic-agent-$version-windows-x86_64.zip"
    $zipFileUrl = "$baseUrl$zipFileName"
    $tempZipFile = "$env:TEMP\$zipFileName"
    $extractPath = "$env:TEMP\ElasticAgent"
    
    # Download the ZIP file
    Log "Downloading Elastic Agent from $zipFileUrl"
    $webClient = New-Object System.Net.WebClient
    $webClient.DownloadFile($zipFileUrl, $tempZipFile)
    Log "Downloaded Elastic Agent to $tempZipFile"

    # Extract the ZIP file
    Log "Extracting Elastic Agent to $extractPath"
    Expand-Archive -Path $tempZipFile -DestinationPath $extractPath -Force
    Log "Extracted Elastic Agent"

    # Run the installation command with enrollment token and force option
    $installCommand = "$extractPath\elastic-agent-$version-windows-x86_64\elastic-agent.exe"
    $arguments = "install", "--url=https://5ac984baeeff4bd89c566035d280569f.fleet.us-east-1.aws.found.io:443", "--force", "--non-interactive", "--enrollment-token=$enrollmentToken"
    Log "Running installation command: $installCommand $arguments"
    Start-Process -FilePath $installCommand -ArgumentList $arguments -Wait
    Log "Installation command completed"

    # Check if Elastic Agent process is running
    $agentProcess = Get-Process -Name elastic-agent -ErrorAction SilentlyContinue
    if (-not $agentProcess) {
        Log "Elastic Agent installation failed."
        throw "Elastic Agent installation failed."
    }
    Log "Elastic Agent installation succeeded"

    # Clean up temporary files
    Log "Cleaning up temporary files"
    Remove-Item $tempZipFile -Force -ErrorAction SilentlyContinue
    Remove-Item $extractPath -Recurse -Force -ErrorAction SilentlyContinue
    Log "Clean up completed"
}

# Main script
try {
    Log "Script started"
    $version = Get-VersionNumber
    $enrollmentToken = "R1g0MFVaRUJRandtUm1kVG54M3k6d3RMSm41Y0lRTWE1MFpPMl9BUW1lQQ=="  # Placeholder for the enrollment token
    if ($enrollmentToken -eq "ENROLLMENT_TOKEN") {
        Log "Error: No enrollment token provided"
        throw "Error: No enrollment token provided"
    }
    Install-ElasticAgent -version $version -enrollmentToken $enrollmentToken
    Log "Script completed successfully"
} catch {
    Log "Error occurred: $_"
    Write-Host "Error occurred: $_"
    exit 1
}