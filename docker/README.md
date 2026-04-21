# Backend Docker — Trazado Eléctrico

Stack completo con PostgreSQL+PostGIS, pg_tileserv y PostgREST.

## Levantar el stack

```bash
cd docker
docker-compose up -d
```

Servicios disponibles:
- **PostgreSQL+PostGIS**: `localhost:5432`
- **PostgREST (API)**: `http://localhost:3000`
- **pg_tileserv (tiles)**: `http://localhost:7800`

## Verificar que funciona

```bash
# Ver logs
docker-compose logs -f

# Verificar API
curl http://localhost:3000/lmt

# Verificar tiles
curl http://localhost:7800/public.lmt_tiles/10/341/585.pbf
```

## Conectar desde el celular

1. Obtener la IP de tu máquina en la red WiFi:
```bash
ip addr show | grep "inet " | grep -v 127.0.0.1
```

2. Actualizar la URL en Flutter:
```bash
flutter run -d ZY32LHM97M --dart-define=API_URL=http://TU-IP:3000 --dart-define=PG_TILESERV_URL=http://TU-IP:7800
```

Ejemplo:
```bash
flutter run -d ZY32LHM97M --dart-define=API_URL=http://192.168.1.100:3000 --dart-define=PG_TILESERV_URL=http://192.168.1.100:7800
```

## Detener el stack

```bash
docker-compose down
```

## Limpiar datos y reiniciar

```bash
docker-compose down -v
docker-compose up -d
```
