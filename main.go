package main

import (
	"context"
	"encoding/json"
	"fmt"
	"log"
	"net/http"
	"strings"
	"time"

	"github.com/dgrijalva/jwt-go"
)

// Secret key for JWT signing/verification
const SECRET_KEY = "MY_SECRETKEY"

// ============================================
// MIDDLEWARE 1: Logging Middleware
// Logs all incoming requests with method, path, and response time
// ============================================
func loggingMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		start := time.Now()

		// Log request
		log.Printf("[%s] %s - Started", r.Method, r.URL.Path)

		// Call next handler
		next.ServeHTTP(w, r)

		// Log completion time
		duration := time.Since(start)
		log.Printf("[%s] %s - Completed in %v", r.Method, r.URL.Path, duration)
	})
}

// ============================================
// MIDDLEWARE 2: JWT Authentication Middleware
// Verifies JWT token from Authorization header
// Blocks requests without valid tokens
// ============================================
func jwtAuthMiddleware(next http.Handler) http.Handler {
	return http.HandlerFunc(func(w http.ResponseWriter, r *http.Request) {
		authHeader := strings.Split(r.Header.Get("Authorization"), "Bearer ")
		if len(authHeader) != 2 {
			log.Println("❌ Malformed token")
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte("Malformed Token - Use: Authorization: Bearer <token>"))
			return
		}

		jwtToken := authHeader[1]
		token, err := jwt.Parse(jwtToken, func(token *jwt.Token) (interface{}, error) {
			if _, ok := token.Method.(*jwt.SigningMethodHMAC); !ok {
				return nil, fmt.Errorf("unexpected signing method: %v", token.Header["alg"])
			}
			return []byte(SECRET_KEY), nil
		})

		if claims, ok := token.Claims.(jwt.MapClaims); ok && token.Valid {
			log.Printf("✅ Authenticated user: %v", claims["user"])

			// Add claims to request context for handlers to use
			ctx := context.WithValue(r.Context(), "props", claims)
			next.ServeHTTP(w, r.WithContext(ctx))
		} else {
			log.Printf("❌ Invalid token: %v", err)
			w.WriteHeader(http.StatusUnauthorized)
			w.Write([]byte("Unauthorized - Invalid Token"))
		}
	})
}

// ============================================
// HANDLERS
// ============================================

// Root handler - unprotected
func home(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	response := map[string]string{
		"message": "Welcome to Golang Middleware Demo!",
		"status":  "Server is running",
	}
	json.NewEncoder(w).Encode(response)
}

// Health check - unprotected
func health(w http.ResponseWriter, r *http.Request) {
	w.WriteHeader(http.StatusOK)
	w.Write([]byte("OK"))
}

// Login endpoint - generates JWT token
func login(w http.ResponseWriter, r *http.Request) {
	// In production, validate username/password here
	username := r.URL.Query().Get("username")
	if username == "" {
		username = "demo_user"
	}

	// Create JWT token
	token := jwt.NewWithClaims(jwt.SigningMethodHS256, jwt.MapClaims{
		"user":  username,
		"email": username + "@example.com",
		"exp":   time.Now().Add(time.Hour * 24).Unix(), // Expires in 24 hours
	})

	tokenString, err := token.SignedString([]byte(SECRET_KEY))
	if err != nil {
		w.WriteHeader(http.StatusInternalServerError)
		w.Write([]byte("Error generating token"))
		return
	}

	response := map[string]string{
		"token": tokenString,
		"type":  "Bearer",
		"usage": "Add header: Authorization: Bearer " + tokenString,
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Protected endpoint - requires JWT
func ping(w http.ResponseWriter, r *http.Request) {
	// Access user info from context (set by middleware)
	props, _ := r.Context().Value("props").(jwt.MapClaims)

	response := map[string]interface{}{
		"message": "pong",
		"user":    props["user"],
		"email":   props["email"],
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// Protected dashboard - requires JWT
func dashboard(w http.ResponseWriter, r *http.Request) {
	props, _ := r.Context().Value("props").(jwt.MapClaims)

	response := map[string]interface{}{
		"message": "Welcome to your dashboard",
		"user":    props["user"],
		"data":    []string{"item1", "item2", "item3"},
	}
	w.WriteHeader(http.StatusOK)
	json.NewEncoder(w).Encode(response)
}

// ============================================
// MAIN
// ============================================
func main() {
	// Unprotected routes (only logging middleware)
	http.Handle("/", loggingMiddleware(http.HandlerFunc(home)))
	http.Handle("/health", loggingMiddleware(http.HandlerFunc(health)))
	http.Handle("/login", loggingMiddleware(http.HandlerFunc(login)))

	// Protected routes (logging + JWT authentication middleware)
	http.Handle("/ping", loggingMiddleware(jwtAuthMiddleware(http.HandlerFunc(ping))))
	http.Handle("/dashboard", loggingMiddleware(jwtAuthMiddleware(http.HandlerFunc(dashboard))))

	log.Println("🚀 Server starting on http://localhost:8080")
	log.Println("📝 Available endpoints:")
	log.Println("   GET  /          - Home (unprotected)")
	log.Println("   GET  /health    - Health check (unprotected)")
	log.Println("   GET  /login     - Get JWT token (unprotected)")
	log.Println("   GET  /ping      - Ping endpoint (protected)")
	log.Println("   GET  /dashboard - Dashboard (protected)")
	log.Println("")
	log.Println("💡 Usage:")
	log.Println("   1. Get token: curl http://localhost:8080/login?username=alice")
	log.Println("   2. Use token:  curl -H \"Authorization: Bearer <token>\" http://localhost:8080/ping")

	log.Fatal(http.ListenAndServe(":8080", nil))
}
