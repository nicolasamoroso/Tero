package main

import (
	"bytes"
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
	"gorm.io/driver/sqlite"
	"gorm.io/gorm"
)

// newTestRouter reemplaza la base global por una SQLite en memoria (vacía en cada test)
// y registra las mismas rutas que main
func newTestRouter(t *testing.T) *gin.Engine {
	t.Helper()
	gin.SetMode(gin.TestMode)

	var err error
	db, err = gorm.Open(sqlite.Open("file::memory:"), &gorm.Config{})
	if err != nil {
		t.Fatal(err)
	}
	if err := db.AutoMigrate(&Order{}, &OrderItem{}); err != nil {
		t.Fatal(err)
	}

	r := gin.New()
	r.GET("/health", health)
	r.GET("/orders", listOrders)
	r.POST("/orders", createOrder)
	return r
}

func do(r *gin.Engine, method, path string, body []byte) *httptest.ResponseRecorder {
	w := httptest.NewRecorder()
	req := httptest.NewRequest(method, path, bytes.NewReader(body))
	req.Header.Set("Content-Type", "application/json")
	r.ServeHTTP(w, req)
	return w
}

const nuevaOrden = `{
	"shippingAddress": {"firstName": "Ana", "lastName": "Test", "email": "ana@example.com", "city": "Montevideo"},
	"items": [{"productId": "prod-1", "name": "Reloj", "quantity": 3, "price": 100}]
}`

func TestHealth(t *testing.T) {
	w := do(newTestRouter(t), http.MethodGet, "/health", nil)
	if w.Code != http.StatusOK || w.Body.String() != "OK" {
		t.Errorf("esperaba 200 OK, vino %d %q", w.Code, w.Body.String())
	}
}

func TestCreateOrder_CalculaElTotalDeCadaItem(t *testing.T) {
	w := do(newTestRouter(t), http.MethodPost, "/orders", []byte(nuevaOrden))
	if w.Code != http.StatusCreated {
		t.Fatalf("esperaba 201, vino %d: %s", w.Code, w.Body.String())
	}

	var order Order
	json.Unmarshal(w.Body.Bytes(), &order)
	if order.ID == "" {
		t.Error("la orden no tiene ID")
	}
	if order.Email != "ana@example.com" {
		t.Errorf("email: esperaba ana@example.com, vino %q", order.Email)
	}
	if len(order.Items) != 1 || order.Items[0].TotalCost != 300 {
		t.Errorf("esperaba 1 item con totalCost 300 (3 x 100), vino %+v", order.Items)
	}
}

func TestListOrders_DevuelveLasOrdenesConSusItems(t *testing.T) {
	r := newTestRouter(t)
	do(r, http.MethodPost, "/orders", []byte(nuevaOrden))

	w := do(r, http.MethodGet, "/orders", nil)
	if w.Code != http.StatusOK {
		t.Fatalf("esperaba 200, vino %d", w.Code)
	}
	var orders []Order
	json.Unmarshal(w.Body.Bytes(), &orders)
	if len(orders) != 1 || len(orders[0].Items) != 1 {
		t.Errorf("esperaba 1 orden con 1 item, vino %+v", orders)
	}
}

func TestCreateOrder_JSONInvalidoDa400(t *testing.T) {
	w := do(newTestRouter(t), http.MethodPost, "/orders", []byte(`{esto no es json`))
	if w.Code != http.StatusBadRequest {
		t.Errorf("esperaba 400, vino %d", w.Code)
	}
}

func TestBuildDSN_SeparaHostYPuerto(t *testing.T) {
	t.Setenv("RETAIL_ORDERS_PERSISTENCE_ENDPOINT", "db.example.com:6543")
	t.Setenv("RETAIL_ORDERS_PERSISTENCE_USERNAME", "usuario")
	t.Setenv("RETAIL_ORDERS_PERSISTENCE_PASSWORD", "secreto")
	t.Setenv("RETAIL_ORDERS_PERSISTENCE_NAME", "ordenes")

	want := "host=db.example.com port=6543 user=usuario password=secreto dbname=ordenes sslmode=disable"
	if got := buildDSN(); got != want {
		t.Errorf("DSN:\n esperaba %q\n vino     %q", want, got)
	}
}

func TestGetEnv_UsaElDefaultSiNoEstaDefinida(t *testing.T) {
	t.Setenv("VARIABLE_DE_PRUEBA", "")
	if got := getEnv("VARIABLE_DE_PRUEBA", "valor-por-defecto"); got != "valor-por-defecto" {
		t.Errorf("esperaba el default, vino %q", got)
	}
}
