import QtQuick
import Quickshell
import Quickshell.Io

// CPU / RAM / GPU / VRAM sampler shared by every System Monitor instance, so the
// widget on six monitors costs one poll instead of six. DesktopWidgets.qml
// loads it while the widget is enabled anywhere and exposes it as
// rootRef.sysmonSampler; SysmonWidget only draws what it finds here.
Item {
  id: sampler
  visible: false

  // Visible instances that show the Top line. The per-process scans (the
  // only part that forks) run only while this is above zero, and on their own
  // slower cadence: two processes every topInterval instead of seven every poll.
  property int topViewers: 0
  readonly property bool topActive: topViewers > 0
  readonly property int topInterval: 5 // seconds

  // CPU use over the last poll interval, as a share of all cores (what btop
  // shows); -1 until the second poll, since it needs a /proc/stat delta
  property real cpuPct: -1
  property real lastTotal: -1
  property real lastIdle: -1

  property real memUsedPct: -1
  property real memTotalKb: 0
  property real memAvailKb: 0

  // nvidia-smi; -1 until the first successful read (GPU readouts stay hidden)
  property real gpuPct: -1
  property real gpuMemUsedMb: 0
  property real gpuMemTotalMb: 0
  // VRAM in use as a share of the card's total
  property real gpuMemPct: -1

  // Tiered in-memory history for the chart. Tier t holds up to
  // tierLengths[t] samples spaced baseInterval * decimation^t seconds apart:
  // 15 min at 2s, then 1 h at 20s. Every decimation-th sample of a tier is
  // averaged into the next coarser tier, so memory stays constant. The fine
  // tier is long enough that the linear time scales up to 15 min are drawn
  // entirely at 2s resolution; beyond that a 20s mean is still under 2px
  // wide at the default card size. Each tier array is newest-LAST. Invalid
  // samples are -1 (GPU absent, first CPU poll); the mean ignores them and
  // the chart draws them as gaps.
  readonly property int baseInterval: 2 // seconds, matches pollTimer below
  readonly property var tierLengths: [451, 181]
  readonly property int tierCount: tierLengths.length
  readonly property int decimation: 10
  property var cpuHistory: [[], []]
  property var memHistory: [[], []]
  property var gpuHistory: [[], []]
  property var gpuMemHistory: [[], []]
  // Finer samples waiting to be averaged into tier t+1, one accumulator per
  // tier boundary.
  property var cpuPending: [[]]
  property var memPending: [[]]
  property var gpuPending: [[]]
  property var gpuMemPending: [[]]

  property string topCpuName: ""
  property real topCpuPct: -1
  property string topMemName: ""
  property real topMemPct: -1
  // Process with the highest GPU utilization; empty while no process is using the GPU
  property string topGpuName: ""
  property real topGpuPct: -1
  // utime + stime ticks per process at the previous scan, keyed "pid_starttime"
  // so a reused pid is never mistaken for the old process
  property var procTicks: ({})
  // All-core jiffies at the previous scan. Kept apart from lastTotal: the scan
  // reads /proc/stat at a different instant than the poll does.
  property real topLastTotal: -1

  function isValidSample(v) {
    return typeof v === "number" && isFinite(v) && v >= 0
  }

  function meanValid(list) {
    const ok = list.filter(sampler.isValidSample)
    return ok.length ? ok.reduce((a, b) => a + b, 0) / ok.length : -1
  }

  // Appends one sample to tier 0 and cascades a mean into each coarser tier
  // whose accumulator fills. Returns { tiers, pending } built from NEW arrays:
  // QML `var` properties only emit their change signal on assignment, never
  // on an in-place push, so callers must assign both results back.
  function pushTiered(hist, pending, value) {
    const tiers = hist.slice()
    const pend = pending.slice()
    let v = value
    for (let t = 0; t < sampler.tierCount; t++) {
      const tier = tiers[t].slice(-(sampler.tierLengths[t] - 1))
      tier.push(v)
      tiers[t] = tier
      if (t === sampler.tierCount - 1) break
      const acc = pend[t].slice()
      acc.push(v)
      if (acc.length < sampler.decimation) {
        pend[t] = acc
        break
      }
      pend[t] = []
      v = sampler.meanValid(acc)
    }
    return { tiers: tiers, pending: pend }
  }

  // All-core [total, idle] jiffies from the aggregate "cpu" line of /proc/stat
  function cpuJiffies(line) {
    const parts = line.trim().split(/\s+/)
    if (parts[0] !== "cpu") return null
    const nums = parts.slice(1).map(Number)
    return [nums.reduce((a, b) => a + b, 0), nums[3] + (nums[4] || 0)]
  }

  function sampleMem(text) {
    const total = text.match(/^MemTotal:\s+(\d+)/m)
    const avail = text.match(/^MemAvailable:\s+(\d+)/m)
    if (total) sampler.memTotalKb = Number(total[1])
    if (avail) sampler.memAvailKb = Number(avail[1])
    if (sampler.memTotalKb > 0)
      sampler.memUsedPct = 100 * (1 - sampler.memAvailKb / sampler.memTotalKb)
  }

  function sampleCpu(text) {
    const end = text.indexOf("\n")
    const j = sampler.cpuJiffies(end < 0 ? text : text.slice(0, end))
    if (j) {
      if (sampler.lastTotal >= 0 && j[0] > sampler.lastTotal) {
        const pct = 100 * (1 - (j[1] - sampler.lastIdle) / (j[0] - sampler.lastTotal))
        sampler.cpuPct = Math.max(0, Math.min(100, pct))
      }
      sampler.lastTotal = j[0]
      sampler.lastIdle = j[1]
    }
    sampler.pushSample()
  }

  // All four series are pushed every poll (GPU and VRAM as -1 when unavailable)
  // so their tiers stay index-aligned and share one age sequence in the chart.
  function pushSample() {
    const c = sampler.pushTiered(sampler.cpuHistory, sampler.cpuPending, sampler.cpuPct)
    sampler.cpuHistory = c.tiers
    sampler.cpuPending = c.pending
    const m = sampler.pushTiered(sampler.memHistory, sampler.memPending, sampler.memUsedPct)
    sampler.memHistory = m.tiers
    sampler.memPending = m.pending
    const g = sampler.pushTiered(sampler.gpuHistory, sampler.gpuPending, sampler.gpuPct >= 0 ? sampler.gpuPct : -1)
    sampler.gpuHistory = g.tiers
    sampler.gpuPending = g.pending
    const v = sampler.pushTiered(sampler.gpuMemHistory, sampler.gpuMemPending, sampler.gpuMemPct >= 0 ? sampler.gpuMemPct : -1)
    sampler.gpuMemHistory = v.tiers
    sampler.gpuMemPending = v.pending
  }

  function parseTop(text) {
    // A scan that finishes after the last viewer left would leave a stale snapshot
    if (!sampler.topActive) return
    // Live top CPU process: the largest tick delta since the previous scan, as
    // a share of the all-core jiffies elapsed over the same interval, so it is
    // on the same scale as cpuPct (and btop's default per-process CPU%).
    let totalDelta = 0
    const ticks = {}
    let bestDelta = -1
    let bestName = ""
    for (const line of text.trim().split("\n")) {
      const parts = line.trim().split(/\s+/)
      if (parts[0] === "P") {
        // "P <pid_starttime> <ticks> <comm, may contain spaces>"
        const t = Number(parts[2])
        ticks[parts[1]] = t
        const prev = sampler.procTicks[parts[1]]
        if (prev !== undefined && t - prev > bestDelta) {
          bestDelta = t - prev
          bestName = parts.slice(3).join(" ")
        }
      } else if (parts[0] === "cpu") {
        const j = sampler.cpuJiffies(line)
        if (sampler.topLastTotal >= 0 && j[0] > sampler.topLastTotal)
          totalDelta = j[0] - sampler.topLastTotal
        sampler.topLastTotal = j[0]
      } else if (parts[0] === "TOPMEM" && parts.length >= 3) {
        // comm may contain spaces ("Web Content"); the percentage is the last column
        sampler.topMemName = parts.slice(1, -1).join(" ")
        sampler.topMemPct = Number(parts[parts.length - 1])
      }
    }

    if (bestDelta >= 0 && totalDelta > 0) {
      sampler.topCpuName = bestName
      sampler.topCpuPct = Math.min(100, 100 * bestDelta / totalDelta)
    } else {
      // First scan: no previous snapshot to diff against yet
      sampler.topCpuName = ""
      sampler.topCpuPct = -1
    }
    sampler.procTicks = ticks
  }

  onTopActiveChanged: {
    if (topActive) {
      if (!topProc.running) topProc.running = true
    } else {
      // Drop the snapshot so the next viewer never diffs a stale one
      sampler.procTicks = ({})
      sampler.topLastTotal = -1
      sampler.topGpuName = ""
      sampler.topGpuPct = -1
      sampler.pendingGpuSeen = false
      sampler.pendingGpuPct = -1
      sampler.pendingGpuName = ""
      sampler.pmonSmCol = -1
      sampler.pmonCmdCol = -1
    }
  }

  // Both files load once on creation (the first sample) and again on every
  // poll. The history sample is pushed from the /proc/stat read; the memory
  // read is started just before it, so it lands first or one poll late.
  FileView {
    id: memFile
    path: "/proc/meminfo"
    printErrors: false
    onLoaded: sampler.sampleMem(text())
  }

  FileView {
    id: statFile
    path: "/proc/stat"
    printErrors: false
    onLoaded: sampler.sampleCpu(text())
  }

  Process {
    id: topProc
    command: ["sh", "-c",
      "head -1 /proc/stat; " +
      // One "P <pid_starttime> <utime+stime ticks> <comm>" line per process that
      // has used any CPU; parseTop() diffs them against the previous scan. comm is
      // everything between the first "(" and the last ")" of /proc/<pid>/stat.
      // The same pass tracks the largest resident set (field 24, in 4 KiB pages)
      // and reports it as "TOPMEM <comm> <percent of MemTotal>", which is what
      // `ps -eo comm,%mem --sort=-%mem | head -1` used to cost two more forks for.
      "awk 'FILENAME == \"/proc/meminfo\" { if ($1 == \"MemTotal:\") mt = $2; next } { s = $0; i = 0; while ((j = index(substr(s, i + 1), \")\")) > 0) i += j; o = index(s, \"(\"); split(substr(s, i + 2), f, \" \"); t = f[12] + f[13]; if (t > 0) print \"P\", $1 \"_\" f[20], t, substr(s, o + 1, i - o - 1); if (f[22] + 0 > mr) { mr = f[22] + 0; mn = substr(s, o + 1, i - o - 1) } } END { if (mt > 0 && mn != \"\") printf \"TOPMEM %s %.1f\\n\", mn, mr * 400 / mt }' /proc/meminfo /proc/[0-9]*/stat 2>/dev/null"]
    stdout: StdioCollector {
      onStreamFinished: sampler.parseTop(this.text)
    }
  }

  // Per-process GPU utilization ("sm" column) from ONE long-running pmon that
  // prints every process once per topInterval, instead of a fresh nvidia-smi
  // (~15 ms of NVML init) per scan. The header row gives the column positions,
  // which differ between driver versions. Runs only while a Top line is shown.
  property string pendingGpuName: ""
  property real pendingGpuPct: -1
  property bool pendingGpuSeen: false
  property int pmonSmCol: -1
  property int pmonCmdCol: -1
  Process {
    id: topGpuProc
    command: ["nvidia-smi", "pmon", "-s", "u", "-d", String(sampler.topInterval)]
    running: sampler.topActive
    stdout: SplitParser {
      onRead: function(line) {
        const parts = String(line).trim().split(/\s+/)
        if (parts[0] === "#") {
          // Data rows have no leading "#", so every column shifts left by one
          if (parts[1] === "gpu") {
            sampler.pmonSmCol = parts.indexOf("sm") - 1
            sampler.pmonCmdCol = parts.indexOf("command") - 1
          }
          return
        }
        if (sampler.pmonSmCol < 1 || sampler.pmonCmdCol < 1) return
        sampler.pendingGpuSeen = true
        const sm = Number(parts[sampler.pmonSmCol]) // "-" (idle) is NaN and skipped
        if (isFinite(sm) && sm > sampler.pendingGpuPct) {
          sampler.pendingGpuPct = sm
          sampler.pendingGpuName = parts[sampler.pmonCmdCol]
        }
      }
    }
  }

  Timer {
    id: topTimer
    interval: sampler.topInterval * 1000
    running: sampler.topActive
    repeat: true
    onTriggered: {
      if (!topProc.running) topProc.running = true
      // Publish the best GPU user seen since the last tick; keep the previous
      // answer when pmon has not reported a batch yet this tick.
      if (sampler.pendingGpuSeen) {
        sampler.topGpuName = sampler.pendingGpuPct >= 0 ? sampler.pendingGpuName : ""
        sampler.topGpuPct = sampler.pendingGpuPct
        sampler.pendingGpuSeen = false
        sampler.pendingGpuPct = -1
        sampler.pendingGpuName = ""
      }
    }
  }

  // GPU: ONE long-running nvidia-smi that streams a line every 2 s. Spawning
  // nvidia-smi per poll costs ~15 ms of NVML init each time; this runs it once.
  Process {
    id: gpuProc
    command: ["nvidia-smi",
      "--query-gpu=utilization.gpu,memory.used,memory.total",
      "--format=csv,noheader,nounits", "-lms", "2000"]
    running: true
    stdout: SplitParser {
      onRead: function(line) {
        const nums = String(line).trim().split(",").map(Number)
        if (nums.length === 3 && nums.every(isFinite)) {
          sampler.gpuPct = nums[0]
          sampler.gpuMemUsedMb = nums[1]
          sampler.gpuMemTotalMb = nums[2]
          if (nums[2] > 0) sampler.gpuMemPct = Math.max(0, Math.min(100, 100 * nums[1] / nums[2]))
        }
      }
    }
  }

  // Keeps running while every instance is hidden so the history stays
  // continuous; that costs two /proc reads per poll and no fork. The forking
  // Top scan has its own slower timer above.
  Timer {
    id: pollTimer
    interval: sampler.baseInterval * 1000
    running: true
    repeat: true
    onTriggered: {
      memFile.reload()
      statFile.reload()
    }
  }
}
