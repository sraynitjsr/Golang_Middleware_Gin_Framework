#!/bin/bash

# ============================================
# Rate Limiting Test Script
# Demonstrates the 5 requests/minute limit
# ============================================

BASE_URL="http://localhost:8080"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
CYAN='\033[0;36m'
BLUE='\033[0;34m'
MAGENTA='\033[0;35m'
NC='\033[0m' # No Color

echo ""
echo -e "${CYAN}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${CYAN}║           ⚡ Rate Limiting Test Script                        ║${NC}"
echo -e "${CYAN}║           Max 5 requests per minute per IP                    ║${NC}"
echo -e "${CYAN}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""

# Check if server is running
if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
    echo -e "${RED}❌ Error: Server is not running!${NC}"
    echo -e "${YELLOW}Please start the server first:${NC}"
    echo "   go run main.go"
    exit 1
fi

echo -e "${GREEN}✅ Server is running at $BASE_URL${NC}"
echo ""

# Test 1: Sequential Requests
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TEST 1: Sending 10 Sequential Requests${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Expected: First 5 succeed ✅, Next 5 blocked ❌${NC}"
echo ""

SUCCESS_COUNT=0
BLOCKED_COUNT=0

for i in {1..10}; do
    RESPONSE=$(curl -s -w "\n%{http_code}" "$BASE_URL/login?username=test_user_$i")
    HTTP_CODE=$(echo "$RESPONSE" | tail -n 1)
    BODY=$(echo "$RESPONSE" | head -n -1)
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✅ Request $i: SUCCESS (HTTP $HTTP_CODE)${NC}"
        TOKEN=$(echo "$BODY" | python3 -c "import sys, json; print(json.load(sys.stdin).get('token', 'N/A')[:30] + '...')" 2>/dev/null || echo "token received")
        echo -e "   Token: $TOKEN"
        ((SUCCESS_COUNT++))
    elif [ "$HTTP_CODE" == "429" ]; then
        echo -e "${RED}❌ Request $i: RATE LIMITED (HTTP $HTTP_CODE)${NC}"
        ERROR=$(echo "$BODY" | python3 -c "import sys, json; r=json.load(sys.stdin); print(f\"   {r.get('error', '')}: {r.get('message', '')}\")" 2>/dev/null || echo "$BODY")
        echo "$ERROR"
        ((BLOCKED_COUNT++))
    else
        echo -e "${YELLOW}⚠️  Request $i: UNEXPECTED (HTTP $HTTP_CODE)${NC}"
    fi
    
    sleep 0.3
done

echo ""
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${BLUE}Results: ${GREEN}$SUCCESS_COUNT succeeded${NC}, ${RED}$BLOCKED_COUNT blocked${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 2: Rapid Fire Test
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TEST 2: Rapid Fire Test (No Delay)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Sending 8 requests as fast as possible...${NC}"
echo ""

RAPID_SUCCESS=0
RAPID_BLOCKED=0

for i in {1..8}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=rapid_$i")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✅ Request $i: SUCCESS${NC}"
        ((RAPID_SUCCESS++))
    elif [ "$HTTP_CODE" == "429" ]; then
        echo -e "${RED}❌ Request $i: BLOCKED${NC}"
        ((RAPID_BLOCKED++))
    fi
done

echo ""
echo -e "${BLUE}Rapid Fire Results: ${GREEN}$RAPID_SUCCESS succeeded${NC}, ${RED}$RAPID_BLOCKED blocked${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Test 3: Timing Test
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TEST 3: Rate Limit Timing Test${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

echo -e "${YELLOW}Sending 5 requests (should all succeed)...${NC}"
for i in {1..5}; do
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=timing_test")
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✅ Request $i: SUCCESS${NC}"
    else
        echo -e "${RED}❌ Request $i: HTTP $HTTP_CODE${NC}"
    fi
done

echo ""
echo -e "${YELLOW}Request 6 (should be blocked)...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=timing_test")
if [ "$HTTP_CODE" == "429" ]; then
    echo -e "${RED}❌ Request 6: BLOCKED ✓ (Rate limit working!)${NC}"
else
    echo -e "${YELLOW}⚠️  Request 6: HTTP $HTTP_CODE (Expected 429)${NC}"
fi

echo ""
echo -e "${CYAN}Waiting 61 seconds for rate limit to reset...${NC}"
for i in {61..1}; do
    echo -ne "${YELLOW}\r⏳ Time remaining: $i seconds... ${NC}"
    sleep 1
done
echo ""

echo -e "${YELLOW}Testing after rate limit reset...${NC}"
HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=timing_test")
if [ "$HTTP_CODE" == "200" ]; then
    echo -e "${GREEN}✅ Request after reset: SUCCESS ✓ (Rate limit reset working!)${NC}"
else
    echo -e "${YELLOW}⚠️  Request after reset: HTTP $HTTP_CODE${NC}"
fi

echo ""

# Test 4: Different Users (Same IP)
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${CYAN}TEST 4: Different Usernames (Same IP)${NC}"
echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo -e "${YELLOW}Testing if rate limit applies per IP (not per user)...${NC}"
echo ""

MULTI_SUCCESS=0
MULTI_BLOCKED=0

for i in {1..7}; do
    USERNAME="user_$(date +%s%N)"  # Unique username each time
    HTTP_CODE=$(curl -s -o /dev/null -w "%{http_code}" "$BASE_URL/login?username=$USERNAME")
    
    if [ "$HTTP_CODE" == "200" ]; then
        echo -e "${GREEN}✅ Request $i (user: $USERNAME): SUCCESS${NC}"
        ((MULTI_SUCCESS++))
    elif [ "$HTTP_CODE" == "429" ]; then
        echo -e "${RED}❌ Request $i (user: $USERNAME): BLOCKED${NC}"
        ((MULTI_BLOCKED++))
    fi
    
    sleep 0.2
done

echo ""
echo -e "${BLUE}Results: ${GREEN}$MULTI_SUCCESS succeeded${NC}, ${RED}$MULTI_BLOCKED blocked${NC}"
echo -e "${YELLOW}Note: Rate limiting is per IP, not per username${NC}"
echo -e "${BLUE}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
echo ""

# Summary
echo ""
echo -e "${MAGENTA}╔════════════════════════════════════════════════════════════════╗${NC}"
echo -e "${MAGENTA}║                    📊 Test Summary                            ║${NC}"
echo -e "${MAGENTA}╚════════════════════════════════════════════════════════════════╝${NC}"
echo ""
echo -e "${GREEN}✅ Rate Limiting Test Completed!${NC}"
echo ""
echo "Configuration:"
echo "  • Rate Limit: 5 requests per minute per IP"
echo "  • Endpoint: /login"
echo "  • Tracking: By IP address (not username)"
echo "  • Cleanup: Every 5 minutes"
echo ""
echo -e "${CYAN}💡 Tips:${NC}"
echo "  • Rate limit applies to IP, not individual users"
echo "  • Counter resets after 1 minute window"
echo "  • HTTP 429 = Rate limit exceeded"
echo "  • HTTP 200 = Request allowed"
echo ""
echo -e "${YELLOW}Check your server terminal to see the middleware logs!${NC}"
echo ""
