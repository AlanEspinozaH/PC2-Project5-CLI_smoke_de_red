# Contrato de salidas
- `out/report.csv` → CSV agregador de sondas (validable con `grep`/`awk`).
- `out/raw/*.txt|*.log` → evidencias crudas para trazabilidad.

## Códigos de salida
- **0**: Éxito.
- **2**: Falla de red (TCP cerrado).
- **4**: Falla HTTP (error en `curl`).
- **5**: Falla de configuración.
