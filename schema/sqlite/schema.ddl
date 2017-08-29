CREATE TABLE simple_config (
    ID integer primary key autoincrement
  , key    text
  , value  text
);
CREATE TABLE readings (
    id                       integer primary key autoincrement
  , serial_number            number
  , reading_datetime         datetime
  , heat_sink_temperature    number
  , panel_1_voltage          number
  , panel_1_dc_voltage       number
  , working_hours            number
  , operating_mode           text
  , tmp_f_value              number
  , pv_1_f_value             number
  , gfci_f_value             number
  , fault_code_high          number
  , fault_code_low           number
  , line_current             number
  , line_voltage             number
  , ac_frequency             number
  , ac_power                 number
  , zac                      number
  , accumulated_energy       number
  , gfci_f_value_volts       number
  , gfci_f_value_hz          number
  , gz_f_value_ohm           number
);
CREATE TABLE daily_summary (
    id                           integer primary key autoincrement
  , reading_date                 date
  , max_heat_sink_temperature    number
  , max_ac_power                 number
  , total_ac_power               number
  , weather_condition            text
  , uploaded                     number
  , upload_status                text
);

