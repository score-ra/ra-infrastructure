#!/bin/bash

# setup-obsidian-vault.sh
# Creates a new Obsidian vault with Excalidraw and Heading Shifter plugins
#
# Usage: ./setup-obsidian-vault.sh <target-vault-path>
# Example: ./setup-obsidian-vault.sh /c/Users/Rohit/workspace/sc-process-master

set -e  # Exit on error

# Color codes for output
GREEN='\033[0;32m'
BLUE='\033[0;34m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m' # No Color

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SOURCE_VAULT="$(dirname "$SCRIPT_DIR")"  # Parent of processing directory
EXCALIDRAW_PLUGIN_ID="obsidian-excalidraw-plugin"
HEADING_SHIFTER_PLUGIN_ID="obsidian-heading-shifter"

# Function to print colored messages
print_info() {
    echo -e "${BLUE}ℹ${NC} $1"
}

print_success() {
    echo -e "${GREEN}✓${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠${NC} $1"
}

print_error() {
    echo -e "${RED}✗${NC} $1"
}

print_header() {
    echo ""
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo -e "${BLUE}  $1${NC}"
    echo -e "${BLUE}═══════════════════════════════════════════════════════${NC}"
    echo ""
}

# Check if target path is provided
if [ -z "$1" ]; then
    print_error "Error: Target vault path is required"
    echo "Usage: $0 <target-vault-path>"
    echo "Example: $0 /c/Users/Rohit/workspace/sc-process-master"
    exit 1
fi

TARGET_VAULT="$1"

# Validate source vault
if [ ! -d "$SOURCE_VAULT/.obsidian" ]; then
    print_error "Error: Source vault not found at $SOURCE_VAULT"
    exit 1
fi

print_header "Obsidian Vault Setup Script"

print_info "Source vault: $SOURCE_VAULT"
print_info "Target vault: $TARGET_VAULT"
echo ""

# Create target vault directory if it doesn't exist
if [ ! -d "$TARGET_VAULT" ]; then
    print_warning "Target directory does not exist. Creating: $TARGET_VAULT"
    mkdir -p "$TARGET_VAULT"
    print_success "Created target directory"
else
    print_info "Target directory exists: $TARGET_VAULT"
fi

# Create .obsidian directory structure
print_header "Creating .obsidian Directory Structure"

OBSIDIAN_DIR="$TARGET_VAULT/.obsidian"
PLUGINS_DIR="$OBSIDIAN_DIR/plugins"

mkdir -p "$OBSIDIAN_DIR"
mkdir -p "$PLUGINS_DIR"
print_success "Created .obsidian directory structure"

# Create core configuration files
print_header "Creating Core Configuration Files"

# 1. app.json - Basic app settings
print_info "Creating app.json..."
cat > "$OBSIDIAN_DIR/app.json" << 'EOF'
{
  "propertiesInDocument": "hidden"
}
EOF
print_success "Created app.json"

# 2. appearance.json - Theme settings
print_info "Creating appearance.json..."
cat > "$OBSIDIAN_DIR/appearance.json" << 'EOF'
{}
EOF
print_success "Created appearance.json"

# 3. community-plugins.json - List of community plugins
print_info "Creating community-plugins.json..."
cat > "$OBSIDIAN_DIR/community-plugins.json" << 'EOF'
[
  "obsidian-excalidraw-plugin",
  "obsidian-heading-shifter"
]
EOF
print_success "Created community-plugins.json"

# 4. core-plugins.json - Core plugins configuration
print_info "Creating core-plugins.json..."
cat > "$OBSIDIAN_DIR/core-plugins.json" << 'EOF'
{
  "file-explorer": true,
  "global-search": true,
  "switcher": true,
  "graph": true,
  "backlink": true,
  "canvas": true,
  "outgoing-link": true,
  "tag-pane": true,
  "footnotes": true,
  "properties": true,
  "page-preview": true,
  "daily-notes": false,
  "templates": false,
  "note-composer": true,
  "command-palette": true,
  "slash-command": true,
  "editor-status": true,
  "bookmarks": true,
  "markdown-importer": true,
  "zk-prefixer": false,
  "random-note": false,
  "outline": true,
  "word-count": true,
  "slides": false,
  "audio-recorder": false,
  "workspaces": true,
  "file-recovery": true,
  "publish": false,
  "sync": false,
  "bases": true,
  "webviewer": false
}
EOF
print_success "Created core-plugins.json"

# Install Excalidraw Plugin
print_header "Installing Excalidraw Plugin"

EXCALIDRAW_SRC="$SOURCE_VAULT/.obsidian/plugins/$EXCALIDRAW_PLUGIN_ID"
EXCALIDRAW_DEST="$PLUGINS_DIR/$EXCALIDRAW_PLUGIN_ID"

if [ ! -d "$EXCALIDRAW_SRC" ]; then
    print_error "Error: Excalidraw plugin not found in source vault"
    exit 1
fi

print_info "Copying Excalidraw plugin files..."
mkdir -p "$EXCALIDRAW_DEST"

# Copy essential plugin files (not source code, dev files, or large test files)
cp "$EXCALIDRAW_SRC/main.js" "$EXCALIDRAW_DEST/" 2>/dev/null || print_warning "main.js not found"
cp "$EXCALIDRAW_SRC/manifest.json" "$EXCALIDRAW_DEST/" 2>/dev/null || print_warning "manifest.json not found"
cp "$EXCALIDRAW_SRC/styles.css" "$EXCALIDRAW_DEST/" 2>/dev/null || print_warning "styles.css not found"
cp "$EXCALIDRAW_SRC/data.json" "$EXCALIDRAW_DEST/" 2>/dev/null || print_warning "data.json not found (will use defaults)"

print_success "Copied Excalidraw plugin (v$(grep -oP '(?<="version": ")[^"]+' "$EXCALIDRAW_DEST/manifest.json"))"

# Install Heading Shifter Plugin
print_header "Installing Heading Shifter Plugin"

HEADING_SHIFTER_SRC="$SOURCE_VAULT/.obsidian/plugins/$HEADING_SHIFTER_PLUGIN_ID"
HEADING_SHIFTER_DEST="$PLUGINS_DIR/$HEADING_SHIFTER_PLUGIN_ID"

if [ ! -d "$HEADING_SHIFTER_SRC" ]; then
    print_error "Error: Heading Shifter plugin not found in source vault"
    exit 1
fi

print_info "Copying Heading Shifter plugin files..."
mkdir -p "$HEADING_SHIFTER_DEST"

cp "$HEADING_SHIFTER_SRC/main.js" "$HEADING_SHIFTER_DEST/" 2>/dev/null || print_warning "main.js not found"
cp "$HEADING_SHIFTER_SRC/manifest.json" "$HEADING_SHIFTER_DEST/" 2>/dev/null || print_warning "manifest.json not found"

print_success "Copied Heading Shifter plugin (v$(grep -oP '(?<="version": ")[^"]+' "$HEADING_SHIFTER_DEST/manifest.json"))"

# Create default Excalidraw folder
print_header "Creating Default Folders"

mkdir -p "$TARGET_VAULT/Excalidraw"
print_success "Created Excalidraw folder for diagrams"

# Summary
print_header "Setup Complete"

echo -e "${GREEN}✓${NC} Obsidian vault configured successfully!"
echo ""
echo "Configuration Summary:"
echo "  • Core plugins: File explorer, search, graph, canvas, backlinks, etc."
echo "  • Community plugins: Excalidraw, Heading Shifter"
echo "  • Default folders: Excalidraw/"
echo ""
echo "Next Steps:"
echo "  1. Open Obsidian"
echo "  2. Select 'Open folder as vault'"
echo "  3. Choose: $TARGET_VAULT"
echo "  4. Trust the plugins when prompted"
echo "  5. Start creating documentation!"
echo ""
print_info "Note: Daily notes and templates are disabled for documentation-focused vaults."
print_info "You can enable them in Settings > Core plugins if needed."
echo ""
