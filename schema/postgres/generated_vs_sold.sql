select
    powercom_readings.reading_datetime                    as reading_datetime
  , powercom_readings.watts                               as sold_watts
  , aggregated_inverter_stats.generated_watts             as generated_watts
from
            public.powercom_readings                      as powercom_readings
inner join (
	with intervals as (
		select
		    (n||' minutes')::interval       as start_time
		  , ((n+30)|| ' minutes')::interval as end_time
		from generate_series(0, (23*60+30), 30) n
	)
	select
		        '2017-09-16'::DATE + i.start_time as gen_datetime
		      , ( max( readings.accumulated_energy ) - min( readings.accumulated_energy ) ) * 1000 as generated_watts
	from
		        intervals i
	left join   "public"."readings"
		                                    on readings.reading_datetime::TIME >= i.start_time and readings.reading_datetime::TIME < i.end_time
	where readings.reading_datetime::DATE = '2017-09-16'
	group by i.start_time, i.end_time
	order by i.start_time
) as aggregated_inverter_stats
                                on powercom_readings.reading_datetime = aggregated_inverter_stats.gen_datetime
where
    powercom_readings.reading_datetime::DATE = '2017-09-16'
and powercom_readings.reading_type = 'Generation'