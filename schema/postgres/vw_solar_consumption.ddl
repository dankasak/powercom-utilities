create view vw_solar_consumption as
select
    *
from
    public.powercom_readings
where
    reading_type = 'Solar Consumed'