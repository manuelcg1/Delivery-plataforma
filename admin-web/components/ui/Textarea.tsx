import { forwardRef, type TextareaHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export interface TextareaProps extends TextareaHTMLAttributes<HTMLTextAreaElement> { error?: boolean; success?: boolean }
export const Textarea = forwardRef<HTMLTextAreaElement, TextareaProps>(function Textarea({ className, error, success, ...props }, ref) {
  return <textarea ref={ref} className={cn('ui-textarea', error && 'is-error', success && 'is-success', className)} aria-invalid={error || undefined} {...props} />;
});
