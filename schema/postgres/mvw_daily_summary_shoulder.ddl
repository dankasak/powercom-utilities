create materialized view mvw_daily_summary_shoulder as
select
    reading_datetime::DATE        as reading_date
  , sum(watts)                    as watt_hours
from
    vw_consumption
where
   reading_datetime::TIME between '21:00:00' and '21:59:59'
or reading_datetime::TIME between '07:00:00' and '14:59:59'
group by
    reading_datetime::DATE
order by
    reading_datetime::DATE