package repository

import (
	"strings"
	"testing"

	"retail-store/catalog/config"
)

func TestBuildDSN_LaContrasenaVaEntreComillasYEscapada(t *testing.T) {
	dsn := buildDSN(config.DatabaseConfiguration{
		Endpoint:       "db.example:5433",
		Name:           "catalogdb",
		User:           "retail_user",
		Password:       `a b'c\d$e`,
		ConnectTimeout: 5,
	})

	esperado := `host=db.example port=5433 user=retail_user password='a b\'c\\d$e' dbname=catalogdb sslmode=disable connect_timeout=5`
	if dsn != esperado {
		t.Errorf("DSN inesperado:\n esperaba %s\n vino     %s", esperado, dsn)
	}
}

func TestBuildDSN_SinPuertoUsa5432(t *testing.T) {
	dsn := buildDSN(config.DatabaseConfiguration{Endpoint: "db.example", Password: "x"})
	if !strings.Contains(dsn, "host=db.example port=5432 ") {
		t.Errorf("esperaba el puerto 5432 por defecto, vino %s", dsn)
	}
}
