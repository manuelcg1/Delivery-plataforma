import {render, screen, cleanup} from '@testing-library/react';
import {afterEach, describe, expect, it, vi} from 'vitest';
import Private from '@/app/(private)/layout';

const state = vi.hoisted(() => ({owner: true, tenant: 'platform', allowed: true}));
vi.mock('next/navigation', () => ({useRouter: () => ({replace: vi.fn()})}));
vi.mock('@/lib/api', () => ({api: vi.fn().mockResolvedValue([{id: 'north', code: 'north-shop', name: 'North', status: 'ACTIVE'}])}));
vi.mock('@/lib/auth', () => ({useAuth: () => ({
  user: {roles: state.owner ? ['ROLE_PLATFORM_OWNER'] : ['TENANT_ADMIN'],
    tenant: {code: state.tenant}, mustChangePassword: false},
  loading: false, logout: vi.fn(), switchTenant: vi.fn(), can: () => state.allowed,
})}));

afterEach(cleanup);
describe('operational merchant navigation', () => {
  it('lets the platform owner access the catalog in the platform tenant', async () => {
    state.owner = true; state.tenant = 'platform'; state.allowed = true;
    render(<Private>Contenido</Private>);
    expect(await screen.findByRole('link', {name: 'Comercios', exact: true})).toHaveAttribute('href', '/merchants');
    expect(screen.getByRole('link', {name: 'Comercios globales'})).toHaveAttribute('href', '/platform/merchants');
  });
  it('preserves the selected business context', async () => {
    state.owner = true; state.tenant = 'north-shop'; state.allowed = true;
    render(<Private>Contenido</Private>);
    expect(await screen.findByText('OPERACIÓN · north-shop')).toBeInTheDocument();
    await screen.findByRole('option', {name: 'North'});
    expect(screen.getByRole('combobox')).toHaveValue('north-shop');
  });
  it('keeps catalog links hidden without catalog permissions', () => {
    state.owner = false; state.tenant = 'north-shop'; state.allowed = false;
    render(<Private>Contenido</Private>);
    expect(screen.queryByRole('link', {name: 'Comercios'})).not.toBeInTheDocument();
    expect(screen.queryByRole('link', {name: 'Comercios globales'})).not.toBeInTheDocument();
  });
});
