package main

import (
	"fmt"
	"io"
	"log/slog"
	"net/http"
	"os"
	"strings"
	"time"

	"github.com/gin-gonic/gin"
)

const serviceName = "catalog"

// initLogger deja a slog (y también al paquete log) escribiendo una línea JSON por evento,
// con el esquema común de los servicios: timestamp, level, service, message.
func initLogger(w io.Writer) {
	handler := slog.NewJSONHandler(w, &slog.HandlerOptions{
		ReplaceAttr: func(_ []string, a slog.Attr) slog.Attr {
			switch a.Key {
			case slog.TimeKey:
				a.Key = "timestamp"
			case slog.MessageKey:
				a.Key = "message"
			case slog.LevelKey:
				a.Value = slog.StringValue(strings.ToLower(a.Value.String()))
			}
			return a
		},
	})
	slog.SetDefault(slog.New(handler).With("service", serviceName))
}

// fatal reemplaza a log.Fatal: deja el error en JSON y termina el proceso.
func fatal(msg string, err error) {
	slog.Error(msg, "error", err.Error())
	os.Exit(1)
}

// requestLogger deja una línea por request (sin query string) y se salta los paths indicados.
func requestLogger(skip ...string) gin.HandlerFunc {
	saltear := make(map[string]bool, len(skip))
	for _, p := range skip {
		saltear[p] = true
	}
	return func(c *gin.Context) {
		inicio := time.Now()
		c.Next()
		path := c.Request.URL.Path
		if saltear[path] {
			return
		}
		status := c.Writer.Status()
		nivel := slog.LevelInfo
		if status >= http.StatusInternalServerError {
			nivel = slog.LevelError
		} else if status >= http.StatusBadRequest {
			nivel = slog.LevelWarn
		}
		slog.Log(c.Request.Context(), nivel, "request",
			"method", c.Request.Method,
			"path", path,
			"status", status,
			"duration_ms", float64(time.Since(inicio).Microseconds())/1000,
			"remote_ip", c.ClientIP(),
		)
	}
}

// recoveryLogger recupera los panics y los deja en JSON en vez del texto de gin.
func recoveryLogger() gin.HandlerFunc {
	return gin.CustomRecoveryWithWriter(io.Discard, func(c *gin.Context, err any) {
		slog.Error("panic recuperado", "error", fmt.Sprint(err), "path", c.Request.URL.Path)
		c.AbortWithStatus(http.StatusInternalServerError)
	})
}
