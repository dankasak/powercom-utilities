create materialized view mvw_daily_summary_peak as
select
    reading_datetime::DATE        as reading_date
  , sum(watts)                    as watt_hours
from
    vw_consumption
where
    reading_datetime::TIME between '15:00:00' and '20:59:59'
group by
    reading_datetime::DATE
order by
    reading_datetime::DATE