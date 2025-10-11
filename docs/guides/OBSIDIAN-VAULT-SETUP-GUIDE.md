---
title: Obsidian Vault Setup Guide
version: 1.0
author: Rohit Anand
last_updated: 2025-10-09
category: Guide
tags: [obsidian, setup, automation, documentation]
context: SC
---

# Obsidian Vault Setup Guide

## Overview

This guide provides comprehensive instructions for using the `setup-obsidian-vault.sh` script to create new Obsidian vaults with pre-configured plugins and settings. The script is designed to create documentation-focused vaults with Excalidraw diagram support.

## What This Script Does

The script automates the creation of a new Obsidian vault with:

1. **Core Obsidian Configuration**
   - Essential core plugins (file explorer, search, graph, canvas, backlinks)
   - Optimized settings for documentation work
   - Daily notes and templates disabled by default (can be enabled later)

2. **Community Plugins**
   - **Excalidraw** (v2.16.1+): Create and edit diagrams directly in Obsidian
   - **Heading Shifter** (v1.9.0+): Easily modify markdown heading levels

3. **Directory Structure**
   - `.obsidian/` configuration directory
   - `Excalidraw/` folder for diagram storage
   - Plugin installations with all necessary files

## Prerequisites

### System Requirements
- **Git Bash** or compatible bash shell (Windows)
- **Linux/macOS**: Native bash shell
- **Obsidian** application installed (v1.5.7 or later)

### Source Vault Requirements
The script requires a source vault with the plugins already installed:
- Default source: `C:\Users\Rohit\workspace\ObsidianVault`
- Must contain `.obsidian/plugins/obsidian-excalidraw-plugin/`
- Must contain `.obsidian/plugins/obsidian-heading-shifter/`

## Installation

### 1. Locate the Script

The script is located at:
```
C:\Users\Rohit\workspace\ObsidianVault\processing\setup-obsidian-vault.sh
```

### 2. Make Script Executable (Linux/macOS)

```bash
chmod +x processing/setup-obsidian-vault.sh
```

Windows Git Bash doesn't require this step.

## Usage

### Basic Syntax

```bash
./processing/setup-obsidian-vault.sh <target-vault-path>
```

### Example 1: Create New Vault for SC Process Master

```bash
cd /c/Users/Rohit/workspace/ObsidianVault
./processing/setup-obsidian-vault.sh /c/Users/Rohit/workspace/sc-process-master
```

### Example 2: Create New Documentation Vault

```bash
./processing/setup-obsidian-vault.sh /c/Users/Rohit/Documents/ProjectDocs
```

### Example 3: Create Vault in Current Directory

```bash
./processing/setup-obsidian-vault.sh ./new-vault
```

## Script Output

The script provides colored, detailed output:

```
═══════════════════════════════════════════════════════
  Obsidian Vault Setup Script
═══════════════════════════════════════════════════════

ℹ Source vault: /c/Users/Rohit/workspace/ObsidianVault
ℹ Target vault: /c/Users/Rohit/workspace/sc-process-master

═══════════════════════════════════════════════════════
  Creating .obsidian Directory Structure
═══════════════════════════════════════════════════════

✓ Created .obsidian directory structure

[... additional output ...]

═══════════════════════════════════════════════════════
  Setup Complete
═══════════════════════════════════════════════════════

✓ Obsidian vault configured successfully!
```

## What Gets Created

### Directory Structure

```
target-vault/
├── .obsidian/
│   ├── plugins/
│   │   ├── obsidian-excalidraw-plugin/
│   │   │   ├── main.js
│   │   │   ├── manifest.json
│   │   │   ├── styles.css
│   │   │   └── data.json
│   │   └── obsidian-heading-shifter/
│   │       ├── main.js
│   │       └── manifest.json
│   ├── app.json
│   ├── appearance.json
│   ├── community-plugins.json
│   └── core-plugins.json
└── Excalidraw/
    └── (empty, ready for diagrams)
```

### Configuration Files

#### app.json
```json
{
  "propertiesInDocument": "hidden"
}
```
- Hides property fields in document view for cleaner reading

#### core-plugins.json
Enables essential plugins:
- File explorer, search, switcher
- Graph view and canvas
- Backlinks and outgoing links
- Tag pane, properties
- Note composer, command palette
- Bookmarks, outline, word count
- Workspaces, file recovery

Disables by default:
- Daily notes, templates (documentation focus)
- Audio recorder, slides
- Publish, sync

#### community-plugins.json
```json
[
  "obsidian-excalidraw-plugin",
  "obsidian-heading-shifter"
]
```

## Post-Setup Steps

### 1. Open the Vault in Obsidian

1. Launch Obsidian application
2. Click "Open folder as vault"
3. Navigate to your target vault path
4. Select the folder

### 2. Trust the Plugins

On first open, Obsidian will prompt:
- "This vault has community plugins. Do you want to enable them?"
- Click **"Trust author and enable plugins"**

### 3. Verify Installation

Check that plugins are active:
1. Open Settings (gear icon)
2. Navigate to Community plugins
3. Verify both plugins are listed and enabled:
   - Excalidraw
   - Heading Shifter

### 4. Test Excalidraw

1. Press `Ctrl/Cmd + P` to open command palette
2. Type "Excalidraw: Create new drawing"
3. Create a test diagram
4. Verify it saves to `Excalidraw/` folder

## Use Cases

### Use Case 1: Migrating SC Process Master

**Scenario**: Move sc-process-master from nested vault to standalone

```bash
# 1. Create new vault configuration
./processing/setup-obsidian-vault.sh /c/Users/Rohit/workspace/sc-process-new

# 2. Move content from sc-process-master to sc-process-new
cp -r sc-process-master/* /c/Users/Rohit/workspace/sc-process-new/

# 3. Move git repository
mv sc-process-master/.git /c/Users/Rohit/workspace/sc-process-new/.git

# 4. Open new vault in Obsidian
```

### Use Case 2: Creating Client Documentation Vault

**Scenario**: New client project needs dedicated documentation vault

```bash
# Create vault for client
./processing/setup-obsidian-vault.sh /c/Users/Rohit/workspace/client-acme-docs

# Initialize git
cd /c/Users/Rohit/workspace/client-acme-docs
git init
git add .
git commit -m "Initial vault setup"
```

### Use Case 3: Team Member Onboarding

**Scenario**: Set up standardized vault for team member

```bash
# Create vault in team member's workspace
./processing/setup-obsidian-vault.sh /c/Users/TeamMember/workspace/sc-docs

# Team member opens vault and starts working
# All plugins and settings pre-configured
```

## Customization

### Enabling Daily Notes

If you need daily notes functionality:

1. Open vault in Obsidian
2. Settings → Core plugins
3. Enable "Daily notes"
4. Configure daily notes settings:
   - Date format: `YYYY-MM-DD`
   - New file location: `daily-notes`
   - Template file: Create or import template

### Adding Templates

1. Create `Templates/` folder in vault
2. Settings → Core plugins → Enable "Templates"
3. Settings → Templates → Template folder location: `Templates`
4. Create template files in the folder

### Modifying Plugin Settings

The script copies default Excalidraw settings. To customize:

1. Open vault in Obsidian
2. Settings → Excalidraw
3. Modify settings as needed
4. Settings are saved to `.obsidian/plugins/obsidian-excalidraw-plugin/data.json`

## Troubleshooting

### Script Errors

**Error: "Target vault path is required"**
- Solution: Provide path as argument
- Example: `./setup-obsidian-vault.sh /path/to/vault`

**Error: "Source vault not found"**
- Solution: Verify script is run from ObsidianVault directory
- Or: Edit `SOURCE_VAULT` variable in script to point to correct location

**Error: "Excalidraw plugin not found in source vault"**
- Solution: Ensure source vault has Excalidraw installed
- Verify path: `.obsidian/plugins/obsidian-excalidraw-plugin/`

### Obsidian Issues

**Plugins Not Loading**
- Ensure you clicked "Trust author and enable plugins"
- Check Settings → Community plugins → Browse for updates
- Restart Obsidian

**Excalidraw Drawings Not Rendering**
- Verify plugin is enabled: Settings → Community plugins
- Check file extension is `.excalidraw.md`
- Try reloading Obsidian

**Existing .obsidian Folder**
- Script creates config in existing directory
- Backup existing `.obsidian/` before running script if needed

## Advanced Configuration

### Modifying Core Plugins

Edit the `core-plugins.json` section in the script:

```bash
# Enable daily notes by default
cat > "$OBSIDIAN_DIR/core-plugins.json" << 'EOF'
{
  ...
  "daily-notes": true,
  "templates": true,
  ...
}
EOF
```

### Adding More Community Plugins

1. Install plugin manually in source vault first
2. Add plugin ID to `community-plugins.json` in script
3. Add plugin copy section:

```bash
# Install Custom Plugin
CUSTOM_PLUGIN_SRC="$SOURCE_VAULT/.obsidian/plugins/plugin-id"
CUSTOM_PLUGIN_DEST="$PLUGINS_DIR/plugin-id"

mkdir -p "$CUSTOM_PLUGIN_DEST"
cp "$CUSTOM_PLUGIN_SRC/main.js" "$CUSTOM_PLUGIN_DEST/"
cp "$CUSTOM_PLUGIN_SRC/manifest.json" "$CUSTOM_PLUGIN_DEST/"
```

### Changing Source Vault

Edit the script's `SOURCE_VAULT` variable:

```bash
# Change from automatic detection to specific path
SOURCE_VAULT="/c/Users/Rohit/different-vault"
```

## Script Maintenance

### Updating Plugin Versions

When source vault plugins are updated:
1. Update source vault plugins via Obsidian
2. Run script again - it will copy latest versions
3. No script modification needed

### Version Control for Script

The script is tracked in the vault repository:
- Location: `processing/setup-obsidian-vault.sh`
- Commit changes when customizing
- Share with team via git

## Best Practices

### 1. Test Before Production Use
```bash
# Test in temporary location first
./processing/setup-obsidian-vault.sh /tmp/test-vault
```

### 2. Backup Existing Vaults
```bash
# Before modifying existing vault
cp -r existing-vault existing-vault-backup
```

### 3. Version Control New Vaults
```bash
# Initialize git immediately after creation
cd new-vault
git init
git add .
git commit -m "Initial vault setup with Excalidraw"
```

### 4. Document Custom Settings
- Keep notes on customizations made post-setup
- Consider creating custom script variants for different use cases
- Track plugin version requirements

## Security Considerations

### Plugin Trust

- Script copies plugins from trusted source vault
- Always verify plugin sources before installation
- Obsidian will prompt to trust plugins on first open

### File Permissions

- Script creates standard file permissions
- No special permissions required
- Safe to run in user directories

## Support and Resources

### Documentation
- Obsidian Documentation: https://help.obsidian.md
- Excalidraw Plugin: https://github.com/zsviczian/obsidian-excalidraw-plugin
- Heading Shifter Plugin: https://github.com/k4a-l/obsidian-heading-shifter

### Getting Help
- Check script output for specific error messages
- Verify source vault has required plugins installed
- Test with minimal example first

## Appendix: Full Script Reference

### Script Location
```
C:\Users\Rohit\workspace\ObsidianVault\processing\setup-obsidian-vault.sh
```

### Script Dependencies
- bash (Git Bash on Windows)
- Source vault with plugins at: `.obsidian/plugins/`
- Write permissions to target directory

### Exit Codes
- `0`: Success
- `1`: Error (missing arguments, source not found, plugin not found)

### Output Features
- Colored status messages (info, success, warning, error)
- Progress headers for each section
- Summary of configuration on completion
- Next steps guidance

## Version History

### v1.0 (2025-10-09)
- Initial release
- Excalidraw plugin support
- Heading Shifter plugin support
- Documentation-focused core plugin configuration
- Comprehensive error handling and user feedback

---

**Script maintained by**: Rohit Anand
**Last updated**: 2025-10-09
**For**: Symphony Core documentation workflows
