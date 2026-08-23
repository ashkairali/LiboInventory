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
- Local library server support
- Access through a web browser

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

---

# Installation

## Recommended: Windows Installer

For normal users, **no separate R or RStudio installation is required**.

### Step 1: Download Libo Inventory

Go to the **Releases** section of this GitHub repository and download:

**`LiboInventory_Setup.exe`**

### Step 2: Install

Double-click:

`LiboInventory_Setup.exe`

Follow the installation instructions.

The installer will install Libo Inventory and its required components.

### Step 3: Start Libo Inventory

After installation, start **Libo Inventory** using the installed application.

The application will start a local web server.

### Step 4: Open Libo Inventory

Open a web browser and go to:

`http://localhost:3838`

The Libo Inventory interface should appear in your browser.

---

# Running on a Library Server

Libo Inventory can be installed on a computer that acts as a local library server.

The application uses port **3838**.

For example, if the server computer has the local IP address:

`192.168.1.25`

other computers on the same local network can access:

`http://192.168.1.25:3838`

### Important

The server computer must be running Libo Inventory for other computers to access the application.

Windows Firewall may need to allow incoming connections on port **3838**.

For institutional use, it is recommended that the application be installed on a dedicated library/server computer.

---

# Data Storage

Libo Inventory uses **SQLite** for local data storage.

Application data is stored locally on the computer running Libo Inventory.

The database and local inventory data are intentionally excluded from the public GitHub repository.

> **Important:** Do not upload library inventory data, personal data, accession records, or other confidential information to the public GitHub repository.

Libraries should maintain appropriate backups of their local database and application data.

---

# Project Structure

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
