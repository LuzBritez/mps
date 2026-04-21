-- Datos de prueba — Red eléctrica de Formosa (ficticios)

INSERT INTO distribuidores (nombre) VALUES ('Distribuidor Norte'), ('Distribuidor Sur');

INSERT INTO lmt (nombre, nivel_tension, distribuidor_id, geometria) VALUES
('LMT-001', '13.2kV', 1, ST_GeomFromText('LINESTRING(-59.98 -24.89, -59.97 -24.88, -59.96 -24.87)', 4326)),
('LMT-002', '33kV',   1, ST_GeomFromText('LINESTRING(-59.95 -24.90, -59.94 -24.89, -59.93 -24.88)', 4326)),
('LMT-003', '13.2kV', 2, ST_GeomFromText('LINESTRING(-60.00 -24.91, -59.99 -24.90, -59.98 -24.89)', 4326));

INSERT INTO setas (nombre, tipo, lmt_id, geometria) VALUES
('Seta-001', 'transformador',  1, ST_GeomFromText('POINT(-59.975 -24.885)', 4326)),
('Seta-002', 'subestacion',    2, ST_GeomFromText('POINT(-59.940 -24.890)', 4326)),
('Seta-003', 'transformador',  3, ST_GeomFromText('POINT(-59.990 -24.900)', 4326));

INSERT INTO barrios (nombre, geometria) VALUES
('Centro', ST_GeomFromText('POLYGON((-59.99 -24.88, -59.96 -24.88, -59.96 -24.91, -59.99 -24.91, -59.99 -24.88))', 4326)),
('Norte',  ST_GeomFromText('POLYGON((-59.99 -24.85, -59.96 -24.85, -59.96 -24.88, -59.99 -24.88, -59.99 -24.85))', 4326));

INSERT INTO nodos (nombre, lmt_id, geometria, orden) VALUES
('Nodo-001', 1, ST_GeomFromText('POINT(-59.980 -24.890)', 4326), 1),
('Nodo-002', 1, ST_GeomFromText('POINT(-59.975 -24.885)', 4326), 2),
('Nodo-003', 1, ST_GeomFromText('POINT(-59.965 -24.875)', 4326), 3);
