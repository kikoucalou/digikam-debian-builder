# 🛠️ digiKam Debian Builder Script

[![License](https://img.shields.io/badge/license-GPLv3-blue.svg)](LICENSE)

This automated script builds a **Debian package (.deb) for [digiKam](https://invent.kde.org/graphics/digikam)** directly from the official Git repository.  
Perfect for advanced users who want the latest features and improvements on Debian, Ubuntu, or derived distributions.

## 📸 About digiKam

> *digiKam is an advanced open-source digital photo management application that runs on Linux, Windows, and MacOS. The application provides a comprehensive set of tools for importing, managing, editing, and sharing photos and raw files.*

🔗 Official website: [https://invent.kde.org/graphics/digikam](https://invent.kde.org/graphics/digikam)

## ✅ Script Features

- 🔁 Automatic update from the official `master` branch
- 🏷️ Version detection (Git tag, commit hash, timestamp)
- 📦 Full `.deb` package generation using `dpkg-buildpackage`
- 🔧 Automatic dependency detection via `CMakeLists.txt`
- 🗂️ Clean Debian package integration:
  - `Replaces: digikam`
  - `Conflicts: digikam`
  - `Provides: digikam`
- 📜 Detailed logging in `build_*.log` files

## ⚙️ Prerequisites

```bash
sudo apt update
sudo apt install git dpkg-dev debhelper dh-make cmake extra-cmake-modules \
                 libkf5config-dev libkf5coreaddons-dev libkf5i18n-dev \
                 libqt5keychain-dev libopencv-dev libexiv2-dev \
                 qtbase5-dev qtwebengine5-dev qtmultimedia5-dev \
                 libsqlite3-dev libjpeg-dev libpng-dev libtiff-dev
