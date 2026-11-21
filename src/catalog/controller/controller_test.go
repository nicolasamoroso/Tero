package controller_test

import (
	"encoding/json"
	"net/http"
	"net/http/httptest"
	"os"
	"testing"

	"github.com/gin-gonic/gin"

	"retail-store/catalog/api"
	"retail-store/catalog/config"
	"retail-store/catalog/controller"
	"retail-store/catalog/model"
	"retail-store/catalog/repository"
)

var router *gin.Engine

// TestMain arma el router una sola vez con el repositorio en memoria (SQLite),
// que carga los 11 productos y los 4 tags de products.json y tags.json
func TestMain(m *testing.M) {
	gin.SetMode(gin.TestMode)

	repo, err := repository.NewRepository(config.DatabaseConfiguration{Type: "in-memory"})
	if err != nil {
		panic(err)
	}
	catalogAPI, _ := api.NewCatalogAPI(repo)
	c, _ := controller.NewController(catalogAPI)

	router = gin.New()
	catalog := router.Group("/catalog")
	catalog.GET("/products", c.GetProducts)
	catalog.GET("/products/:id", c.GetProduct)
	catalog.GET("/size", c.CatalogSize)
	catalog.GET("/tags", c.ListTags)

	os.Exit(m.Run())
}

// get hace el pedido y devuelve el código HTTP y el cuerpo
func get(t *testing.T, path string) (int, []byte) {
	t.Helper()
	w := httptest.NewRecorder()
	req := httptest.NewRequest(http.MethodGet, path, nil)
	router.ServeHTTP(w, req)
	return w.Code, w.Body.Bytes()
}

func TestGetProducts_PrimeraPaginaTrae10(t *testing.T) {
	code, body := get(t, "/catalog/products")
	if code != http.StatusOK {
		t.Fatalf("esperaba 200, vino %d", code)
	}
	var products []model.Product
	if err := json.Unmarshal(body, &products); err != nil {
		t.Fatal(err)
	}
	if len(products) != 10 {
		t.Errorf("esperaba 10 productos (tamaño de página por defecto), vinieron %d", len(products))
	}
}

func TestGetProducts_SegundaPaginaTraeElResto(t *testing.T) {
	_, body := get(t, "/catalog/products?page=2&size=10")
	var products []model.Product
	json.Unmarshal(body, &products)
	if len(products) != 1 {
		t.Errorf("esperaba 1 producto en la página 2, vinieron %d", len(products))
	}
}

func TestGetProducts_FiltraPorTag(t *testing.T) {
	_, body := get(t, "/catalog/products?tags=food")
	var products []model.Product
	json.Unmarshal(body, &products)
	if len(products) == 0 {
		t.Fatal("esperaba al menos un producto con el tag food")
	}
	for _, p := range products {
		tieneFood := false
		for _, tag := range p.Tags {
			if tag.Name == "food" {
				tieneFood = true
			}
		}
		if !tieneFood {
			t.Errorf("el producto %s no tiene el tag food", p.Name)
		}
	}
}

func TestGetProducts_OrdenPorPrecio(t *testing.T) {
	_, body := get(t, "/catalog/products?order=price_asc&size=20")
	var products []model.Product
	json.Unmarshal(body, &products)
	for i := 1; i < len(products); i++ {
		if products[i].Price < products[i-1].Price {
			t.Fatalf("no está ordenado por precio: %d antes que %d", products[i-1].Price, products[i].Price)
		}
	}
}

func TestGetProducts_PaginaInvalidaDa400(t *testing.T) {
	code, _ := get(t, "/catalog/products?page=abc")
	if code != http.StatusBadRequest {
		t.Errorf("esperaba 400, vino %d", code)
	}
}

func TestGetProduct_Existente(t *testing.T) {
	code, body := get(t, "/catalog/products/cc789f85-1476-452a-8100-9e74502198e0")
	if code != http.StatusOK {
		t.Fatalf("esperaba 200, vino %d", code)
	}
	var p model.Product
	json.Unmarshal(body, &p)
	if p.Name != "Reloj Inteligente" {
		t.Errorf("esperaba Reloj Inteligente, vino %q", p.Name)
	}
}

func TestGetProduct_InexistenteDa404(t *testing.T) {
	code, _ := get(t, "/catalog/products/no-existe")
	if code != http.StatusNotFound {
		t.Errorf("esperaba 404, vino %d", code)
	}
}

func TestCatalogSize(t *testing.T) {
	_, body := get(t, "/catalog/size")
	var r model.CatalogSizeResponse
	json.Unmarshal(body, &r)
	if r.Size != 11 {
		t.Errorf("esperaba 11 productos, vino %d", r.Size)
	}
}

func TestListTags(t *testing.T) {
	_, body := get(t, "/catalog/tags")
	var tags []model.Tag
	json.Unmarshal(body, &tags)
	if len(tags) != 4 {
		t.Errorf("esperaba 4 tags, vinieron %d", len(tags))
	}
}
