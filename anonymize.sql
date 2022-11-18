DROP FUNCTION IF EXISTS `reg_replace`;
DELIMITER $$
CREATE FUNCTION `reg_replace`(pattern VARCHAR(1000), replacement VARCHAR(1000), original VARCHAR(1000))
    RETURNS VARCHAR(1000)
    DETERMINISTIC
BEGIN
    DECLARE prev VARCHAR(1000);
    DECLARE next VARCHAR(1000);
    DECLARE sub VARCHAR(1000);
    DECLARE replaced VARCHAR(1000);
    DECLARE start_counter INT;
    DECLARE end_counter INT;
    DECLARE max_length INT;
    SET max_length = CHAR_LENGTH(original);
    SET replaced = original;
    IF original REGEXP pattern THEN
        SET end_counter = 1;
        end_loop: LOOP
            IF end_counter > max_length THEN
                LEAVE end_loop;
            END IF;
            SET sub = SUBSTRING(original, 1, end_counter);
            IF sub REGEXP pattern THEN
                SET next = SUBSTRING(original, end_counter, max_length - end_counter + 1);
                SET start_counter = end_counter - 1;
                start_loop: LOOP
                    IF start_counter < 1 THEN
                        LEAVE start_loop;
                    END IF;
                    SET sub = SUBSTRING(original, start_counter, end_counter - start_counter);
                    IF sub REGEXP pattern THEN
                        SET prev = SUBSTRING(original, 1, start_counter - 1);
                        SET replaced = CONCAT(prev, replacement, next);
                        LEAVE end_loop;
                    END IF;
                    SET start_counter = start_counter - 1;
                END LOOP;
            END IF;
            SET end_counter = end_counter + 1;
        END LOOP;
    END IF;
    RETURN replaced;
END$$
DELIMITER ;

DELIMITER $$
CREATE PROCEDURE anonymizeMagento(databaseName VARCHAR(255))
BEGIN
    -- ### customer data ###
    -- e-mail
    UPDATE customer_entity SET email = CONCAT('kunde-', entity_id, '@localhost.local');
    -- all names
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'customer_entity' AND COLUMN_NAME = 'firstname') THEN
        UPDATE customer_entity SET firstname = CONCAT('Vorname-', entity_id);
        UPDATE customer_entity SET middlename = CONCAT('Zweiter-Vorname-', entity_id) WHERE middlename IS NOT NULL AND middlename <> '';
        UPDATE customer_entity SET lastname = CONCAT('Nachname-', entity_id);
        UPDATE customer_entity SET dob = '1990-04-08' WHERE dob IS NOT NULL;
    END IF;
    UPDATE customer_entity_varchar SET value = CONCAT('Vorname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'firstname' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) AND NOT(value IS NULL or value = '');
    UPDATE customer_entity_varchar SET value = CONCAT('Zweiter-Vorname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'middlename' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) AND NOT(value IS NULL or value = '');
    UPDATE customer_entity_varchar SET value = CONCAT('Nachname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'lastname' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = CONCAT('Vorname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'firstname' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = CONCAT('Zweiter-Vorname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'middlename' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = CONCAT('Nachname-', entity_id) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'lastname' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    -- dob
    UPDATE customer_entity_datetime SET value = '1990-04-08' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'dob' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer'));
    -- gender
    UPDATE customer_entity_int SET value = (SELECT option_id FROM eav_attribute_option WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) ORDER BY sort_order LIMIT 1) WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer'));
    -- address
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'customer_address_entity' AND COLUMN_NAME = 'firstname') THEN
        UPDATE customer_address_entity SET city = 'Jena';
        UPDATE customer_address_entity SET company = 'Tofex UG' WHERE company IS NOT NULL AND company <> '';
        UPDATE customer_address_entity SET fax = '03641/55987-59' WHERE fax IS NOT NULL AND fax <> '';
        UPDATE customer_address_entity SET firstname = CONCAT('Vorname-', entity_id);
        UPDATE customer_address_entity SET lastname = CONCAT('Nachname-', entity_id);
        UPDATE customer_address_entity SET middlename = CONCAT('Zweiter-Vorname-', entity_id) WHERE middlename IS NOT NULL AND middlename <> '';
        UPDATE customer_address_entity SET postcode = '07743';
        UPDATE customer_address_entity SET region = 'THU' WHERE region IS NOT NULL AND region <> '';
        UPDATE customer_address_entity SET street = 'Unterm Markt 2';
        UPDATE customer_address_entity SET telephone = '03641/55987-40' WHERE telephone IS NOT NULL AND telephone <> '';
        UPDATE customer_address_entity SET vat_id = 'DE1234567890' WHERE vat_id IS NOT NULL AND vat_id <> '';
    END IF;
    UPDATE customer_address_entity_text SET value = 'Unterm Markt 2' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'street' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = '07743' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'postcode' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = 'Jena' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'city' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = 'THU' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'region' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = 'DE' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'country_id' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer_address')) AND NOT(value IS NULL or value = '');
    -- telephone, fax
    UPDATE customer_address_entity_varchar SET value = '03641/55987-40' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'telephone' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) AND NOT(value IS NULL or value = '');
    UPDATE customer_address_entity_varchar SET value = '03641/55987-59' WHERE attribute_id in (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'fax' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) AND NOT(value IS NULL or value = '');
    -- flat --
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'customer_entity' AND COLUMN_NAME = 'firstname') THEN
        UPDATE customer_entity SET email = CONCAT('kunde-', entity_id, '@localhost.local');
        UPDATE customer_entity SET firstname = CONCAT('Vorname-', entity_id);
        UPDATE customer_entity SET middlename = CONCAT('Zweiter-Vorname-', entity_id) WHERE middlename IS NOT NULL AND middlename <> '';
        UPDATE customer_entity SET lastname = CONCAT('Nachname-', entity_id);
        UPDATE customer_entity SET dob = '1990-04-08' WHERE dob IS NOT NULL;
        UPDATE customer_entity SET taxvat = 'DE273791342' WHERE taxvat IS NOT NULL;
    END IF;
    -- grid --
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'customer_grid_flat') THEN
        UPDATE customer_grid_flat SET name = CONCAT('Vorname-', entity_id, ' ', 'Nachname-', entity_id);
        UPDATE customer_grid_flat SET email = CONCAT('kunde-', entity_id, '@localhost.local');
        UPDATE customer_grid_flat SET dob = '1990-04-08' WHERE dob IS NOT NULL;
        UPDATE customer_grid_flat SET taxvat = 'DE273791342' WHERE taxvat IS NOT NULL;
        UPDATE customer_grid_flat SET shipping_full = 'Unterm Markt 2 Jena Thüringen 07743' WHERE shipping_full IS NOT NULL AND shipping_full <> '';
        UPDATE customer_grid_flat SET billing_full = 'Unterm Markt 2 Jena Thüringen 07743' WHERE billing_full IS NOT NULL AND billing_full <> '';
        UPDATE customer_grid_flat SET billing_firstname = CONCAT('Vorname-', entity_id) WHERE billing_firstname IS NOT NULL AND billing_firstname <> '';
        UPDATE customer_grid_flat SET billing_lastname = CONCAT('Nachname-', entity_id) WHERE billing_lastname IS NOT NULL AND billing_lastname <> '';
        UPDATE customer_grid_flat SET billing_telephone = '03641/55987-40' WHERE billing_telephone IS NOT NULL AND billing_telephone <> '';
        UPDATE customer_grid_flat SET billing_postcode = '07743' WHERE billing_postcode IS NOT NULL AND billing_postcode <> '';
        UPDATE customer_grid_flat SET billing_country_id = 'DE' WHERE billing_country_id IS NOT NULL AND billing_country_id <> '';
        UPDATE customer_grid_flat SET billing_region = 'Thüringen' WHERE billing_region IS NOT NULL AND billing_region <> '';
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'customer_grid_flat' AND COLUMN_NAME = 'billing_region_id') THEN
            UPDATE customer_grid_flat SET billing_region_id = 94 WHERE billing_region_id IS NOT NULL;
        END IF;
        UPDATE customer_grid_flat SET billing_street = 'Unterm Markt 2' WHERE billing_street IS NOT NULL AND billing_street <> '';
        UPDATE customer_grid_flat SET billing_city = 'Jena' WHERE billing_city IS NOT NULL AND billing_city <> '';
        UPDATE customer_grid_flat SET billing_fax = '03641/55987-59' WHERE billing_fax IS NOT NULL AND billing_fax <> '';
        UPDATE customer_grid_flat SET billing_company = 'Tofex UG' WHERE billing_company IS NOT NULL AND billing_company <> '';
    END IF;

    -- ### newsletter data ###
    -- e-mail
    UPDATE newsletter_subscriber SET subscriber_email = CONCAT('gast-', subscriber_id, '@localhost.local') WHERE customer_id = 0;
    UPDATE newsletter_subscriber SET subscriber_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE customer_id > 0;

    -- ### review data ###
    UPDATE review_detail SET nickname = CONCAT('Reviewer-', review_id) WHERE nickname <> 'Anonym';

    -- ### quote data ###
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_flat_quote') THEN
        -- e-mail
        UPDATE sales_flat_quote SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT customer_email IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_email = CONCAT('gast-', entity_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote_address SET email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT email IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote_address SET email = CONCAT('gast-', quote_id, '@localhost.local') WHERE NOT email IS NULL AND customer_id IS NULL;
        -- names
        UPDATE sales_flat_quote SET customer_firstname = CONCAT('Vorname-', customer_id) WHERE NOT customer_firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT customer_middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_lastname = CONCAT('Nachname-', customer_id) WHERE NOT customer_lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote SET customer_lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote_address SET firstname = CONCAT('Vorname-', customer_id) WHERE NOT firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote_address SET firstname = CONCAT('Gast-Vorname-', address_id) WHERE NOT firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote_address SET middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote_address SET middlename = CONCAT('Gast-Zweiter-Vorname-', address_id) WHERE NOT middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote_address SET lastname = CONCAT('Nachname-', customer_id) WHERE NOT lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_quote_address SET lastname = CONCAT('Gast-Nachname-', address_id) WHERE NOT lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_quote_payment JOIN sales_flat_quote ON sales_flat_quote.entity_id = sales_flat_quote_payment.quote_id SET cc_owner = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND NOT sales_flat_quote.customer_id IS NULL;
        UPDATE sales_flat_quote_payment JOIN sales_flat_quote ON sales_flat_quote.entity_id = sales_flat_quote_payment.quote_id SET cc_owner = CONCAT('Gast-Vorname-', quote_id, ' Gast-Nachname-', quote_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND sales_flat_quote.customer_id IS NULL;
        -- dob
        UPDATE sales_flat_quote SET customer_dob = '1990-04-08' WHERE NOT customer_dob IS NULL;
        -- gender
        UPDATE sales_flat_quote SET customer_gender = (SELECT option_id FROM eav_attribute_option WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) ORDER BY sort_order LIMIT 1) WHERE NOT customer_gender IS NULL;
        -- address
        UPDATE sales_flat_quote_address SET street = 'Unterm Markt 2' WHERE NOT street IS NULL;
        UPDATE sales_flat_quote_address SET postcode = '07743' WHERE NOT postcode IS NULL;
        UPDATE sales_flat_quote_address SET city = 'Jena' WHERE NOT city IS NULL;
        UPDATE sales_flat_quote_address SET region = 'THU' WHERE NOT region IS NULL;
        UPDATE sales_flat_quote_address SET country_id = 'DE' WHERE NOT country_id IS NULL;
        UPDATE sales_flat_quote_address SET company = 'Tofex UG' WHERE NOT company IS NULL;
        -- telephone, fax
        UPDATE sales_flat_quote_address SET telephone = '03641/55987-40' WHERE NOT telephone IS NULL;
        UPDATE sales_flat_quote_address SET fax = '03641/55987-59' WHERE NOT fax IS NULL;
        -- ip
        UPDATE sales_flat_quote SET remote_ip = '127.0.0.1';
    ELSE
        -- e-mail
        UPDATE quote SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT customer_email IS NULL AND NOT customer_id IS NULL;
        UPDATE quote SET customer_email = CONCAT('gast-', entity_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NULL;
        UPDATE quote_address SET email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT email IS NULL AND NOT customer_id IS NULL;
        UPDATE quote_address SET email = CONCAT('gast-', quote_id, '@localhost.local') WHERE NOT email IS NULL AND customer_id IS NULL;
        -- names
        UPDATE quote SET customer_firstname = CONCAT('Vorname-', customer_id) WHERE NOT customer_firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE quote SET customer_firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NULL;
        UPDATE quote SET customer_middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT customer_middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE quote SET customer_middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NULL;
        UPDATE quote SET customer_lastname = CONCAT('Nachname-', customer_id) WHERE NOT customer_lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE quote SET customer_lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NULL;
        UPDATE quote_address SET firstname = CONCAT('Vorname-', customer_id) WHERE NOT firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE quote_address SET firstname = CONCAT('Gast-Vorname-', address_id) WHERE NOT firstname IS NULL AND customer_id IS NULL;
        UPDATE quote_address SET middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE quote_address SET middlename = CONCAT('Gast-Zweiter-Vorname-', address_id) WHERE NOT middlename IS NULL AND customer_id IS NULL;
        UPDATE quote_address SET lastname = CONCAT('Nachname-', customer_id) WHERE NOT lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE quote_address SET lastname = CONCAT('Gast-Nachname-', address_id) WHERE NOT lastname IS NULL AND customer_id IS NULL;
        UPDATE quote_payment JOIN quote ON quote.entity_id = quote_payment.quote_id SET cc_owner = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND NOT quote.customer_id IS NULL;
        UPDATE quote_payment JOIN quote ON quote.entity_id = quote_payment.quote_id SET cc_owner = CONCAT('Gast-Vorname-', quote_id, ' Gast-Nachname-', quote_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND quote.customer_id IS NULL;
        -- dob
        UPDATE quote SET customer_dob = '1990-04-08' WHERE NOT customer_dob IS NULL;
        -- gender
        UPDATE quote SET customer_gender = (SELECT option_id FROM eav_attribute_option WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) ORDER BY sort_order LIMIT 1) WHERE NOT customer_gender IS NULL;
        -- address
        UPDATE quote_address SET street = 'Unterm Markt 2' WHERE NOT street IS NULL;
        UPDATE quote_address SET postcode = '07743' WHERE NOT postcode IS NULL;
        UPDATE quote_address SET city = 'Jena' WHERE NOT city IS NULL;
        UPDATE quote_address SET region = 'THU' WHERE NOT region IS NULL;
        UPDATE quote_address SET country_id = 'DE' WHERE NOT country_id IS NULL;
        UPDATE quote_address SET company = 'Tofex UG' WHERE NOT company IS NULL;
        -- telephone, fax
        UPDATE quote_address SET telephone = '03641/55987-40' WHERE NOT telephone IS NULL;
        UPDATE quote_address SET fax = '03641/55987-59' WHERE NOT fax IS NULL;
        -- ip
        UPDATE quote SET remote_ip = '127.0.0.1';
    END IF;

    -- ### order data ###
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_flat_order') THEN
        -- e-mail
        UPDATE sales_flat_order SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_flat_order SET customer_email = CONCAT('gast-', entity_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order_address SET email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT email IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_order_address SET email = CONCAT('gast-', parent_id, '@localhost.local') WHERE NOT email IS NULL AND customer_id IS NULL;
        -- names
        UPDATE sales_flat_creditmemo_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_creditmemo_grid.order_id SET billing_name = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_creditmemo_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_creditmemo_grid.order_id SET billing_name = CONCAT('Gast-Vorname-', order_id, ' Gast-Nachname-', order_id) WHERE sales_flat_order.customer_id IS NULL;
        UPDATE sales_flat_invoice_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_invoice_grid.order_id SET billing_name = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_invoice_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_invoice_grid.order_id SET billing_name = CONCAT('Gast-Vorname-', order_id, ' Gast-Nachname-', order_id) WHERE sales_flat_order.customer_id IS NULL;
        UPDATE sales_flat_order SET customer_firstname = CONCAT('Vorname-', customer_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_flat_order SET customer_firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order SET customer_middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_flat_order SET customer_middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order SET customer_lastname = CONCAT('Nachname-', customer_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_flat_order SET customer_lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order_address SET firstname = CONCAT('Vorname-', customer_id) WHERE NOT firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_order_address SET firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order_address SET middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_order_address SET middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order_address SET lastname = CONCAT('Nachname-', customer_id) WHERE NOT lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_flat_order_address SET lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_flat_order_grid JOIN sales_flat_order ON sales_flat_order.increment_id = sales_flat_order_grid.increment_id SET billing_name = CONCAT('Vorname-', sales_flat_order.customer_id, ' Nachname-', sales_flat_order.customer_id) WHERE sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_order_grid JOIN sales_flat_order ON sales_flat_order.increment_id = sales_flat_order_grid.increment_id SET billing_name = CONCAT('Gast-Vorname-', sales_flat_order.entity_id, ' Gast-Nachname-', sales_flat_order.entity_id) WHERE sales_flat_order.customer_id IS NULL;
        UPDATE sales_flat_order_grid JOIN sales_flat_order ON sales_flat_order.increment_id = sales_flat_order_grid.increment_id SET shipping_name = CONCAT('Vorname-', sales_flat_order.customer_id, ' Nachname-', sales_flat_order.customer_id) WHERE sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_order_grid JOIN sales_flat_order ON sales_flat_order.increment_id = sales_flat_order_grid.increment_id SET shipping_name = CONCAT('Gast-Vorname-', sales_flat_order.entity_id, ' Gast-Nachname-', sales_flat_order.entity_id) WHERE sales_flat_order.customer_id IS NULL;
        UPDATE sales_flat_order_payment JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_order_payment.parent_id SET cc_owner = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_order_payment JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_order_payment.parent_id SET cc_owner = CONCAT('Gast-Vorname-', parent_id, ' Gast-Nachname-', parent_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND sales_flat_order.customer_id IS NULL;
        UPDATE sales_flat_shipment_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_shipment_grid.order_id SET shipping_name = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE sales_flat_order.customer_id IS NOT NULL;
        UPDATE sales_flat_shipment_grid JOIN sales_flat_order ON sales_flat_order.entity_id = sales_flat_shipment_grid.order_id SET shipping_name = CONCAT('Gast-Vorname-', order_id, ' Gast-Nachname-', order_id) WHERE sales_flat_order.customer_id IS NULL;
        -- dob
        UPDATE sales_flat_order SET customer_dob = '1990-04-08' WHERE NOT customer_dob IS NULL;
        -- gender
        UPDATE sales_flat_order SET customer_gender = (SELECT option_id FROM eav_attribute_option WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) ORDER BY sort_order LIMIT 1) WHERE NOT customer_gender IS NULL;
        -- address
        UPDATE sales_flat_order_address SET street = 'Unterm Markt 2' WHERE NOT street IS NULL;
        UPDATE sales_flat_order_address SET postcode = '07743' WHERE NOT postcode IS NULL;
        UPDATE sales_flat_order_address SET city = 'Jena' WHERE NOT city IS NULL;
        UPDATE sales_flat_order_address SET region = 'THU' WHERE NOT region IS NULL;
        UPDATE sales_flat_order_address SET country_id = 'DE' WHERE NOT country_id IS NULL;
        UPDATE sales_flat_order_address SET company = 'Tofex UG' WHERE NOT company IS NULL;
        -- telephone, fax
        UPDATE sales_flat_order_address SET telephone = '03641/55987-40' WHERE NOT telephone IS NULL;
        UPDATE sales_flat_order_address SET fax = '03641/55987-59' WHERE NOT fax IS NULL;
        -- ip
        UPDATE sales_flat_order SET remote_ip = '127.0.0.1';
        -- tracking
        UPDATE sales_flat_shipment_track SET track_number = '1234567890';
    ELSE
        -- e-mail
        UPDATE sales_order SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_order SET customer_email = CONCAT('gast-', entity_id, '@localhost.local') WHERE NOT customer_email IS NULL AND customer_id IS NULL;
        UPDATE sales_order_address SET email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE NOT email IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_order_address SET email = CONCAT('gast-', parent_id, '@localhost.local') WHERE NOT email IS NULL AND customer_id IS NULL;
        -- names
        UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET billing_name = CONCAT('Vorname-', customer_id, ' Nachname-', customer_id) WHERE sales_order.customer_id IS NOT NULL;
        UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET billing_name = CONCAT('Gast-Vorname-', sales_creditmemo_grid.order_id, ' Gast-Nachname-', sales_creditmemo_grid.order_id) WHERE sales_order.customer_id IS NULL;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_creditmemo_grid' AND COLUMN_NAME = 'customer_name') THEN
            UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET customer_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET customer_name = CONCAT('Gast-Vorname-', sales_creditmemo_grid.order_id, ' Gast-Nachname-', sales_creditmemo_grid.order_id) WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_creditmemo_grid' AND COLUMN_NAME = 'customer_email') THEN
            UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET sales_creditmemo_grid.customer_email = CONCAT('kunde-', sales_order.customer_id, '@localhost.local') WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_creditmemo_grid JOIN sales_order ON sales_order.entity_id = sales_creditmemo_grid.order_id SET sales_creditmemo_grid.customer_email = CONCAT('gast-', sales_creditmemo_grid.order_id, '@localhost.local') WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_creditmemo_grid' AND COLUMN_NAME = 'billing_address') THEN
            UPDATE sales_creditmemo_grid SET billing_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_creditmemo_grid' AND COLUMN_NAME = 'shipping_address') THEN
            UPDATE sales_creditmemo_grid SET shipping_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET billing_name = CONCAT('Vorname-', customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
        UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET billing_name = CONCAT('Gast-Vorname-', sales_invoice_grid.order_id, ' Gast-Nachname-', sales_invoice_grid.order_id) WHERE sales_order.customer_id IS NULL;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_invoice_grid' AND COLUMN_NAME = 'customer_name') THEN
            UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET customer_name = CONCAT('Vorname-', customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET customer_name = CONCAT('Gast-Vorname-', sales_invoice_grid.order_id, ' Gast-Nachname-', sales_invoice_grid.order_id) WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_invoice_grid' AND COLUMN_NAME = 'customer_email') THEN
            UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET sales_invoice_grid.customer_email = CONCAT('kunde-', sales_order.customer_id, '@localhost.local') WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_invoice_grid JOIN sales_order ON sales_order.entity_id = sales_invoice_grid.order_id SET sales_invoice_grid.customer_email = CONCAT('gast-', sales_invoice_grid.order_id, '@localhost.local') WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_invoice_grid' AND COLUMN_NAME = 'billing_address') THEN
            UPDATE sales_invoice_grid SET billing_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_invoice_grid' AND COLUMN_NAME = 'shipping_address') THEN
            UPDATE sales_invoice_grid SET shipping_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        UPDATE sales_order SET customer_firstname = CONCAT('Vorname-', customer_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_order SET customer_firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT customer_firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_order SET customer_middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_order SET customer_middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT customer_middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_order SET customer_lastname = CONCAT('Nachname-', customer_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NOT NULL;
        UPDATE sales_order SET customer_lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT customer_lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_order_address SET firstname = CONCAT('Vorname-', customer_id) WHERE NOT firstname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_order_address SET firstname = CONCAT('Gast-Vorname-', entity_id) WHERE NOT firstname IS NULL AND customer_id IS NULL;
        UPDATE sales_order_address SET middlename = CONCAT('Zweiter-Vorname-', customer_id) WHERE NOT middlename IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_order_address SET middlename = CONCAT('Gast-Zweiter-Vorname-', entity_id) WHERE NOT middlename IS NULL AND customer_id IS NULL;
        UPDATE sales_order_address SET lastname = CONCAT('Nachname-', customer_id) WHERE NOT lastname IS NULL AND NOT customer_id IS NULL;
        UPDATE sales_order_address SET lastname = CONCAT('Gast-Nachname-', entity_id) WHERE NOT lastname IS NULL AND customer_id IS NULL;
        UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET billing_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
        UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET billing_name = CONCAT('Gast-Vorname-', sales_order.entity_id, ' Gast-Nachname-', sales_order.entity_id) WHERE sales_order.customer_id IS NULL;
        UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET shipping_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
        UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET shipping_name = CONCAT('Gast-Vorname-', sales_order.entity_id, ' Gast-Nachname-', sales_order.entity_id) WHERE sales_order.customer_id IS NULL;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_grid' AND COLUMN_NAME = 'customer_name') THEN
            UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET customer_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET customer_name = CONCAT('Gast-Vorname-', sales_order.entity_id, ' Gast-Nachname-', sales_order.entity_id) WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_grid' AND COLUMN_NAME = 'customer_email') THEN
            UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET sales_order_grid.customer_email = CONCAT('kunde-', sales_order.customer_id, '@localhost.local') WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_order_grid JOIN sales_order ON sales_order.increment_id = sales_order_grid.increment_id SET sales_order_grid.customer_email = CONCAT('gast-', sales_order.entity_id, '@localhost.local') WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_grid' AND COLUMN_NAME = 'billing_address') THEN
            UPDATE sales_order_grid SET billing_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_grid' AND COLUMN_NAME = 'shipping_address') THEN
            UPDATE sales_order_grid SET shipping_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        UPDATE sales_order_payment JOIN sales_order ON sales_order.entity_id = sales_order_payment.parent_id SET cc_owner = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND sales_order.customer_id IS NOT NULL;
        UPDATE sales_order_payment JOIN sales_order ON sales_order.entity_id = sales_order_payment.parent_id SET cc_owner = CONCAT('Gast-Vorname-', parent_id, ' Gast-Nachname-', parent_id) WHERE NOT(cc_owner IS NULL OR cc_owner = '') AND sales_order.customer_id IS NULL;
        UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET shipping_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
        UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET shipping_name = CONCAT('Gast-Vorname-', sales_shipment_grid.order_id, ' Gast-Nachname-', sales_shipment_grid.order_id) WHERE sales_order.customer_id IS NULL;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_shipment_grid' AND COLUMN_NAME = 'billing_name') THEN
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET billing_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET billing_name = CONCAT('Gast-Vorname-', sales_shipment_grid.order_id, ' Gast-Nachname-', sales_shipment_grid.order_id) WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_shipment_grid' AND COLUMN_NAME = 'customer_name') THEN
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET customer_name = CONCAT('Vorname-', sales_order.customer_id, ' Nachname-', sales_order.customer_id) WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET customer_name = CONCAT('Gast-Vorname-', sales_shipment_grid.order_id, ' Gast-Nachname-', sales_shipment_grid.order_id) WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_shipment_grid' AND COLUMN_NAME = 'customer_email') THEN
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET sales_shipment_grid.customer_email = CONCAT('kunde-', sales_order.customer_id, '@localhost.local') WHERE sales_order.customer_id IS NOT NULL;
            UPDATE sales_shipment_grid JOIN sales_order ON sales_order.entity_id = sales_shipment_grid.order_id SET sales_shipment_grid.customer_email = CONCAT('gast-', sales_shipment_grid.order_id, '@localhost.local') WHERE sales_order.customer_id IS NULL;
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_shipment_grid' AND COLUMN_NAME = 'billing_address') THEN
            UPDATE sales_shipment_grid SET billing_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.COLUMNS WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_shipment_grid' AND COLUMN_NAME = 'shipping_address') THEN
            UPDATE sales_shipment_grid SET shipping_address = 'Unterm Markt 2 07743 Jena';
        END IF;
        -- dob
        UPDATE sales_order SET customer_dob = '1990-04-08' WHERE NOT customer_dob IS NULL;
        -- gender
        UPDATE sales_order SET customer_gender = (SELECT option_id FROM eav_attribute_option WHERE attribute_id = (SELECT attribute_id FROM eav_attribute WHERE attribute_code = 'gender' AND entity_type_id IN (SELECT entity_type_id FROM eav_entity_type WHERE entity_type_code = 'customer')) ORDER BY sort_order LIMIT 1) WHERE NOT customer_gender IS NULL;
        -- address
        UPDATE sales_order_address SET street = 'Unterm Markt 2' WHERE NOT street IS NULL;
        UPDATE sales_order_address SET postcode = '07743' WHERE NOT postcode IS NULL;
        UPDATE sales_order_address SET city = 'Jena' WHERE NOT city IS NULL;
        UPDATE sales_order_address SET region = 'THU' WHERE NOT region IS NULL;
        UPDATE sales_order_address SET country_id = 'DE' WHERE NOT country_id IS NULL;
        UPDATE sales_order_address SET company = 'Tofex UG' WHERE NOT company IS NULL;
        -- telephone, fax
        UPDATE sales_order_address SET telephone = '03641/55987-40' WHERE NOT telephone IS NULL;
        UPDATE sales_order_address SET fax = '03641/55987-59' WHERE NOT fax IS NULL;
        -- ip
        UPDATE sales_order SET remote_ip = '127.0.0.1';
        -- tracking
        UPDATE sales_shipment_track SET track_number = '1234567890';
    END IF;
    -- amazon
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'm2epro_amazon_order') THEN
        UPDATE m2epro_amazon_order SET buyer_name = CONCAT('Vorname-', order_id, ' Nachname-', order_id);
        UPDATE m2epro_amazon_order SET buyer_email = CONCAT('amazon-', order_id, '@localhost.local');
        UPDATE m2epro_amazon_order SET shipping_address = '{"county":"","country_code":"DE","state":"","city":"Jena","postal_code":"07743","recipient_name":"Tofex UG","phone":"03641 5598740","company":"","street":["Unterm Markt 2"]}';
    END IF;
    -- ebay
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'm2epro_ebay_order') THEN
        UPDATE m2epro_ebay_order SET buyer_name = CONCAT('Vorname-', order_id, ' Nachname-', order_id);
        UPDATE m2epro_ebay_order SET buyer_email = CONCAT('ebay-', order_id, '@localhost.local');
        UPDATE m2epro_ebay_order SET buyer_user_id = CONCAT('ebay-', order_id);
        UPDATE m2epro_ebay_order SET shipping_details = '{"address":{"country_code":"DE","country_name":"Deutschland","city":"Jena","state":"","postal_code":"07743","phone":"Invalid Request","street":["Unterm Markt 2"],"company":""},"service":"DHL Paket","price":5.95,"date":null,"global_shipping_details":[],"click_and_collect_details":[],"in_store_pickup_details":[],"cash_on_delivery_cost":0}';
    END IF;

    -- ### payment data ###
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_payment') THEN
        -- Paypal
        UPDATE quote_payment
        SET additional_information = reg_replace('"paypal_payer_email":".*"', '"paypal_payer_email":"payment@localhost.local"', additional_information)
        WHERE payment_id IN (
            SELECT payment_id FROM (
                SELECT payment_id
                FROM quote_payment
                WHERE additional_information LIKE '%paypal_payer_email%' AND additional_information NOT LIKE '%payment@localhost.local%'
            ) AS temp
        );
        -- Creditcard
        UPDATE quote_payment
        SET additional_information = reg_replace('"firstname":".*"', '"firstname":"Vorname"', additional_information)
        WHERE payment_id IN (
            SELECT payment_id FROM (
                SELECT payment_id
                FROM quote_payment
                WHERE additional_information LIKE '%firstname%' AND additional_information NOT LIKE '%Vorname%'
            ) AS temp
        );
        UPDATE quote_payment
        SET additional_information = reg_replace('"lastname":".*"', '"lastname":"Nachname"', additional_information)
        WHERE payment_id IN (
            SELECT payment_id FROM (
                SELECT payment_id
                FROM quote_payment
                WHERE additional_information LIKE '%lastname%' AND additional_information NOT LIKE '%Nachname%'
            ) AS temp
        );
    END IF;
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_flat_order_payment') THEN
        UPDATE sales_flat_order_payment
        SET additional_information = reg_replace('s:18:"paypal_payer_email";s:[0-9]+:".*"', 's:18:"paypal_payer_email";s:23:"payment@localhost.local"', additional_information)
        WHERE entity_id IN (
            SELECT entity_id FROM (
                SELECT entity_id
                FROM sales_flat_order_payment
                WHERE additional_information LIKE '%paypal_payer_email%' AND additional_information NOT LIKE '%payment@localhost.local%'
            ) AS temp
        );
    END IF;
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'sales_order_payment') THEN
        -- Paypal
        UPDATE sales_order_payment
        SET additional_information = reg_replace('"paypal_payer_email":".*"', '"paypal_payer_email":"payment@localhost.local"', additional_information)
        WHERE entity_id IN (
            SELECT entity_id FROM (
                SELECT entity_id
                FROM sales_order_payment
                WHERE additional_information LIKE '%paypal_payer_email%' AND additional_information NOT LIKE '%payment@localhost.local%'
            ) AS temp
        );
        -- Creditcard
        UPDATE sales_order_payment
        SET additional_information = reg_replace('"firstname":".*"', '"firstname":"Vorname"', additional_information)
        WHERE entity_id IN (
            SELECT entity_id FROM (
                SELECT entity_id
                FROM sales_order_payment
                WHERE additional_information LIKE '%firstname%' AND additional_information NOT LIKE '%Vorname%'
            ) AS temp
        );
        UPDATE sales_order_payment
        SET additional_information = reg_replace('"lastname":".*"', '"lastname":"Nachname"', additional_information)
        WHERE entity_id IN (
            SELECT entity_id FROM (
                SELECT entity_id
                FROM sales_order_payment
                WHERE additional_information LIKE '%lastname%' AND additional_information NOT LIKE '%Nachname%'
            ) AS temp
        );
    END IF;

    -- Stripe
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'cryozonic_stripesubscriptions_customers') THEN
        UPDATE cryozonic_stripesubscriptions_customers SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE customer_id > 0;
        UPDATE cryozonic_stripesubscriptions_customers SET customer_email = CONCAT('gast-', id, '@localhost.local') WHERE customer_id > 0;
    END IF;

    -- Payone
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'payone_protocol_api') THEN
        UPDATE payone_protocol_api SET raw_request = 'a:0:{}';
        UPDATE payone_protocol_api SET raw_response = 'a:0:{}';
    END IF;
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'payone_protocol_transactionstatus') THEN
        UPDATE payone_protocol_transactionstatus SET email = CONCAT('kunde-', customerid, '@localhost.local') WHERE customerid IS NOT NULL AND customerid <> '';
        UPDATE payone_protocol_transactionstatus SET email = CONCAT('gast-', order_id, '@localhost.local') WHERE customerid IS NULL OR customerid = '';
        UPDATE payone_protocol_transactionstatus SET firstname = CONCAT('Vorname-', customerid) WHERE customerid IS NOT NULL AND customerid <> '';
        UPDATE payone_protocol_transactionstatus SET firstname = CONCAT('Gast-Vorname-', order_id) WHERE customerid IS NULL OR customerid = '';
        UPDATE payone_protocol_transactionstatus SET lastname = CONCAT('Nachname-', customerid) WHERE customerid IS NOT NULL AND customerid <> '';
        UPDATE payone_protocol_transactionstatus SET lastname = CONCAT('Gast-Nachname-', order_id) WHERE customerid IS NULL OR customerid = '';
        UPDATE payone_protocol_transactionstatus SET company = 'Tofex UG' WHERE company IS NOT NULL AND company <> '';
        UPDATE payone_protocol_transactionstatus SET street = 'Unterm Markt 2';
        UPDATE payone_protocol_transactionstatus SET zip = '07743';
        UPDATE payone_protocol_transactionstatus SET city = 'Jena';
        UPDATE payone_protocol_transactionstatus SET country = 'DE';
        UPDATE payone_protocol_transactionstatus SET shipping_firstname = CONCAT('Vorname-', customerid) WHERE customerid IS NOT NULL AND customerid <> '';
        UPDATE payone_protocol_transactionstatus SET shipping_firstname = CONCAT('Gast-Vorname-', order_id) WHERE customerid IS NULL OR customerid = '';
        UPDATE payone_protocol_transactionstatus SET shipping_lastname = CONCAT('Nachname-', customerid) WHERE customerid IS NOT NULL AND customerid <> '';
        UPDATE payone_protocol_transactionstatus SET shipping_lastname = CONCAT('Gast-Nachname-', order_id) WHERE customerid IS NULL OR customerid = '';
        UPDATE payone_protocol_transactionstatus SET shipping_company = 'Tofex UG' WHERE shipping_company IS NOT NULL AND company <> '';
        UPDATE payone_protocol_transactionstatus SET shipping_street = 'Unterm Markt 2';
        UPDATE payone_protocol_transactionstatus SET shipping_zip = '07743';
        UPDATE payone_protocol_transactionstatus SET shipping_city = 'Jena';
        UPDATE payone_protocol_transactionstatus SET shipping_country = 'DE';
        UPDATE payone_protocol_transactionstatus SET raw_status = 'a:0:{}';
    END IF;

    -- ### Spielemax ###
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'spielemax_customer_email_history') THEN
        UPDATE spielemax_customer_email_history SET email = CONCAT('kunde-', customer_id, '-', entity_id, '@localhost.local');
    END IF;
    IF EXISTS(SELECT 1 FROM INFORMATION_SCHEMA.TABLES WHERE TABLE_SCHEMA = databaseName AND TABLE_NAME = 'spielemax_giftcard') THEN
        UPDATE spielemax_giftcard SET customer_email = CONCAT('kunde-', customer_id, '@localhost.local') WHERE customer_id > 0;
        UPDATE spielemax_giftcard SET customer_email = CONCAT('gast-', giftcard_id, '@localhost.local') WHERE customer_id IS NULL;
    END IF;
END $$
DELIMITER ;
