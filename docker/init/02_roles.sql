-- Rol anónimo para PostgREST
CREATE ROLE trazado_anon NOLOGIN;
GRANT USAGE ON SCHEMA public TO trazado_anon;
GRANT SELECT, INSERT, UPDATE ON ALL TABLES IN SCHEMA public TO trazado_anon;
GRANT USAGE, SELECT ON ALL SEQUENCES IN SCHEMA public TO trazado_anon;
