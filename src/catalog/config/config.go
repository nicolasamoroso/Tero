package config

import (
	"context"
	"os"

	"github.com/sethvargo/go-envconfig/pkg/envconfig"
)

const passwordEnv = "RETAIL_CATALOG_PERSISTENCE_PASSWORD"

// Load lee la configuración de las variables de entorno.
//
// La versión de go-envconfig que usa catalog (v0.1.1) expande siempre los "$" de los valores,
// como si fueran variables de entorno, y no tiene forma de apagarlo. Una contraseña con "$" le
// llegaba cortada a la base: pasó en dev cuando RDS rotó la contraseña y la nueva tenía un "$".
// Por eso la contraseña se vuelve a leer tal cual, sin expandir.
func Load(ctx context.Context) (AppConfiguration, error) {
	var config AppConfiguration
	if err := envconfig.Process(ctx, &config); err != nil {
		return config, err
	}

	if password, ok := os.LookupEnv(passwordEnv); ok {
		config.Database.Password = password
	}

	return config, nil
}

// Configuration exported
type AppConfiguration struct {
	Port     int `env:"PORT,default=8080"`
	Database DatabaseConfiguration
}

// DatabaseConfiguration exported
type DatabaseConfiguration struct {
	Type           string `env:"RETAIL_CATALOG_PERSISTENCE_PROVIDER,default=in-memory"`
	Endpoint       string `env:"RETAIL_CATALOG_PERSISTENCE_ENDPOINT"`
	Name           string `env:"RETAIL_CATALOG_PERSISTENCE_DB_NAME,default=catalogdb"`
	User           string `env:"RETAIL_CATALOG_PERSISTENCE_USER,default=catalog_user"`
	Password       string `env:"RETAIL_CATALOG_PERSISTENCE_PASSWORD"`
	ConnectTimeout int    `env:"RETAIL_CATALOG_PERSISTENCE_CONNECT_TIMEOUT,default=5"`
}
