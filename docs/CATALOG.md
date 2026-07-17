# Commerce Catalog v0.3

El catálogo sigue el flujo comercio → sucursal/categoría → producto → variante. Los productos nacen en `DRAFT` y solo aparecen públicamente después de `publish`, cuando tienen precio y disponibilidad válidos; los variables requieren una variante disponible. `unpublish` y `archive` retiran el producto de lectura pública.

Permisos `CATALOG_*` separan consulta, creación, actualización, publicación, inventario, horarios, precios y media. `TENANT_ADMIN` recibe estos permisos mediante Flyway V7. Todas las consultas administrativas usan el `tenantId` del principal autenticado.
