import std/[os, strutils, unicode, algorithm, tables, sequtils]


type
  ScriptKind* = enum
    skAlphabet,
    skGreek,
    skCyrillic,
    skArmenian,
    skGeorgian,
    skMongolian,
    skKorean,
    skArabic,
    skHebrew,
    skKhmer,
    skTamil,
    skThai,
    skTibetan,
    skBurmese,
    skLao,
    skDevanagari,
    skGujarati,
    skKana

  Range = tuple[lo: int, hi: int]

  RemoveCharsStats* = object
    scanned*: int
    removed*: int
    changed*: bool

  CliOptions = object
    files: seq[string]
    scripts: set[ScriptKind]
    useStdout: bool
    listScripts: bool  # ←   parseCli result.listFiles  
    help: bool


const
  HelpText = """
char_remover

Usage:
  char_remover <file> [options]
  char_remover --list
  char_remover --help

Options:
  --remove:<Script>[,<Script>...]
      Remove selected scripts.
      Example: --remove:Korean,Alphabet,Greek

  --remove <Script[,Script...]>
      Same as above.

  --stdout
      Print result to stdout instead of overwriting the input file.

  --list
      List available script names.

Examples:
  char_remover input.txt --remove:Kana
  char_remover input.txt --remove:Korean --remove:Alphabet --remove:Greek
  char_remover input.txt --remove:Alphabet,Greek,Cyrillic --stdout > out.txt
"""


proc scriptName*(s: ScriptKind): string =
  case s
  of skAlphabet: "Alphabet"
  of skGreek: "Greek"
  of skCyrillic: "Cyrillic"
  of skArmenian: "Armenian"
  of skGeorgian: "Georgian"
  of skMongolian: "Mongolian"
  of skKorean: "Korean"
  of skArabic: "Arabic"
  of skHebrew: "Hebrew"
  of skKhmer: "Khmer"
  of skTamil: "Tamil"
  of skThai: "Thai"
  of skTibetan: "Tibetan"
  of skBurmese: "Burmese"
  of skLao: "Lao"
  of skDevanagari: "Devanagari"
  of skGujarati: "Gujarati"
  of skKana: "Kana"


let scriptAliases: Table[string, ScriptKind] = {
  "alphabet": skAlphabet,
  "latin": skAlphabet,
  "alpha": skAlphabet,
  "basiclatin": skAlphabet,
  "extendedalphabet": skAlphabet,
  "extendedlatin": skAlphabet,
  "english": skAlphabet,

  "greek": skGreek,
  "cyrillic": skCyrillic,
  "armenian": skArmenian,
  "georgian": skGeorgian,
  "mongolian": skMongolian,

  "korean": skKorean,
  "hangul": skKorean,

  "arabic": skArabic,
  "hebrew": skHebrew,
  "khmer": skKhmer,
  "tamil": skTamil,
  "thai": skThai,
  "tibetan": skTibetan,

  "burmese": skBurmese,
  "myanmar": skBurmese,

  "lao": skLao,
  "devanagari": skDevanagari,
  "gujarati": skGujarati,

  "kana": skKana,
  "hiragana": skKana,
  "katakana": skKana,
  "japanesekana": skKana
}.toTable


let scriptRanges: Table[ScriptKind, seq[Range]] = {
  skAlphabet: @[
    (lo: 0x0041, hi: 0x005A),
    (lo: 0x0061, hi: 0x007A),
    (lo: 0x00C0, hi: 0x00D6),
    (lo: 0x00D8, hi: 0x00F6),
    (lo: 0x00F8, hi: 0x00FF),
    (lo: 0x0100, hi: 0x017F),
    (lo: 0x0180, hi: 0x024F),
    (lo: 0x0250, hi: 0x02AF),
    (lo: 0x1E00, hi: 0x1EFF),
    (lo: 0x2C60, hi: 0x2C7F),
    (lo: 0xA720, hi: 0xA7FF),
    (lo: 0xAB30, hi: 0xAB6F),
    (lo: 0xFB00, hi: 0xFB06),
    (lo: 0xFF21, hi: 0xFF3A),
    (lo: 0xFF41, hi: 0xFF5A)
  ],

  skGreek: @[
    (lo: 0x0370, hi: 0x03FF),
    (lo: 0x1F00, hi: 0x1FFF)
  ],

  skCyrillic: @[
    (lo: 0x0400, hi: 0x04FF),
    (lo: 0x0500, hi: 0x052F),
    (lo: 0x1C80, hi: 0x1C8F),
    (lo: 0x2DE0, hi: 0x2DFF),
    (lo: 0xA640, hi: 0xA69F)
  ],

  skArmenian: @[
    (lo: 0x0530, hi: 0x058F),
    (lo: 0xFB13, hi: 0xFB17)
  ],

  skGeorgian: @[
    (lo: 0x10A0, hi: 0x10FF),
    (lo: 0x1C90, hi: 0x1CBF),
    (lo: 0x2D00, hi: 0x2D2F)
  ],

  skMongolian: @[
    (lo: 0x1800, hi: 0x18AF),
    (lo: 0x11660, hi: 0x1167F)
  ],

  skKorean: @[
    (lo: 0x1100, hi: 0x11FF),
    (lo: 0x3130, hi: 0x318F),
    (lo: 0xA960, hi: 0xA97F),
    (lo: 0xAC00, hi: 0xD7AF),
    (lo: 0xD7B0, hi: 0xD7FF),
    (lo: 0xFFA0, hi: 0xFFDC)
  ],

  skArabic: @[
    (lo: 0x0600, hi: 0x06FF),
    (lo: 0x0750, hi: 0x077F),
    (lo: 0x0870, hi: 0x089F),
    (lo: 0x08A0, hi: 0x08FF),
    (lo: 0xFB50, hi: 0xFDFF),
    (lo: 0xFE70, hi: 0xFEFF)
  ],

  skHebrew: @[
    (lo: 0x0590, hi: 0x05FF),
    (lo: 0xFB1D, hi: 0xFB4F)
  ],

  skKhmer: @[
    (lo: 0x1780, hi: 0x17FF),
    (lo: 0x19E0, hi: 0x19FF)
  ],

  skTamil: @[
    (lo: 0x0B80, hi: 0x0BFF)
  ],

  skThai: @[
    (lo: 0x0E00, hi: 0x0E7F)
  ],

  skTibetan: @[
    (lo: 0x0F00, hi: 0x0FFF)
  ],

  skBurmese: @[
    (lo: 0x1000, hi: 0x109F),
    (lo: 0xA9E0, hi: 0xA9FF),
    (lo: 0xAA60, hi: 0xAA7F)
  ],

  skLao: @[
    (lo: 0x0E80, hi: 0x0EFF)
  ],

  skDevanagari: @[
    (lo: 0x0900, hi: 0x097F),
    (lo: 0xA8E0, hi: 0xA8FF)
  ],

  skGujarati: @[
    (lo: 0x0A80, hi: 0x0AFF)
  ],

  skKana: @[
    (lo: 0x3040, hi: 0x309F),
    (lo: 0x30A0, hi: 0x30FF),
    (lo: 0x31F0, hi: 0x31FF),
    (lo: 0xFF66, hi: 0xFF9F),
    (lo: 0x1B000, hi: 0x1B0FF),
    (lo: 0x1B100, hi: 0x1B12F),
    (lo: 0x1AFF0, hi: 0x1AFFF)
  ]
}.toTable


proc parseScriptName(raw: string): ScriptKind =
  let k = raw.strip().toLowerAscii()
  if scriptAliases.hasKey(k):
    return scriptAliases[k]
  raise newException(ValueError, "unknown script: " & raw)


proc parseScriptList(raw: string, scripts: var set[ScriptKind]) =
  for part in raw.split({',', ';', ' ', '\t'}):
    let name = part.strip()
    if name.len == 0:
      continue
    if name.toLowerAscii() == "all":
      for s in low(ScriptKind)..high(ScriptKind):
        scripts.incl(s)
    else:
      scripts.incl(parseScriptName(name))


proc parseCli(args: seq[string]): CliOptions =
  var i = 0
  while i < args.len:
    let a = args[i]
    if a == "--":
      inc i
      while i < args.len:
        result.files.add(args[i])
        inc i
      break
    elif a == "--help" or a == "-h":
      result.help = true
    elif a == "--list":
      result.listScripts = true
    elif a == "--stdout":
      result.useStdout = true
    elif a.startsWith("--remove:") or a.startsWith("--remove="):
      parseScriptList(a.substr(9), result.scripts)
    elif a == "--remove":
      if i + 1 >= args.len:
        raise newException(ValueError, "--remove requires a value")
      inc i
      parseScriptList(args[i], result.scripts)
    elif a.startsWith("--"):
      raise newException(ValueError, "unknown option: " & a)
    else:
      result.files.add(a)
    inc i


proc buildSelectedRanges(scripts: set[ScriptKind]): seq[Range] =
  for s in low(ScriptKind)..high(ScriptKind):
    if s in scripts:
      result.add(scriptRanges[s])
  result.sort(proc(a, b: Range): int = cmp(a.lo, b.lo))


proc mergeRanges(ranges: seq[Range]): seq[Range] =
  if ranges.len == 0:
    return
  var current = ranges[0]
  for i in 1..<ranges.len:
    let r = ranges[i]
    if r.lo <= current.hi + 1:
      if r.hi > current.hi:
        current.hi = r.hi
    else:
      result.add(current)
      current = r
  result.add(current)


proc containsRange(ranges: openArray[Range], cp: int): bool =
  var lo = 0
  var hi = ranges.high
  while lo <= hi:
    let mid = (lo + hi) div 2
    if cp < ranges[mid].lo:
      hi = mid - 1
    elif cp > ranges[mid].hi:
      lo = mid + 1
    else:
      return true
  return false


proc removeScripts*(
    input: string,
    scripts: set[ScriptKind],
    stats: var RemoveCharsStats
): string =
  stats = RemoveCharsStats()
  if scripts.card == 0 or input.len == 0:
    return input
  let ranges = mergeRanges(buildSelectedRanges(scripts))
  result = newStringOfCap(input.len)
  for r in input.runes:
    inc stats.scanned
    if ranges.containsRange(ord(r)):
      inc stats.removed
    else:
      result.add($r)
  stats.changed = stats.removed > 0


proc printList =
  echo "Available script options:"
  for s in low(ScriptKind)..high(ScriptKind):
    echo "  ", scriptName(s)
  echo ""
  echo "Aliases include:"
  echo "  all, alphabet, latin, hangul, myanmar, hiragana, katakana"


proc processFile(
    path: string,
    scripts: set[ScriptKind],
    useStdout: bool
): int =
  try:
    let src = readFile(path)
    var stats: RemoveCharsStats
    let outp = removeScripts(src, scripts, stats)
    if useStdout:
      stdout.write(outp)
      return 0
    if stats.changed:
      writeFile(path, outp)
      echo path,
        " | scanned=", stats.scanned,
        " | removed=", stats.removed
    else:
      echo path, " | unchanged"
    return 0
  except CatchableError as e:
    stderr.writeLine("error: ", path, " : ", e.msg)
    return 2


proc main(): int =
  var opts: CliOptions
  try:
    opts = parseCli(commandLineParams())
  except ValueError as e:
    stderr.writeLine("error: ", e.msg)
    stderr.writeLine("try: char_remover --help")
    return 1

  if opts.help:
    echo HelpText
    return 0

  if opts.listScripts:
    printList()
    return 0

  if opts.files.len == 0:
    stderr.writeLine("error: no input file")
    stderr.writeLine("try: char_remover --help")
    return 1

  if opts.scripts.card == 0:
    stderr.writeLine("error: no script selected; use --remove:<Script>")
    return 1

  var rc = 0
  for f in opts.files:
    let r = processFile(f, opts.scripts, opts.useStdout)
    if r != 0:
      rc = r
  return rc


when isMainModule:
  quit(main())
