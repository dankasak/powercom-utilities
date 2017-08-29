create view vw_daily_summary_production as
select
    reading_datetime::DATE     as reading_date
--  , max(heat_sink_temperature) as max_heatsink_temperature
--  , max(ac_power) as max_ac_power
  , ( max(accumulated_energy) - min(accumulated_energy) ) * 1000 as watt_hours
from
    readings
group by
    READINGS.reading_datetime::DATE
order by
    READINGS.reading_datetime::DATE desc