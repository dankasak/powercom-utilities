create materialized view mvw_daily_summary_production as
select
    reading_datetime::DATE     as reading_date
  , ( max(accumulated_energy) - min(accumulated_energy) ) * 1000 as watt_hours
from
    readings
group by
    READINGS.reading_datetime::DATE
order by
    READINGS.reading_datetime::DATE desc