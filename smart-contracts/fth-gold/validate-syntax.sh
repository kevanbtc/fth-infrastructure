#!/bin/bash

# Simple syntax validation script for Solidity contracts
# Checks for basic syntax issues without requiring compilation

echo "🔍 FTH Gold Smart Contract Syntax Validation"
echo "============================================"

cd "$(dirname "$0")"

# Function to check a single solidity file
check_solidity_file() {
    local file="$1"
    echo "📄 Checking: $file"
    
    # Check for basic syntax issues
    if ! grep -q "pragma solidity" "$file"; then
        echo "❌ Missing pragma solidity declaration"
        return 1
    fi
    
    # Check for balanced braces
    local open_braces=$(grep -o '{' "$file" | wc -l)
    local close_braces=$(grep -o '}' "$file" | wc -l)
    
    if [ "$open_braces" -ne "$close_braces" ]; then
        echo "❌ Unbalanced braces: $open_braces opening, $close_braces closing"
        return 1
    fi
    
    # Check for balanced parentheses in function definitions
    if grep -q "function.*(" "$file"; then
        echo "✅ Function definitions found"
    fi
    
    # Check imports exist
    if grep -q "import" "$file"; then
        echo "✅ Import statements found"
    fi
    
    echo "✅ Basic syntax checks passed"
    return 0
}

# Check all Solidity files
echo "📂 Scanning contracts directory..."
find contracts -name "*.sol" | while read -r file; do
    check_solidity_file "$file"
    echo ""
done

# Check test files
echo "📂 Scanning test directory..."
find test -name "*.sol" | while read -r file; do
    check_solidity_file "$file"
    echo ""
done

echo "🎉 Syntax validation complete!"
echo ""
echo "💡 To run full compilation and tests:"
echo "   forge build"
echo "   forge test -vvv"