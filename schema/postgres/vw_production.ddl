create view vw_production as
select
    readings.reading_datetime                             as reading_datetime
  , readings.ac_power                                     as watts
from
    "public"."readings" as readings