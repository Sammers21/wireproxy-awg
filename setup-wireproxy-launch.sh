#!/bin/bash

# Paths
APP_NAME="wireproxy-awg"
SCRIPT_DIR="$HOME/Git/ext"
COMMAND_PATH="$SCRIPT_DIR/$APP_NAME"
CONFIG_PATH="$SCRIPT_DIR/config"
WRAPPER_SCRIPT="$SCRIPT_DIR/start-wireproxy.sh"
PLIST_NAME="com.user.wireproxy-awg.plist"
PLIST_PATH="$HOME/Library/LaunchAgents/$PLIST_NAME"

# Create wrapper script
cat <<EOF > "$WRAPPER_SCRIPT"
#!/bin/bash
# Run wireproxy in background
"$COMMAND_PATH" -c "$CONFIG_PATH" &
EOF

chmod +x "$WRAPPER_SCRIPT"

# Create LaunchAgent plist
cat <<EOF > "$PLIST_PATH"
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN"
 "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
    <key>Label</key>
    <string>com.user.wireproxy-awg</string>

    <key>ProgramArguments</key>
    <array>
        <string>$WRAPPER_SCRIPT</string>
    </array>

    <key>RunAtLoad</key>
    <true/>

    <key>StandardOutPath</key>
    <string>/tmp/wireproxy-awg.out</string>
    <key>StandardErrorPath</key>
    <string>/tmp/wireproxy-awg.err</string>
</dict>
</plist>
EOF

# Load the LaunchAgent
launchctl unload "$PLIST_PATH" 2>/dev/null
launchctl load "$PLIST_PATH"

echo "✅ wireproxy-awg autolaunch setup complete!"
