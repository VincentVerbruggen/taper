#!/bin/bash
# Switch Android emulator from gesture navigation to 3-button navigation (back, home, recents)
~/Library/Android/sdk/platform-tools/adb shell cmd overlay enable com.android.internal.systemui.navbar.threebutton
