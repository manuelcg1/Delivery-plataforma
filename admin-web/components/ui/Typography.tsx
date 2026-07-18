import { type HTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

type Props = HTMLAttributes<HTMLElement>;
export function PageTitle({ className, ...props }: Props) { return <h1 className={cn('ui-page-title', className)} {...props} />; }
export function SectionTitle({ className, ...props }: Props) { return <h2 className={cn('ui-section-title', className)} {...props} />; }
export function Typography({ as: Tag = 'p', variant = 'body', className, ...props }: Props & { as?: 'p'|'span'|'div'; variant?: 'display'|'heading'|'body'|'caption'|'label' }) { return <Tag className={cn('ui-typography', `ui-typography--${variant}`, className)} {...props} />; }
