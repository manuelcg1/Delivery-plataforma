import { LoaderCircle } from 'lucide-react';
import { type HTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export function Spinner({ className, ...props }: HTMLAttributes<SVGSVGElement>) { return <LoaderCircle className={cn('ui-spinner', className)} aria-label="Cargando" role="status" {...props} />; }
export function Loader({ label = 'Cargando…' }: { label?: string }) { return <div className="ui-loader" role="status"><Spinner /><span>{label}</span></div>; }
export function Divider({ className, ...props }: HTMLAttributes<HTMLHRElement>) { return <hr className={cn('ui-divider', className)} {...props} />; }
export function Container({ className, ...props }: HTMLAttributes<HTMLDivElement>) { return <div className={cn('ui-container', className)} {...props} />; }
