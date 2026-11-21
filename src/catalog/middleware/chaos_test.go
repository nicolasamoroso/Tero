package middleware_test

import (
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"

	"retail-store/catalog/middleware"
)

// newRouter arma un router con las rutas de chaos y un endpoint de prueba que pasa por el middleware
func newRouter() *gin.Engine {
	gin.SetMode(gin.TestMode)
	chaos := middleware.NewChaosController()

	r := gin.New()
	chaos.SetupChaosRoutes(r)
	api := r.Group("/catalog")
	api.Use(chaos.ChaosMiddleware())
	api.GET("/products", func(c *gin.Context) { c.String(http.StatusOK, "ok") })
	return r
}

func pedir(r *gin.Engine, method, path string) int {
	w := httptest.NewRecorder()
	r.ServeHTTP(w, httptest.NewRequest(method, path, nil))
	return w.Code
}

func TestChaos_ErrorStatusForzado(t *testing.T) {
	r := newRouter()

	if code := pedir(r, http.MethodPost, "/chaos/status/500"); code != http.StatusOK {
		t.Fatalf("activar el error: esperaba 200, vino %d", code)
	}
	if code := pedir(r, http.MethodGet, "/catalog/products"); code != http.StatusInternalServerError {
		t.Errorf("con chaos activo esperaba 500, vino %d", code)
	}

	pedir(r, http.MethodDelete, "/chaos/status")
	if code := pedir(r, http.MethodGet, "/catalog/products"); code != http.StatusOK {
		t.Errorf("con chaos apagado esperaba 200, vino %d", code)
	}
}

func TestChaos_ValoresInvalidosDan400(t *testing.T) {
	r := newRouter()

	if code := pedir(r, http.MethodPost, "/chaos/status/999"); code != http.StatusBadRequest {
		t.Errorf("código HTTP inválido: esperaba 400, vino %d", code)
	}
	if code := pedir(r, http.MethodPost, "/chaos/latency/abc"); code != http.StatusBadRequest {
		t.Errorf("latencia inválida: esperaba 400, vino %d", code)
	}
}

func TestChaos_ElHealthSeApagaYSePrende(t *testing.T) {
	chaos := middleware.NewChaosController()
	r := gin.New()
	chaos.SetupChaosRoutes(r)

	pedir(r, http.MethodPost, "/chaos/health")
	if chaos.IsHealthy() {
		t.Error("después de POST /chaos/health esperaba IsHealthy() = false")
	}

	pedir(r, http.MethodDelete, "/chaos/health")
	if !chaos.IsHealthy() {
		t.Error("después de DELETE /chaos/health esperaba IsHealthy() = true")
	}
}
