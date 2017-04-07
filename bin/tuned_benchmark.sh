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


rum_time=1200
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
#     测试1:
#         Paritions
# 
replication_factor=1
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
acks="1"
#
user="zm"
#
test_seq="Test_1"
test_name="${test_seq}_Partitions"
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
	for partitions in 3 6 9 12 24 48 96; do
	
		print ${test_name}"_"${i} "Starting test with partitions = ${partitions} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/Partitions-${partitions}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		# worker1
		print ${test_name}"_"${i} "${worker1} Consuming ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/Partitions-${partitions}_${worker1}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait
		
		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with partitions = ${partitions} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait









#--------------------------------------------
#     测试3:
#         ProducerNum
# 
replication_factor=1
partitions=12
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
acks="1"
#
user="zm"
#
test_seq="Test_3"
test_name="${test_seq}_ProducerNum"
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
	for num in 1 2 3; do
	
		print ${test_name}"_"${i} "Starting test with ProducerNum = ${num} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ProducerNum-${num}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		if [ ${num} -gt 1 ]; then
			print ${test_name}"_"${i} "${worker2} Producing ..."  ${log}
			nohup ssh ${user}@${worker2} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ProducerNum-${num}_${worker2}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
			if [ ${num} -gt 2 ]; then
				print ${test_name}"_"${i} "${worker3} Producing ..."  ${log}
				nohup ssh ${user}@${worker3} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ProducerNum-${num}_${worker3}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
			fi
		fi
		wait
		
		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with ProducerNum = ${num} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait










#--------------------------------------------
#     测试10:
#         ProducerAndConsumer
# 
replication_factor=1
partitions=12
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
acks="1"
#
user="zm"
#
test_seq="Test_10"
test_name="${test_seq}_ProducerAndConsumer"
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
	
	print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
	create_topic ${topic} ${replication_factor} ${partitions}


	
	print ${test_name}"_"${i} "Starting test with ProducerAndConsumer ..."  ${log}

	print ${test_name}"_"${i} "Benchmarking ..."  ${log}
	
	print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
	nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ConsumerNum_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &

	# worker1
	print ${test_name}"_"${i} "${worker2} Consuming ..."  ${log}
	nohup ssh ${user}@${worker2} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/ConsumerNum-${num}_${worker2}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
	wait
	
	print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
	delete_topic ${topic}

	print ${test_name}"_"${i} "Finishing test with ProducerAndConsumer ..."  ${log}
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait




#--------------------------------------------
#     测试5:
#         RecordSize
# 
replication_factor=1
#record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
partitions=12
acks="1"
#
user="zm"
#
test_seq="Test_5"
test_name="${test_seq}_RecordSize"
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
	for record_size in 10 100 1000 10000 100000; do
	
		print ${test_name}"_"${i} "Starting test with RecordSize = ${record_size} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/RecordSize-${record_size}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with RecordSize = ${record_size} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait



#--------------------------------------------
#     测试6:
#         BatchSize
# 
replication_factor=1
record_size=1024
throughput=-1
buffer_memory=1048576
#batch_size=8192
partitions=12
acks="1"
#
user="zm"
#
test_seq="Test_6"
test_name="${test_seq}_BatchSize"
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
	for batch_size in 1024 4096 8192 16384 32768; do
	
		print ${test_name}"_"${i} "Starting test with BatchSize = ${batch_size} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/BatchSize-${batch_size}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with BatchSize = ${batch_size} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait


#--------------------------------------------
#     测试7:
#         BufferMemory
# 
replication_factor=1
record_size=1024
throughput=-1
#buffer_memory=1048576
batch_size=8192
partitions=12
acks="1"
#
user="zm"
#
test_seq="Test_7"
test_name="${test_seq}_BufferMemory"
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
	for buffer_memory in 65536 131072 262144 1048576 4194304 16777216 67108864; do
	
		print ${test_name}"_"${i} "Starting test with BufferMemory = ${buffer_memory} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/BufferMemory-${buffer_memory}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with BufferMemory = ${buffer_memory} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait






#--------------------------------------------
#     测试8:
#         Compression
# 
replication_factor=1
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
partitions=12
acks="1"
#
user="zm"
#
test_seq="Test_8"
test_name="${test_seq}_Compression"
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
	for compression in none gzip snappy lz4; do
	
		print ${test_name}"_"${i} "Starting test with Compression = ${compression} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} compression.type=${compression} linger.ms=1 > "${benchmark_path}${test_name}/${i}/Compression-${compression}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with Compression = ${compression} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait




#--------------------------------------------
#     测试9:
#         LingerMs
# 
replication_factor=1
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=32768
partitions=12
acks="1"
#
user="zm"
#
test_seq="Test_9"
test_name="${test_seq}_LingerMs"
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
	for linger_ms in 0 1 5 10 100; do
	
		print ${test_name}"_"${i} "Starting test with LingerMs = ${linger_ms} ..."  ${log}

		print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
		create_topic ${topic} ${replication_factor} ${partitions}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time ${rum_time} --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} linger.ms=${linger_ms} > "${benchmark_path}${test_name}/${i}/LingerMs-${linger_ms}_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		wait

		print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
		delete_topic ${topic}
		print ${test_name}"_"${i} "Finishing test with LingerMs = ${linger_ms} ..."  ${log}
	done
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait






#--------------------------------------------
#     测试4:
#         ConsumerNum
# 
replication_factor=1
partitions=12
record_size=1024
throughput=-1
buffer_memory=1048576
batch_size=8192
acks="1"
#
user="zm"
#
test_seq="Test_4"
test_name="${test_seq}_ConsumerNum"
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
	
	print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
	create_topic ${topic} ${replication_factor} ${partitions}

	print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
	nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time `expr ${rum_time} + 200` --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ConsumerNum_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
	wait
	
	for num in 1 2 3; do
	
		print ${test_name}"_"${i} "Starting test with ConsumerNum = ${num} ..."  ${log}

		print ${test_name}"_"${i} "Benchmarking ..."  ${log}
		
		# worker1
		print ${test_name}"_"${i} "${worker1} Consuming ..."  ${log}
		nohup ssh ${user}@${worker1} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/ConsumerNum-${num}_${worker1}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
		if [ ${num} -gt 1 ]; then
			print ${test_name}"_"${i} "${worker2} Consuming ..."  ${log}
			nohup ssh ${user}@${worker2} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/ConsumerNum-${num}_${worker2}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
			if [ ${num} -gt 2 ]; then
				print ${test_name}"_"${i} "${worker3} Consuming ..."  ${log}
				nohup ssh ${user}@${worker3} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/ConsumerNum-${num}_${worker3}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
			fi
		fi
		wait
		print ${test_name}"_"${i} "Finishing test with ConsumerNum = ${num} ..."  ${log}
	done
	
	print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
	delete_topic ${topic}
	
    print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    println 1
done
print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
wait






# #--------------------------------------------
# #     测试11:     需要监控cpu memory disk net gc
# #         Process
# # 
# replication_factor=1
# partitions=12
# record_size=1024
# throughput=-1
# buffer_memory=1048576
# batch_size=8192
# acks="1"
# #
# user="zm"
# #
# test_seq="Test_11"
# test_name="${test_seq}_Process"
# #--------------------------------------------
# println 3
# print ${test_name} "Starting test with ${test_count} times"  ${log}
# if [ -d "${benchmark_path}${test_name}" ]
# then
	# rm -rf "${benchmark_path}${test_name}"
# fi
# mkdir "${benchmark_path}${test_name}"
# println 1
# # 测试次数
# for i in `seq ${test_count}`;
# do
	# mkdir "${benchmark_path}${test_name}/${i}"
	
	# print ${test_name}"_"${i} "Creating topic ${topic} ${replication_factor} ${partitions} ..."  ${log}
	# create_topic ${topic} ${replication_factor} ${partitions}


	
	# print ${test_name}"_"${i} "Starting test with Process ..."  ${log}

	# print ${test_name}"_"${i} "Benchmarking ..."  ${log}
	
	# print ${test_name}"_"${i} "${worker1} Producing ..."  ${log}
	# nohup ssh ${user}@${worker1} ${run_prefix} ${producer_jar_name} --topic ${topic} --run-time `expr ${rum_time} + 200` --record-size ${record_size} --throughput ${throughput} --producer-props bootstrap.servers=${bootstrap_servers} buffer.memory=${buffer_memory} batch.size=${batch_size} acks=${acks} > "${benchmark_path}${test_name}/${i}/ConsumerNum_${worker1}_Producer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &

	# # worker1
	# print ${test_name}"_"${i} "${worker2} Consuming ..."  ${log}
	# nohup ssh ${user}@${worker2} ${run_prefix} ${consumer_jar_name} --new-consumer --show-detailed-stats --topic ${topic} --time ${rum_time} --broker-list ${borker_list}  > "${benchmark_path}${test_name}/${i}/ConsumerNum-${num}_${worker2}_Consumer_"`date "+%Y%m%d_%H-%M-%S"`".log" 2>&1 &
	# wait
	
	# print ${test_name}"_"${i} "Deleting topic ${topic} ..."  ${log}
	# delete_topic ${topic}

	# print ${test_name}"_"${i} "Finishing test with Process ..."  ${log}
    # print ${test_name}"_"${i} "${test_seq}_${i} Completed."  ${log}
    # println 1
# done
# print ${test_name} "${test_seq} with ${test_count} times completed!"  ${log}
# wait