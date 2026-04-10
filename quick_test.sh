#!/bin/bash

# Quick Rate Limit Test
# Shows rate limiting in action - simple and fast!

BASE_URL="http://localhost:8080"

echo ""
echo "⚡ Quick Rate Limit Test"
echo "========================"
echo ""
echo "Sending 8 requests rapidly to /login..."
echo "Expected: First 5 succeed ✅, Last 3 blocked ❌"
echo ""

for i in {1..8}; do
    STATUS=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=test")
    
    if [ "$STATUS" == "200" ]; then
        echo "✅ Request $i: SUCCESS (HTTP $STATUS)"
    elif [ "$STATUS" == "429" ]; then
        echo "❌ Request $i: BLOCKED (HTTP $STATUS) - Rate limit exceeded!"
    else
        echo "⚠️  Request $i: HTTP $STATUS"
    fi
done

echo ""
echo "🔍 Check your server logs to see rate limiter in action!"
echo ""
