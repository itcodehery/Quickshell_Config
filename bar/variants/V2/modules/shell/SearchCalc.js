.pragma library

// Inline calculator / unit converter for the pet search bar.
// evaluate(text) returns one of:
//   null                                  -> not a calculation
//   { display, copy }                     -> instant answer
//   { currency: true, amount, from, to }  -> needs an exchange rate lookup

// ── Units (factor to the category base unit) ───────────────────────────
var UNITS = {
    length: { base: "m", units: {
        m: 1, km: 1000, cm: 0.01, mm: 0.001, um: 1e-6, mi: 1609.344, ft: 0.3048,
        inch: 0.0254, yd: 0.9144, nmi: 1852 } },
    mass: { base: "kg", units: {
        kg: 1, g: 0.001, mg: 1e-6, lb: 0.45359237, oz: 0.028349523125, t: 1000, st: 6.35029318 } },
    volume: { base: "l", units: {
        l: 1, ml: 0.001, gal: 3.785411784, qt: 0.946352946, pt: 0.473176473,
        cup: 0.2365882365, floz: 0.0295735295625, tbsp: 0.01478676478, tsp: 0.00492892159 } },
    data: { base: "B", units: {
        B: 1, KB: 1e3, MB: 1e6, GB: 1e9, TB: 1e12, KiB: 1024, MiB: 1048576,
        GiB: 1073741824, TiB: 1099511627776 } },
    time: { base: "s", units: {
        ms: 0.001, s: 1, min: 60, h: 3600, day: 86400, week: 604800, year: 31557600 } },
    speed: { base: "m/s", units: {
        "m/s": 1, "km/h": 1 / 3.6, mph: 0.44704, kn: 1852 / 3600 } },
    area: { base: "m2", units: {
        m2: 1, km2: 1e6, cm2: 1e-4, ha: 10000, acre: 4046.8564224, ft2: 0.09290304, mi2: 2589988.110336 } },
    temp: { base: "c", units: { c: 1, f: 1, k: 1 } }
}

var ALIASES = {
    meter: "m", meters: "m", metre: "m", metres: "m",
    kilometer: "km", kilometers: "km", kilometre: "km", kilometres: "km",
    centimeter: "cm", centimeters: "cm", millimeter: "mm", millimeters: "mm",
    mile: "mi", miles: "mi", foot: "ft", feet: "ft", ft: "ft",
    "in": "inch", inch: "inch", inches: "inch", yard: "yd", yards: "yd",
    kilogram: "kg", kilograms: "kg", kgs: "kg", gram: "g", grams: "g", gm: "g",
    pound: "lb", pounds: "lb", lbs: "lb", ounce: "oz", ounces: "oz",
    tonne: "t", tonnes: "t", ton: "t",
    liter: "l", liters: "l", litre: "l", litres: "l", ltr: "l",
    milliliter: "ml", milliliters: "ml", gallon: "gal", gallons: "gal",
    quart: "qt", pint: "pt", cups: "cup", tablespoon: "tbsp", teaspoon: "tsp",
    byte: "B", bytes: "B", kb: "KB", mb: "MB", gb: "GB", tb: "TB",
    kib: "KiB", mib: "MiB", gib: "GiB", tib: "TiB",
    millisecond: "ms", milliseconds: "ms", sec: "s", secs: "s", second: "s", seconds: "s",
    mins: "min", minute: "min", minutes: "min", hr: "h", hrs: "h", hour: "h", hours: "h",
    days: "day", weeks: "week", years: "year", yr: "year", yrs: "year",
    kmh: "km/h", kph: "km/h", kmph: "km/h", mps: "m/s", knot: "kn", knots: "kn",
    sqm: "m2", sqft: "ft2", hectare: "ha", hectares: "ha", acres: "acre",
    celsius: "c", centigrade: "c", fahrenheit: "f", kelvin: "k"
}

function canonUnit(token) {
    var t = String(token).replace(/°/g, "").replace(/²/g, "2")
    if (UNITS.data.units[t] !== undefined) return t
    t = t.toLowerCase()
    if (ALIASES[t] !== undefined) return ALIASES[t]
    for (var cat in UNITS) {
        if (UNITS[cat].units[t] !== undefined) return t
    }
    return null
}

function categoryOf(unit) {
    for (var cat in UNITS) {
        if (UNITS[cat].units[unit] !== undefined) return cat
    }
    return null
}

function fmt(n) {
    if (!isFinite(n)) return "∞"
    var a = Math.abs(n)
    if (a !== 0 && (a >= 1e15 || a < 1e-9)) return n.toExponential(6).replace(/\.?0+e/, "e")
    var s = parseFloat(n.toPrecision(8)).toString()
    if (s.indexOf("e") >= 0) return s
    var parts = s.split(".")
    parts[0] = parts[0].replace(/\B(?=(\d{3})+(?!\d))/g, ",")
    return parts.join(".")
}

function plain(n) {
    if (!isFinite(n)) return ""
    return parseFloat(n.toPrecision(12)).toString()
}

function convertTemp(v, from, to) {
    var c = from === "c" ? v : (from === "f" ? (v - 32) * 5 / 9 : v - 273.15)
    return to === "c" ? c : (to === "f" ? c * 9 / 5 + 32 : c + 273.15)
}

function convert(amount, from, to) {
    var cat = categoryOf(from)
    if (!cat || cat !== categoryOf(to)) return null
    if (cat === "temp") return convertTemp(amount, from, to)
    var u = UNITS[cat].units
    return amount * u[from] / u[to]
}

function unitLabel(u) {
    return u === "inch" ? "in" : (u === "c" || u === "f" ? "°" + u.toUpperCase() : u)
}

// ── Expression parser (no eval) ────────────────────────────────────────
function parseExpr(src) {
    var s = src, i = 0
    function ws() { while (i < s.length && s[i] === " ") i++ }
    function peek() { ws(); return s[i] }
    function fail() { throw new Error("parse") }

    var FUNCS = {
        sqrt: Math.sqrt, sin: function(x) { return Math.sin(x * Math.PI / 180) },
        cos: function(x) { return Math.cos(x * Math.PI / 180) },
        tan: function(x) { return Math.tan(x * Math.PI / 180) },
        log: Math.log10, ln: Math.log, abs: Math.abs,
        round: Math.round, floor: Math.floor, ceil: Math.ceil
    }

    function primary() {
        var c = peek()
        if (c === "(") {
            i++
            var v = add()
            if (peek() !== ")") fail()
            i++
            return v
        }
        var m = /^(\d+\.?\d*|\.\d+)(e[+-]?\d+)?/.exec(s.slice(i))
        if (m) { i += m[0].length; return parseFloat(m[0]) }
        m = /^[a-z]+/.exec(s.slice(i))
        if (m) {
            var name = m[0]
            i += name.length
            if (name === "pi") return Math.PI
            if (name === "e") return Math.E
            if (FUNCS[name]) {
                if (peek() !== "(") fail()
                i++
                var a = add()
                if (peek() !== ")") fail()
                i++
                return FUNCS[name](a)
            }
        }
        fail()
    }
    function postfix() {
        var v = primary()
        while (peek() === "!") { i++; v = factorial(v) }
        while (peek() === "%" && !/^%\s*[\d(a-z.]/.test(s.slice(i))) { i++; v = v / 100 }
        return v
    }
    function factorial(n) {
        if (n < 0 || n > 170 || n !== Math.floor(n)) fail()
        var r = 1
        for (var k = 2; k <= n; k++) r *= k
        return r
    }
    function unary() {
        var c = peek()
        if (c === "-") { i++; return -unary() }
        if (c === "+") { i++; return unary() }
        return pow()
    }
    function pow() {
        var base = postfix()
        if (peek() === "^") { i++; return Math.pow(base, unary()) }
        return base
    }
    function mul() {
        var v = unary()
        for (;;) {
            var c = peek()
            if (c === "*" || c === "x") { i++; v = v * unary() }
            else if (c === "/") { i++; v = v / unary() }
            else if (c === "%") { i++; v = v % unary() }
            else if (c === "(") { v = v * unary() } // implicit multiplication: 2(3+4)
            else return v
        }
    }
    function add() {
        var v = mul()
        for (;;) {
            var c = peek()
            if (c === "+") { i++; v = v + mul() }
            else if (c === "-") { i++; v = v - mul() }
            else return v
        }
    }

    var out = add()
    ws()
    if (i !== s.length) fail()
    return out
}

function hasMathShape(s) {
    // Needs a digit and (an operator or a function/constant) so plain words/numbers don't trigger.
    if (!/\d/.test(s)) return false
    if (!/^[0-9a-z+\-*\/().%^!,\s×÷]+$/.test(s)) return false
    return /[+\-*\/^%!×÷x]|\(|sqrt|sin|cos|tan|log|ln|abs|round|floor|ceil|pi/.test(s.replace(/e[+-]?\d+/g, ""))
}

function evaluate(input) {
    var text = String(input || "").trim().toLowerCase()
    if (text.length < 2) return null

    // ── "x% of y"
    var pm = /^([\d.]+)\s*%\s*of\s*([\d.,]+)$/.exec(text)
    if (pm) {
        var r = parseFloat(pm[1]) / 100 * parseFloat(pm[2].replace(/,/g, ""))
        return { display: "= " + fmt(r), copy: plain(r) }
    }

    // ── "<amount> <from> in|to <to>"
    var cm = /^(-?[\d.,]+(?:e[+-]?\d+)?)\s*([a-z°²\/0-9]+?)\s+(?:in|to|into|as)\s+([a-z°²\/0-9]+)$/.exec(text)
    if (!cm) cm = /^(-?[\d.,]+(?:e[+-]?\d+)?)\s*([a-z°²\/0-9]+?)\s*(?:->|=>|=)\s*([a-z°²\/0-9]+)$/.exec(text)
    if (cm) {
        var amount = parseFloat(cm[1].replace(/,/g, ""))
        if (isFinite(amount)) {
            var from = canonUnit(cm[2]), to = canonUnit(cm[3])
            if (from && to) {
                var res = convert(amount, from, to)
                if (res === null) return null
                var shown = fmt(res) + " " + unitLabel(to)
                return { display: "= " + shown, copy: plain(res) + " " + unitLabel(to) }
            }
            if (/^[a-z]{3}$/.test(cm[2]) && /^[a-z]{3}$/.test(cm[3]) && cm[2] !== cm[3]) {
                return { currency: true, amount: amount, from: cm[2].toUpperCase(), to: cm[3].toUpperCase() }
            }
        }
        return null
    }

    // ── Plain math
    var expr = text.replace(/×/g, "*").replace(/÷/g, "/").replace(/,/g, "")
    if (hasMathShape(expr)) {
        try {
            var v = parseExpr(expr)
            if (typeof v === "number" && isFinite(v)) return { display: "= " + fmt(v), copy: plain(v) }
        } catch (e) {}
    }
    return null
}

function currencyResult(amount, rate, to) {
    var v = amount * rate
    return { display: "= " + fmt(v) + " " + to, copy: plain(v) + " " + to }
}
