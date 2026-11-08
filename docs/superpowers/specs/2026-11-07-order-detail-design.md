# Detalle de pedido CERKA

Diseño aprobado mediante prototipo visual. Mantener los colores del tema de CERKA, sin cambiar el tema global. Organizar el resumen, total, seguimiento y repartidor en tarjetas claras; representar el historial real mediante una línea vertical conectada. Conservar identificadores, fechas, estados y orden de eventos recibidos.

El chat solo se muestra con entrega existente y estado `IN_TRANSIT` (En camino). Mantener navegación al chat, seguimiento en mapa, actualizaciones, polling, errores y calificación con sus reglas actuales. No añadir cancelación, etapas ficticias ni cambios de API o base de datos.

Enfoque: componentes visuales pequeños, integrados en OrderDetailPage; evitar reescribir controladores o cambiar el tema global. Validar visibilidad del chat, navegación por callback, colores del tema y pantallas estrechas con texto ampliado.
