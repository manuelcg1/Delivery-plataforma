ALTER TABLE notifications
  ADD COLUMN IF NOT EXISTS attempt_count INTEGER NOT NULL DEFAULT 0,
  ADD COLUMN IF NOT EXISTS last_attempt_at TIMESTAMPTZ;

CREATE INDEX IF NOT EXISTS idx_notifications_failed_retry
  ON notifications(last_attempt_at,created_at)
  WHERE status='FAILED';
