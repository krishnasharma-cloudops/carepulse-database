CREATE TABLE departments (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 name text UNIQUE NOT NULL, beds integer NOT NULL CHECK(beds>0),
 occupied integer NOT NULL CHECK(occupied>=0 AND occupied<=beds),
 waiting integer NOT NULL CHECK(waiting>=0)
);
CREATE TABLE appointments (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 booking_code text UNIQUE NOT NULL,
 department_id integer NOT NULL REFERENCES departments(id),
 scheduled_at timestamptz NOT NULL,
 status text NOT NULL CHECK(status IN ('Scheduled','Completed','Cancelled'))
);
CREATE TABLE equipment (
 id integer GENERATED ALWAYS AS IDENTITY PRIMARY KEY,
 asset_code text UNIQUE NOT NULL, name text NOT NULL,
 department_id integer NOT NULL REFERENCES departments(id),
 status text NOT NULL CHECK(status IN ('Available','In use','Maintenance'))
);
CREATE INDEX appointments_schedule_idx ON appointments(scheduled_at,department_id);
CREATE INDEX equipment_department_idx ON equipment(department_id);
