-- Preserve existing codes and allow the additional merchant specializations.
ALTER TABLE merchants DROP CONSTRAINT merchants_merchant_type_check;
ALTER TABLE merchants ADD CONSTRAINT merchants_merchant_type_check
 CHECK (merchant_type IN ('RESTAURANT','GROCERY','PHARMACY','RETAIL','DARK_STORE','OTHER',
                         'POLLERIA','BURGERS','CHIFA','ICE_CREAM','BODEGA','SERVICES'));
