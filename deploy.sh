#!/usr/bin/env bash
set -euo pipefail

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

echo "tmux-sessionx Deployment Script"
echo "==============================="

SOURCE_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
TARGET_DIR="$HOME/.config/tmux/plugins/tmux-sessionx"

# Check if we're in tmux
if [[ -n "${TMUX:-}" ]]; then
    echo -e "${YELLOW}Warning: You are currently in a tmux session.${NC}"
    echo "It's recommended to deploy from outside tmux to avoid issues."
    read -p "Continue anyway? (y/N) " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        echo "Deployment cancelled."
        exit 0
    fi
fi

# Backup existing installation
if [[ -d "$TARGET_DIR" ]]; then
    BACKUP_DIR="${TARGET_DIR}.backup.$(date +%Y%m%d_%H%M%S)"
    echo -e "${YELLOW}Backing up existing installation to:${NC}"
    echo "  $BACKUP_DIR"
    cp -r "$TARGET_DIR" "$BACKUP_DIR"
fi

# Validate source files
echo -e "\n${YELLOW}Validating source files...${NC}"
VALIDATION_FAILED=false

for script in scripts/{sessionx.sh,common.sh,tmuxinator.sh,help.sh,preview.sh,reload_sessions.sh}; do
    if [[ ! -f "$SOURCE_DIR/$script" ]]; then
        echo -e "${RED}✗ Missing: $script${NC}"
        VALIDATION_FAILED=true
    elif ! bash -n "$SOURCE_DIR/$script" 2>/dev/null; then
        echo -e "${RED}✗ Syntax error in: $script${NC}"
        VALIDATION_FAILED=true
    else
        echo -e "${GREEN}✓ Valid: $script${NC}"
    fi
done

if [[ "$VALIDATION_FAILED" == "true" ]]; then
    echo -e "\n${RED}Validation failed! Please fix issues before deploying.${NC}"
    exit 1
fi

# Check specific requirements
echo -e "\n${YELLOW}Checking specific requirements...${NC}"

# Check tmuxinator.sh has all required functions
for func in "is_tmuxinator_enabled" "is_tmuxinator_template" "load_tmuxinator_binding"; do
    if grep -q "$func" "$SOURCE_DIR/scripts/tmuxinator.sh"; then
        echo -e "${GREEN}✓ Function $func found in tmuxinator.sh${NC}"
    else
        echo -e "${RED}✗ Function $func missing from tmuxinator.sh${NC}"
        VALIDATION_FAILED=true
    fi
done

# Check common.sh has required functions
for func in "tmux_option_or_fallback" "validate_session_name" "validate_path"; do
    if grep -q "$func" "$SOURCE_DIR/scripts/common.sh"; then
        echo -e "${GREEN}✓ Function $func found in common.sh${NC}"
    else
        echo -e "${RED}✗ Function $func missing from common.sh${NC}"
        VALIDATION_FAILED=true
    fi
done

if [[ "$VALIDATION_FAILED" == "true" ]]; then
    echo -e "\n${RED}Validation failed! Please fix issues before deploying.${NC}"
    exit 1
fi

# Deploy
echo -e "\n${YELLOW}Deploying to: $TARGET_DIR${NC}"
echo "This will replace the existing installation."
read -p "Continue? (y/N) " -n 1 -r
echo

if [[ $REPLY =~ ^[Yy]$ ]]; then
    # Create target directory if it doesn't exist
    mkdir -p "$TARGET_DIR"
    
    # Copy files
    echo "Copying files..."
    cp -r "$SOURCE_DIR"/* "$TARGET_DIR/"
    
    # Ensure scripts are executable
    chmod +x "$TARGET_DIR"/scripts/*.sh
    chmod +x "$TARGET_DIR"/sessionx.tmux
    
    echo -e "${GREEN}✓ Deployment complete!${NC}"
    
    # Test the installation
    echo -e "\n${YELLOW}Testing installation...${NC}"
    if bash -n "$TARGET_DIR/scripts/sessionx.sh" 2>/dev/null; then
        echo -e "${GREEN}✓ Installation test passed${NC}"
    else
        echo -e "${RED}✗ Installation test failed${NC}"
        echo "You may want to restore from backup: $BACKUP_DIR"
    fi
    
    echo -e "\n${GREEN}Next steps:${NC}"
    echo "1. Exit tmux completely"
    echo "2. Start a new tmux session"
    echo "3. Test the plugin with your configured keybinding (default: prefix + O)"
    
    if [[ -d "$BACKUP_DIR" ]]; then
        echo -e "\n${YELLOW}If you encounter issues, restore the backup with:${NC}"
        echo "  rm -rf $TARGET_DIR && mv $BACKUP_DIR $TARGET_DIR"
    fi
else
    echo "Deployment cancelled."
fi