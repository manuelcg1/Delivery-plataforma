# Inventario

`POST /api/v1/inventory/adjustments` admite ajustes manuales `INITIAL`, `INCREASE`, `DECREASE` y `ADJUSTMENT`. La operación bloquea el registro, impide resultados negativos y crea un movimiento y una auditoría en la misma transacción.
