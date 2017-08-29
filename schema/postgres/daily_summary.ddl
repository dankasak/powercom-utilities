create table daily_summary
(
    max_ac_power                             numeric(6,4)
  , id                                       integer
  , upload_status                            varchar(50)
  , total_ac_power                           numeric(6,4)
  , max_heat_sink_temperature                numeric(6,4)
  , weather_condition                        varchar(50)
  , uploaded                                 numeric(6,4)
  , reading_date                             timestamp
)