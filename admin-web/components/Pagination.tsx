type Props = {
  page: number;
  totalPages: number;
  first: boolean;
  last: boolean;
  onPageChange: (page: number) => void;
};

export function Pagination({ page, totalPages, first, last, onPageChange }: Props) {
  if (totalPages <= 1) return null;
  return <nav className="pagination" aria-label="Paginación">
    <button disabled={first} onClick={() => onPageChange(page - 1)}>Anterior</button>
    <span>Página {page + 1} de {totalPages}</span>
    <button disabled={last} onClick={() => onPageChange(page + 1)}>Siguiente</button>
  </nav>;
}
