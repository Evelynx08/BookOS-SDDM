/*
 * BookOS SDDM — widgets del greeter.
 *
 * Dos modos de colocación:
 *  · stack → en fila bajo el reloj, se mueven con él.
 *  · free  → cada widget en SU PROPIA posición (widgetPos), así se puede tener
 *            uno arriba a la izquierda y otro abajo a la derecha.
 *
 * Cada widget es una tarjeta del HIG: radio 25, fondo de píldora, título
 * 14/Medium y subtítulo 11/Regular en text-2.
 *
 * NINGÚN widget hace red. El greeter arranca antes de que haya sesión y
 * consultar servicios externos desde la pantalla de acceso sería un riesgo de
 * privacidad y una fuente de cuelgues: el tiempo se lee de un fichero que la
 * sesión del escritorio dejó cacheado y que bookos-sddm-appearance-sync.service
 * copia a /var/lib/sddm/. Si no existe, ese widget no aparece.
 */
import QtQuick 2.15

Item {
    id: widgets

    // Lista separada por ';' — p.ej. "battery;weather;date".
    property string enabledList: ""
    // "battery:12,20;weather:50,34" — centro de cada uno en % de pantalla.
    property string positions: ""
    property string layoutMode: "stack"
    // "weather:large;battery:compact" — variante de cada widget.
    property string sizes: ""
    // "weather:120" — escala individual en %.
    property string scales: ""
    // Ancla del modo stack: centro del reloj y borde inferior del bloque.
    property real stackX: 0
    property real stackY: 0

    property bool  isDark: true
    property color accent: "#007aff"
    property color pillBg: "#CC1c1c1e"
    property color fg: "#ffffff"
    property color fg2: "#8e8e93"
    property string localeName: "es_ES"

    property string battCapacity: ""
    property string battStatus: ""
    property string battTimeLeft: ""

    anchors.fill: parent

    readonly property var list:
        enabledList === "" ? [] : enabledList.split(";").filter(function (w) { return w !== "" })

    /** Variante de un widget: "compact" (píldora) o "large" (tarjeta). */
    function sizeOf(key) {
        var parts = sizes.split(";")
        for (var i = 0; i < parts.length; i++) {
            var kv = parts[i].split(":")
            if (kv[0] === key && kv.length > 1) return kv[1]
        }
        return "compact"
    }
    /** Escala individual en % (100 = base). */
    function scaleOf(key) {
        var parts = scales.split(";")
        for (var i = 0; i < parts.length; i++) {
            var kv = parts[i].split(":")
            if (kv[0] === key && kv.length > 1) {
                var v = parseFloat(kv[1])
                if (!isNaN(v)) return Math.max(50, Math.min(200, v)) / 100
            }
        }
        return 1.0
    }

    /** Previsión de 7 días del caché: [{d:"27", t:"32", s:"clouds"}, …] */
    property var wxDays: []

    /** Posición guardada de un widget, o un reparto por defecto si no tiene. */
    function posOf(key, axis) {
        var parts = positions.split(";")
        for (var i = 0; i < parts.length; i++) {
            var kv = parts[i].split(":")
            if (kv[0] === key && kv.length > 1) {
                var xy = kv[1].split(",")
                var v = parseFloat(axis === "x" ? xy[0] : xy[1])
                if (!isNaN(v)) return Math.max(0, Math.min(100, v))
            }
        }
        // Reparto inicial en abanico para que no nazcan todos apilados.
        var idx = list.indexOf(key)
        return axis === "x" ? (30 + idx * 20) : 34
    }

    // ── Tiempo, leído del caché ───────────────────────────────────────────
    property string wxTemp: ""
    property string wxDesc: ""
    property string wxCity: ""
    property string wxIcon: "☁"
    // Estado del tiempo: clear | clouds | partly | night | dawn | dusk.
    // Lo trae el caché; si falta, se deduce de la hora para no salir siempre
    // con el mismo color.
    property string wxState: ""
    readonly property string wxEffective: {
        if (wxState !== "") return wxState
        var h = new Date().getHours()
        if (h >= 21 || h < 6)  return "night"
        if (h < 9)             return "dawn"
        if (h >= 19)           return "dusk"
        return "clear"
    }
    // Colores exactos del archivo de Figma (ver BookOS-HIG/widgets-tokens.md).
    // Los dos últimos son degradados verticales.
    readonly property color wxTop: {
        switch (wxEffective) {
        case "clouds": return "#AEC5DD"
        case "partly": return "#225784"
        case "night":  return "#09253E"
        case "dawn":   return "#09253E"
        case "dusk":   return "#468ECD"
        default:       return "#4D9BDE"
        }
    }
    readonly property color wxBottom: {
        switch (wxEffective) {
        case "dawn": return "#2E6698"
        case "dusk": return "#1E4A71"
        default:     return wxTop
        }
    }
    Component.onCompleted: {
        try {
            var xhr = new XMLHttpRequest()
            xhr.open("GET", "file:///var/lib/sddm/bookos-weather.json", false)
            xhr.send()
            var j = JSON.parse(xhr.responseText || "{}")
            wxTemp = j.temp !== undefined ? String(j.temp) : ""
            wxDesc = j.desc || ""
            wxCity = j.city || ""
            if (j.icon) wxIcon = j.icon
            if (j.state) wxState = j.state
            if (j.days && j.days.length) wxDays = j.days
        } catch (e) {
            wxTemp = ""   // sin caché no hay widget del tiempo
        }
    }

    Repeater {
        model: widgets.list

        delegate: Rectangle {
            id: card
            required property string modelData
            required property int index

            readonly property bool isBattery: modelData === "battery"
            readonly property bool isWeather: modelData === "weather"
            readonly property bool isDate:    modelData === "date"
            // El del tiempo se esconde entero si no hay dato cacheado.
            visible: !isWeather || widgets.wxTemp !== ""

            readonly property bool large: widgets.sizeOf(modelData) === "large"
            readonly property real k: widgets.scaleOf(modelData)

            // Proporciones del Figma (750x330) reducidas a la escala del
            // greeter; la píldora conserva el alto de 92 de antes.
            implicitWidth:  large ? Math.round(330 * k) : content.implicitWidth + 32
            implicitHeight: large ? Math.round(145 * k) : Math.round(92 * k)
            width: implicitWidth
            height: implicitHeight
            radius: 25
            color: isWeather ? widgets.wxTop : widgets.pillBg

            // Degradado solo en amanecer y atardecer; en el resto los dos
            // extremos son el mismo color y Qt lo resuelve como relleno liso.
            gradient: isWeather && widgets.wxTop !== widgets.wxBottom
                ? weatherGradient : null
            Gradient {
                id: weatherGradient
                GradientStop { position: 0.0; color: widgets.wxTop }
                GradientStop { position: 1.0; color: widgets.wxBottom }
            }

            // stack: en fila centrada bajo el reloj. free: coordenadas propias.
            x: widgets.layoutMode === "free"
                 ? Math.round(widgets.width * widgets.posOf(modelData, "x") / 100 - width / 2)
                 : Math.round(widgets.stackX - stackTotal / 2 + stackOffset)
            y: widgets.layoutMode === "free"
                 ? Math.round(widgets.height * widgets.posOf(modelData, "y") / 100 - height / 2)
                 : Math.round(widgets.stackY)
            Behavior on x { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }
            Behavior on y { NumberAnimation { duration: 160; easing.type: Easing.OutCubic } }

            // Ancho total de la fila y desplazamiento de esta tarjeta dentro de
            // ella. Se recalculan al cambiar la lista, no en cada frame.
            property real stackTotal: 0
            property real stackOffset: 0
            function relayout() {
                if (widgets.layoutMode !== "stack") return
                var total = 0, off = 0
                for (var i = 0; i < widgets.list.length; i++) {
                    var w = i === index ? implicitWidth : 148   // ancho típico
                    if (i < index) off += w + 14
                    total += w + (i < widgets.list.length - 1 ? 14 : 0)
                }
                stackTotal = total
                stackOffset = off
            }
            Component.onCompleted: relayout()
            onImplicitWidthChanged: relayout()

            // ── Tiempo, variante grande ──
            Item {
                anchors.fill: parent
                anchors.margins: Math.round(14 * card.k)
                visible: card.isWeather && card.large

                Column {
                    anchors.left: parent.left
                    anchors.top: parent.top
                    spacing: Math.round(2 * card.k)

                    Row {
                        spacing: Math.round(6 * card.k)
                        Text {
                            text: widgets.wxCity !== "" ? widgets.wxCity : "—"
                            font.pixelSize: Math.round(15 * card.k)
                            font.weight: Font.Medium
                            color: "#ffffff"
                        }
                        WxIcon {
                            width: Math.round(15 * card.k); height: width
                            anchors.verticalCenter: parent.verticalCenter
                            kind: widgets.wxEffective
                            color: "#ffffff"
                        }
                    }
                    Text {
                        text: widgets.wxTemp + "ºC"
                        font.pixelSize: Math.round(34 * card.k)
                        font.weight: Font.Normal
                        color: "#ffffff"
                    }
                }

                // Previsión: siete columnas repartidas a lo ancho.
                Row {
                    anchors.bottom: parent.bottom
                    anchors.horizontalCenter: parent.horizontalCenter
                    spacing: Math.round(10 * card.k)
                    visible: widgets.wxDays.length > 0

                    Repeater {
                        model: widgets.wxDays
                        delegate: Column {
                            required property var modelData
                            spacing: Math.round(3 * card.k)
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: modelData.d || ""
                                font.pixelSize: Math.round(11 * card.k)
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }
                            WxIcon {
                                anchors.horizontalCenter: parent.horizontalCenter
                                width: Math.round(15 * card.k); height: width
                                kind: modelData.s || "clear"
                                color: Qt.rgba(1, 1, 1, 0.9)
                            }
                            Text {
                                anchors.horizontalCenter: parent.horizontalCenter
                                text: (modelData.t || "") + "ºC"
                                font.pixelSize: Math.round(11 * card.k)
                                color: Qt.rgba(1, 1, 1, 0.85)
                            }
                        }
                    }
                }
            }

            Row {
                id: content
                anchors.centerIn: parent
                visible: !(card.isWeather && card.large)
                spacing: 12

                // ── Batería: anillo de carga ──
                Item {
                    width: card.isBattery ? 52 : 0
                    height: 52
                    visible: card.isBattery
                    anchors.verticalCenter: parent.verticalCenter

                    Canvas {
                        anchors.fill: parent
                        renderTarget: Canvas.FramebufferObject
                        property real pct: parseFloat(widgets.battCapacity) / 100
                        onPctChanged: requestPaint()
                        onPaint: {
                            var ctx = getContext("2d")
                            ctx.reset()
                            var cx = width / 2, cy = height / 2, r = width / 2 - 4
                            ctx.lineWidth = 6
                            ctx.lineCap = "round"
                            ctx.strokeStyle = widgets.isDark ? "#3a3a3c" : "#d1d1d6"
                            ctx.beginPath(); ctx.arc(cx, cy, r, 0, Math.PI * 2); ctx.stroke()
                            if (pct > 0) {
                                ctx.strokeStyle = widgets.battStatus === "Charging" ? "#34C759"
                                                : pct <= 0.15 ? "#FF9500" : widgets.accent
                                ctx.beginPath()
                                ctx.arc(cx, cy, r, -Math.PI / 2, -Math.PI / 2 + Math.PI * 2 * pct)
                                ctx.stroke()
                            }
                        }
                    }
                    Text {
                        anchors.centerIn: parent
                        text: widgets.battCapacity
                        font.pixelSize: 15; font.weight: Font.Bold; color: widgets.fg
                    }
                }

                Text {
                    visible: card.isWeather
                    text: widgets.wxIcon
                    font.pixelSize: 34
                    anchors.verticalCenter: parent.verticalCenter
                }

                Column {
                    anchors.verticalCenter: parent.verticalCenter
                    spacing: 2
                    Text {
                        text: card.isBattery
                                ? (widgets.battStatus === "Charging" ? "Cargando" : "Batería")
                            : card.isWeather ? widgets.wxTemp + "°"
                            : new Date().toLocaleDateString(Qt.locale(widgets.localeName), "ddd").toUpperCase()
                        font.pixelSize: card.isDate ? 11 : (card.isWeather ? 22 : 14)
                        font.weight: card.isBattery ? Font.Medium : Font.Bold
                        color: card.isDate ? widgets.accent : widgets.fg
                    }
                    Text {
                        text: card.isBattery
                                ? (widgets.battTimeLeft !== "" ? widgets.battTimeLeft : widgets.battCapacity + " %")
                            : card.isWeather ? (widgets.wxDesc !== "" ? widgets.wxDesc : widgets.wxCity)
                            : String(new Date().getDate())
                        font.pixelSize: card.isDate ? 32 : 11
                        font.weight: card.isDate ? Font.Bold : Font.Normal
                        color: card.isDate ? widgets.fg : widgets.fg2
                    }
                }
            }
        }
    }
}
