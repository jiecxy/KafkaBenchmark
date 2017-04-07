/**
 * Licensed to the Apache Software Foundation (ASF) under one or more contributor license agreements. See the NOTICE
 * file distributed with this work for additional information regarding copyright ownership. The ASF licenses this file
 * to You under the Apache License, Version 2.0 (the "License"); you may not use this file except in compliance with the
 * License. You may obtain a copy of the License at
 *
 * http://www.apache.org/licenses/LICENSE-2.0
 *
 * Unless required by applicable law or agreed to in writing, software distributed under the License is distributed on
 * an "AS IS" BASIS, WITHOUT WARRANTIES OR CONDITIONS OF ANY KIND, either express or implied. See the License for the
 * specific language governing permissions and limitations under the License.
 */
package jiecxy.kafka.producer;

import net.sourceforge.argparse4j.ArgumentParsers;
import net.sourceforge.argparse4j.inf.ArgumentParser;
import net.sourceforge.argparse4j.inf.ArgumentParserException;
import net.sourceforge.argparse4j.inf.MutuallyExclusiveGroup;
import net.sourceforge.argparse4j.inf.Namespace;
import org.HdrHistogram.Histogram;
import org.HdrHistogram.Recorder;
import org.apache.kafka.clients.producer.*;
import org.apache.kafka.common.utils.Utils;

import java.nio.charset.StandardCharsets;
import java.nio.file.Files;
import java.nio.file.Path;
import java.nio.file.Paths;
import java.text.SimpleDateFormat;
import java.util.*;
import java.util.concurrent.TimeUnit;

import static net.sourceforge.argparse4j.impl.Arguments.store;

public class ProducerPerformanceByTime {

    public static void main(String[] args) throws Exception {
        ArgumentParser parser = argParser();

        try {
            Namespace res = parser.parseArgs(args);

            /* parse args */
            String topicName = res.getString("topic");
//            long numRecords = res.getLong("numRecords");
            long runTime = res.getLong("runTime") * 1000;
            Integer recordSize = res.getInt("recordSize");
            int throughput = res.getInt("throughput");
            List<String> producerProps = res.getList("producerConfig");
            String producerConfig = res.getString("producerConfigFile");
            String payloadFilePath = res.getString("payloadFile");

            // since default value gets printed with the help text, we are escaping \n there and replacing it with correct value here.
            String payloadDelimiter = res.getString("payloadDelimiter").equals("\\n") ? "\n" : res.getString("payloadDelimiter");

            if (producerProps == null && producerConfig == null) {
                throw new ArgumentParserException("Either --producer-props or --producer.config must be specified.", parser);
            }

            List<byte[]> payloadByteList = new ArrayList<>();
            if (payloadFilePath != null) {
                Path path = Paths.get(payloadFilePath);
                System.out.println("Reading payloads from: " + path.toAbsolutePath());
                if (Files.notExists(path) || Files.size(path) == 0)  {
                    throw new  IllegalArgumentException("File does not exist or empty file provided.");
                }

                String[] payloadList = new String(Files.readAllBytes(path), "UTF-8").split(payloadDelimiter);

                System.out.println("Number of messages read: " + payloadList.length);

                for (String payload : payloadList) {
                    payloadByteList.add(payload.getBytes(StandardCharsets.UTF_8));
                }
            }

            Properties props = new Properties();
            if (producerConfig != null) {
                props.putAll(Utils.loadProps(producerConfig));
            }
            if (producerProps != null)
                for (String prop : producerProps) {
                    String[] pieces = prop.split("=");
                    if (pieces.length != 2)
                        throw new IllegalArgumentException("Invalid property: " + prop);
                    props.put(pieces[0], pieces[1]);
                }

            props.put(ProducerConfig.KEY_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.ByteArraySerializer");
            props.put(ProducerConfig.VALUE_SERIALIZER_CLASS_CONFIG, "org.apache.kafka.common.serialization.ByteArraySerializer");
            KafkaProducer<byte[], byte[]> producer = new KafkaProducer<byte[], byte[]>(props);

            /* setup perf test */
            byte[] payload = null;
            Random random = new Random(0);
            if (recordSize != null) {
                payload = new byte[recordSize];
                for (int i = 0; i < payload.length; ++i)
                    payload[i] = (byte) (random.nextInt(26) + 65);
            }
            ProducerRecord<byte[], byte[]> record;

            long startMs = System.currentTimeMillis();
            System.out.println("# Start time: " +  longTimeToString(startMs));
            Stats stats = new Stats(startMs, 5000);

            int i = 0; // records
            ThroughputThrottler throttler = new ThroughputThrottler(throughput, startMs);
            while (System.currentTimeMillis() - startMs < runTime) {
                if (payloadFilePath != null) {
                    payload = payloadByteList.get(random.nextInt(payloadByteList.size()));
                }
                record = new ProducerRecord<>(topicName, payload);

                long sendStartMs = System.currentTimeMillis();
                Callback cb = stats.nextCompletion(sendStartMs, payload.length, stats);
                producer.send(record, cb);

                if (throttler.shouldThrottle(i, sendStartMs)) {
                    throttler.throttle();
                }
                i++;
            }

            /* print final results */
            producer.close();
            stats.printTotal();
        } catch (ArgumentParserException e) {
            if (args.length == 0) {
                parser.printHelp();
                System.exit(0);
            } else {
                parser.handleError(e);
                System.exit(1);
            }
        }

    }

    private static String longTimeToString(long time) {
        return new SimpleDateFormat("yyyy-MM-dd HH:mm:ss.SSS").format(new Date(time));
    }

    /** Get the command-line argument parser. */
    private static ArgumentParser argParser() {
        ArgumentParser parser = ArgumentParsers
                .newArgumentParser("producer-performance")
                .defaultHelp(true)
                .description("This tool is used to verify the producer performance.");

        MutuallyExclusiveGroup payloadOptions = parser
                .addMutuallyExclusiveGroup()
                .required(true)
                .description("either --record-size or --payload-file must be specified but not both.");

        parser.addArgument("--topic")
                .action(store())
                .required(true)
                .type(String.class)
                .metavar("TOPIC")
                .help("produce messages to this topic");

        parser.addArgument("--run-time")
                .action(store())
                .required(true)
                .type(Long.class)
                .metavar("RUN-TIME")
                .dest("runTime")
                .help("testTime");

        payloadOptions.addArgument("--record-size")
                .action(store())
                .required(false)
                .type(Integer.class)
                .metavar("RECORD-SIZE")
                .dest("recordSize")
                .help("message size in bytes. Note that you must provide exactly one of --record-size or --payload-file.");

        payloadOptions.addArgument("--payload-file")
                .action(store())
                .required(false)
                .type(String.class)
                .metavar("PAYLOAD-FILE")
                .dest("payloadFile")
                .help("file to read the message payloads from. This works only for UTF-8 encoded text files. " +
                        "Payloads will be read from this file and a payload will be randomly selected when sending messages. " +
                        "Note that you must provide exactly one of --record-size or --payload-file.");

        parser.addArgument("--payload-delimiter")
                .action(store())
                .required(false)
                .type(String.class)
                .metavar("PAYLOAD-DELIMITER")
                .dest("payloadDelimiter")
                .setDefault("\\n")
                .help("provides delimiter to be used when --payload-file is provided. " +
                        "Defaults to new line. " +
                        "Note that this parameter will be ignored if --payload-file is not provided.");

        parser.addArgument("--throughput")
                .action(store())
                .required(true)
                .type(Integer.class)
                .metavar("THROUGHPUT")
                .help("throttle maximum message throughput to *approximately* THROUGHPUT messages/sec");

        parser.addArgument("--producer-props")
                 .nargs("+")
                 .required(false)
                 .metavar("PROP-NAME=PROP-VALUE")
                 .type(String.class)
                 .dest("producerConfig")
                 .help("kafka producer related configuration properties like bootstrap.servers,client.id etc. " +
                         "These configs take precedence over those passed via --producer.config.");

        parser.addArgument("--producer.config")
                .action(store())
                .required(false)
                .type(String.class)
                .metavar("CONFIG-FILE")
                .dest("producerConfigFile")
                .help("producer config properties file.");

        return parser;
    }

    private static class Stats {

        private long start;
        private long totalCount;
        private long totalBytes;

        private long windowStart;
        private long windowCount;
        private long windowBytes;

        private long reportingInterval;

        private Recorder windowLatencyRecorder;
        private Recorder totalLatencyRecorder;

        public Stats(long start, int reportingInterval) {
            this.start = start;
            this.windowStart = this.start;
            this.windowCount = 0;
            this.windowBytes = 0;
            this.totalCount = 0;
            this.totalBytes = 0;
            this.reportingInterval = reportingInterval;

            windowLatencyRecorder = new Recorder(TimeUnit.SECONDS.toMillis(120000), 5);
            totalLatencyRecorder = new Recorder(TimeUnit.SECONDS.toMillis(120000), 5);

            System.out.printf("%-24s %-14s %-14s %-14s %-14s %-14s\n", "# Window Time", "Records Sent", "Records/Sec", "MB/sec", "Avg Latency(ms)", "Max Latency");
        }

        public void record(int latency, int bytes, long time) {

            this.windowCount++;
            this.totalCount++;
            this.windowBytes += bytes;
            this.totalBytes += bytes;

            windowLatencyRecorder.recordValue(latency);
            totalLatencyRecorder.recordValue(latency);


            /* maybe report the recent perf */
            if (time - windowStart >= reportingInterval) {
                printWindow();
                newWindow();
            }
        }

        public Callback nextCompletion(long start, int bytes, Stats stats) {
            Callback cb = new PerfCallback(start, bytes, stats);
            return cb;
        }

        public void printWindow() {
            long now = System.currentTimeMillis();
            long ellapsed = now - windowStart;
            double recsPerSec = 1000.0 * windowCount / (double) ellapsed;
            double mbPerSec = 1000.0 * this.windowBytes / (double) ellapsed / (1024.0 * 1024.0);
            Histogram reportHist = windowLatencyRecorder.getIntervalHistogram();
            // %d records sent, %.1f records/sec (%.2f MB/sec), %.1f ms avg latency, %.1f max latency
            System.out.println(String.format("%-24s %-14d %-14.1f %-14.2f %-14.1f %-14d",
                              longTimeToString(now),
                              windowCount,
                              recsPerSec,
                              mbPerSec,
                              reportHist.getMean(),
                              reportHist.getMaxValue()));
            reportHist.reset();
        }

        public void newWindow() {
            this.windowStart = System.currentTimeMillis();
            this.windowCount = 0;
            this.windowBytes = 0;
        }

        public void printTotal() {
            if (this.windowCount > 0) {
//                System.out.println("windowCount " + windowCount);
                printWindow();
            }
            long now = System.currentTimeMillis();
            long elapsed = now - start;
            double recsPerSec = 1000.0 * totalCount / (double) elapsed;
            double mbPerSec = 1000.0 * this.totalBytes / (double) elapsed / (1024.0 * 1024.0);
            Histogram reportHist = totalLatencyRecorder.getIntervalHistogram();
            // %d records sent, %f records/sec (%.2f MB/sec), %.2f ms avg latency, %.2f ms max latency, %d ms 50th, %d ms 95th, %d ms 99th, %d ms 99.9th.
            System.out.println("# End time: " +  longTimeToString(now));
            System.out.println(String.format("# %d records sent, %f records/sec ( %.2f MB/sec), %.2f ms avg latency, %d ms max latency, %d ms 50th, %d ms 95th, %d ms 99th, %d ms 99.9th.\n",
                              totalCount,
                              recsPerSec,
                              mbPerSec,
                              reportHist.getMean(),
                              reportHist.getMaxValue(),
                              reportHist.getValueAtPercentile(50),
                              reportHist.getValueAtPercentile(95),
                              reportHist.getValueAtPercentile(99),
                              reportHist.getValueAtPercentile(99.9)));
        }
    }

    private static final class PerfCallback implements Callback {
        private final long start;
        private final int bytes;
        private final Stats stats;

        public PerfCallback(long start, int bytes, Stats stats) {
            this.start = start;
            this.stats = stats;
            this.bytes = bytes;
        }

        public void onCompletion(RecordMetadata metadata, Exception exception) {
            long now = System.currentTimeMillis();
            int latency = (int) (now - start);
            this.stats.record(latency, bytes, now);
            if (exception != null)
                exception.printStackTrace();
        }
    }

}
