ALTER TABLE users DROP CONSTRAINT uq_users_tenant_email;
DROP INDEX idx_users_email;

CREATE UNIQUE INDEX uq_users_tenant_email_ci ON users(tenant_id, lower(email));
