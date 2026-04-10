# GoLang Middleware Gin Framework

## What is Middleware?

Middleware is a function that sits between the HTTP request and your application's handler. It intercepts incoming requests, performs operations (like authentication, logging, validation), and either:
- Passes the request to the next handler in the chain
- Terminates the request early by sending a response

Think of middleware as a chain of filters that requests pass through before reaching your business logic.

```
Client Request → Middleware 1 → Middleware 2 → Handler → Response
```

## When to Use Middleware?

Use middleware for cross-cutting concerns that apply to multiple routes:

1. **Authentication & Authorization** - Verify JWT tokens, API keys, or session data
2. **Logging** - Record request details, response times, status codes
3. **Request Validation** - Check headers, content types, rate limits
4. **CORS Handling** - Set cross-origin headers for browser requests
5. **Error Recovery** - Catch panics and return proper error responses
6. **Request/Response Modification** - Add headers, transform data
7. **Metrics & Monitoring** - Track performance and usage statistics

## How to Use Middleware?

### Standard Library (net/http)
```go
func middleware(next http.Handler) http.Handler {
    return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
        // Before handler logic
        fmt.Println("Before handler")
        
        next.ServeHTTP(w, r)  // Call next handler
        
        // After handler logic
        fmt.Println("After handler")
    })
}

// Apply to specific route
http.Handle("/protected", middleware(http.HandlerFunc(handler)))

// Apply globally
http.ListenAndServe(":8080", middleware(http.DefaultServeMux))
```

### Gin Framework
```go
func middleware() gin.HandlerFunc {
    return func(c *gin.Context) {
        // Before handler logic
        fmt.Println("Before handler")
        
        c.Next()  // Call next handler
        
        // After handler logic
        fmt.Println("After handler")
    }
}

// Apply globally
r.Use(middleware())

// Apply to specific route
r.GET("/protected", middleware(), handler)

// Apply to route group
protected := r.Group("/admin")
protected.Use(middleware())
```

## Project Examples

This project demonstrates:
- **JWT authentication middleware** - Token-based authentication for protected routes
- **Logging middleware** - Request/response logging with timing
- **Rate limiting middleware** - Prevents abuse by limiting requests per IP
- Multiple middleware chaining
- Protected vs unprotected routes
- Context value passing between middleware and handlers

## Rate Limiting

The rate limiter prevents abuse by tracking requests per IP address:
- **Limit**: 5 requests per minute per IP
- **Applied to**: `/login` endpoint (prevents brute force attacks)
- **Storage**: In-memory map with automatic cleanup
- **Response**: HTTP 429 (Too Many Requests) when limit exceeded

Example test:
```bash
# Send 7 requests quickly to test rate limiting
for i in {1..7}; do
  echo "Request $i:"
  curl "http://localhost:8080/login?username=test"
  echo ""
done
```
