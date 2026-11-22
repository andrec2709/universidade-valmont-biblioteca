DO $$
DECLARE
	db_name text;
BEGIN
	FOR db_name IN SELECT datname FROM pg_database WHERE datistemplate = false LOOP
		EXECUTE format('REVOKE CONNECT ON DATABASE %I FROM PUBLIC;', db_name);
	END LOOP;
END $$;