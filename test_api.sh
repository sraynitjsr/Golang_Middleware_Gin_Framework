#!/bin/bash

# ============================================
# Golang Middleware API Test Script
# Tests: Logging, JWT Auth, Rate Limiting
# ============================================

BASE_URL="http://localhost:8080"
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

echo ""
echo "╔════════════════════════════════════════════════════════════════╗"
echo "║        🚀 Golang Middleware API Test Suite                    ║"
echo "║        Testing: Logging | JWT Auth | Rate Limiting            ║"
echo "╚════════════════════════════════════════════════════════════════╝"
echo ""

# Function to print section headers
print_section() {
    echo ""
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
    echo -e "${CYAN}$1${NC}"
    echo -e "${CYAN}━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━━${NC}"
}

# Check if server is running
check_server() {
    if ! curl -s "$BASE_URL/health" > /dev/null 2>&1; then
        echo -e "${RED}❌ Error: Server is not running!${NC}"
        echo -e "${YELLOW}Please start the server first:${NC}"
        echo "   go run main.go"
        exit 1
    fi
    echo -e "${GREEN}✅ Server is running at $BASE_URL${NC}"
}

# Test 1: Unprotected Endpoints
test_unprotected() {
    print_section "📋 TEST 1: Unprotected Endpoints"
    
    echo -e "${BLUE}Testing GET /${NC}"
    curl -s "$BASE_URL/" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/"
    echo ""
    
    echo -e "${BLUE}Testing GET /health${NC}"
    HEALTH=$(curl -s "$BASE_URL/health")
    echo "Response: $HEALTH"
    echo ""
}

# Test 2: JWT Authentication
test_jwt_auth() {
    print_section "🔐 TEST 2: JWT Authentication"
    
    echo -e "${BLUE}Getting JWT token for user 'alice'...${NC}"
    LOGIN_RESPONSE=$(curl -s "$BASE_URL/login?username=alice")
    echo "$LOGIN_RESPONSE" | python3 -m json.tool 2>/dev/null || echo "$LOGIN_RESPONSE"
    
    TOKEN=$(echo "$LOGIN_RESPONSE" | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])" 2>/dev/null)
    
    if [ -z "$TOKEN" ]; then
        echo -e "${RED}❌ Failed to get token${NC}"
        return 1
    fi
    
    echo -e "${GREEN}✅ Token received: ${TOKEN:0:30}...${NC}"
    echo ""
    
    echo -e "${BLUE}Testing protected endpoint /ping WITH token...${NC}"
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/ping" | python3 -m json.tool 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/ping"
    echo ""
    
    echo -e "${BLUE}Testing protected endpoint /ping WITHOUT token (should fail)...${NC}"
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" "$BASE_URL/ping")
    echo "$RESPONSE"
    echo ""
    
    echo -e "${BLUE}Testing /dashboard WITH valid token...${NC}"
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/dashboard" | python3 -m json.tool 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/dashboard"
    echo ""
}

# Test 3: Rate Limiting
test_rate_limiting() {
    print_section "⚡ TEST 3: Rate Limiting (Max 5 requests per minute)"
    
    echo -e "${YELLOW}Sending 8 rapid requests to /login endpoint...${NC}"
    echo -e "${YELLOW}Expected: First 5 succeed ✅, Last 3 blocked ❌${NC}"
    echo ""
    
    for i in {1..8}; do
        STATUS=$(curl -s -o /tmp/rate_test_response.json -w "%{http_code}" "$BASE_URL/login?username=rate_test_user")
        
        if [ "$STATUS" == "200" ]; then
            echo -e "${GREEN}✅ Request $i: SUCCESS (HTTP $STATUS)${NC}"
        elif [ "$STATUS" == "429" ]; then
            echo -e "${RED}❌ Request $i: RATE LIMITED (HTTP $STATUS)${NC}"
            RESPONSE=$(cat /tmp/rate_test_response.json)
            echo "   $RESPONSE" | python3 -m json.tool 2>/dev/null || echo "   $RESPONSE"
        else
            echo -e "${YELLOW}⚠️  Request $i: HTTP $STATUS${NC}"
        fi
        
        sleep 0.2
    done
    
    echo ""
    rm -f /tmp/rate_test_response.json
}

# Test 4: Middleware Chaining
test_middleware_chaining() {
    print_section "🔗 TEST 4: Middleware Chaining"
    
    echo -e "${BLUE}Testing endpoint with multiple middleware layers...${NC}"
    echo -e "${YELLOW}1. Logging Middleware (all requests)${NC}"
    echo -e "${YELLOW}2. Rate Limiting Middleware (/login only)${NC}"
    echo -e "${YELLOW}3. JWT Auth Middleware (/ping, /dashboard)${NC}"
    echo ""
    
    # Get a fresh token
    TOKEN=$(curl -s "$BASE_URL/login?username=test_chain" | python3 -c "import sys, json; print(json.load(sys.stdin)['token'])" 2>/dev/null)
    
    echo -e "${BLUE}Request to /dashboard (goes through Logging + JWT Auth)...${NC}"
    curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/dashboard" | python3 -m json.tool 2>/dev/null || curl -s -H "Authorization: Bearer $TOKEN" "$BASE_URL/dashboard"
    echo ""
    
    echo -e "${BLUE}Request to /login (goes through Logging + Rate Limiting)...${NC}"
    curl -s "$BASE_URL/login?username=chain_test" | python3 -m json.tool 2>/dev/null || curl -s "$BASE_URL/login?username=chain_test"
    echo ""
}

# Test 5: Error Handling
test_error_handling() {
    print_section "🚨 TEST 5: Error Handling"
    
    echo -e "${BLUE}Testing invalid JWT token...${NC}"
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "Authorization: Bearer invalid_token_12345" "$BASE_URL/ping")
    echo "$RESPONSE"
    echo ""
    
    echo -e "${BLUE}Testing malformed Authorization header...${NC}"
    RESPONSE=$(curl -s -w "\nHTTP_CODE:%{http_code}" -H "Authorization: InvalidFormat" "$BASE_URL/ping")
    echo "$RESPONSE"
    echo ""
}

# Summary
print_summary() {
    print_section "📊 Test Summary"
    
    echo -e "${GREEN}✅ Completed all test cases!${NC}"
    echo ""
    echo "Features Tested:"
    echo "  ✓ Unprotected endpoints (/, /health)"
    echo "  ✓ JWT token generation (/login)"
    echo "  ✓ JWT authentication (/ping, /dashboard)"
    echo "  ✓ Rate limiting (5 requests/minute)"
    echo "  ✓ Middleware chaining"
    echo "  ✓ Error handling"
    echo ""
    echo -e "${CYAN}Check the server logs to see middleware execution!${NC}"
    echo ""
}

# Main execution
main() {
    check_server
    test_unprotected
    test_jwt_auth
    test_rate_limiting
    test_middleware_chaining
    test_error_handling
    print_summary
}

# Run all tests
main
