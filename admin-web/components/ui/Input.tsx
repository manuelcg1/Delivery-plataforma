import { X, type LucideIcon } from 'lucide-react';
import { forwardRef, type InputHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export interface InputProps extends InputHTMLAttributes<HTMLInputElement> {
  error?: boolean;
  success?: boolean;
  loading?: boolean;
  leftIcon?: LucideIcon;
  rightIcon?: LucideIcon;
  onClear?: () => void;
}

export const Input = forwardRef<HTMLInputElement, InputProps>(function Input(
  { className, error, success, loading, leftIcon: LeftIcon, rightIcon: RightIcon, onClear, disabled, readOnly, ...props }, ref,
) {
  return <div className={cn('ui-input-wrap', error && 'is-error', success && 'is-success', disabled && 'is-disabled', loading && 'is-loading')}>
    {LeftIcon && <LeftIcon className="ui-input-icon ui-input-icon--left" aria-hidden="true" />}
    <input ref={ref} className={cn('ui-input', LeftIcon && 'has-left-icon', (RightIcon || onClear || loading) && 'has-right-icon', className)} aria-invalid={error || undefined} disabled={disabled} readOnly={readOnly} {...props} />
    {loading ? <span className="ui-spinner ui-input-icon--right" aria-hidden="true" /> : onClear ? <button type="button" className="ui-input-clear" onClick={onClear} aria-label="Limpiar campo"><X aria-hidden="true" /></button> : RightIcon ? <RightIcon className="ui-input-icon ui-input-icon--right" aria-hidden="true" /> : null}
  </div>;
});
