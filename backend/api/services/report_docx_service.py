from __future__ import annotations

from datetime import date, datetime, time
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence

from django.conf import settings

from docx import Document
from docx.enum.table import WD_CELL_VERTICAL_ALIGNMENT, WD_TABLE_ALIGNMENT
from docx.enum.text import WD_ALIGN_PARAGRAPH
from docx.oxml import OxmlElement
from docx.oxml.ns import qn
from docx.shared import Mm, Pt, RGBColor


DEFAULT_TEMPLATE_PATH = Path(getattr(settings, "BASE_DIR", Path("."))) / "api" / "assets" / "Modelo.docx"
EMU_PER_MM = 36000  # 1mm = 36000 EMU


def _fmt_date(v: Any) -> str:
    if v is None or v == "":
        return "--"
    if isinstance(v, (datetime, date)):
        try:
            return v.strftime("%d/%m/%Y")
        except Exception:
            return str(v)
    return str(v)


def _fmt_time(v: Any) -> str:
    if v is None or v == "":
        return "--"
    if isinstance(v, time):
        try:
            return v.strftime("%H:%M")
        except Exception:
            return str(v)
    s = str(v)
    if ":" in s and len(s) >= 5:
        return s[:5]
    return s


def _hex_to_rgb(hex_color: str) -> RGBColor:
    hx = (hex_color or "").strip().lstrip("#").upper()
    if len(hx) != 6:
        hx = "000000"
    return RGBColor.from_string(hx)


def _set_cell_shading(cell, fill_hex: str) -> None:
    fill = (fill_hex or "").strip().lstrip("#")
    if not fill:
        return
    tc_pr = cell._tc.get_or_add_tcPr()
    shd = OxmlElement("w:shd")
    shd.set(qn("w:val"), "clear")
    shd.set(qn("w:color"), "auto")
    shd.set(qn("w:fill"), fill)
    tc_pr.append(shd)


def _set_cell_text(
    cell,
    text: str,
    *,
    bold: bool = False,
    underline: bool = False,
    color_hex: Optional[str] = None,
    align: Optional[int] = None,
    font_size: Pt = Pt(9),
) -> None:
    cell.text = ""
    p = cell.paragraphs[0]
    if align is not None:
        p.alignment = align
    run = p.add_run("" if text is None else str(text))
    run.bold = bold
    run.underline = underline
    run.font.size = font_size
    if color_hex:
        run.font.color.rgb = _hex_to_rgb(color_hex)


def _add_field(paragraph, instr: str, *, font_size: Pt = Pt(8)) -> None:
    """
    Insere um field do Word (ex.: PAGE, NUMPAGES).
    Word recalcula ao abrir.
    """
    fld = OxmlElement("w:fldSimple")
    fld.set(qn("w:instr"), instr)

    r = OxmlElement("w:r")
    r_pr = OxmlElement("w:rPr")

    sz = OxmlElement("w:sz")
    sz.set(qn("w:val"), str(int(font_size.pt * 2)))  # half-points
    r_pr.append(sz)
    r.append(r_pr)

    t = OxmlElement("w:t")
    t.text = "1"  # placeholder; Word substitui ao atualizar campos
    r.append(t)

    fld.append(r)
    paragraph._p.append(fld)


def _apply_page_number_footer(doc: Document) -> None:
    """
    Adiciona "Página X de Y" no rodapé (sem remover o rodapé do Modelo.docx).
    """
    try:
        section = doc.sections[0]
    except Exception:
        return

    footer = section.footer
    p = footer.add_paragraph()
    p.alignment = WD_ALIGN_PARAGRAPH.RIGHT

    r1 = p.add_run("Página ")
    r1.font.size = Pt(8)

    _add_field(p, "PAGE", font_size=Pt(8))

    r2 = p.add_run(" de ")
    r2.font.size = Pt(8)

    _add_field(p, "NUMPAGES", font_size=Pt(8))


def _clear_document_body(doc: Document) -> None:
    """
    Remove todo conteúdo do BODY, mantendo sectPr (margens / headers / footers).
    """
    body = doc._element.body
    for child in list(body.iterchildren()):
        if child.tag == qn("w:sectPr"):
            continue
        body.remove(child)


def _usable_width_mm(doc: Document) -> float:
    section = doc.sections[0]
    return float(section.page_width - section.left_margin - section.right_margin) / EMU_PER_MM


def _calc_col_widths_mm(doc: Document, weights: List[float]) -> List[float]:
    wmm = _usable_width_mm(doc)
    total = sum(weights) if weights else 1
    return [(wmm * (w / total)) for w in weights]


def _add_table(doc: Document, *, rows: int, cols: int, col_widths_mm: List[float]):
    table = doc.add_table(rows=rows, cols=cols)
    try:
        table.style = "Table Grid"
    except Exception:
        pass

    table.alignment = WD_TABLE_ALIGNMENT.CENTER
    table.autofit = False

    for i, w in enumerate(col_widths_mm):
        for cell in table.columns[i].cells:
            cell.width = Mm(w)
            cell.vertical_alignment = WD_CELL_VERTICAL_ALIGNMENT.CENTER

    return table


def _add_total_row(doc: Document, total: int) -> None:
    widths = _calc_col_widths_mm(doc, [80, 20])
    tbl = _add_table(doc, rows=1, cols=2, col_widths_mm=widths)

    for j in range(2):
        _set_cell_shading(tbl.cell(0, j), "#dbeafe")

    _set_cell_text(tbl.cell(0, 0), "Total", bold=True, underline=True, font_size=Pt(10))
    _set_cell_text(
        tbl.cell(0, 1),
        str(total),
        bold=True,
        underline=True,
        align=WD_ALIGN_PARAGRAPH.RIGHT,
        font_size=Pt(10),
    )


def gerar_relatorio_operacoes_sessoes(
    sessoes: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    template_path = template_path or DEFAULT_TEMPLATE_PATH
    doc = Document(str(template_path)) if template_path and Path(template_path).exists() else Document()

    _clear_document_body(doc)
    _apply_page_number_footer(doc)

    title = doc.add_paragraph("Registros de Operação (Sessões)")
    try:
        title.style = "Heading 2"
    except Exception:
        pass

    if not sessoes:
        doc.add_paragraph("Nenhum registro encontrado para os filtros aplicados.")
        buf = BytesIO()
        doc.save(buf)
        return buf.getvalue()

    master_w = [90, 60, 200, 80, 80]  # Sala, Data, Autor, Checklist, Em Aberto
    master_cols = _calc_col_widths_mm(doc, master_w)

    ent_w = [35, 115, 65, 165, 45, 45, 45, 55]  # Nº, Operador, Tipo, Evento, Pauta, Início, Fim, Anormalidade
    ent_cols = _calc_col_widths_mm(doc, ent_w)

    for idx, s in enumerate(sessoes):
        t_master = _add_table(doc, rows=2, cols=5, col_widths_mm=master_cols)

        headers = ["Local", "Data", "1º Registro por", "Checklist?", "Em Aberto?"]
        for j, h in enumerate(headers):
            cell = t_master.cell(0, j)
            _set_cell_shading(cell, "#dbeafe")
            _set_cell_text(cell, h, bold=True, font_size=Pt(9))

        sala_txt = s.get("sala") or "--"
        data_txt = _fmt_date(s.get("data"))
        autor_txt = s.get("autor") or "--"

        verific_txt = str(s.get("verificacao") or "--").strip() or "--"
        verific_norm = verific_txt.lower()
        verific_color = "#16a34a" if verific_norm == "realizado" else "#64748b"

        em_txt = str(s.get("em_aberto") or "--").strip() or "--"
        em_norm = em_txt.lower()
        em_color = "#2563eb" if em_norm == "sim" else "#0f172a"

        values = [
            (str(sala_txt), True, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(data_txt), True, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(autor_txt), True, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(verific_txt), True, verific_color, WD_ALIGN_PARAGRAPH.LEFT),
            (str(em_txt), True, em_color, WD_ALIGN_PARAGRAPH.LEFT),
        ]

        for j, (txt, bold, color, align) in enumerate(values):
            cell = t_master.cell(1, j)
            _set_cell_shading(cell, "#f8fafc")
            _set_cell_text(cell, txt, bold=bold, color_hex=color, align=align, font_size=Pt(9))

        doc.add_paragraph("")

        bar = _add_table(doc, rows=1, cols=1, col_widths_mm=_calc_col_widths_mm(doc, [100]))
        _set_cell_shading(bar.cell(0, 0), "#e0f2fe")
        _set_cell_text(bar.cell(0, 0), "Entradas da Operação:", bold=True, font_size=Pt(9))

        entradas = s.get("entradas") or []
        t_ent = _add_table(doc, rows=1 + (len(entradas) if entradas else 1), cols=8, col_widths_mm=ent_cols)

        ent_headers = ["Nº", "Operador", "Tipo", "Evento", "Pauta", "Início", "Fim", "Anormalidade?"]
        for j, h in enumerate(ent_headers):
            cell = t_ent.cell(0, j)
            _set_cell_shading(cell, "#bfdbfe")
            _set_cell_text(cell, h, bold=True, font_size=Pt(8))

        if entradas:
            for i, ent in enumerate(entradas, start=1):
                ordem = ent.get("ordem")
                ordem_txt = f"{ordem}º" if ordem is not None and str(ordem) != "" else "--"

                anom = bool(ent.get("anormalidade"))
                anom_txt = "SIM" if anom else "Não"
                anom_color = "#dc2626" if anom else "#16a34a"

                row_vals = [
                    (ordem_txt, None, WD_ALIGN_PARAGRAPH.CENTER),
                    (ent.get("operador") or "--", None, WD_ALIGN_PARAGRAPH.LEFT),
                    (ent.get("tipo") or "--", None, WD_ALIGN_PARAGRAPH.LEFT),
                    (ent.get("evento") or "--", None, WD_ALIGN_PARAGRAPH.LEFT),
                    (_fmt_time(ent.get("pauta")), None, WD_ALIGN_PARAGRAPH.CENTER),
                    (_fmt_time(ent.get("inicio")), None, WD_ALIGN_PARAGRAPH.CENTER),
                    (_fmt_time(ent.get("fim")), None, WD_ALIGN_PARAGRAPH.CENTER),
                    (anom_txt, anom_color, WD_ALIGN_PARAGRAPH.CENTER),
                ]

                for j, (txt, color, align) in enumerate(row_vals):
                    _set_cell_text(
                        t_ent.cell(i, j),
                        str(txt),
                        color_hex=color,
                        align=align,
                        font_size=Pt(8),
                        bold=(j == 7),
                    )
        else:
            c = t_ent.cell(1, 0)
            _set_cell_text(c, "Nenhuma entrada registrada nesta sessão.", font_size=Pt(8))
            for j in range(1, 8):
                c = c.merge(t_ent.cell(1, j))

        if idx < len(sessoes) - 1:
            doc.add_paragraph("")
            doc.add_paragraph("")

    doc.add_paragraph("")
    _add_total_row(doc, total=len(sessoes))

    buf = BytesIO()
    doc.save(buf)
    return buf.getvalue()


def gerar_relatorio_operacoes_entradas(
    entradas: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    template_path = template_path or DEFAULT_TEMPLATE_PATH
    doc = Document(str(template_path)) if template_path and Path(template_path).exists() else Document()

    _clear_document_body(doc)
    _apply_page_number_footer(doc)

    title = doc.add_paragraph("Registros de Operação (Sessões)")
    try:
        title.style = "Heading 2"
    except Exception:
        pass

    if not entradas:
        doc.add_paragraph("Nenhum registro encontrado para os filtros aplicados.")
        buf = BytesIO()
        doc.save(buf)
        return buf.getvalue()

    base_w = [80, 60, 110, 70, 170, 45, 45, 45, 70]
    colw = _calc_col_widths_mm(doc, base_w)

    tbl = _add_table(doc, rows=1 + len(entradas), cols=9, col_widths_mm=colw)

    headers = ["Local", "Data", "Operador", "Tipo", "Evento", "Pauta", "Início", "Fim", "Anormalidade?"]
    for j, h in enumerate(headers):
        cell = tbl.cell(0, j)
        _set_cell_shading(cell, "#dbeafe")
        _set_cell_text(cell, h, bold=True, font_size=Pt(8))

    for i, r in enumerate(entradas, start=1):
        anom = bool(r.get("anormalidade"))
        anom_txt = "SIM" if anom else "Não"
        anom_color = "#dc2626" if anom else "#16a34a"

        row = [
            (r.get("sala") or "--", WD_ALIGN_PARAGRAPH.LEFT, True, None),
            (_fmt_date(r.get("data")), WD_ALIGN_PARAGRAPH.LEFT, False, None),
            (r.get("operador") or "--", WD_ALIGN_PARAGRAPH.LEFT, False, None),
            (r.get("tipo") or "--", WD_ALIGN_PARAGRAPH.LEFT, False, None),
            (r.get("evento") or "--", WD_ALIGN_PARAGRAPH.LEFT, False, None),
            (_fmt_time(r.get("pauta")), WD_ALIGN_PARAGRAPH.CENTER, False, None),
            (_fmt_time(r.get("inicio")), WD_ALIGN_PARAGRAPH.CENTER, False, None),
            (_fmt_time(r.get("fim")), WD_ALIGN_PARAGRAPH.CENTER, False, None),
            (anom_txt, WD_ALIGN_PARAGRAPH.CENTER, True, anom_color),
        ]

        for j, (txt, align, bold, color) in enumerate(row):
            _set_cell_text(tbl.cell(i, j), str(txt), bold=(bold if j in (0, 8) else False), color_hex=color, align=align, font_size=Pt(8))

    doc.add_paragraph("")
    _add_total_row(doc, total=len(entradas))

    buf = BytesIO()
    doc.save(buf)
    return buf.getvalue()


def gerar_relatorio_anormalidades(
    anormalidades: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    template_path = template_path or DEFAULT_TEMPLATE_PATH
    doc = Document(str(template_path)) if template_path and Path(template_path).exists() else Document()

    _clear_document_body(doc)
    _apply_page_number_footer(doc)

    title = doc.add_paragraph("Relatórios de Anormalidades")
    try:
        title.style = "Heading 2"
    except Exception:
        pass

    if not anormalidades:
        doc.add_paragraph("Nenhum registro encontrado para os filtros aplicados.")
        buf = BytesIO()
        doc.save(buf)
        return buf.getvalue()

    base_w = [70, 60, 110, 170, 70, 60, 70]
    colw = _calc_col_widths_mm(doc, base_w)

    tbl = _add_table(doc, rows=1 + len(anormalidades), cols=7, col_widths_mm=colw)

    headers = ["Data", "Local", "Registrado por", "Descrição", "Solucionada", "Prejuízo", "Reclamação"]
    for j, h in enumerate(headers):
        cell = tbl.cell(0, j)
        _set_cell_shading(cell, "#dbeafe")
        _set_cell_text(cell, h, bold=True, font_size=Pt(8))

    for i, r in enumerate(anormalidades, start=1):
        solucionada = bool(r.get("solucionada"))
        preju = bool(r.get("houve_prejuizo"))
        recl = bool(r.get("houve_reclamacao"))

        sol_txt = "Sim" if solucionada else "Não"
        sol_color = "#16a34a" if solucionada else "#dc2626"

        prej_txt = "Sim" if preju else "Não"
        prej_color = "#dc2626" if preju else "#64748b"

        recl_txt = "Sim" if recl else "Não"
        recl_color = "#dc2626" if recl else "#64748b"

        row = [
            (_fmt_date(r.get("data")), None),
            (r.get("sala") or "--", None),
            (r.get("registrado_por") or "--", None),
            (r.get("descricao") or "--", None),
            (sol_txt, sol_color),
            (prej_txt, prej_color),
            (recl_txt, recl_color),
        ]

        for j, (txt, color) in enumerate(row):
            align = WD_ALIGN_PARAGRAPH.CENTER if j >= 4 else WD_ALIGN_PARAGRAPH.LEFT
            bold = True if j >= 4 else False
            _set_cell_text(tbl.cell(i, j), str(txt), bold=bold, color_hex=color, align=align, font_size=Pt(8))

    doc.add_paragraph("")
    _add_total_row(doc, total=len(anormalidades))

    buf = BytesIO()
    doc.save(buf)
    return buf.getvalue()

def gerar_relatorio_operadores(
    operadores: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """Gera DOCX para a tabela "Operadores de Áudio" (dashboard)."""
    template_path = template_path or DEFAULT_TEMPLATE_PATH
    doc = Document(str(template_path)) if template_path and Path(template_path).exists() else Document()

    _clear_document_body(doc)
    _apply_page_number_footer(doc)

    title = doc.add_paragraph("Operadores de Áudio")
    try:
        title.style = "Heading 2"
    except Exception:
        pass

    if not operadores:
        doc.add_paragraph("Nenhum registro encontrado para os filtros aplicados.")
        buf = BytesIO()
        doc.save(buf)
        return buf.getvalue()

    # Nome | E-mail
    colw = _calc_col_widths_mm(doc, [60, 40])
    tbl = _add_table(doc, rows=1 + len(operadores), cols=2, col_widths_mm=colw)

    headers = ["Nome", "E-mail"]
    for j, h in enumerate(headers):
        cell = tbl.cell(0, j)
        _set_cell_shading(cell, "#dbeafe")
        _set_cell_text(cell, h, bold=True, font_size=Pt(9))

    for i, op in enumerate(operadores, start=1):
        nome = op.get("nome_completo") or op.get("nome") or "--"
        email = op.get("email") or "--"

        _set_cell_text(tbl.cell(i, 0), str(nome), align=WD_ALIGN_PARAGRAPH.LEFT, font_size=Pt(9))
        _set_cell_text(tbl.cell(i, 1), str(email), align=WD_ALIGN_PARAGRAPH.LEFT, font_size=Pt(9))

    doc.add_paragraph("")
    _add_total_row(doc, total=len(operadores))

    buf = BytesIO()
    doc.save(buf)
    return buf.getvalue()


def gerar_relatorio_checklists(
    checklists: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """Gera DOCX para a tabela "Verificação de Plenários" (dashboard), com detalhes sempre expandidos."""
    template_path = template_path or DEFAULT_TEMPLATE_PATH
    doc = Document(str(template_path)) if template_path and Path(template_path).exists() else Document()

    _clear_document_body(doc)
    _apply_page_number_footer(doc)

    title = doc.add_paragraph("Verificação de Plenários")
    try:
        title.style = "Heading 2"
    except Exception:
        pass

    if not checklists:
        doc.add_paragraph("Nenhum registro encontrado para os filtros aplicados.")
        buf = BytesIO()
        doc.save(buf)
        return buf.getvalue()

    # Tabela principal (colunas do dashboard)
    master_w = [70, 60, 150, 45, 50, 60, 50]  # Sala, Data, Verificado por, Início, Término, Duração, Status
    master_cols = _calc_col_widths_mm(doc, master_w)

    # Subtabela (itens)
    itens_w = [45, 15, 40]  # Item, Status, Descrição da Falha
    itens_cols = _calc_col_widths_mm(doc, itens_w)

    for idx, chk in enumerate(checklists):
        itens = chk.get("itens") or []

        # Status geral: se tiver pelo menos 1 Falha => Falha (vermelho); senão Ok (verde)
        has_failure = any(str(it.get("status") or "").strip().lower() == "falha" for it in itens)
        status_txt = "Falha" if has_failure else "Ok"
        status_color = "#dc2626" if has_failure else "#16a34a"

        # --- 1) Linha principal (tabela com header + valores)
        t_master = _add_table(doc, rows=2, cols=7, col_widths_mm=master_cols)

        headers = ["Local", "Data", "Verificado por", "Início", "Término", "Duração", "Status"]
        for j, h in enumerate(headers):
            cell = t_master.cell(0, j)
            _set_cell_shading(cell, "#dbeafe")
            _set_cell_text(cell, h, bold=True, font_size=Pt(8))

        sala = chk.get("sala_nome") or chk.get("sala") or "--"
        data_txt = _fmt_date(chk.get("data"))
        operador = chk.get("operador") or "--"
        inicio = _fmt_time(chk.get("inicio"))
        termino = _fmt_time(chk.get("termino"))
        duracao = chk.get("duracao") or "--"

        row_vals = [
            (str(sala), True, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(data_txt), False, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(operador), False, None, WD_ALIGN_PARAGRAPH.LEFT),
            (str(inicio), False, None, WD_ALIGN_PARAGRAPH.CENTER),
            (str(termino), False, None, WD_ALIGN_PARAGRAPH.CENTER),
            (str(duracao), False, None, WD_ALIGN_PARAGRAPH.CENTER),
            (str(status_txt), True, status_color, WD_ALIGN_PARAGRAPH.CENTER),
        ]

        for j, (txt, bold, color, align) in enumerate(row_vals):
            cell = t_master.cell(1, j)
            _set_cell_shading(cell, "#f8fafc")
            _set_cell_text(cell, txt, bold=bold, color_hex=color, align=align, font_size=Pt(8))

        doc.add_paragraph("")

        # --- 2) Barra "Detalhes da Verificação"
        bar = _add_table(doc, rows=1, cols=1, col_widths_mm=_calc_col_widths_mm(doc, [100]))
        _set_cell_shading(bar.cell(0, 0), "#e0f2fe")
        _set_cell_text(bar.cell(0, 0), "Detalhes da Verificação:", bold=True, font_size=Pt(9))

        # --- 3) Tabela de itens (sempre expandida)
        # Se não houver itens, ainda renderiza a tabela com uma linha dizendo isso.
        rows_count = 1 + (len(itens) if itens else 1)
        t_itens = _add_table(doc, rows=rows_count, cols=3, col_widths_mm=itens_cols)

        itens_headers = ["Item verificado", "Status", "Descrição"]
        for j, h in enumerate(itens_headers):
            cell = t_itens.cell(0, j)
            _set_cell_shading(cell, "#bfdbfe")
            _set_cell_text(cell, h, bold=True, font_size=Pt(8))

        if itens:
            for i, it in enumerate(itens, start=1):
                is_text = (it.get("tipo_widget") or "radio") == "text"

                if is_text:
                    st = "Texto"
                    st_color = "#334155"
                    desc_txt = it.get("valor_texto")
                    desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"
                else:
                    st = str(it.get("status") or "--").strip() or "--"
                    st_lower = st.lower()
                    if st_lower == "falha":
                        st_color = "#dc2626"
                    elif st_lower == "ok":
                        st_color = "#16a34a"
                    else:
                        st_color = "#334155"
                    desc_txt = it.get("falha")
                    desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"

                _set_cell_text(
                    t_itens.cell(i, 0),
                    str(it.get("item") or "--"),
                    align=WD_ALIGN_PARAGRAPH.LEFT,
                    font_size=Pt(8),
                )
                _set_cell_text(
                    t_itens.cell(i, 1),
                    st,
                    bold=True,
                    color_hex=st_color,
                    align=WD_ALIGN_PARAGRAPH.CENTER,
                    font_size=Pt(8),
                )
                _set_cell_text(
                    t_itens.cell(i, 2),
                    str(desc_txt),
                    align=WD_ALIGN_PARAGRAPH.LEFT,
                    font_size=Pt(8),
                )
        else:
            _set_cell_text(t_itens.cell(1, 0), "Nenhum item encontrado.", font_size=Pt(8))
            t_itens.cell(1, 0).merge(t_itens.cell(1, 1))
            t_itens.cell(1, 0).merge(t_itens.cell(1, 2))

        # Espaço entre grupos (mas não depois do último)
        if idx < len(checklists) - 1:
            doc.add_paragraph("")
            doc.add_paragraph("")

    doc.add_paragraph("")
    _add_total_row(doc, total=len(checklists))

    buf = BytesIO()
    doc.save(buf)
    return buf.getvalue()