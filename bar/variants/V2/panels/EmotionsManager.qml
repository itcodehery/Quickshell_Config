import QtQuick
import Quickshell
import Quickshell.Io

Item {
    id: mgr
    visible: false

    readonly property string filePath: Quickshell.env("HOME") + "/.local/state/quickshell_emotions.json"

    property var dataMap: ({
        lastPromptedDate: "",
        entries: {}
    })

    function getTodayKey() {
        var d = new Date()
        var yyyy = d.getFullYear()
        var mm = String(d.getMonth() + 1).padStart(2, '0')
        var dd = String(d.getDate()).padStart(2, '0')
        return yyyy + "-" + mm + "-" + dd
    }

    property string todayKey: getTodayKey()

    Timer {
        interval: 60000
        repeat: true
        running: true
        onTriggered: mgr.todayKey = mgr.getTodayKey()
    }

    readonly property var levels: [
        {
            id: 0,
            score: -3,
            name: "Very Unpleasant",
            color: "#A855F7",
            glowColor: "#7E22CE",
            icon: "sentiment_very_dissatisfied",
            badge: "Down",
            defaultTags: ["Overwhelmed", "Exhausted", "Angry", "Sad", "Hopeless"]
        },
        {
            id: 1,
            score: -2,
            name: "Unpleasant",
            color: "#6366F1",
            glowColor: "#4338CA",
            icon: "sentiment_dissatisfied",
            badge: "Low",
            defaultTags: ["Stressed", "Frustrated", "Anxious", "Irritated", "Down"]
        },
        {
            id: 2,
            score: -1,
            name: "Slightly Unpleasant",
            color: "#38BDF8",
            glowColor: "#0284C7",
            icon: "sentiment_neutral",
            badge: "Meh",
            defaultTags: ["Uneasy", "Tired", "Bored", "Distracted", "Drained"]
        },
        {
            id: 3,
            score: 0,
            name: "Neutral",
            color: "#2DD4BF",
            glowColor: "#0F766E",
            icon: "face",
            badge: "Neutral",
            defaultTags: ["Calm", "Fine", "Indifferent", "Quiet", "Stable"]
        },
        {
            id: 4,
            score: 1,
            name: "Slightly Pleasant",
            color: "#A3E635",
            glowColor: "#65A30D",
            icon: "sentiment_satisfied",
            badge: "Good",
            defaultTags: ["Hopeful", "Relaxed", "Content", "Present", "Thoughtful"]
        },
        {
            id: 5,
            score: 2,
            name: "Pleasant",
            color: "#FACC15",
            glowColor: "#CA8A04",
            icon: "sentiment_very_satisfied",
            badge: "Pleasant",
            defaultTags: ["Happy", "Grateful", "Productive", "Peaceful", "Warm"]
        },
        {
            id: 6,
            score: 3,
            name: "Very Pleasant",
            color: "#FB923C",
            glowColor: "#EA580C",
            icon: "sunny",
            badge: "Radiant",
            defaultTags: ["Joyful", "Excited", "Inspired", "Confident", "Loved"]
        }
    ]

    readonly property var contextOptions: [
        "Work", "Family", "Health", "Hobbies", "Fitness", "Rest", "Friends", "Education"
    ]

    readonly property var todayEntry: (dataMap && dataMap.entries) ? (dataMap.entries[todayKey] || null) : null
    readonly property bool hasLoggedToday: todayEntry !== null
    readonly property string lastPromptedDate: dataMap ? (dataMap.lastPromptedDate || "") : ""

    function getLevel(levelId) {
        var idx = Math.max(0, Math.min(levels.length - 1, levelId))
        return levels[idx]
    }

    function shouldPromptToday() {
        return lastPromptedDate !== todayKey
    }

    function markPromptedToday() {
        var copy = JSON.parse(JSON.stringify(dataMap || { lastPromptedDate: "", entries: {} }))
        copy.lastPromptedDate = todayKey
        dataMap = copy
        save()
    }

    function logToday(levelId, mode, tags, context, note) {
        var lvl = getLevel(levelId)
        var d = new Date()
        var timeStr = d.toLocaleTimeString([], { hour: '2-digit', minute: '2-digit' })
        var dateFormatted = d.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' })

        var copy = JSON.parse(JSON.stringify(dataMap || { lastPromptedDate: "", entries: {} }))
        copy.lastPromptedDate = todayKey
        if (!copy.entries) copy.entries = {}

        copy.entries[todayKey] = {
            date: todayKey,
            dateFormatted: dateFormatted,
            level: lvl.id,
            levelName: lvl.name,
            score: lvl.score,
            mode: mode || "overall",
            time: timeStr,
            timestamp: Date.now(),
            tags: tags || lvl.defaultTags.slice(0, 2),
            context: context || ["Work"],
            note: note || ""
        }

        dataMap = copy
        save()
    }

    // Weekly calculations for the chart
    function getWeekDays(weekOffset) {
        var offset = weekOffset || 0
        var now = new Date()
        now.setDate(now.getDate() - (offset * 7))

        var dayOfWeek = now.getDay() // 0 = Sun, 1 = Mon ...
        var mondayDiff = now.getDate() - dayOfWeek + (dayOfWeek === 0 ? -6 : 1)
        var monday = new Date(now.setDate(mondayDiff))

        var days = []
        var dayLetters = ["M", "T", "W", "T", "F", "S", "S"]
        var dayNames = ["Mon", "Tue", "Wed", "Thu", "Fri", "Sat", "Sun"]

        var today = new Date()
        var todayYMD = todayKey

        for (var i = 0; i < 7; i++) {
            var curr = new Date(monday)
            curr.setDate(monday.getDate() + i)

            var yyyy = curr.getFullYear()
            var mm = String(curr.getMonth() + 1).padStart(2, '0')
            var dd = String(curr.getDate()).padStart(2, '0')
            var k = yyyy + "-" + mm + "-" + dd

            var entry = (dataMap && dataMap.entries) ? (dataMap.entries[k] || null) : null
            var isToday = (k === todayYMD)
            var isFuture = curr.getTime() > today.getTime() && !isToday

            days.push({
                dateKey: k,
                dayLetter: dayLetters[i],
                dayLabel: dayNames[i],
                dateFormatted: curr.toLocaleDateString([], { weekday: 'short', month: 'short', day: 'numeric' }),
                dateShort: dayNames[i] + " " + curr.getDate(),
                isToday: isToday,
                isFuture: isFuture,
                hasData: entry !== null,
                entry: entry,
                level: entry ? entry.level : -1,
                levelObj: entry ? getLevel(entry.level) : null
            })
        }
        return days
    }

    FileView {
        id: fileView
        path: mgr.filePath
        watchChanges: true
        printErrors: false
        onFileChanged: fileView.reload()
        onLoaded: {
            try {
                var txt = fileView.text().trim()
                if (txt.length > 0) {
                    var parsed = JSON.parse(txt)
                    if (parsed && typeof parsed === "object") {
                        if (!parsed.entries) parsed.entries = {}
                        mgr.dataMap = parsed
                    }
                }
            } catch(e) {}
        }
    }

    Component.onCompleted: {
        if (fileView.loaded) {
            try {
                var txt = fileView.text().trim()
                if (txt.length > 0) {
                    var parsed = JSON.parse(txt)
                    if (parsed && typeof parsed === "object") {
                        if (!parsed.entries) parsed.entries = {}
                        mgr.dataMap = parsed
                    }
                }
            } catch(e) {}
        }
    }

    Process {
        id: saveProc
        property string payload: "{}"
        command: ["python3", "-c",
            "import sys, os; os.makedirs(os.path.dirname(sys.argv[1]), exist_ok=True); open(sys.argv[1], 'w', encoding='utf-8').write(sys.argv[2])",
            mgr.filePath,
            payload
        ]
    }

    function save() {
        saveProc.payload = JSON.stringify(dataMap, null, 2)
        saveProc.running = false
        saveProc.running = true
    }
}
