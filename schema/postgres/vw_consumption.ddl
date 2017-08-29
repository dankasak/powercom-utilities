create view vw_consumption as
select
    *
from
    public.powercom_readings
where
    reading_type = 'Consumption'