const acceptedTypes = new Set(['image/jpeg', 'image/png', 'image/webp']);
export const merchantImageMaxBytes = 5 * 1024 * 1024;

export function catalogImageError(file: Pick<File, 'type' | 'size'>) {
  if (!acceptedTypes.has(file.type)) return 'Usa una imagen JPEG, PNG o WebP';
  if (file.size > merchantImageMaxBytes) return 'La imagen no debe superar 5 MB';
  return '';
}

export const merchantImageError = catalogImageError;

export function catalogImagesError(files: Array<Pick<File, 'type' | 'size'>>, limit = 8) {
  if (files.length > limit) return `Puedes seleccionar hasta ${limit} imágenes por producto.`;
  return files.map(catalogImageError).find(Boolean) ?? '';
}
