# syntax=docker/dockerfile:1

FROM golang:1.24.5-alpine AS build
WORKDIR /src
COPY go.mod go.sum ./
RUN go mod download
COPY . .
# CGO_ENABLED=0 genera un binario estático para distroless/static.
# Ojo: el provider in-memory (SQLite, default del código) necesita CGO y NO arranca así.
# catalog tiene que correr con RETAIL_CATALOG_PERSISTENCE_PROVIDER=postgres.
RUN CGO_ENABLED=0 GOOS=linux go build -trimpath -ldflags="-s -w" -o /out/catalog .

FROM gcr.io/distroless/static-debian12:nonroot
COPY --from=build /out/catalog /catalog
USER nonroot:nonroot
EXPOSE 8080
ENTRYPOINT ["/catalog"]
