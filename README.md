# GitHub Release Asset Downloader

This script allows you to download assets from the latest releases of GitHub repositories listed in a `repo.txt` file. The process is interactive, allowing you to choose specific repositories and assets to download.

---

## Features

- Reads repository names from a `repo.txt` file.
- Fetches the latest release of specified repositories from GitHub.
- Allows selection of repositories and assets to download.
- Downloads all selected assets to a designated folder.

---

## Prerequisites

- **PowerShell 5.1** or later.
- An active internet connection.

---

## File Structure

```plaintext
.
├── script.ps1         # The script file
├── repo.txt           # File containing the list of repositories
├── downloads/         # Folder where assets will be saved
