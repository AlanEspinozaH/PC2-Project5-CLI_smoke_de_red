# PC2-Project5-Grupo3:
Espinoza Huaman Jose Alan C. - Estacio Sanchez Jose Rodolfo - Ortega Turpo Junior

# Proyecto 5: CLI Smoke Test de Red (ip/ss/curl/nc/ssh) 

## Descripción General

Suite de diagnóstico reproducible para pruebas de red que implementa smoke tests sobre protocolos TCP, HTTP/HTTPS y SSH. El proyecto aplica principios 12-Factor, Bash robusto, separación Compilar-Lanzar-Ejecutar (C-L-E) y metodología AAA/RGR en pruebas.

## Características Principales

- ✅ **Sondas de sistema**: Inspección de interfaces (ip), sockets (ss), logs (journalctl)
- ✅ **Sondas TCP**: Conectividad con netcat (nc)
- ✅ **Sondas HTTP/HTTPS**: Códigos de estado y latencias con curl
- ✅ **Sondas SSH**: Banner, scp y rsync opcionales
- ✅ **12-Factor compliant**: Base única (I), config por env (III), separación C-L-E (V)
- ✅ **Bash robusto**: `set -euo pipefail`, trap, manejo de errores
- ✅ **Caché incremental**: Make solo rehace trabajo si cambian dependencias
- ✅ **Pruebas Bats**: Suite AAA/RGR con casos positivos/negativos/idempotencia

## Requisitos del Sistema

### Sistema Operativo
- Ubuntu 24.04 LTS / WSL2
- Bash 5.0+

### Herramientas Requeridas
Todas las herramientas son estándar en Ubuntu:

```bash
ip ss curl nc ssh scp rsync journalctl bats tar git
```

Para verificar disponibilidad:
```bash
make tools
```

## Instalación y Configuración

### 1. Clonar el Repositorio

```bash
git clone <url-repositorio>
cd pc2-proyecto5-smoke
```

### 2. Verificar Herramientas

```bash
make tools
```

### 3. Configurar Variables de Entorno

Copiar plantilla y editar:
```bash
cp .env.example .env
source .env
```

O exportar directamente:
```bash
export HOSTS="example.com,1.1.1.1"
export PORTS="80,443,22"
export RELEASE="v0.1.0"
```

## Variables de Entorno (12-Factor III)

### Tabla Variable → Efecto

| Variable | Efecto Observable | Ejemplo | Obligatoria |
|----------|-------------------|---------|-------------|
| `HOSTS` | Define hosts a probar (comma-separated). Afecta filas en `out/report.csv` | `example.com,1.1.1.1` | No (default: `example.com`) |
| `PORTS` | Define puertos a probar (comma-separated). Afecta columnas en `out/report.csv` | `80,443,22` | No (default: `80,443`) |
| `RELEASE` | Versión del release. Afecta nombre de paquete en `dist/` | `v0.1.0` | No (default: `dev`) |
| `SSH_USER` | Usuario para pruebas SSH. Habilita `probe_scp_rsync_optional` | `ubuntu` | No |
| `SSH_HOST` | Host para pruebas SSH. Debe usarse con `SSH_USER` | `192.168.1.10` | No |
| `SSH_PORT` | Puerto SSH (default 22). Verificable con `ss -ltnp \| grep :SSH_PORT` | `2222` | No (default: `22`) |
| `SSH_KEY` | Ruta a llave privada SSH. Afecta autenticación en scp/rsync | `~/.ssh/id_rsa` | No |
| `HTTP_TIMEOUT` | Timeout HTTP en segundos. Afecta latencias en `report.csv` | `10` | No (default: `5`) |
| `DEBUG` | Habilita logging debug (`1`/`0`). Visible en stderr | `1` | No (default: `0`) |

### Validación de Variables

El script valida:
- ✅ Al menos un host y un puerto
- ✅ Puertos entre 1-65535
- ✅ Consistencia SSH (USER y HOST juntos)
- ✅ Existencia de `SSH_KEY` si se especifica

## Uso Básico

### Flujo Completo

```bash
# 1. Verificar herramientas
make tools

# 2. Preparar artefactos (build)
time make build   # Observar caché incremental

# 3. Configurar y ejecutar
export HOSTS="example.com,google.com" PORTS="80,443,22"
make run

# 4. Ejecutar pruebas
make test

# 5. Empaquetar release
make pack
```

### Casos de Uso Específicos

#### Smoke Test Básico (HTTP)
```bash
export HOSTS="example.com" PORTS="80,443"
make run
# Ver: out/report.csv
```

#### Smoke Test con SSH
```bash
export HOSTS="example.com" PORTS="22"
make run
# Ver: out/raw/ssh_banner.txt
```

#### Smoke Test Completo con Transferencias
```bash
export HOSTS="example.com" PORTS="80,443,22"
export SSH_USER="ubuntu" SSH_HOST="192.168.1.10" SSH_KEY="~/.ssh/id_rsa"
make run
# Ver: out/raw/ssh_scp.log, out/raw/ssh_rsync.log
```

#### Smoke Test de Red Local
```bash
export HOSTS="127.0.0.1,192.168.1.1" PORTS="22,80,443,3000,8080"
make run
```

## Estructura del Proyecto

```
pc2-proyecto5-smoke/
├── src/
│   ├── probe_sys.sh      # Sondas de sistema (ip/ss/journalctl)
│   ├── probe_tcp.sh      # Sondas TCP/SSH (nc/banner/scp/rsync)
│   ├── probe_http.sh     # Sondas HTTP/HTTPS (curl)
│   └── smoke.sh          # Orquestador principal
├── tests/
│   └── smoke.bats        # Suite de pruebas AAA/RGR
├── docs/
│   ├── README.md         # Esta documentación
│   ├── contrato-salidas.md   # Especificación de artefactos
│   └── bitacora-sprint-1.md  # Plantilla de bitácora
├── systemd/
│   └── smoke.service     # Unidad systemd (opcional)
├── out/                  # Salidas (git-ignored)
│   ├── report.csv        # Reporte principal
│   └── raw/              # Artefactos crudos
├── dist/                 # Paquetes (git-ignored)
├── Makefile              # Automatización con caché
└── .gitattributes        # EOL normalization
```

## Arquitectura de Módulos

### Separación de Responsabilidades

```
┌─────────────────────────────────────────┐
│         smoke.sh (Orquestador)          │
│  - Validación de config                 │
│  - Iteración hosts×ports                │
│  - Generación CSV                       │
│  - Manejo de exit codes                 │
└─────────────────┬───────────────────────┘
                  │
          ┌───────┴───────┬─────────────────┐
          ▼               ▼                 ▼
  ┌───────────────┐ ┌─────────────┐ ┌──────────────┐
  │ probe_sys.sh  │ │probe_tcp.sh │ │probe_http.sh │
  │ - ip addr     │ │ - nc        │ │ - curl       │
  │ - ip route    │ │ - ssh banner│ │ - latencias  │
  │ - ss          │ │ - scp/rsync │ │ - códigos    │
  │ - journalctl  │ └─────────────┘ └──────────────┘
  └───────────────┘
```

### Interfaces de Módulos (Contratos)

#### `probe_sys.sh`
```bash
# Entrada: ninguna (usa variables de entorno)
# Salida: archivos en $RAW/

probe_ip()    # → raw/ip_addr.txt, raw/ip_route.txt
probe_ss()    # → raw/ss_listen.txt
log_jctl()    # → raw/journalctl_err.txt
```

#### `probe_tcp.sh`
```bash
# Entrada: <host> <port>
# Salida: stdout + archivos en $RAW/

probe_tcp <host> <port>           # → "OPEN" | "CLOSED"
probe_ssh_banner <host>           # → banner SSH o vacío
probe_scp_rsync_optional          # → logs en raw/ (si SSH_* configurado)
```

#### `probe_http.sh`
```bash
# Entrada: <host> <port>
# Salida: stdout

probe_http <host> <port>          # → "HTTP_CODE,TIME" | "ERR,NA"
# Ejemplos: "200,0.234" | "404,0.123" | "ERR,NA"
```

## Códigos de Salida (Severidad Acumulativa)

El script retorna el código más grave encontrado:

| Código | Significado | Causa Típica |
|--------|-------------|--------------|
| `0` | Éxito | Todas las pruebas pasaron |
| `1` | Error genérico | Fallo inesperado |
| `2` | Error de red/TCP | Puerto cerrado, timeout |
| `3` | Error DNS | Host no resuelve |
| `4` | Error HTTP | Código 4xx/5xx, ERR |
| `5` | Error de configuración | Variables inválidas |

### Ejemplos

```bash
# Caso 1: Todo OK → exit 0
export HOSTS="example.com" PORTS="80"
make run
echo $?  # 0

# Caso 2: DNS no resuelve → exit 3
export HOSTS="noexiste.invalid" PORTS="80"
make run
echo $?  # 3

# Caso 3: Puerto cerrado → exit 2
export HOSTS="127.0.0.1" PORTS="9999"
make run
echo $?  # 2

# Caso 4: HTTP error → exit 4
export HOSTS="httpstat.us" PORTS="80"
make run  # (si httpstat.us/500 retorna 500)
echo $?  # 4
```

## Idempotencia

El proyecto garantiza idempotencia observable:

### Caché Incremental en Make

```bash
# Primera ejecución: genera artefactos
time make build
# real 0m0.123s

# Segunda ejecución: usa caché
time make build
# real 0m0.012s (10x más rápido)

# Solo se rehace si cambian dependencias:
touch src/smoke.sh
time make build
# real 0m0.098s (regenera)
```

### Reproducibilidad en Ejecución

```bash
# Dos ejecuciones con mismas variables → mismo resultado
export HOSTS="example.com" PORTS="80"

make run > /tmp/run1.log 2>&1
lines1=$(wc -l < out/report.csv)

make run > /tmp/run2.log 2>&1
lines2=$(wc -l < out/report.csv)

[ "$lines1" == "$lines2" ]  # true
```

## Pruebas (Bats - AAA/RGR)

### Suite Actual

1. **tools disponibles**: Verifica que todas las herramientas existen
2. **run genera CSV**: Ejecución básica produce `out/report.csv`
3. **tcp cerrado provoca código ≥2**: Puerto imposible falla correctamente
4. **idempotencia**: Doble ejecución no cambia resultado

### Ejecutar Pruebas

```bash
# Todas las pruebas
make test

# Prueba específica
bats -f "idempotencia" tests/smoke.bats

# Verbose
bats -T tests/smoke.bats
```

### Metodología AAA/RGR

- **Arrange**: Setup de variables de entorno
- **Act**: Ejecución de `make run`
- **Assert**: Verificación de exit code, archivos, contenido

Ciclo RGR (Rojo-Verde-Refactor):
- Sprint 1: Casos rojos (fallan)
- Sprint 2: Implementación (verde)
- Sprint 3: Refactor y optimización

## Targets del Makefile

### `make tools`
Verifica disponibilidad de herramientas requeridas.

```bash
$ make tools
→ Verificando herramientas requeridas...
✓ ip
✓ ss
✓ curl
✓ nc
✓ ssh
✓ scp
✓ rsync
✓ journalctl
✓ bats
✓ tar
✓ git
✓ Todas las herramientas están disponibles
```

### `make build`
Prepara artefactos con caché incremental.

```bash
$ time make build
→ Preparando artefactos (build)...
  Validando: probe_sys.sh
  Validando: probe_tcp.sh
  Validando: probe_http.sh
  Validando: smoke.sh
✓ Build completado

real    0m0.145s
```

### `make test`
Ejecuta suite de pruebas Bats.

```bash
$ make test
→ Ejecutando suite de pruebas Bats...
 ✓ tools disponibles
 ✓ run genera out/report.csv
 ✓ tcp cerrado provoca código de salida de red (>=2)
 ✓ idempotencia: segunda corrida no cambia tamaño

4 tests, 0 failures
✓ Todas las pruebas pasaron
```

### `make run`
Ejecuta el smoke test principal.

```bash
$ export HOSTS="example.com,google.com" PORTS="80,443"
$ make run
→ Ejecutando smoke test...
  HOSTS: example.com,google.com
  PORTS: 80,443
  RELEASE: v0.1.0
[INFO] 2025-01-15T10:30:00-0500 === Smoke Test de Red - Proyecto 5 PC2 ===
[INFO] 2025-01-15T10:30:00-0500 Release: v0.1.0
[INFO] 2025-01-15T10:30:00-0500 Capturando estado del sistema...
[INFO] 2025-01-15T10:30:01-0500 Iniciando sondas de red...
[INFO] 2025-01-15T10:30:05-0500 Sondas completadas: 4 pruebas, 0 fallidas
[INFO] 2025-01-15T10:30:05-0500 === Resumen ===
[INFO] 2025-01-15T10:30:05-0500 Estado: ÉXITO - Todas las pruebas pasaron
```

### `make pack`
Crea paquete distribuible reproducible.

```bash
$ export RELEASE="v0.1.0"
$ make pack
→ Creando paquete distribuible...
✓ Paquete creado: dist/pc2-smoke-v0.1.0.tar.gz
-rw-r--r-- 1 user user 12K Jan 15 10:35 dist/pc2-smoke-v0.1.0.tar.gz
```

### `make clean`
Limpia artefactos generados.

```bash
$ make clean
→ Limpiando artefactos...
  Eliminando: out
  Eliminando: dist
✓ Limpieza completada
```

## Troubleshooting

### Error: "Herramienta faltante"

```bash
$ make tools
✗ FALTA: bats

ERROR: Faltan 1 herramientas.
Instale las herramientas faltantes antes de continuar.
```

**Solución**:
```bash
sudo apt-get update
sudo apt-get install -y bats
```

### Error: "SSH_USER y SSH_HOST deben estar ambos definidos"

**Causa**: Configuración SSH inconsistente.

**Solución**:
```bash
# Opción 1: Definir ambos
export SSH_USER="ubuntu"
export SSH_HOST="192.168.1.10"

# Opción 2: No definir ninguno
unset SSH_USER SSH_HOST
```

### Error: "Puerto inválido"

**Causa**: Puerto fuera de rango o no numérico.

**Solución**:
```bash
# Incorrecto
export PORTS="80,https,22"

# Correcto
export PORTS="80,443,22"
```

### Problema: Caché no funciona

**Síntoma**: `make build` siempre regenera artefactos.

**Diagnóstico**:
```bash
# Verificar timestamp de marker
ls -la out/.deps.ok

# Verificar dependencias
make -d build | grep "newer than target"
```

**Solución**: Asegurar que timestamps son consistentes (no tocar archivos manualmente).

## Ejemplos Avanzados

### Análisis de Latencias HTTP

```bash
export HOSTS="example.com,google.com,github.com" PORTS="443"
make run

# Extraer latencias
awk -F, '$5 != "NA" {print $2,$6}' out/report.csv | sort -k2 -n
```

### Detección de Puertos Abiertos

```bash
export HOSTS="192.168.1.1" PORTS="22,80,443,3000,8080,9000"
make run

# Filtrar solo OPEN
awk -F, '$4 == "OPEN" {print $2":"$3}' out/report.csv
```

### Monitoreo Continuo (cron)

```bash
# Agregar a crontab
*/15 * * * * cd /path/to/project && export HOSTS="..." PORTS="..." && make run && cp out/report.csv /var/log/smoke/report-$(date +\%s).csv
```

## Referencias

- [12-Factor App](https://12factor.net/)
- [Bash Strict Mode](http://redsymbol.net/articles/unofficial-bash-strict-mode/)
- [Bats Testing](https://github.com/bats-core/bats-core)
- [GNU Make Manual](https://www.gnu.org/software/make/manual/)

## Equipo y Contribuciones

**Proyecto PC2-5**: CLI Smoke Test de Red  
**Curso**: CC3S2 - Desarrollo de Software  
**Sprint**: 1/3

Ver `docs/bitacora-sprint-1.md` para detalles de implementación.

## Licencia

Proyecto académico - CC3S2 2025
