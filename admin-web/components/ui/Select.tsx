import { ChevronDown } from 'lucide-react';
import { forwardRef, type SelectHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export interface SelectProps extends SelectHTMLAttributes<HTMLSelectElement> { error?: boolean; success?: boolean }
export const Select = forwardRef<HTMLSelectElement, SelectProps>(function Select({ className, error, success, children, ...props }, ref) {
  return <div className={cn('ui-select-wrap', error && 'is-error', success && 'is-success')}><select ref={ref} className={cn('ui-select', className)} aria-invalid={error || undefined} {...props}>{children}</select><ChevronDown aria-hidden="true" /></div>;
});
