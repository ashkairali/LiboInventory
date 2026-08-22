# Libo Inventory

**Libo Inventory** is a web-based library stock verification and inventory management application developed using **R and Shiny**.

It is designed for libraries that need a lightweight system for conducting stock verification, recording inventory scans, identifying exceptions, and generating reports.

## Features

- Library stock verification
- Accession number scanning
- Master catalogue management
- Live scan tracking
- Exception identification
- Inventory status monitoring
- Institutional and audit details
- Stock verification reporting
- Excel report generation
- SQLite database storage
- Web-based interface
- Can be deployed on a local library server
- Can be accessed through a web browser

## Technology

- R
- Shiny
- bslib
- DT
- dplyr
- DBI
- RSQLite
- openxlsx
- SQLite

## Requirements

- Windows 10 or later
- R 4.6.0 or later
- Internet connection for the initial installation of R packages

## Installation

### 1. Install R

Download and install R from:

https://cran.r-project.org/

### 2. Download Libo Inventory

Download the Libo Inventory repository from GitHub.

You can either download the ZIP file or clone the repository using Git.

### 3. Install required packages

Open the Libo Inventory folder and double-click:

`Install-Libo-Inventory.bat`

The installer will install the required R packages.

### 4. Start Libo Inventory

Double-click:

`Start-Libo-Inventory.bat`

The application will start the Libo Inventory Shiny server.

Open the address shown by the application in a web browser.

Normally:

`http://localhost:3838`

## Running on a Library Server

Libo Inventory can be run on a computer that acts as a local library server.

The application listens on port `3838`.

For example, if the server computer has the local IP address:

`192.168.1.25`

other computers on the same network can access:

`http://192.168.1.25:3838`

The server computer must be running Libo Inventory.

Windows Firewall may need to allow incoming connections on port `3838`.

## Data Storage

Libo Inventory uses SQLite for local data storage.

Application data is stored locally on the computer running Libo Inventory.

The database and local inventory data are intentionally excluded from the GitHub repository.

**Do not upload library inventory data, personal data, or other confidential information to the public GitHub repository.**

## Project Structure

```text
LiboInventory/
│
├── app.R
├── run.R
├── Install-Libo-Inventory.bat
├── Start-Libo-Inventory.bat
├── .gitignore
│
├── data/
├── docs/
│
└── scripts/
    └── install.R
