#!/bin/bash

echo "🔧 Fixing Godot export for Farcaster..."

cd dist

# Fix config in index.html using perl (works on all systems)
perl -pi -e 's/"ensureCrossOriginIsolationHeaders":true/"ensureCrossOriginIsolationHeaders":false/g' index.html
perl -pi -e 's/threads: GODOT_THREADS_ENABLED/threads: false/g' index.html

echo "✅ Fixed index.html threading config"
echo "✅ Export ready for Farcaster deployment!"