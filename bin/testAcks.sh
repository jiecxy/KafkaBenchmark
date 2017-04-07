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


rum_time=600
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



#--------------------------------------------
#     测试2:   需要更改 min.insync.replicas=2
#         Acks
# 
replication_factor=3
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
partitions=12
#
user="zm"
#
test_seq="Test_2"
test_name="${test_seq}_Acks"
#--------------------------------------------
println 3
print ${test_name} "Starting test with ${test_count} times"  ${log}
if [ -d "${benchmark_path}${test_name}" ]
then
	rm -rf "${benchmark_path}${test_name}"
fi
mkdir "${benchmark_path}${test_name}"
println 1
# 测试次数
for i in `seq ${test_count}`;
do
	mkdir "${benchmark_path}${test_name}/${i}"
	for acks in all; do
	
		print ${test_name}"_"${i} "Starting test with acks = ${acks} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/Acks-${acks}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with acks = ${acks} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait