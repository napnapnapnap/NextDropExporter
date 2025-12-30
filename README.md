# NextDropExporter (WotLK 3.3.5a)

World of Warcraft addon that collects character data (achievements, criterias, professions, collections, stats, reputation, armory) and produces a compact export string for external decoding.

This fork is adapted for **WotLK 3.3.5a** (private servers) and for http://findmy.nextdrop.ovh/.

## Install

- The latest release is at https://github.com/napnapnapnap/NextDropExporter/archive/refs/heads/main.zip
- Inside `NextDropExporter-main`, copy `NextDropExporter/` into your WoW folder: `Interface/AddOns/`
- **Ensure the `.toc` is at: `Interface/AddOns/NextDropExporter/NextDropExporter.toc`**

## Usage

- Open UI: `/nd` or `/nextdrop`
- Export: go to the **Export** tab and copy the string
- Import the string on http://findmy.nextdrop.ovh/
- Debug toggle: `/nddebug` (or `/nextdropdebug`)
