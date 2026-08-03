ALTER TABLE orders
  ADD COLUMN eta_preparation_minutes INTEGER,
  ADD COLUMN eta_assignment_minutes INTEGER,
  ADD COLUMN eta_courier_to_merchant_minutes INTEGER,
  ADD COLUMN eta_merchant_to_customer_minutes INTEGER,
  ADD COLUMN eta_minimum_minutes INTEGER,
  ADD COLUMN eta_maximum_minutes INTEGER;

ALTER TABLE orders ADD CONSTRAINT ck_orders_eta_snapshot CHECK (
  (eta_preparation_minutes IS NULL OR eta_preparation_minutes >= 0) AND
  (eta_assignment_minutes IS NULL OR eta_assignment_minutes >= 0) AND
  (eta_courier_to_merchant_minutes IS NULL OR eta_courier_to_merchant_minutes >= 0) AND
  (eta_merchant_to_customer_minutes IS NULL OR eta_merchant_to_customer_minutes >= 0) AND
  (eta_minimum_minutes IS NULL OR eta_minimum_minutes >= 0) AND
  (eta_maximum_minutes IS NULL OR eta_maximum_minutes >= eta_minimum_minutes)
);
