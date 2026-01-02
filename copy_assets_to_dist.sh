#!/bin/bash
# Post-export script to copy additional assets to dist folder
# Run this after each Godot export

echo "Copying assets to dist folder..."

# Copy preview image
if [ -f "Assets/UI/previewimage.png" ]; then
    cp Assets/UI/previewimage.png dist/preview.png
    echo "✓ Copied preview.png"
else
    echo "⚠ Assets/UI/previewimage.png not found"
fi

# Copy splash image
if [ -f "Assets/UI/splash.png" ]; then
    cp Assets/UI/splash.png dist/splash.png
    echo "✓ Copied splash.png"
else
    echo "⚠ Assets/UI/splash.png not found"
fi

echo "Done! Ready to deploy to Netlify."
