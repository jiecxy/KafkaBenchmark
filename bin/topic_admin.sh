path_prefix="/home/username/"
kafka_path="${path_prefix}/kafka_2.11-0.10.2.0/"
zookeeper_list="hw167:12181,hw168:12181,hw169:12181"

is_topic_exist() {
    path=$1
	zk_list=$2
    t=$3
	result=`${path}bin/kafka-topics.sh --list --zookeeper ${zk_list} | grep -E "^${t}(\s.*deletion){0,1}$" | awk '{print $1}'`
	if [ x${t} == x${result} ]; then
	    return 0
	fi
	return 1
}

wait_topic_deleted() {
	path=$1
	zk_list=$2
    t=$3
	while true
	do
	    if is_topic_exist ${path} ${zk_list} ${t}; then
            sleep 0.5s
	    else
		    break
	    fi
	done
}

create_topic() {
	topic=$1
	replication_factor=$2
	partitions=$3
	if is_topic_exist ${kafka_path} ${zookeeper_list} ${topic}; then
		${kafka_path}bin/kafka-topics.sh --delete --zookeeper ${zookeeper_list} --topic ${topic}
		wait_topic_deleted ${kafka_path} ${zookeeper_list} ${topic}
	fi
	${kafka_path}bin/kafka-topics.sh --create --zookeeper ${zookeeper_list} --replication-factor ${replication_factor} --partitions ${partitions} --topic ${topic}
	${kafka_path}bin/kafka-topics.sh --describe --zookeeper ${zookeeper_list} --topic ${topic}
	wait
	echo "ok"
}

delete_topic() {
	topic=$1
	${kafka_path}bin/kafka-topics.sh --delete --zookeeper ${zookeeper_list} --topic ${topic}
	wait_topic_deleted ${kafka_path} ${zookeeper_list} ${topic}
	wait
	echo "ok"
}

if [ $# -eq 3 ]; then
	create_topic $1 $2 $3
else
	delete_topic $1
fi

