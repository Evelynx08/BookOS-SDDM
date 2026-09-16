/*
 * BookOS — icono meteorológico (Heroicons outline).
 *
 * Los trazos vienen de BookOS-HIG/heroicons/24/outline. El HIG manda subir su
 * stroke-width de 1.5 a 2 al integrarlos, que es lo que hace `strokeWidth`.
 *
 * Se dibuja con Shapes y no con una imagen SVG porque el greeter necesita
 * teñir el icono según el fondo, y un SVG cargado como Image no se puede
 * recolorear sin una capa de efecto por cada icono.
 */
import QtQuick 2.15
import QtQuick.Shapes 1.15

Item {
    id: ico

    // clear | clouds | partly | night | rain
    property string kind: "clear"
    property color color: "#ffffff"
    property real strokeWidth: 2

    implicitWidth: 24
    implicitHeight: 24

    // Los trazos están definidos en un lienzo de 24x24: se escala al tamaño
    // real para que el icono sirva igual a 18 px que a 40.
    readonly property real k: width / 24

    Shape {
        anchors.fill: parent
        preferredRendererType: Shape.CurveRenderer
        layer.enabled: true
        layer.samples: 4

        // ── Sol ──
        ShapePath {
            strokeColor: ico.color
            strokeWidth: ico.strokeWidth * ico.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: (ico.kind === "clear" || ico.kind === "partly")
                    ? "M12 3v2.25M18.364 5.636l-1.591 1.591M21 12h-2.25M18.364 18.364l-1.591-1.591M12 18.75V21M7.227 16.773l-1.591 1.591M5.25 12H3M7.227 7.227L5.636 5.636"
                    : ""
            }
        }
        ShapePath {
            strokeColor: ico.color
            strokeWidth: ico.strokeWidth * ico.k
            fillColor: "transparent"
            PathSvg {
                path: (ico.kind === "clear" || ico.kind === "partly")
                    ? "M15.75 12a3.75 3.75 0 1 1-7.5 0 3.75 3.75 0 0 1 7.5 0Z" : ""
            }
        }

        // ── Luna ──
        ShapePath {
            strokeColor: ico.color
            strokeWidth: ico.strokeWidth * ico.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: ico.kind === "night"
                    ? "M21.752 15.002A9.72 9.72 0 0 1 18 15.75c-5.385 0-9.75-4.365-9.75-9.75 0-1.33.266-2.597.748-3.752A9.753 9.753 0 0 0 3 11.25C3 16.635 7.365 21 12.75 21a9.753 9.753 0 0 0 9.002-5.998Z"
                    : ""
            }
        }

        // ── Nube. En "partly" se dibuja desplazada y algo menor, para que el
        //    sol asome por detrás sin necesitar un icono compuesto aparte. ──
        ShapePath {
            strokeColor: ico.color
            strokeWidth: ico.strokeWidth * ico.k
            fillColor: ico.kind === "partly" ? Qt.rgba(0, 0, 0, 0.001) : "transparent"
            capStyle: ShapePath.RoundCap
            joinStyle: ShapePath.RoundJoin
            PathSvg {
                path: (ico.kind === "clouds" || ico.kind === "partly" || ico.kind === "rain")
                    ? "M2.25 15a4.5 4.5 0 0 0 4.5 4.5H18a3.75 3.75 0 0 0 1.332-7.257 3 3 0 0 0-3.758-3.848 5.25 5.25 0 0 0-10.233 2.33A4.502 4.502 0 0 0 2.25 15Z"
                    : ""
            }
        }

        // ── Lluvia: tres trazos cortos bajo la nube ──
        ShapePath {
            strokeColor: ico.color
            strokeWidth: ico.strokeWidth * ico.k
            fillColor: "transparent"
            capStyle: ShapePath.RoundCap
            PathSvg {
                path: ico.kind === "rain"
                    ? "M7.5 20.5l-1 2.5M12 20.5l-1 2.5M16.5 20.5l-1 2.5" : ""
            }
        }
    }

    // El sol de "partly" se encoge y sube a la esquina para que la nube lo
    // solape: es el mismo recurso, no un icono nuevo.
    transform: Scale { }
}
