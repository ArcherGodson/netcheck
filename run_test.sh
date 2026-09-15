#!/bin/bash
cd /Users/ag/projects/macos-native/NetCheck
./.build/debug/NetCheck &
APP_PID=$!
echo "App started with PID: $APP_PID"
sleep 5
echo "Killing app..."
kill $APP_PID
