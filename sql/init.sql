
CREATE TABLE visits (
    id SERIAL PRIMARY KEY,
    ip inet NOT NULL,
    ts timestamptz NOT NULL DEFAULT now()
);
