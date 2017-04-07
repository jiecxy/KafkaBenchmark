package jiecxy.kafka.consumer

import java.util.Properties

import joptsimple.{OptionParser, OptionSet, OptionSpec}

/**
* Helper functions for dealing with command line utilities
*/
object CommandLineUtils  {

  trait ExitPolicy {
    def exit(msg: String): Nothing
  }

  val DEFAULT_EXIT_POLICY = new ExitPolicy {
    override def exit(msg: String): Nothing = sys.exit(1)
  }

  private var exitPolicy = DEFAULT_EXIT_POLICY

 /**
  * Check that all the listed options are present
  */
 def checkRequiredArgs(parser: OptionParser, options: OptionSet, required: OptionSpec[_]*) {
   for(arg <- required) {
     if(!options.has(arg))
       printUsageAndDie(parser, "Missing required argument \"" + arg + "\"")
   }
 }

 /**
  * Check that none of the listed options are present
  */
 def checkInvalidArgs(parser: OptionParser, options: OptionSet, usedOption: OptionSpec[_], invalidOptions: Set[OptionSpec[_]]) {
   if(options.has(usedOption)) {
     for(arg <- invalidOptions) {
       if(options.has(arg))
         printUsageAndDie(parser, "Option \"" + usedOption + "\" can't be used with option\"" + arg + "\"")
     }
   }
 }

 /**
  * Print usage and exit
  */
 def printUsageAndDie(parser: OptionParser, message: String): Nothing = {
   System.err.println(message)
   parser.printHelpOn(System.err)
   exitPolicy.exit(message)
 }

 def exitPolicy(policy: ExitPolicy): Unit = this.exitPolicy = policy

 /**
  * Parse key-value pairs in the form key=value
  */
 def parseKeyValueArgs(args: Iterable[String], acceptMissingValue: Boolean = true): Properties = {
   val splits = args.map(_ split "=").filterNot(_.length == 0)

   val props = new Properties
   for(a <- splits) {
     if (a.length == 1) {
       if (acceptMissingValue) props.put(a(0), "")
       else throw new IllegalArgumentException(s"Missing value for key ${a(0)}")
     }
     else if (a.length == 2) props.put(a(0), a(1))
     else {
       System.err.println("Invalid command line properties: " + args.mkString(" "))
       System.exit(1)
     }
   }
   props
 }
}
