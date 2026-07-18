import { LoaderCircle, type LucideIcon } from 'lucide-react';
import { forwardRef, type ButtonHTMLAttributes } from 'react';
import { cn } from '@/lib/cn';

export type ButtonVariant = 'primary' | 'secondary' | 'outline' | 'ghost' | 'danger' | 'success';
export type ButtonSize = 'sm' | 'md' | 'lg' | 'icon';

export interface ButtonProps extends ButtonHTMLAttributes<HTMLButtonElement> {
  variant?: ButtonVariant;
  size?: ButtonSize;
  loading?: boolean;
  leftIcon?: LucideIcon;
  rightIcon?: LucideIcon;
}

export const Button = forwardRef<HTMLButtonElement, ButtonProps>(function Button(
  { className, children, variant = 'primary', size = 'md', loading = false, leftIcon: LeftIcon, rightIcon: RightIcon, disabled, type = 'button', ...props },
  ref,
) {
  return (
    <button ref={ref} type={type} className={cn('ui-button', `ui-button--${variant}`, `ui-button--${size}`, className)} disabled={disabled || loading} aria-busy={loading || undefined} {...props}>
      {loading ? <LoaderCircle className="ui-spinner" aria-hidden="true" /> : LeftIcon ? <LeftIcon aria-hidden="true" /> : null}
      {size !== 'icon' && <span>{children}</span>}
      {!loading && RightIcon ? <RightIcon aria-hidden="true" /> : null}
      {size === 'icon' && <span className="sr-only">{children}</span>}
    </button>
  );
});
