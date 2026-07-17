import { render, screen } from '@testing-library/react';
import userEvent from '@testing-library/user-event';
import { describe, expect, it, vi } from 'vitest';
import { Pagination } from './Pagination';

describe('Pagination', () => {
  it('shows totals and requests the next page', async () => {
    const change = vi.fn();
    render(<Pagination page={0} totalPages={3} first last={false} onPageChange={change} />);
    expect(screen.getByText('Página 1 de 3')).toBeInTheDocument();
    expect(screen.getByRole('button', { name: 'Anterior' })).toBeDisabled();
    await userEvent.click(screen.getByRole('button', { name: 'Siguiente' }));
    expect(change).toHaveBeenCalledWith(1);
  });

  it('does not render for a single page', () => {
    const { container } = render(<Pagination page={0} totalPages={1} first last onPageChange={() => undefined} />);
    expect(container).toBeEmptyDOMElement();
  });
});
