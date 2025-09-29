# PC2-Project5-CLI_smoke_de_red
PC2- Grupo 3 - Proyecto 5 - CLI smoke de red (ip/ss/curl/nc/ssh)

## Uso rápido
`
export HOSTS="example.com,1.1.1.1"
export PORTS="80,443,22"
export RELEASE="v0.1.0"
make tools && make build && make run && make test && make pack
`

## Variables (variable -> efecto observable)
| Variable | Efecto |
|---|---|
| `HOSTS` | Lista coma-separada de destinos; se ven en `out/report.csv`. |
| `PORTS` | Puertos TCP a verificar (80/443 hacen `curl`, 22 intenta banner SSH). |
| `RELEASE` | Versionado del paquete en `dist/`. |
| `SSH_USER`/`HOST`/`PORT`/`KEY` | Si se definen, se prueba `scp`/`rsync` no destructivo y se registran en `out/raw/ssh_*`. |

## Contrato de salidas
- `out/report.csv`: `timestamp,host,port,tcp,http_code,http_time`.
- [cite_start]`out/raw/`: `ip_addr.txt`, `ip_route.txt`, `ss_listen.txt`, `journalctl_err.txt`, etc. [cite: 22]
