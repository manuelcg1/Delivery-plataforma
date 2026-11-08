// @vitest-environment jsdom
import '@testing-library/jest-dom/vitest';
import {cleanup,render,screen} from '@testing-library/react';
import {afterEach,describe,expect,it} from 'vitest';
import CustomerContact from './customer-contact';

afterEach(cleanup);
describe('contacto del cliente',()=>{
  it('permite llamar al móvil peruano registrado',()=>{
    render(<CustomerContact phone="+51912345678"/>);
    expect(screen.getByRole('link',{name:'Llamar al cliente: +51912345678'})).toHaveAttribute('href','tel:+51912345678');
  });
  it.each([null,undefined,''])('identifica una cuenta sin teléfono (%s)',phone=>{
    render(<CustomerContact phone={phone}/>);
    expect(screen.getByText('No registrado')).toBeInTheDocument();
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });
  it.each(['javascript:alert(1)','+12025550123','+51812345678'])('no crea enlaces para un teléfono no válido: %s',phone=>{
    render(<CustomerContact phone={phone}/>);
    expect(screen.queryByRole('link')).not.toBeInTheDocument();
  });
});
