ALTER TABLE notifications ADD COLUMN claim_token UUID;
ALTER TABLE notifications ADD COLUMN claim_until TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN next_attempt_at TIMESTAMPTZ;
ALTER TABLE notifications ADD COLUMN last_error VARCHAR(200);

CREATE INDEX idx_notifications_arrival_outbox
  ON notifications(next_attempt_at,created_at)
  WHERE event_type='COURIER_ARRIVED' AND status IN ('PENDING','FAILED');
