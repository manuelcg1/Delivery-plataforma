import { forwardRef, type HTMLAttributes, type LabelHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export const Label = forwardRef<HTMLLabelElement, LabelHTMLAttributes<HTMLLabelElement> & { required?: boolean; secondary?: boolean }>(function Label({ className, required, secondary, children, ...props }, ref) {
  return <label ref={ref} className={cn('ui-label', secondary && 'ui-label--secondary', className)} {...props}>{children}{required && <span className="ui-required" aria-hidden="true">*</span>}</label>;
});
export function FormDescription({ className, ...props }: HTMLAttributes<HTMLParagraphElement>) { return <p className={cn('ui-form-description', className)} {...props} />; }
export function FormMessage({ className, children, ...props }: HTMLAttributes<HTMLParagraphElement>) { return <p className={cn('ui-form-message', className)} role="alert" {...props}>{children}</p>; }
