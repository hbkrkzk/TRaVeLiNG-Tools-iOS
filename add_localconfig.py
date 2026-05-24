import os
import json
import subprocess

# Get the file reference ID format
pbxproj_path = "TRaVeLiNG-Tools_iOS.xcodeproj/project.pbxproj"

# Try to add LocalConfig.plist to the project using xcodebuild
result = subprocess.run([
    "xcodebuild",
    "-project", "TRaVeLiNG-Tools_iOS.xcodeproj",
    "-scheme", "TRaVeLiNG-Tools_iOS",
    "-configuration", "Debug",
    "-destination", "generic/platform=iOS Simulator",
    "build"
], capture_output=True, text=True)

if "LocalConfig.plist" in result.stderr or "LocalConfig.plist" in result.stdout:
    print("LocalConfig.plist is already included")
else:
    print("Manual Xcode UI step needed")
    print("Or use the terminal method below:")
    print("")
    print("1. Open the project in Xcode:")
    print("   open TRaVeLiNG-Tools_iOS.xcodeproj")
    print("")
    print("2. Select the project in the Navigator")
    print("3. Select target 'TRaVeLiNG-Tools_iOS'")
    print("4. Go to 'Build Phases'")
    print("5. Expand 'Copy Bundle Resources'")
    print("6. Click '+' and add 'LocalConfig.plist'")
