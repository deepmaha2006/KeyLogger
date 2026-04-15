# justfile for KeyLogger project
# Install 'just' to use: https://github.com/casey/just
# Windows: winget install Casey.Just
# macOS/Linux: curl -sSf https://just.systems/install.sh | bash -s -- --to ~/.local/bin

set windows-shell := ["powershell.exe", "-NoLogo", "-Command"]

# Show available commands
default:
    @just --list --unsorted

# =============================================================================
# Setup Commands
# =============================================================================

# Create virtual environment and install all dependencies
[group('setup')]
setup:
    @echo "Creating virtual environment..."
    python -m venv .venv
    @echo "Installing dependencies..."
    .venv/Scripts/pip install -r requirements.txt
    @echo ""
    @echo "Setup complete!"
    @echo "Activate with: .venv\Scripts\activate  (Windows)"
    @echo "Activate with: source .venv/bin/activate  (Linux/macOS)"
    @echo "Run tests with: just test"

# Install main dependencies only
[group('setup')]
install:
    pip install pynput requests

# Install with dev dependencies
[group('setup')]
install-dev:
    pip install -r requirements.txt

# =============================================================================
# Testing & Quality
# =============================================================================

# Run test suite
[group('test')]
test:
    @echo "Running tests..."
    pytest test_keylogger.py -v

# Format code with yapf
[group('test')]
format:
    @echo "Formatting code with yapf..."
    yapf -i keylogger.py test_keylogger.py
    @echo "Code formatted"

# =============================================================================
# Utilities
# =============================================================================

# Remove virtual environment and cache files
[group('utility')]
clean:
    @echo "Cleaning up..."
    rm -rf .venv
    rm -rf __pycache__
    rm -rf .pytest_cache
    rm -rf .mypy_cache
    @echo "Cleaned"

# Run the keylogger (use with caution - for testing only)
[group('utility')]
[confirm("This will start the keylogger. Only run on systems you own. Continue?")]
run:
    python keylogger.py

# =============================================================================
# CI / Full Pipeline
# =============================================================================

# Run tests only
[group('ci')]
ci: test
    @echo "CI checks passed"
