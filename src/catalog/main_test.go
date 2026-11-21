package main

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"retail-store/catalog/middleware"
)

func TestHealth_RespondeOKYDa503SiSeApagaDesdeChaos(t *testing.T) {
	gin.SetMode(gin.TestMode)
	chaos := middleware.NewChaosController()

	r := gin.New()
	chaos.SetupChaosRoutes(r)
	r.GET("/health", healthHandler(chaos))

	pedir := func(method, path string) int {
		w := httptest.NewRecorder()
		r.ServeHTTP(w, httptest.NewRequest(method, path, nil))
		return w.Code
	}

	if code := pedir(http.MethodGet, "/health"); code != http.StatusOK {
		t.Fatalf("esperaba 200, vino %d", code)
	}

	pedir(http.MethodPost, "/chaos/health") // apaga el health
	if code := pedir(http.MethodGet, "/health"); code != http.StatusServiceUnavailable {
		t.Errorf("con el health apagado esperaba 503, vino %d", code)
	}

	pedir(http.MethodDelete, "/chaos/health") // lo vuelve a prender
	if code := pedir(http.MethodGet, "/health"); code != http.StatusOK {
		t.Errorf("con el health prendido de nuevo esperaba 200, vino %d", code)
	}
}
