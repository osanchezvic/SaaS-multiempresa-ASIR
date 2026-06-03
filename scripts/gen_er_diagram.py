#!/usr/bin/env python3
"""Genera el diagrama ER de users_db en formato draw.io (.drawio / mxGraph XML).

Refleja infra/users-db/init.sql con las cardinalidades mínimas corregidas:
  - usuarios.empresa_id es NULL  -> usuario pertenece a 0..1 empresa
  - empresas puede tener 0 servicios contratados -> 0..N
  - un usuario puede no tener logs -> 0..N
"""

HEADER = 30
ROW = 30
W = 260
C1, C2, C3 = 70, 150, 40  # ancho de columnas: tipo / nombre / clave

# (titulo, x, y, [(tipo, nombre, clave), ...])
TABLES = [
    ("usuarios", 700, 40, [
        ("int", "id", "PK"),
        ("int", "empresa_id", "FK"),
        ("varchar", "empresa", ""),
        ("varchar", "usuario", ""),
        ("varchar", "hash_password", ""),
        ("varchar", "rol", ""),
        ("tinyint", "es_admin", ""),
        ("enum", "estado", ""),
        ("timestamp", "created_at", ""),
    ]),
    ("access_logs", 1100, 180, [
        ("int", "id", "PK"),
        ("int", "usuario_id", "FK"),
        ("varchar", "accion", ""),
        ("varchar", "ip_address", ""),
        ("timestamp", "fecha", ""),
    ]),
    ("empresas", 40, 440, [
        ("int", "id", "PK"),
        ("varchar", "nombre", ""),
        ("text", "descripcion", ""),
        ("enum", "estado", ""),
        ("timestamp", "created_at", ""),
    ]),
    ("servicios_contratados", 560, 660, [
        ("int", "id", "PK"),
        ("int", "empresa_id", "FK"),
        ("varchar", "nombre_servicio", ""),
        ("varchar", "tipo", ""),
        ("int", "puerto", ""),
        ("varchar", "url_admin", ""),
        ("enum", "estado", ""),
        ("timestamp", "fecha_contratacion", ""),
    ]),
]

# (source, target, etiqueta, startArrow=lado source, endArrow=lado target)
EDGES = [
    ("empresas", "usuarios", "tiene (0..N)", "ERzeroToOne", "ERzeroToMany"),
    ("empresas", "servicios_contratados", "contrata (0..N)", "ERmandOne", "ERzeroToMany"),
    ("usuarios", "access_logs", "genera (0..N)", "ERmandOne", "ERzeroToMany"),
]

TABLE_STYLE = ("shape=table;startSize=30;container=1;collapsible=0;childLayout=tableLayout;"
               "fixedRows=1;rowLines=1;fontSize=13;fontStyle=1;align=center;"
               "fillColor=#eeeee9;strokeColor=#666666;")
ROW_STYLE = ("shape=tableRow;horizontal=0;startSize=0;swimlaneHead=0;swimlaneBody=0;"
             "strokeColor=inherit;top=0;left=0;bottom=0;right=0;collapsible=0;"
             "dropTarget=0;fillColor=none;points=[[0,0.5],[1,0.5]];"
             "portConstraint=eastwest;fontSize=12;fontStyle=0;")
CELL_STYLE = ("shape=partialRectangle;overflow=hidden;connectable=0;fillColor=none;"
              "top=0;left=0;bottom=0;right=0;pointerEvents=1;fontSize=12;align=left;"
              "spacingLeft=6;fontStyle=0;")
EDGE_STYLE = ("edgeStyle=entityRelationEdgeStyle;fontSize=12;html=1;endFill=0;"
              "rounded=0;strokeColor=#666666;labelBackgroundColor=#e8b3a8;")


def esc(s):
    return s.replace("&", "&amp;").replace("<", "&lt;").replace(">", "&gt;")


def cell(cid, value, parent, x, w, style):
    return (f'        <mxCell id="{cid}" value="{esc(value)}" style="{style}" '
            f'vertex="1" parent="{parent}">\n'
            f'          <mxGeometry x="{x}" width="{w}" height="{ROW}" as="geometry">\n'
            f'            <mxRectangle width="{w}" height="{ROW}" as="alternateBounds"/>\n'
            f'          </mxGeometry>\n        </mxCell>\n')


def build():
    out = []
    out.append('<mxfile host="app.diagrams.net">\n')
    out.append('  <diagram name="ER users_db" id="er-users-db">\n')
    out.append('    <mxGraphModel dx="1200" dy="800" grid="1" gridSize="10" '
               'guides="1" tooltips="1" connect="1" arrows="1" fold="1" page="1" '
               'pageScale="1" pageWidth="1600" pageHeight="1100" math="0" shadow="0">\n')
    out.append('      <root>\n')
    out.append('        <mxCell id="0"/>\n')
    out.append('        <mxCell id="1" parent="0"/>\n')

    for title, x, y, cols in TABLES:
        h = HEADER + ROW * len(cols)
        out.append(f'        <mxCell id="{title}" value="{esc(title)}" '
                   f'style="{TABLE_STYLE}" vertex="1" parent="1">\n'
                   f'          <mxGeometry x="{x}" y="{y}" width="{W}" height="{h}" '
                   f'as="geometry"/>\n        </mxCell>\n')
        for i, (tipo, nombre, clave) in enumerate(cols):
            rid = f"{title}-r{i}"
            out.append(f'        <mxCell id="{rid}" value="" style="{ROW_STYLE}" '
                       f'vertex="1" parent="{title}">\n'
                       f'          <mxGeometry y="{HEADER + ROW * i}" width="{W}" '
                       f'height="{ROW}" as="geometry"/>\n        </mxCell>\n')
            out.append(cell(f"{rid}-c1", tipo, rid, 0, C1, CELL_STYLE))
            out.append(cell(f"{rid}-c2", nombre, rid, C1, C2, CELL_STYLE))
            out.append(cell(f"{rid}-c3", clave, rid, C1 + C2, C3,
                            CELL_STYLE + "align=center;spacingLeft=0;fontStyle=1;"))

    for i, (src, tgt, label, sarrow, earrow) in enumerate(EDGES):
        style = f"{EDGE_STYLE}startArrow={sarrow};endArrow={earrow};"
        out.append(f'        <mxCell id="edge{i}" value="{esc(label)}" style="{style}" '
                   f'edge="1" parent="1" source="{src}" target="{tgt}">\n'
                   f'          <mxGeometry relative="1" as="geometry"/>\n'
                   f'        </mxCell>\n')

    out.append('      </root>\n    </mxGraphModel>\n  </diagram>\n</mxfile>\n')
    return "".join(out)


if __name__ == "__main__":
    import sys
    dest = sys.argv[1] if len(sys.argv) > 1 else "docs/er-users-db.drawio"
    with open(dest, "w", encoding="utf-8") as f:
        f.write(build())
    print(f"Escrito {dest}")
