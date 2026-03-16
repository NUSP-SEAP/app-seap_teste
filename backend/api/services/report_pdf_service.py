from __future__ import annotations

from io import BytesIO
from pathlib import Path
from typing import Any, Callable, Dict, List, Optional, Sequence, Tuple
from xml.sax.saxutils import escape as xml_escape

from django.conf import settings

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle, KeepTogether
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm

from .utils import fmt_date, fmt_time
from . import report_config as cfg

try:
    import fitz  # PyMuPDF
except Exception:
    fitz = None


DEFAULT_TEMPLATE_PATH = Path(getattr(settings, "BASE_DIR", Path("."))) / "api" / "assets" / "Modelo.pdf"

# Margens (em pontos) ajustadas para não colidir com cabeçalho/rodapé do Modelo.pdf
TOP_MARGIN = 170
BOTTOM_MARGIN = 90
LEFT_MARGIN = 40
RIGHT_MARGIN = 40

PAGE_WIDTH = A4[0] - LEFT_MARGIN - RIGHT_MARGIN


# ---------------------------------------------------------------------------
# Helpers internos
# ---------------------------------------------------------------------------

def _hex(c: colors.Color) -> str:
    hx = c.hexval()
    if hx.startswith("0x"):
        return "#" + hx[2:]
    return hx


def _txt(v: Any) -> str:
    return xml_escape("" if v is None else str(v))


def _scale_weights(weights: List[int]) -> List[float]:
    scale = PAGE_WIDTH / sum(weights)
    return [w * scale for w in weights]


def _base_table_style(
    header_bg: str = cfg.HEADER_FILL,
    valign: str = "MIDDLE",
    pad: int = 4,
    left_pad: Optional[int] = None,
    right_pad: Optional[int] = None,
) -> List[Tuple]:
    lp = left_pad if left_pad is not None else pad
    rp = right_pad if right_pad is not None else pad
    return [
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor(header_bg)),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor(cfg.GRID_COLOR)),
        ("VALIGN", (0, 0), (-1, -1), valign),
        ("LEFTPADDING", (0, 0), (-1, -1), lp),
        ("RIGHTPADDING", (0, 0), (-1, -1), rp),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]


def _data_row_style(pad: int = 4) -> List[Tuple]:
    return [
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(cfg.DATA_ROW_FILL)),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor(cfg.GRID_COLOR)),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), pad),
        ("RIGHTPADDING", (0, 0), (-1, -1), pad),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]


def _detail_bar_style() -> List[Tuple]:
    return [
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(cfg.DETAIL_BAR_FILL)),
        ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor(cfg.GRID_COLOR)),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]


def _bool_paragraph(value: bool, normal: ParagraphStyle, *, true_text: str = "Sim", false_text: str = "Não",
                     true_color: str = cfg.COLOR_GREEN, false_color: str = cfg.COLOR_RED) -> Paragraph:
    txt = true_text if value else false_text
    color = true_color if value else false_color
    return Paragraph(f'<font color="{color}"><b>{txt}</b></font>', normal)


# ---------------------------------------------------------------------------
# Estilos reutilizáveis (factory — ReportLab exige nomes únicos por story)
# ---------------------------------------------------------------------------

def _make_styles(font_size: int = 9, leading: int = 11):
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=font_size, leading=leading)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor(cfg.COLOR_DARK))
    return styles, title_style, normal, header_style


# ---------------------------------------------------------------------------
# Canvas com numeração de páginas
# ---------------------------------------------------------------------------

class NumberedCanvas(canvas.Canvas):
    def __init__(self, *args, **kwargs):
        super().__init__(*args, **kwargs)
        self._saved_page_states = []

    def showPage(self):
        self._saved_page_states.append(dict(self.__dict__))
        self._startPage()

    def save(self):
        total = len(self._saved_page_states)
        for state in self._saved_page_states:
            self.__dict__.update(state)
            self._draw_page_number(total)
            canvas.Canvas.showPage(self)
        canvas.Canvas.save(self)

    def _draw_page_number(self, total_pages: int):
        w, h = self._pagesize
        x = w - RIGHT_MARGIN
        y = 12 * mm
        self.setFont("Helvetica", 8)
        self.drawRightString(x, y, f"Página {self._pageNumber} de {total_pages}")


# ---------------------------------------------------------------------------
# Infraestrutura de geração
# ---------------------------------------------------------------------------

def _build_content_pdf(story: List[Any]) -> bytes:
    buf = BytesIO()
    doc = SimpleDocTemplate(
        buf,
        pagesize=A4,
        topMargin=TOP_MARGIN,
        bottomMargin=BOTTOM_MARGIN,
        leftMargin=LEFT_MARGIN,
        rightMargin=RIGHT_MARGIN,
        title="Relatório",
    )
    doc.build(story, canvasmaker=NumberedCanvas)
    return buf.getvalue()


def _append_total_row(story: List[Any], *, total: int, text_style: ParagraphStyle) -> None:
    story.append(Spacer(1, 10))

    data = [[
        Paragraph("<b><u>Total</u></b>", text_style),
        Paragraph(f"<b><u>{total}</u></b>", text_style),
    ]]

    tbl = Table(data, colWidths=[PAGE_WIDTH * 0.80, PAGE_WIDTH * 0.20])
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor(cfg.HEADER_FILL)),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor(cfg.GRID_COLOR)),
        ("LINEBELOW", (0, 0), (-1, 0), 1, colors.black),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("ALIGN", (1, 0), (1, 0), "RIGHT"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 5),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 5),
    ]))
    story.append(tbl)


def _merge_with_template(content_pdf: bytes, template_path: Optional[Path] = None) -> bytes:
    template_path = template_path or DEFAULT_TEMPLATE_PATH

    if not template_path or not Path(template_path).exists():
        return content_pdf

    if fitz is None:
        raise RuntimeError(
            "PyMuPDF (pymupdf) não está instalado, mas é necessário para aplicar o Modelo.pdf."
        )

    tmpl_doc = fitz.open(str(template_path))
    content_doc = fitz.open("pdf", content_pdf)

    out = fitz.open()
    rect = tmpl_doc[0].rect

    for i in range(content_doc.page_count):
        page = out.new_page(width=rect.width, height=rect.height)
        page.show_pdf_page(rect, tmpl_doc, 0)
        page.show_pdf_page(rect, content_doc, i)

    return out.tobytes()


# ---------------------------------------------------------------------------
# Relatório flat genérico (tabela simples com header + N linhas de dados)
# ---------------------------------------------------------------------------

def _build_flat_report(
    title: str,
    rows: Sequence[Dict[str, Any]],
    headers: List[str],
    weights: List[int],
    row_builder: Callable[[Dict[str, Any], ParagraphStyle], List[Any]],
    template_path: Optional[Path],
    *,
    font_size: int = 9,
    leading: int = 11,
    valign: str = "MIDDLE",
    extra_style_cmds: Optional[List[Tuple]] = None,
    pad: int = 6,
) -> bytes:
    _, title_style, normal, header_style = _make_styles(font_size, leading)

    story: List[Any] = []
    story.append(Paragraph(title, title_style))

    if not rows:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    colw = _scale_weights(weights)

    data: List[List[Any]] = [
        [Paragraph(f"<b>{h}</b>", header_style) for h in headers]
    ]

    for r in rows:
        data.append(row_builder(r, normal))

    tbl = Table(data, colWidths=colw, repeatRows=1)
    style_cmds = _base_table_style(valign=valign, left_pad=pad, right_pad=pad)
    if extra_style_cmds:
        style_cmds = style_cmds + extra_style_cmds
    tbl.setStyle(TableStyle(style_cmds))
    story.append(tbl)

    _append_total_row(story, total=len(rows), text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)


# ---------------------------------------------------------------------------
# Relatórios públicos — flat (tabela simples)
# ---------------------------------------------------------------------------

def gerar_relatorio_operadores(
    operadores: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    def row_builder(op: Dict[str, Any], normal: ParagraphStyle) -> List[Any]:
        return [
            Paragraph(_txt(op.get("nome_completo") or op.get("nome") or ""), normal),
            Paragraph(_txt(op.get("email") or ""), normal),
        ]

    return _build_flat_report(
        "Operadores de Áudio", operadores,
        headers=["Nome", "E-mail"],
        weights=cfg.COLS_OPERADORES,
        row_builder=row_builder,
        template_path=template_path,
        font_size=10, leading=12,
    )


def gerar_relatorio_anormalidades(
    anormalidades: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    def row_builder(r: Dict[str, Any], normal: ParagraphStyle) -> List[Any]:
        solucionada = bool(r.get("solucionada"))
        preju = bool(r.get("houve_prejuizo"))
        recl = bool(r.get("houve_reclamacao"))

        return [
            Paragraph(_txt(fmt_date(r.get("data"))), normal),
            Paragraph(_txt(r.get("sala") or ""), normal),
            Paragraph(_txt(r.get("registrado_por") or ""), normal),
            Paragraph(_txt(r.get("descricao") or ""), normal),
            _bool_paragraph(solucionada, normal),
            _bool_paragraph(preju, normal, true_color=cfg.COLOR_RED, false_color=cfg.COLOR_MUTED),
            _bool_paragraph(recl, normal, true_color=cfg.COLOR_RED, false_color=cfg.COLOR_MUTED),
        ]

    return _build_flat_report(
        "Relatórios de Anormalidades", anormalidades,
        headers=["Data", "Local", "Registrado por", "Descrição", "Solucionada", "Prejuízo", "Reclamação"],
        weights=cfg.COLS_ANORMALIDADES,
        row_builder=row_builder,
        template_path=template_path,
        valign="TOP", pad=5,
    )


def gerar_relatorio_operacoes_entradas(
    entradas: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    def row_builder(r: Dict[str, Any], normal: ParagraphStyle) -> List[Any]:
        anom = bool(r.get("anormalidade"))
        anom_color = colors.red if anom else colors.green
        anom_txt = "SIM" if anom else "Não"

        return [
            Paragraph(f"<b>{_txt(r.get('sala') or '--')}</b>", normal),
            Paragraph(_txt(fmt_date(r.get("data"))), normal),
            Paragraph(_txt(r.get("operador") or "--"), normal),
            Paragraph(_txt(r.get("tipo") or "--"), normal),
            Paragraph(_txt(r.get("evento") or "--"), normal),
            Paragraph(_txt(fmt_time(r.get("pauta"))), normal),
            Paragraph(_txt(fmt_time(r.get("inicio"))), normal),
            Paragraph(_txt(fmt_time(r.get("fim"))), normal),
            Paragraph(f'<font color="{_hex(anom_color)}"><b>{anom_txt}</b></font>', normal),
        ]

    return _build_flat_report(
        "Registros de Operação (Entradas)", entradas,
        headers=["Local", "Data", "Operador", "Tipo", "Evento", "Pauta", "Início", "Fim", "Anormalidade?"],
        weights=cfg.COLS_OPERACOES_ENTRADAS,
        row_builder=row_builder,
        template_path=template_path,
        font_size=8, leading=10,
        valign="TOP", pad=5,
        extra_style_cmds=[
            ("ALIGN", (5, 0), (7, -1), "CENTER"),
            ("ALIGN", (8, 0), (8, -1), "CENTER"),
        ],
    )


def gerar_relatorio_meus_checklists(
    checklists: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    def row_builder(chk: Dict[str, Any], normal: ParagraphStyle) -> List[Any]:
        qtde_ok = int(chk.get("qtde_ok") or 0)
        qtde_falha = int(chk.get("qtde_falha") or 0)

        ok_color = colors.green if qtde_ok > 0 else colors.HexColor(cfg.COLOR_SLATE)
        falha_color = colors.red if qtde_falha > 0 else colors.HexColor(cfg.COLOR_SLATE)

        return [
            Paragraph(f"<b>{_txt(chk.get('sala_nome') or '')}</b>", normal),
            Paragraph(_txt(fmt_date(chk.get("data"))), normal),
            Paragraph(f'<font color="{_hex(ok_color)}"><b>{qtde_ok}</b></font>', normal),
            Paragraph(f'<font color="{_hex(falha_color)}"><b>{qtde_falha}</b></font>', normal),
        ]

    return _build_flat_report(
        "Verificação de Salas", checklists,
        headers=["Sala", "Data", "Qtde. OK", "Qtde. Falha"],
        weights=cfg.COLS_MEUS_CHECKLISTS,
        row_builder=row_builder,
        template_path=template_path,
        font_size=10, leading=12,
        extra_style_cmds=[("ALIGN", (2, 0), (3, -1), "CENTER")],
    )


def gerar_relatorio_minhas_operacoes(
    operacoes: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    def row_builder(op: Dict[str, Any], normal: ParagraphStyle) -> List[Any]:
        anom = op.get("anormalidade")
        anom_color = colors.red if anom else colors.green
        anom_txt = "SIM" if anom else "Não"

        return [
            Paragraph(f"<b>{_txt(op.get('sala') or '')}</b>", normal),
            Paragraph(_txt(fmt_date(op.get("data"))), normal),
            Paragraph(_txt(fmt_time(op.get("inicio_operacao"))), normal),
            Paragraph(_txt(fmt_time(op.get("fim_operacao"))), normal),
            Paragraph(f'<font color="{_hex(anom_color)}"><b>{anom_txt}</b></font>', normal),
        ]

    return _build_flat_report(
        "Registros de Operação de Áudio", operacoes,
        headers=["Sala", "Data", "Início Operação", "Fim Operação", "Anormalidade?"],
        weights=cfg.COLS_MINHAS_OPERACOES,
        row_builder=row_builder,
        template_path=template_path,
        extra_style_cmds=[("ALIGN", (2, 0), (4, -1), "CENTER")],
    )


# ---------------------------------------------------------------------------
# Relatórios públicos — master/detail (checklists e sessões de operação)
# ---------------------------------------------------------------------------

def gerar_relatorio_checklists(
    checklists: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    _, title_style, normal, header_style = _make_styles(9, 11)
    small_bold = ParagraphStyle("small_bold", parent=getSampleStyleSheet()["Normal"], fontSize=9, leading=11, spaceAfter=0)

    story: List[Any] = []
    story.append(Paragraph("Verificação de Plenários", title_style))

    if not checklists:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    colw = _scale_weights(cfg.COLS_CHECKLISTS_MASTER)

    hdr = [[Paragraph(f"<b>{h}</b>", header_style) for h in
            ["Local", "Data", "Verificado por", "Início", "Término", "Duração", "Status"]]]

    for idx, chk in enumerate(checklists):
        itens = chk.get("itens") or []

        has_failure = any(str(it.get("status") or "").strip().lower() == "falha" for it in itens)
        status_txt = "Falha" if has_failure else "Ok"
        status_color = colors.red if has_failure else colors.green

        master = [[
            Paragraph(f"<b>{_txt(chk.get('sala_nome') or chk.get('sala') or '')}</b>", normal),
            Paragraph(_txt(chk.get("data") or ""), normal),
            Paragraph(_txt(chk.get("operador") or ""), normal),
            Paragraph(_txt(chk.get("inicio") or ""), normal),
            Paragraph(_txt(chk.get("termino") or ""), normal),
            Paragraph(_txt(chk.get("duracao") or ""), normal),
            Paragraph(f'<font color="{_hex(status_color)}"><b>{status_txt}</b></font>', normal),
        ]]

        hdr_tbl = Table(hdr, colWidths=colw)
        hdr_tbl.setStyle(TableStyle(_base_table_style()))

        master_tbl = Table(master, colWidths=colw)
        master_tbl.setStyle(TableStyle(_data_row_style()))

        details_bar = Table(
            [[Paragraph("<b>Detalhes da Verificação:</b>", small_bold)]],
            colWidths=[PAGE_WIDTH],
        )
        details_bar.setStyle(TableStyle(_detail_bar_style()))

        item_header = [
            Paragraph("<b>Item verificado</b>", header_style),
            Paragraph("<b>Status</b>", header_style),
            Paragraph("<b>Descrição</b>", header_style),
        ]
        item_rows: List[List[Any]] = [item_header]

        for it in itens:
            is_text = (it.get("tipo_widget") or "radio") == "text"

            if is_text:
                st = "Texto"
                st_color = colors.HexColor(cfg.COLOR_SLATE)
                desc_txt = it.get("valor_texto")
                desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"
            else:
                st = str(it.get("status") or "--")
                st_lower = st.strip().lower()
                st_color = colors.red if st_lower == "falha" else colors.green if st_lower == "ok" else colors.HexColor(cfg.COLOR_SLATE)
                desc_txt = it.get("falha")
                desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"

            item_rows.append([
                Paragraph(_txt(it.get("item") or ""), normal),
                Paragraph(f'<font color="{_hex(st_color)}"><b>{_txt(st)}</b></font>', normal),
                Paragraph(_txt(desc_txt), normal),
            ])

        it_colw = [PAGE_WIDTH * 0.45, PAGE_WIDTH * 0.15, PAGE_WIDTH * 0.40]
        items_tbl = Table(item_rows, colWidths=it_colw, repeatRows=1)
        items_tbl.setStyle(TableStyle(_base_table_style(header_bg=cfg.HEADER_DETAIL_FILL, valign="TOP", left_pad=6, right_pad=6)))

        story.append(KeepTogether([hdr_tbl, Spacer(1, 6), master_tbl, Spacer(1, 4), details_bar]))
        story.append(items_tbl)

        if idx < len(checklists) - 1:
            story.append(Spacer(1, 12))

    _append_total_row(story, total=len(checklists), text_style=normal)
    return _merge_with_template(_build_content_pdf(story), template_path)


def gerar_relatorio_operacoes_sessoes(
    sessoes: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    _, title_style, normal, header_style = _make_styles(9, 11)

    styles_base = getSampleStyleSheet()
    small = ParagraphStyle("small", parent=styles_base["Normal"], fontSize=8, leading=10)
    small_header = ParagraphStyle("small_hdr", parent=small, textColor=colors.HexColor(cfg.COLOR_DARK))
    small_bold = ParagraphStyle("small_bold", parent=styles_base["Normal"], fontSize=9, leading=11, spaceAfter=0)

    story: List[Any] = []
    story.append(Paragraph("Registros de Operação (Sessões)", title_style))

    if not sessoes:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    colw_master = _scale_weights(cfg.COLS_OPERACOES_SESSOES_MASTER)
    colw_ent = _scale_weights(cfg.COLS_OPERACOES_SESSOES_ENTRADAS)

    hdr_master = [[Paragraph(f"<b>{h}</b>", header_style) for h in
                   ["Local", "Data", "1º Registro por", "Checklist?", "Em Aberto?"]]]

    for idx, sessao in enumerate(sessoes):
        sala_txt = str(sessao.get("sala") or "--")
        data_txt = fmt_date(sessao.get("data"))
        autor_txt = str(sessao.get("autor") or "--")

        verific_raw = sessao.get("verificacao")
        verific_txt = str(verific_raw).strip() if verific_raw is not None and str(verific_raw).strip() != "" else "--"
        verific_color = colors.green if verific_txt.lower() == "realizado" else colors.HexColor(cfg.COLOR_MUTED)

        em_raw = sessao.get("em_aberto")
        em_txt = str(em_raw).strip() if em_raw is not None and str(em_raw).strip() != "" else "--"
        em_color = colors.HexColor(cfg.COLOR_BLUE) if em_txt.lower() == "sim" else colors.HexColor(cfg.COLOR_DARK)

        hdr_tbl = Table(hdr_master, colWidths=colw_master)
        hdr_tbl.setStyle(TableStyle(_base_table_style()))

        master = [[
            Paragraph(f"<b>{_txt(sala_txt)}</b>", normal),
            Paragraph(f"<b>{_txt(data_txt)}</b>", normal),
            Paragraph(f"<b>{_txt(autor_txt)}</b>", normal),
            Paragraph(f'<font color="{_hex(verific_color)}"><b>{_txt(verific_txt)}</b></font>', normal),
            Paragraph(f'<font color="{_hex(em_color)}"><b>{_txt(em_txt)}</b></font>', normal),
        ]]
        master_tbl = Table(master, colWidths=colw_master)
        master_tbl.setStyle(TableStyle(_data_row_style()))

        details_bar = Table(
            [[Paragraph("<b>Entradas da Operação:</b>", small_bold)]],
            colWidths=[PAGE_WIDTH],
        )
        details_bar.setStyle(TableStyle(_detail_bar_style()))

        ent_header = [Paragraph(f"<b>{h}</b>", small_header) for h in
                      ["Nº", "Operador", "Tipo", "Evento", "Pauta", "Início", "Fim", "Anormalidade?"]]
        ent_rows: List[List[Any]] = [ent_header]

        entradas = sessao.get("entradas") or []
        if entradas:
            for ent in entradas:
                ordem = ent.get("ordem")
                ordem_txt = f"{ordem}º" if ordem is not None and str(ordem) != "" else "--"

                anom = bool(ent.get("anormalidade"))
                anom_txt = "SIM" if anom else "Não"
                anom_color = colors.red if anom else colors.green

                ent_rows.append([
                    Paragraph(_txt(ordem_txt), small),
                    Paragraph(_txt(ent.get("operador") or "--"), small),
                    Paragraph(_txt(ent.get("tipo") or "--"), small),
                    Paragraph(_txt(ent.get("evento") or "--"), small),
                    Paragraph(_txt(fmt_time(ent.get("pauta"))), small),
                    Paragraph(_txt(fmt_time(ent.get("inicio"))), small),
                    Paragraph(_txt(fmt_time(ent.get("fim"))), small),
                    Paragraph(f'<font color="{_hex(anom_color)}"><b>{_txt(anom_txt)}</b></font>', small),
                ])
        else:
            ent_rows.append([
                Paragraph("<i>Nenhuma entrada registrada nesta sessão.</i>", small),
                *[Paragraph("", small) for _ in range(7)],
            ])

        ent_style_cmds = _base_table_style(header_bg=cfg.HEADER_DETAIL_FILL, valign="TOP", pad=5)
        ent_style_cmds += [
            ("ALIGN", (0, 0), (0, -1), "CENTER"),
            ("ALIGN", (4, 0), (6, -1), "CENTER"),
            ("ALIGN", (7, 0), (7, -1), "CENTER"),
        ]
        if not entradas:
            ent_style_cmds.append(("SPAN", (0, 1), (-1, 1)))
            ent_style_cmds.append(("ALIGN", (0, 1), (-1, 1), "LEFT"))

        ent_tbl = Table(ent_rows, colWidths=colw_ent, repeatRows=1)
        ent_tbl.setStyle(TableStyle(ent_style_cmds))

        story.append(KeepTogether([hdr_tbl, Spacer(1, 6), master_tbl, Spacer(1, 4), details_bar]))
        story.append(ent_tbl)

        if idx < len(sessoes) - 1:
            story.append(Spacer(1, 12))

    _append_total_row(story, total=len(sessoes), text_style=normal)
    return _merge_with_template(_build_content_pdf(story), template_path)
