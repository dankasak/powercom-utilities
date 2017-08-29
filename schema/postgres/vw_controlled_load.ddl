create view vw_controlled_load as
select
    *
from
    public.powercom_readings
where
    reading_type = 'Controlled Load Consumption'