path_prefix="/home/username/"
benchmark_path=${path_prefix}"kafkabench/"
kafka_path="${path_prefix}/kafka_2.11-0.10.2.0/"
# 所有测试记录
log="${benchmark_path}process_log.log"
# 每个测试的测试次数
readonly test_count=1

if [ ! -d ${benchmark_path} ]
then
    mkdir ${benchmark_path}
    touch ${log}
fi

print() {
    echo `date "+%Y%m%d %H:%M:%S"`" --- $1 --- $2" >> $3
}

println() {
    for i in `seq $1`;
    do
        echo -e "" >> ${log}
    done
}



#--------------------------------------------
#     Global Variables:
#
zookeeper_list="hw167:12181,hw168:12181,hw169:12181"
bootstrap_servers="hw160:9092,hw161:9092,hw170:9092"
borker_list="hw160:9092,hw161:9092,hw170:9092"
master="hw167"
worker1="hw168"
worker2="hw169"
worker3="hw167"
broker1="hw160"
user="zm"
producer_jar_name=${benchmark_path}"ProducerPerformanceByTime.jar"
consumer_jar_name=${benchmark_path}"ConsumerPerformanceByTime.jar"
run_prefix=" exec java -jar "
# 
#--------------------------------------------


if ! ssh ${user}@${worker1} test -d ${benchmark_path}; then
    ssh ${user}@${worker1} mkdir ${benchmark_path}
fi
scp ${producer_jar_name}  ${consumer_jar_name} ${user}@${worker1}:${benchmark_path} >> ${log}
if ! ssh ${user}@${worker2} test -d ${benchmark_path}; then
    ssh ${user}@${worker2} mkdir ${benchmark_path}
fi
scp ${producer_jar_name}  ${consumer_jar_name} ${user}@${worker2}:${benchmark_path} >> ${log}



topic="test"


create_topic() {
		_name=$1
		_replication_factor=$2
		_partitions=$3
		${path_prefix}topic_cmd.sh ${_name} ${_replication_factor} ${_partitions} >> ${log}
		wait
}

delete_topic() {
		_name=$1
		${path_prefix}topic_cmd.sh ${_name} >> ${log}
		wait
}



rum_time=600
#--------------------------------------------
#     测试12:
#         DiskNum
#
# 
# 
#
#
DiskNum=12
replication_factor=1
record_size=1024
throughput=-1
partitions=12
buffer_memory=1048576
batch_size=8192
acks="1"
#
user="zm"
#
test_seq="Test_12"
test_name="${test_seq}_DiskNum"
#--------------------------------------------
println 3
print ${test_name} "Starting test with ${test_count} times"  ${log}
if [ ! -d "${benchmark_path}${test_name}" ]
then
	mkdir "${benchmark_path}${test_name}"
fi

println 1
# 测试次数
for i in `seq ${test_count}`;
do
	if [ ! -d "${benchmark_path}${test_name}/${i}" ]
	then
		mkdir "${benchmark_path}${test_name}/${i}"
	fi
		
	print ${test_name}"_"${i} "Starting test with DiskNum = ${DiskNum} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/DiskNum-${DiskNum}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		# worker1
		print ${test_name}"_"${i} "${worker1} Consuming ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/DiskNum-${DiskNum}_${worker1}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait
		
		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with DiskNum = ${DiskNum} ..."  ${log}
	
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait




exit


# iostat -x 1 > io.log

# DiskNum=3

for _disk_name in sdc sdd sde sdf;do
	grep "${_disk_name}" io.log > ${_disk_name}".log"
done

#grep sdd io.log > sdd.log
#grep sde io.log > sde.log
#grep sdf io.log > sdf.log

graph () {
gnuplot << EOF
	set terminal pngcairo
	set xlabel "time"
	set grid
	set key outside horizontal bottom center
	set key reverse
	set key Left
	set title "Disk: r & w - ${_disk_name}"
	set ylabel "MB/s"
	set output "./IO_ReadAndWrite_${_disk_name}.png"
	plot "./${_disk_name}.log" u 6 w lp pt 0 ps 0.5 t "read", "./${_disk_name}.log" u 7 w lp pt 0 ps 0.5 lc 3 t "write"

	set title "Disk: avgqu-sz - ${_disk_name}"
	set ylabel "queue length"
	set output "./IO_Avgqu-sz_${_disk_name}.png"
	plot "./${_disk_name}.log" u 9 w lp pt 0 ps 0.3 t "avgqu-sz"

	set title "Disk: await & svctm - ${_disk_name}"
	set ylabel "ms"
	set output "./IO_Await_Svctm_${_disk_name}.png"
	plot "./${_disk_name}.log" u 10 w lp pt 0 ps 0.3 t "await","./${_disk_name}.log" u 11 w lp pt 0 ps 0.3 lc 3 t "svctm"
	
	EOF
}

for _disk_name in sdc sdd sde sdf;do
	graph
done