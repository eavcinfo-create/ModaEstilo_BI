# Crea copias del Excel de origen con N filas en Ventas y en Alquileres.
# Las filas se copian en ciclo desde el original; desde la segunda copia los numeros de pedido y alquiler
# llevan un sufijo (-00002, -00003...) para que no se repitan. Inspeccion lleva las devoluciones de los
# alquileres generados (y sus filas con error, en la misma proporcion). El Catalogo no cambia.
import sys, os
import datetime as dt
from openpyxl import load_workbook, Workbook
from openpyxl.cell import WriteOnlyCell

src, outdir = sys.argv[1], sys.argv[2]
tamanos = [int(x) for x in sys.argv[3].split(",")]
base = load_workbook(src)
os.makedirs(outdir, exist_ok=True)
datos = {ws.title: (list(next(ws.iter_rows(min_row=1, max_row=1, values_only=True))),
                    [[c.value for c in r] for r in ws.iter_rows(min_row=2)]) for ws in base.worksheets}

def fmt(ws, v):
    if isinstance(v, (dt.date, dt.datetime)):
        cel = WriteOnlyCell(ws, value=v); cel.number_format = "dd/mm/yyyy"; return cel
    return v

def clave(v): return str(v).strip().upper() if v is not None else ""
def sufijo(v, c): return v if c == 0 or v is None else f"{str(v).strip()}-{c:05d}"

def ciclo(rows, n):
    """Devuelve n filas copiando rows en ciclo, con el numero de copia."""
    out, c = [], 0
    while len(out) < n:
        for r in rows:
            if len(out) >= n: break
            out.append((c, r))
        c += 1
    return out

alq_base = {(clave(r[0]), clave(r[9])) for r in datos["Alquileres"][1]}
for n in tamanos:
    wb = Workbook(write_only=True)
    generados = {}
    for hoja in ["Catalogo", "Ventas", "Alquileres", "Inspeccion"]:
        cab, rows = datos[hoja]
        ws = wb.create_sheet(hoja); ws.append(cab)
        if hoja == "Catalogo":
            for r in rows: ws.append([fmt(ws, v) for v in r])
            continue
        if hoja in ("Ventas", "Alquileres"):
            lista = ciclo(rows, n)
            for c, r in lista:
                r2 = list(r); r2[0] = sufijo(r2[0], c)
                ws.append([fmt(ws, v) for v in r2])
                if hoja == "Alquileres": generados[(clave(r2[0]), clave(r2[9]))] = True
            continue
        # Inspeccion: por cada copia de alquileres, sus devoluciones
        copias = max(c for c, _ in ciclo(datos["Alquileres"][1], n)) + 1
        for c in range(copias):
            for r in rows:
                es_red = clave(r[0]).startswith("RED-")
                if not es_red and c > 0: continue                       # contratos OLTP solo una vez
                r2 = list(r); r2[0] = sufijo(r2[0], c) if es_red else r2[0]
                existe_en_base = (clave(r[0]), clave(r[1])) in alq_base
                if es_red and existe_en_base and (clave(r2[0]), clave(r2[1])) not in generados: continue
                ws.append([fmt(ws, v) for v in r2])
    ruta = os.path.join(outdir, f"Fuentes_ModaEstilo_{n}.xlsx")
    wb.save(ruta)
    print(n, "->", os.path.basename(ruta), round(os.path.getsize(ruta) / 1024), "KB")
