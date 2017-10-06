create or replace view vw_peak as
select
    id
  , reading_datetime
  , reading_type
  , case
        when ( reading_datetime::TIME between '15:00:00' and '20:59:59' )
          then watts
          else 0
    end as watts
from
    public.powercom_readings
where
    reading_type = 'Consumption'
