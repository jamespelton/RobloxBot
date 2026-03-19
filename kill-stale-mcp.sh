#!/bin/bash
# Kill stale robloxstudio-mcp processes that hog port 58741
# This runs as a PreToolUse hook before MCP tool calls

# Count how many robloxstudio-mcp processes exist
COUNT=$(pgrep -f "robloxstudio-mcp" | wc -l | tr -d ' ')

if [ "$COUNT" -gt "1" ]; then
    # Multiple processes = stale ones exist. Kill all so the fresh one can start.
    pkill -f "robloxstudio-mcp" 2>/dev/null
    sleep 1
fi
