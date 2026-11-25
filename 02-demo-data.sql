INSERT INTO departments(name,beds,occupied,waiting) VALUES
 ('Emergency',24,20,9),('General Medicine',40,28,5),('Surgery',30,19,3),('Pediatrics',20,12,4),('Cardiology',18,15,2),('Orthopedics',28,16,3)
 ON CONFLICT(name) DO NOTHING;
INSERT INTO appointments(booking_code,department_id,scheduled_at,status)
SELECT 'DEMO-'||lpad(g::text,3,'0'), d.id, date_trunc('day',now()) + (g+8)*interval '30 minutes',
 CASE WHEN g%5=0 THEN 'Cancelled' WHEN g%3=0 THEN 'Completed' ELSE 'Scheduled' END
FROM generate_series(1,24) g JOIN departments d ON d.id=1+(g-1)%6 ON CONFLICT(booking_code) DO NOTHING;
INSERT INTO equipment(asset_code,name,department_id,status)
SELECT 'ASSET-'||d.id||'-'||g, (ARRAY['Patient monitor','Infusion pump','Portable ultrasound'])[g], d.id,
 CASE WHEN (d.id+g)%7=0 THEN 'Maintenance' WHEN g=2 THEN 'In use' ELSE 'Available' END
FROM departments d CROSS JOIN generate_series(1,3) g ON CONFLICT(asset_code) DO NOTHING;
