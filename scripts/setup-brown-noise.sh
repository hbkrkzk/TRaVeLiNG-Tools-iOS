#!/bin/bash
# Brown Noise Feature - Xcode Project Setup Script

echo "🎵 Brown Noise Feature - Xcode Project Setup"
echo "=============================================="
echo ""
echo "This script helps add the brown noise feature files to the Xcode project."
echo ""
echo "MANUAL STEPS REQUIRED:"
echo ""
echo "1️⃣  Open Xcode Project"
echo "   - File -> Open -> TRaVeLiNG-Tools_iOS.xcodeproj"
echo ""
echo "2️⃣  Add Audio File to Target"
echo "   - In Xcode, go to Build Phases"
echo "   - Click 'Copy Bundle Resources' section"
echo "   - Click the '+' button"
echo "   - Navigate to TRaVeLiNG-Tools_iOS/brownnoise_30min.m4a"
echo "   - Select 'TRaVeLiNG-Tools_iOS' target"
echo "   - Click 'Add'"
echo ""
echo "3️⃣  Verify New Files"
echo "   - In Xcode project navigator:"
echo "   - BrownNoisePlayer.swift should be in the file list"
echo "   - BrownNoiseView.swift should be in the file list"
echo "   - Both should have 'TRaVeLiNG-Tools_iOS' target selected"
echo ""
echo "4️⃣  Build and Run"
echo "   - Press Cmd+B to build"
echo "   - Press Cmd+R to run"
echo ""
echo "✅ After setup, the Brown Noise feature will appear in the app!"
echo ""

# Check if files exist
if [ -f "TRaVeLiNG-Tools_iOS/brownnoise_30min.m4a" ]; then
    echo "✅ Audio file found at: TRaVeLiNG-Tools_iOS/brownnoise_30min.m4a"
else
    echo "❌ Audio file NOT found!"
    exit 1
fi

if [ -f "TRaVeLiNG-Tools_iOS/BrownNoisePlayer.swift" ]; then
    echo "✅ BrownNoisePlayer.swift found"
else
    echo "❌ BrownNoisePlayer.swift NOT found!"
    exit 1
fi

if [ -f "TRaVeLiNG-Tools_iOS/BrownNoiseView.swift" ]; then
    echo "✅ BrownNoiseView.swift found"
else
    echo "❌ BrownNoiseView.swift NOT found!"
    exit 1
fi

echo ""
echo "All files are in place! 🎉"
echo ""
echo "Next: Open Xcode and follow the manual steps above."
