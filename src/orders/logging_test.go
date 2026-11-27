package main

import (
	"bytes"
	"encoding/json"
	"log/slog"
	"net/http"
	"net/http/httptest"
	"testing"

	"github.com/gin-gonic/gin"
)

func eventos(t *testing.T, salida *bytes.Buffer) []map[string]any {
	t.Helper()
	var lista []map[string]any
	for _, linea := range bytes.Split(bytes.TrimSpace(salida.Bytes()), []byte("\n")) {
		if len(linea) == 0 {
			continue
		}
		var e map[string]any
		if err := json.Unmarshal(linea, &e); err != nil {
			t.Fatalf("la línea no es JSON: %q", linea)
		}
		lista = append(lista, e)
	}
	return lista
}

func TestLogger_EscribeJSONConElEsquemaComun(t *testing.T) {
	anterior := slog.Default()
	t.Cleanup(func() { slog.SetDefault(anterior) })
	var salida bytes.Buffer
	initLogger(&salida)

	slog.Warn("hola", "k", "v")

	lista := eventos(t, &salida)
	if len(lista) != 1 {
		t.Fatalf("esperaba 1 evento, vinieron %d", len(lista))
	}
	e := lista[0]
	if e["level"] != "warn" || e["message"] != "hola" || e["service"] != serviceName || e["k"] != "v" {
		t.Fatalf("esquema inesperado: %v", e)
	}
	if _, ok := e["timestamp"]; !ok {
		t.Fatalf("falta timestamp: %v", e)
	}
}

func TestRequestLogger_LogueaElRequestYSaltaElHealth(t *testing.T) {
	gin.SetMode(gin.TestMode)
	anterior := slog.Default()
	t.Cleanup(func() { slog.SetDefault(anterior) })
	var salida bytes.Buffer
	initLogger(&salida)

	r := gin.New()
	r.Use(requestLogger("/health"), recoveryLogger())
	r.GET("/health", func(c *gin.Context) { c.String(http.StatusOK, "OK") })
	r.GET("/roto", func(_ *gin.Context) { panic("boom") })
	for _, path := range []string{"/health", "/nada", "/roto"} {
		r.ServeHTTP(httptest.NewRecorder(), httptest.NewRequest(http.MethodGet, path, nil))
	}

	// /health no deja log; /nada deja un warn 404; /roto deja el panic y el request con 500
	lista := eventos(t, &salida)
	if len(lista) != 3 {
		t.Fatalf("esperaba 3 eventos, vinieron %d: %v", len(lista), lista)
	}
	if lista[0]["level"] != "warn" || lista[0]["status"] != float64(404) || lista[0]["path"] != "/nada" {
		t.Fatalf("request 404 inesperado: %v", lista[0])
	}
	if lista[1]["message"] != "panic recuperado" {
		t.Fatalf("falta el log del panic: %v", lista[1])
	}
	if lista[2]["level"] != "error" || lista[2]["status"] != float64(500) {
		t.Fatalf("request 500 inesperado: %v", lista[2])
	}
}
