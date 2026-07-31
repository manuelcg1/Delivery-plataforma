ALTER TABLE courier_location_history
    ADD CONSTRAINT courier_location_history_delivery_required
    CHECK (delivery_id IS NOT NULL) NOT VALID;
