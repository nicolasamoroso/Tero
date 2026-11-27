# syntax=docker/dockerfile:1
FROM python:3.12.16-slim AS build
WORKDIR /app
# requirements.lock fija con hashes todas las dependencias (directas y transitivas) y solo instala paquetes binarios
COPY requirements.lock ./
RUN pip install --no-cache-dir --only-binary :all: --require-hashes --prefix=/install -r requirements.lock

FROM python:3.12.16-slim
ENV PYTHONUNBUFFERED=1 PYTHONDONTWRITEBYTECODE=1 PORT=8080
WORKDIR /app
COPY --from=build /install /usr/local
COPY app ./app
# Parches de seguridad del sistema que todavía no están en la imagen base
RUN apt-get update && apt-get upgrade -y && rm -rf /var/lib/apt/lists/*
RUN useradd --system --uid 10001 --no-create-home app
USER app
EXPOSE 8080
HEALTHCHECK --interval=30s --timeout=3s --retries=3 \
  CMD python -c "import urllib.request,os;urllib.request.urlopen('http://127.0.0.1:'+os.environ['PORT']+'/health')" || exit 1
CMD ["sh", "-c", "uvicorn app.main:app --host 0.0.0.0 --port $PORT"]
