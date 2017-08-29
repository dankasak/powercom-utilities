create table powercom_readings
(
    id                      serial       not null
  , reading_datetime        timestamp    not null
  , reading_type            varchar(40)  not null
  , watts                   integer      not null

  , primary key             ( id )
)