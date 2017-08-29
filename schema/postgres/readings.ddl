drop table readings;

create table readings
(
    id                                       integer
  , serial_number                            bigint
  , reading_datetime                         timestamp
  , heat_sink_temperature                    numeric(6,2)
  , panel_1_voltage                          numeric(6,2)
  , panel_1_dc_voltage                       numeric(6,2)
  , working_hours                            numeric(6,2)
  , operating_mode                           varchar(50)
  , tmp_f_value                              numeric(6,2)
  , pv_1_f_value                             numeric(6,2)
  , gfci_f_value                             numeric(6,2)
  , fault_code_high                          numeric(6,2)
  , fault_code_low                           numeric(6,2)
  , line_current                             numeric(6,2)
  , line_voltage                             numeric(6,2)
  , ac_frequency                             numeric(6,2)
  , ac_power                                 numeric(6,2)
  , zac                                      numeric(6,2)
  , accumulated_energy                       numeric(6,2)
  , gfci_f_value_volts                       numeric(6,2)
  , gfci_f_value_hz                          numeric(6,2)
  , gz_f_value_ohm                           numeric(6,2)
);
