param(
  [parameter(Mandatory=$true)]
  [String]$ReleaseVersion
)

$ErrorActionPreference = 'Stop'

Write-Host "Attempting to release $ReleaseVersion..."

if ($null -eq $ENV:RELEASE_GITHUB_USERNAME) {
  Throw "Missing RELEASE_GITHUB_USERNAME environment variable"
  Exit 1
}
if ($null -eq $ENV:RELEASE_GITHUB_TOKEN) {
  Throw "Missing RELEASE_GITHUB_TOKEN environment variable"
  Exit 1
}

# Adapted from https://www.herebedragons.io/powershell-create-github-release-with-artifact
function Update-GitHubRelease($versionNumber, $preRelease, $releaseNotes, $artifactOutputDirectory, $gitHubUsername, $gitHubRepository, $gitHubApiUsername, $gitHubApiKey)
{
  $draft = $false

  $auth = 'Basic ' + [Convert]::ToBase64String([Text.Encoding]::ASCII.GetBytes($gitHubApiUsername + ':' + $gitHubApiKey));

  # Github uses TLS 1.2
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

  # Find existing release
  $ReleaseDetails = $null
  $releaseParams = @{
    Uri = "https://api.github.com/repos/$gitHubUsername/$gitHubRepository/releases/tags/$versionNumber";
    Method = 'GET';
    Headers = @{
      Authorization = $auth;
    }
    ContentType = 'application/json';
  }
  try {
    $ReleaseDetails = Invoke-RestMethod @releaseParams
  }
  catch {
    # Release is missing, create it
    $ReleaseDetails = $null
  }

  if ($ReleaseDetails -eq $null) {
    Write-Host "Creating release $versionNumber"
    # Create a release
    $releaseData = @{
      tag_name = [string]::Format("{0}", $versionNumber);
      name = [string]::Format("{0}", $versionNumber);
      body = $releaseNotes;
      draft = $draft;
      prerelease = $preRelease;
    }
    $releaseParams = @{
      ContentType = 'application/json'
      Uri = "https://api.github.com/repos/$gitHubUsername/$gitHubRepository/releases";
      Method = 'POST';
      Headers = @{
        Authorization = $auth;
      }
      Body = (ConvertTo-Json $releaseData -Compress)
    }
    $ReleaseDetails = Invoke-RestMethod @releaseParams
  } else {
    Write-Host "Updating release $versionNumber"
    # Create a release
    $releaseData = @{
      tag_name = [string]::Format("{0}", $versionNumber);
      name = [string]::Format("{0}", $versionNumber);
      body = $releaseNotes;
      draft = $draft;
      prerelease = $preRelease;
    }
    $releaseParams = @{
      ContentType = 'application/json'
      Uri = "https://api.github.com/repos/$gitHubUsername/$gitHubRepository/releases/$($ReleaseDetails.id)";
      Method = 'PATCH';
      Headers = @{
        Authorization = $auth;
      }
      Body = (ConvertTo-Json $releaseData -Compress)
    }
    $ReleaseDetails = Invoke-RestMethod @releaseParams
  }

  # Upload assets
  $uploadUri = $ReleaseDetails | Select -ExpandProperty upload_url
  $uploadUri = $uploadUri -creplace '\{\?name,label\}'

  Get-ChildItem -Path $artifactOutputDirectory |
    Where-Object { $_.Extension -ne '.md'} |
     ForEach-Object {
    $filename = $_.Name
    $filepath = $_.Fullname
    Write-Host "Uploading $filename ..."

    $uploadParams = @{
      Uri = $uploadUri;
      Method = 'POST';
      Headers = @{
        Authorization = $auth;
      }
      ContentType = 'application/text';
      InFile = $filepath
    }

    if ($filename -match '\.zip$') {
      $uploadParams.ContentType = 'application/zip'
    }
    if ($filename -match '\.gz$') {
      $uploadParams.ContentType = 'application/tar+gzip'
    }
    $uploadParams.Uri += "?name=$filename"

    Invoke-RestMethod @uploadParams | Out-Null
  }
}

function Get-ReleaseNotes($Version) {
  Write-Host "Getting release notes for version $Version ..."

  $changelog = Join-Path -Path $PSScriptRoot -ChildPath '..\CHANGELOG.md'

  $releaseNotes = $null
  $inSection = $false
  Get-Content $changelog | ForEach-Object {
    $line = $_

    if ($inSection) {
      if ($line -match "^## ") {
        $inSection = $false
      } else {
        $releaseNotes = $releaseNotes + "`n" + $line
      }
    } else {
      if ($line -match "^## ${version} ") {
        $releaseNotes = $line
        $inSection = $true
      }
    }
  }
  return $releaseNotes
}

function Test-APIVersion($artifactDir) {
  Write-Host "Version to release is $ReleaseVersion"
  $packageJSON = Join-Path $PSScriptRoot '..' 'package.json'
  $packageVersion = (Get-Content $packageJSON -Raw | ConvertFrom-Json -AsHashtable).version
  Write-Host "Version in package.json is $packageVersion"

  $apiJSON = Join-Path $artifactDir 'openapi-terraform-cloud.json'
  $apiVersion = (Get-Content $apiJSON -Raw | ConvertFrom-Json -AsHashtable).info.version
  Write-Host "Version in openapi-terraform-cloud.json is $apiVersion"

  if ($ReleaseVersion -ne $packageVersion) {
    Throw "Package version is not the version we are trying to release"
    Exit 1
  }

  if ($ReleaseVersion -ne $apiVersion) {
    Throw "API version is not the version we are trying to release"
    Exit 1
  }
}

$artifactDir = Join-Path $PSScriptRoot '..' 'specifications'

# Validate the release number
Test-APIVersion -artifactDir $artifactDir

Update-GitHubRelease -versionNumber $releaseVersion `
               -preRelease $false `
               -releaseNotes (Get-ReleaseNotes -Version $releaseVersion) `
               -artifactOutputDirectory $artifactDir `
               -gitHubUsername 'glennsarti' `
               -gitHubRepository 'openapi-terraform-cloud' `
               -gitHubApiUsername $ENV:RELEASE_GITHUB_USERNAME `
               -gitHubApiKey $ENV:RELEASE_GITHUB_TOKEN
