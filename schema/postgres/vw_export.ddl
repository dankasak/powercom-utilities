create view vw_export as
select
    *
from
    public.powercom_readings
where
    reading_type = 'Generation'