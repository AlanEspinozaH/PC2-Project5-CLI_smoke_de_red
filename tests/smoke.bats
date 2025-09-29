#!/usr/bin/env bats

setup(){ cd "${BATS_TEST_DIRNAME}/.."; }

@test "tools disponibles" {
  run make -s tools
  [ "$status" -eq 0 ]
}

@test "run genera out/report.csv" {
  export HOSTS="example.com" PORTS="80"
  run make -s run
  [ "$status" -eq 0 ]
  [ -f "out/report.csv" ]
}

@test "tcp cerrado provoca código de salida de red (>=2)" {
  export HOSTS="127.0.0.1" PORTS="1"  # puerto improbable -> cerrado
  run make -s run
  [ "$status" -ge 2 ]
}

@test "idempotencia: segunda corrida no cambia tamaño del reporte (sin cambios de entrada)" {
  export HOSTS="example.com" PORTS="80"
  run make -s run
  [ "$status" -eq 0 ]
  size1=$(stat -c%s out/report.csv)
  run make -s run
  [ "$status" -eq 0 ]
  size2=$(stat -c%s out/report.csv)
  [ "$size1" -eq "$size2" ]
}
