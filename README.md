# TruffleHogOnRepos
## TLDR;
A PowerShell script to automate running TruffleHog on all repositories of a company

### Description
This script will run through an entire GitHub Company's set of repositories, clone it to disk and then scan it (multi threaded) with [TruffleHog](https://github.com/trufflesecurity/truffleHog).
When it has findings it will create a json file per repo detailing it's findings.

## Requirements
* You need to have TruffleHog installed and on your `$Env:Path`.
* You need to have Git installed and on your `$Env:Path`.

## Usage
Here's how you use it:

### Lazy individual
`./TruffleHogOnRepos.ps1 -CompanyName aws`

It will run in the folder you are currently in. This will create a subfolder called trufflehogOutput where the results will be dropped.

### Less lazy individual
`./TruffleHogOnRepos.ps1 -CompanyName aws -Path ./amazon-git`

It will run in the folder you've specified. This will create a subfolder called trufflehogOutput where the results will be dropped.

### Hard working individual
`./TruffleHogOnRepos.ps1 -CompanyName aws -Path ./amazon-git -OutputPath ./amazon-git/output`

It will run in the folder you've specified with the output folder you've specified. 

### Running it on a local set of repositories
`./TruffleHogOnRepos.ps1 -Path ./amazon-git`

See the ommitted `-CompanyName`, it will now skip the cloning of repos and go directly into scanning the folders in the given `-Path`