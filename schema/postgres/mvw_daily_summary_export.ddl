create materialized view mvw_daily_summary_export as
select
    reading_datetime::DATE        as reading_date
  , sum(watts)                    as watt_hours
from
    vw_export
group by
    reading_datetime::DATE
order by
    reading_datetime::DATE