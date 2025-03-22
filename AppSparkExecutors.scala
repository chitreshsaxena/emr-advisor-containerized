package com.amazonaws.emr.spark.models

import com.amazonaws.emr.Config
import com.amazonaws.emr.spark.models.metrics.{AggExecutorMetrics, AggTaskMetrics}
import com.amazonaws.emr.spark.models.timespan.ExecutorTimeSpan
import com.amazonaws.emr.utils.Formatter.{byteStringAsBytes, humanReadableBytes}

import scala.util.Try

class AppSparkExecutors(val executors: Map[String, ExecutorTimeSpan], val appConfigs: AppConfigs) {

  val defaultDriverCores: Int = appConfigs.driverCores
  val defaultDriverMemory: Long = appConfigs.driverMemory
  val defaultExecutorCores: Int = appConfigs.executorCores
  val defaultExecutorMemory: Long = appConfigs.executorMemory

  val executorsLaunched: Int = executors.size - 1
  val executorsMaxRunning: Int = getMaxConcurrent
  val executorsTotalCores: Long = executorsMaxRunning * defaultExecutorCores
  val executorsTotalMemory: Long = executorsMaxRunning * defaultExecutorMemory

  @deprecated
  def getRequiredStoragePerExecutor: Long = {
    val shuffleWrites = getOnlyExecutors.values.map(x =>
      Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.shuffleWriteBytesWritten)).getOrElse(0L)
    ).toList
    val diskSpills = getOnlyExecutors.values.map(x =>
      Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.diskBytesSpilled)).getOrElse(0L)
    ).toList
    (if (shuffleWrites.nonEmpty) shuffleWrites.max else 0L) +
    (if (diskSpills.nonEmpty) diskSpills.max else 0L)
  }

  def isShuffleWriteUniform: Boolean = {
    val totalBytes = getTotalShuffleBytesWritten
    if (executorsMaxRunning == 0) return true
    val toleration = totalBytes * 0.2
    val avgShuffleBytes = totalBytes / executorsMaxRunning
    getOnlyExecutors.forall { e =>
      val writes = Try(e._2.executorTaskMetrics.getMetricSum(AggTaskMetrics.shuffleWriteBytesWritten)).getOrElse(0L)
      (avgShuffleBytes - toleration).toLong <= writes && writes <= (avgShuffleBytes + toleration.toLong)
    }
  }

  def getTotalTasksProcessed: Long = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.count).getOrElse(0L))
    .sum

  def getMaxDiskBytesSpilled: Long = {
    val values = getOnlyExecutors.values.map(x =>
      Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.diskBytesSpilled)).getOrElse(0L)
    )
    if (values.nonEmpty) values.max else 0L
  }

  def getTotalDiskBytesSpilled: Long = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.diskBytesSpilled)).getOrElse(0L))
    .sum

  def getTotalShuffleBytesWritten: Long = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.shuffleWriteBytesWritten)).getOrElse(0L))
    .sum

  def getTotalInputBytesRead: Long = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.inputBytesRead)).getOrElse(0L))
    .sum

  def getTotalOutputBytesWritten: Long = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.getMetricSum(AggTaskMetrics.outputBytesWritten)).getOrElse(0L))
    .sum

  def getMinLaunchTime: Long = {
    val values = getOnlyExecutors.map(x =>
      x._2.startTime - x._2.executorInfo.requestTime.getOrElse(x._2.startTime)
    )
    if (values.nonEmpty) values.min else 0L
  }

  def getMaxLaunchTime: Long = {
    val values = getOnlyExecutors.map(x =>
      x._2.startTime - x._2.executorInfo.requestTime.getOrElse(x._2.startTime)
    )
    if (values.nonEmpty) values.max else 0L
  }


  def getMaxTaskMemoryUsed: Long = {
  val values = getOnlyExecutors.values
    .map(x => Try(x.executorTaskMetrics.getMetricMax(AggTaskMetrics.peakExecutionMemory)).getOrElse(0L))
    .toList
  if (values.nonEmpty) values.max else 0L
}


  def getMaxJvmMemoryUsed: Long = {
    val values = getOnlyExecutors.values
      .map(x => Try(x.executorMetrics.getMetricMax(AggExecutorMetrics.JVMHeapMemory)).getOrElse(0L))
      .toList
    if (values.nonEmpty) values.max else 0L
  }

  def isComputeIntensive: Boolean = getMaxTaskMemoryUsed <= byteStringAsBytes(Config.ComputeIntensiveMaxMemory)

  def isMemoryIntensive: Boolean = getMaxTaskMemoryUsed >= byteStringAsBytes(Config.MemoryIntensiveMinMemory)

  def summary: String =
    s"""The application launched a total of <b>$executorsLaunched</b> Spark executors. Maximum number of concurrent
       |executors was <b>$executorsMaxRunning</b>, for a total of <b>$executorsTotalCores</b> cores and
       |<b>${humanReadableBytes(executorsTotalMemory)}</b> memory.""".stripMargin

  def summaryResources: String =
    s"""Maximum number of concurrent executors was <b>$executorsMaxRunning</b>, for a total of
       |<b>$executorsTotalCores</b> cores and <b>${humanReadableBytes(executorsTotalMemory)}</b> memory.""".stripMargin

  def getOnlyExecutors: Map[String, ExecutorTimeSpan] = executors.filter(!_._1.equalsIgnoreCase("driver"))

  private def getMaxConcurrent: Int = {
      val onlyExecutors = getOnlyExecutors
      if(onlyExecutors.isEmpty){
        return 0
      }
      val sorted = onlyExecutors.values
        .filter(t => t.startTime != 0)
        .flatMap(timeSpan => Seq((timeSpan.startTime, 1L), (timeSpan.endTime, -1L)))
        .toArray
        .sortWith { case ((t1, op1), (t2, op2)) =>
          if (t1 == t2) op1 > op2 else t1 < t2
        }

      var count = 0L
      var maxConcurrent = 0L

      sorted.foreach { case (_, delta) =>
        count += delta
        maxConcurrent = math.max(maxConcurrent, count)
      }

      math.max(maxConcurrent, 1).toInt
    }

}
