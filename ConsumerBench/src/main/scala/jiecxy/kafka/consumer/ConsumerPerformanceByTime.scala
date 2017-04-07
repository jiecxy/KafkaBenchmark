package jiecxy.kafka.consumer


import java.text.SimpleDateFormat
import java.util
import java.util.concurrent.atomic.{AtomicBoolean, AtomicLong}
import java.util.{Collections, Properties, Random}

import org.apache.kafka.clients.consumer.{ConsumerConfig, ConsumerRebalanceListener, KafkaConsumer}
import org.apache.kafka.common.TopicPartition
import org.apache.kafka.common.serialization.ByteArrayDeserializer
import org.apache.kafka.common.utils.Utils
import org.apache.log4j.Logger

import scala.collection.JavaConverters._

/**
 * Performance test for the full zookeeper consumer
 */
object ConsumerPerformanceByTime {
  private val logger = Logger.getLogger(getClass())

  def main(args: Array[String]): Unit = {

    val config = new ConsumerPerfConfig(args)
    logger.info("Starting consumer...")
    val totalMessagesRead = new AtomicLong(0)
    val totalBytesRead = new AtomicLong(0)
    val consumerTimeout = new AtomicBoolean(false)

    if (!config.hideHeader) {
      if (!config.showDetailedStats)
        printf("%-24s %-24s %-20s %-14s %-22s %-14s\n", "# start.time", "end.time", "data.consumed.in.MB", "MB.sec", "data.consumed.in.nMsg", "nMsg.sec")
      else
        printf("%-24s %-20s %-14s %-22s %-14s\n", "# time", "data.consumed.in.MB", "MB.sec", "data.consumed.in.nMsg", "nMsg.sec")
    }

    var startMs, lastConsumeTime, endMs = 0l
    if (!config.useOldConsumer) {

      val consumer = new KafkaConsumer[Array[Byte], Array[Byte]](config.props)
      consumer.subscribe(Collections.singletonList(config.topic))
      val t = consume(consumer, List(config.topic), config.time * 1000, 1000, config, totalMessagesRead, totalBytesRead)
      startMs = t._1
      lastConsumeTime = t._2
      endMs = System.currentTimeMillis()
      consumer.close()
    } else {
      println("Please Use New Consumer")
      System.exit(1)
    }
    val elapsedSecs = (lastConsumeTime - startMs) / 1000.0

//    if (!config.showDetailedStats) {
      val totalMBRead = (totalBytesRead.get * 1.0) / (1024 * 1024)
      println("")
      printf("%-24s %-24s %-20s %-14s %-22s %-14s\n", "# start.time", "end.time", "data.consumed.in.MB", "MB.sec", "data.consumed.in.nMsg", "nMsg.sec")
      println("%-24s %-24s %-20.4f %-14.4f %-22d %-14.4f".format(config.dateFormat.format(startMs), config.dateFormat.format(endMs),
        totalMBRead, totalMBRead / elapsedSecs, totalMessagesRead.get, totalMessagesRead.get / elapsedSecs))
//    }
  }

  def consume(consumer: KafkaConsumer[Array[Byte], Array[Byte]], topics: List[String], runTime: Long, timeout: Long, config: ConsumerPerfConfig, totalMessagesRead: AtomicLong, totalBytesRead: AtomicLong) : (Long, Long) = {
    var bytesRead = 0L
    var messagesRead = 0L
    var lastBytesRead = 0L
    var lastMessagesRead = 0L

    // Wait for group join, metadata fetch, etc
    val joinTimeout = 10000
    val isAssigned = new AtomicBoolean(false)
    consumer.subscribe(topics.asJava, new ConsumerRebalanceListener {
      def onPartitionsAssigned(partitions: util.Collection[TopicPartition]) {
        isAssigned.set(true)
      }
      def onPartitionsRevoked(partitions: util.Collection[TopicPartition]) {
        isAssigned.set(false)
      }})
    val joinStart = System.currentTimeMillis()
    while (!isAssigned.get()) {
      if (System.currentTimeMillis() - joinStart >= joinTimeout) {
        throw new Exception("Timed out waiting for initial group join.")
      }
      consumer.poll(100)
    }
    consumer.seekToBeginning(Collections.emptyList())

    // Now start the benchmark
    val startMs = System.currentTimeMillis
    var lastReportTime = startMs
    var lastConsumedTime = System.currentTimeMillis
    var currentTimeMillis = lastConsumedTime
    //&& currentTimeMillis - lastConsumedTime <= timeout
    while (System.currentTimeMillis - startMs < runTime) {
      val records = consumer.poll(100).asScala
      currentTimeMillis = System.currentTimeMillis
      if (records.nonEmpty)
        lastConsumedTime = currentTimeMillis
      for (record <- records) {
        messagesRead += 1
        if (record.key != null)
          bytesRead += record.key.size
        if (record.value != null)
          bytesRead += record.value.size

        if (currentTimeMillis - lastReportTime >= config.reportingInterval) {
          if (config.showDetailedStats) {
            printProgressMessage(bytesRead, lastBytesRead, messagesRead, lastMessagesRead, lastReportTime, currentTimeMillis, config.dateFormat)
          }
          lastReportTime = currentTimeMillis
          lastMessagesRead = messagesRead
          lastBytesRead = bytesRead
        }
      }
    }

    if (lastMessagesRead > 0) {
      if (config.showDetailedStats) {
        printProgressMessage(bytesRead, lastBytesRead, messagesRead, lastMessagesRead, lastReportTime, lastConsumedTime, config.dateFormat)
      }
    }

    totalMessagesRead.set(messagesRead)
    totalBytesRead.set(bytesRead)

    (startMs, lastConsumedTime)
  }

  def printProgressMessage( bytesRead: Long, lastBytesRead: Long, messagesRead: Long, lastMessagesRead: Long,
    startMs: Long, endMs: Long, dateFormat: SimpleDateFormat) = {
    val elapsedMs: Double = endMs - startMs
    val totalMBRead = (bytesRead * 1.0) / (1024 * 1024)
    val mbRead = ((bytesRead - lastBytesRead) * 1.0) / (1024 * 1024)
    println("%-24s %-20.4f %-14.4f %-22d %-14.4f".format(dateFormat.format(endMs), totalMBRead,
        1000.0 * (mbRead / elapsedMs), messagesRead, ((messagesRead - lastMessagesRead) / elapsedMs) * 1000.0))
  }

  class ConsumerPerfConfig(args: Array[String]) extends PerfConfig(args) {
    val zkConnectOpt = parser.accepts("zookeeper", "REQUIRED (only when using old consumer): The connection string for the zookeeper connection in the form host:port. " +
      "Multiple URLS can be given to allow fail-over. This option is only used with the old consumer.")
      .withRequiredArg
      .describedAs("urls")
      .ofType(classOf[String])
    val bootstrapServersOpt = parser.accepts("broker-list", "REQUIRED (unless old consumer is used): A broker list to use for connecting if using the new consumer.")
      .withRequiredArg()
      .describedAs("host")
      .ofType(classOf[String])
    val topicOpt = parser.accepts("topic", "REQUIRED: The topic to consume from.")
      .withRequiredArg
      .describedAs("topic")
      .ofType(classOf[String])
    val groupIdOpt = parser.accepts("group", "The group id to consume on.")
      .withRequiredArg
      .describedAs("gid")
      .defaultsTo("perf-consumer-" + new Random().nextInt(100000))
      .ofType(classOf[String])
    val fetchSizeOpt = parser.accepts("fetch-size", "The amount of data to fetch in a single request.")
      .withRequiredArg
      .describedAs("size")
      .ofType(classOf[java.lang.Integer])
      .defaultsTo(1024 * 1024)
    val resetBeginningOffsetOpt = parser.accepts("from-latest", "If the consumer does not already have an established " +
      "offset to consume from, start with the latest message present in the log rather than the earliest message.")
    val socketBufferSizeOpt = parser.accepts("socket-buffer-size", "The size of the tcp RECV size.")
      .withRequiredArg
      .describedAs("size")
      .ofType(classOf[java.lang.Integer])
      .defaultsTo(2 * 1024 * 1024)
    val newConsumerOpt = parser.accepts("new-consumer", "Use the new consumer implementation. This is the default.")
    val consumerConfigOpt = parser.accepts("consumer.config", "Consumer config properties file.")
      .withRequiredArg
      .describedAs("config file")
      .ofType(classOf[String])

    val options = parser.parse(args: _*)

    CommandLineUtils.checkRequiredArgs(parser, options, topicOpt, timeOpt)

    val useOldConsumer = options.has(zkConnectOpt)

    val props = if (options.has(consumerConfigOpt))
      Utils.loadProps(options.valueOf(consumerConfigOpt))
    else
      new Properties
    if (!useOldConsumer) {
      CommandLineUtils.checkRequiredArgs(parser, options, bootstrapServersOpt)
      props.put(ConsumerConfig.BOOTSTRAP_SERVERS_CONFIG, options.valueOf(bootstrapServersOpt))
      props.put(ConsumerConfig.GROUP_ID_CONFIG, options.valueOf(groupIdOpt))
      props.put(ConsumerConfig.RECEIVE_BUFFER_CONFIG, options.valueOf(socketBufferSizeOpt).toString)
      props.put(ConsumerConfig.MAX_PARTITION_FETCH_BYTES_CONFIG, options.valueOf(fetchSizeOpt).toString)
      props.put(ConsumerConfig.AUTO_OFFSET_RESET_CONFIG, if (options.has(resetBeginningOffsetOpt)) "latest" else "earliest")
      props.put(ConsumerConfig.KEY_DESERIALIZER_CLASS_CONFIG, classOf[ByteArrayDeserializer])
      props.put(ConsumerConfig.VALUE_DESERIALIZER_CLASS_CONFIG, classOf[ByteArrayDeserializer])
      props.put(ConsumerConfig.CHECK_CRCS_CONFIG, "false")
    }

    val topic = options.valueOf(topicOpt)
    val time = options.valueOf(timeOpt).longValue
    val reportingInterval = options.valueOf(reportingIntervalOpt).intValue
    if (reportingInterval <= 0)
      throw new IllegalArgumentException("Reporting interval must be greater than 0.")
    val showDetailedStats = options.has(showDetailedStatsOpt)
    val dateFormat = new SimpleDateFormat(options.valueOf(dateFormatOpt))
    val hideHeader = options.has(hideHeaderOpt)
  }
}
