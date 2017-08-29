create table sources
(
    source         varchar(50)    not null      primary key
  , dataset_sql    varchar(8192)
  , summary_sql    varchar(8102)
  , display_bits   varchar(100)
  , colour         varchar(20)
  , sort_order     integer
  , multiplier     numeric(5,3)   not null      default 1
)