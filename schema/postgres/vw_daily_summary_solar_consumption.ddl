create view vw_daily_summary_solar_consumption as
select
    reading_datetime::DATE        as reading_date
  , sum(watts)                    as watt_hours
from
    vw_solar_consumption
group by
    reading_datetime::DATE
order by
    reading_datetime::DATE