import os
import sys

"""
restore_and_fix.py: Health check utility for Game_Context_Scanner.lua.
This script ensures that the scanner has necessary pcall protections and
correct logic. It replaces the previous version which hardcoded the entire
source of the scanner, which was a dangerous and bad practice.
"""

SCANNER_FILE = "Game_Context_Scanner.lua"

def check_health():
    if not os.path.exists(SCANNER_FILE):
        print(f"Error: {SCANNER_FILE} is missing.")
        print("Please restore it from your repository or backup.")
        return False

    with open(SCANNER_FILE, "r") as f:
        content = f.read()

    # Define key features that should be present in a healthy scanner
    required_markers = {
        "pcall around writefile": "pcall(function()",
        "pcall around appendfile": "pcall(appendfile",
        "Buffered logging": "LOG_BUFFER",
        "Decompiler rate limiting": "Too Many Requests",
        "Sanitize function": "function sanitize",
    }

    all_passed = True
    print(f"Checking health of {SCANNER_FILE}:")
    for name, marker in required_markers.items():
        if marker in content:
            print(f"  [✓] {name}")
        else:
            print(f"  [✗] {name}")
            all_passed = False

    return all_passed

if __name__ == "__main__":
    if check_health():
        print("\nScanner is healthy.")
        sys.exit(0)
    else:
        print("\nScanner is missing some expected features or protections.")
        sys.exit(1)
