package config

import (
	"context"
	"testing"
)

// La contraseña tiene que llegar tal cual, aunque tenga "$": es el caso que rompió catalog en dev
// cuando RDS rotó la contraseña de la base.
func TestLoad_LaContrasenaConDolarNoSeExpande(t *testing.T) {
	const password = "ab$HOME(c):d$x~"
	t.Setenv("RETAIL_CATALOG_PERSISTENCE_PASSWORD", password)
	t.Setenv("HOME", "esto-no-tiene-que-aparecer")

	config, err := Load(context.Background())
	if err != nil {
		t.Fatalf("Load devolvió un error: %v", err)
	}
	if config.Database.Password != password {
		t.Errorf("la contraseña cambió: esperaba %q, vino %q", password, config.Database.Password)
	}
}

func TestLoad_ElRestoSigueConSusDefaults(t *testing.T) {
	t.Setenv("RETAIL_CATALOG_PERSISTENCE_ENDPOINT", "db:5432")

	config, err := Load(context.Background())
	if err != nil {
		t.Fatalf("Load devolvió un error: %v", err)
	}
	if config.Port != 8080 || config.Database.Name != "catalogdb" || config.Database.Endpoint != "db:5432" {
		t.Errorf("config inesperada: %+v", config)
	}
}
