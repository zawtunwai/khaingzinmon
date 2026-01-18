#!/bin/bash
# ZIVPN Self-Destruct Script
# Destroys all source code after installation

echo "🧨 ZIVPN SELF-DESTRUCT ACTIVATED"

# Destroy Python files
find /etc/zivpn -name "*.py" -type f | while read file; do
    echo "Destroying: $file"
    # Overwrite 3 times
    for i in {1..3}; do
        dd if=/dev/urandom of="$file" bs=1K count=10 status=none 2>/dev/null
    done
    rm -f "$file"
done

# Remove cache files
rm -rf /etc/zivpn/__pycache__ 2>/dev/null
find /etc/zivpn -name "*.pyc" -delete 2>/dev/null

# Remove protection scripts
rm -f /root/protection.py 2>/dev/null
rm -f /etc/zivpn/self_destruct.sh 2>/dev/null

echo "✅ Source code destruction completed"
