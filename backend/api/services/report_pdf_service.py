from __future__ import annotations

from datetime import date, datetime, time
from io import BytesIO
from pathlib import Path
from typing import Any, Dict, List, Optional, Sequence
from xml.sax.saxutils import escape as xml_escape

from django.conf import settings

from reportlab.lib import colors
from reportlab.lib.enums import TA_LEFT
from reportlab.lib.pagesizes import A4
from reportlab.lib.styles import ParagraphStyle, getSampleStyleSheet
from reportlab.platypus import Paragraph, SimpleDocTemplate, Spacer, Table, TableStyle, KeepTogether
from reportlab.pdfgen import canvas
from reportlab.lib.units import mm

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


def _hex(c: colors.Color) -> str:
    hx = c.hexval()
    if hx.startswith("0x"):
        return "#" + hx[2:]
    return hx


def _txt(v: Any) -> str:
    return xml_escape("" if v is None else str(v))

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

class NumberedCanvas(canvas.Canvas):
    """
    Canvas com 2-pass para escrever 'Página X de Y'.
    """
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
        # canto inferior direito, dentro das margens
        x = w - RIGHT_MARGIN
        y = 12 * mm
        self.setFont("Helvetica", 8)
        self.drawRightString(x, y, f"Página {self._pageNumber} de {total_pages}")


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


def _append_total_row(story: List[Any], *, total: int, page_width: float, text_style: ParagraphStyle) -> None:
    """
    Após a última linha/tabela do relatório, adiciona:
      - espaço ~10px
      - tabela 1x2: Total | N
      - linha em negrito e sublinhada
      - fundo azul igual ao header (#dbeafe)
    """
    story.append(Spacer(1, 10))  # ~10px

    data = [[
        Paragraph("<b><u>Total</u></b>", text_style),
        Paragraph(f"<b><u>{total}</u></b>", text_style),
    ]]

    tbl = Table(data, colWidths=[page_width * 0.80, page_width * 0.20])
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("LINEBELOW", (0, 0), (-1, 0), 1, colors.black),  # sublinhado “garantido”
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

    # Fallback: se não houver template, devolve o PDF cru (sem header/footer).
    if not template_path or not Path(template_path).exists():
        return content_pdf

    if fitz is None:
        raise RuntimeError(
            "PyMuPDF (pymupdf) não está instalado, mas é necessário para aplicar o Modelo.pdf."
        )

    tmpl_doc = fitz.open(str(template_path))
    content_doc = fitz.open("pdf", content_pdf)

    out = fitz.open()
    rect = tmpl_doc[0].rect  # usa o tamanho da página do template

    for i in range(content_doc.page_count):
        page = out.new_page(width=rect.width, height=rect.height)
        page.show_pdf_page(rect, tmpl_doc, 0)      # fundo (Modelo.pdf)
        page.show_pdf_page(rect, content_doc, i)   # conteúdo (ReportLab)

    return out.tobytes()


def gerar_relatorio_operadores(
    operadores: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=10, leading=12)
    header = ParagraphStyle("header", parent=styles["Normal"], fontSize=10, leading=12)

    story: List[Any] = []
    story.append(Paragraph("Operadores de Áudio", title_style))

    if not operadores:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN
    colw = [page_width * 0.60, page_width * 0.40]

    data: List[List[Any]] = [
        [Paragraph("<b>Nome</b>", header), Paragraph("<b>E-mail</b>", header)]
    ]

    for op in operadores:
        data.append([
            Paragraph(_txt(op.get("nome_completo") or op.get("nome") or ""), normal),
            Paragraph(_txt(op.get("email") or ""), normal),
        ])

    tbl = Table(data, colWidths=colw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    story.append(tbl)

    _append_total_row(story, total=len(operadores), page_width=page_width, text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)


def gerar_relatorio_checklists(
    checklists: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=9, leading=11)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))
    small_bold = ParagraphStyle("small_bold", parent=styles["Normal"], fontSize=9, leading=11, spaceAfter=0)

    story: List[Any] = []
    story.append(Paragraph("Verificação de Plenários", title_style))

    if not checklists:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    # Larguras base (escala para caber na página)
    base = [70, 60, 150, 45, 50, 60, 50]  # Local, Data, Verificado por, Início, Término, Duração, Status
    scale = page_width / sum(base)
    colw = [w * scale for w in base]

    # Cabeçalho da tabela principal (uma vez)
    hdr = [[
        Paragraph("<b>Local</b>", header_style),
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>Verificado por</b>", header_style),
        Paragraph("<b>Início</b>", header_style),
        Paragraph("<b>Término</b>", header_style),
        Paragraph("<b>Duração</b>", header_style),
        Paragraph("<b>Status</b>", header_style),
    ]]
    hdr_tbl = Table(hdr, colWidths=colw, repeatRows=1)
    hdr_tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 4),
        ("RIGHTPADDING", (0, 0), (-1, -1), 4),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))
    # story.append(hdr_tbl)
    # story.append(Spacer(1, 6))

    # Para cada checklist: linha principal + “Detalhes…” + tabela de itens (SEMPRE expandido)
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
        # Cabeçalho da tabela principal (repetir antes de cada registro)
        hdr_tbl = Table(hdr, colWidths=colw)
        hdr_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))
        master_tbl = Table(master, colWidths=colw)
        master_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f8fafc")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

        details_bar = Table(
            [[Paragraph("<b>Detalhes da Verificação:</b>", small_bold)]],
            colWidths=[page_width],
        )
        details_bar.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#e0f2fe")),
            ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

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
                st_color = colors.HexColor("#334155")
                desc_txt = it.get("valor_texto")
                desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"
            else:
                st = str(it.get("status") or "--")
                st_lower = st.strip().lower()
                st_color = colors.red if st_lower == "falha" else colors.green if st_lower == "ok" else colors.HexColor("#334155")
                desc_txt = it.get("falha")
                desc_txt = desc_txt if (desc_txt is not None and str(desc_txt).strip() != "") else "-"

            item_rows.append([
                Paragraph(_txt(it.get("item") or ""), normal),
                Paragraph(f'<font color="{_hex(st_color)}"><b>{_txt(st)}</b></font>', normal),
                Paragraph(_txt(desc_txt), normal),
            ])

        it_colw = [page_width * 0.45, page_width * 0.15, page_width * 0.40]
        items_tbl = Table(item_rows, colWidths=it_colw, repeatRows=1)
        items_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#bfdbfe")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

        # Mantém cabeçalho + linha principal + barra "Detalhes" juntos
        story.append(KeepTogether([
            hdr_tbl,
            Spacer(1, 6),
            master_tbl,
            Spacer(1, 4),
            details_bar
        ]))

        story.append(items_tbl)

        # Espaço entre grupos, mas NÃO depois do último (para o "Total" ficar com ~10px)
        if idx < len(checklists) - 1:
            story.append(Spacer(1, 12))

    _append_total_row(story, total=len(checklists), page_width=page_width, text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)



def gerar_relatorio_anormalidades(
    anormalidades: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=9, leading=11)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))

    story: List[Any] = []
    story.append(Paragraph("Relatórios de Anormalidades", title_style))

    if not anormalidades:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    # Pesos -> escala para caber
    base = [70, 60, 110, 170, 70, 60, 70]  # Data, Sala, Registrado por, Descrição, Solucionada, Prejuízo, Reclamação
    scale = page_width / sum(base)
    colw = [w * scale for w in base]

    data: List[List[Any]] = [[
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>Local</b>", header_style),
        Paragraph("<b>Registrado por</b>", header_style),
        Paragraph("<b>Descrição</b>", header_style),
        Paragraph("<b>Solucionada</b>", header_style),
        Paragraph("<b>Prejuízo</b>", header_style),
        Paragraph("<b>Reclamação</b>", header_style),
    ]]

    for r in anormalidades:
        dt = r.get("data")
        if isinstance(dt, (datetime, date)):
            dt_txt = dt.strftime("%d/%m/%Y")
        else:
            dt_txt = str(dt or "")

        solucionada = bool(r.get("solucionada"))
        preju = bool(r.get("houve_prejuizo"))
        recl = bool(r.get("houve_reclamacao"))

        data.append([
            Paragraph(_txt(dt_txt), normal),
            Paragraph(_txt(r.get("sala") or ""), normal),
            Paragraph(_txt(r.get("registrado_por") or ""), normal),
            Paragraph(_txt(r.get("descricao") or ""), normal),
            Paragraph(f'<font color="{_hex(colors.green if solucionada else colors.red)}"><b>{"Sim" if solucionada else "Não"}</b></font>', normal),
            Paragraph(f'<font color="{_hex(colors.red if preju else colors.HexColor("#64748b"))}"><b>{"Sim" if preju else "Não"}</b></font>', normal),
            Paragraph(f'<font color="{_hex(colors.red if recl else colors.HexColor("#64748b"))}"><b>{"Sim" if recl else "Não"}</b></font>', normal),
        ])

    tbl = Table(data, colWidths=colw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
    ]))

    story.append(tbl)

    _append_total_row(story, total=len(anormalidades), page_width=page_width, text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)

def gerar_relatorio_operacoes_sessoes(
    sessoes: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """
    Relatório no formato AGRUPADO (igual ao de Checklists):
      - Linha principal (sessão) + sub-tabela (entradas)
      - NÃO inclui a linha/ícone "Dê um duplo-clique..."
    """
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=9, leading=11)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))

    small = ParagraphStyle("small", parent=styles["Normal"], fontSize=8, leading=10)
    small_header = ParagraphStyle("small_hdr", parent=small, textColor=colors.HexColor("#0f172a"))
    small_bold = ParagraphStyle("small_bold", parent=styles["Normal"], fontSize=9, leading=11, spaceAfter=0)

    story: List[Any] = []
    story.append(Paragraph("Registros de Operação (Sessões)", title_style))

    if not sessoes:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    # Colunas da tabela principal (sem a coluna de toggle)
    base_master = [90, 60, 200, 80, 80]  # Local, Data, 1º Registro por, Checklist?, Em Aberto?
    scale_master = page_width / sum(base_master)
    colw_master = [w * scale_master for w in base_master]

    hdr_master = [[
        Paragraph("<b>Local</b>", header_style),
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>1º Registro por</b>", header_style),
        Paragraph("<b>Checklist?</b>", header_style),
        Paragraph("<b>Em Aberto?</b>", header_style),
    ]]

    # Colunas da sub-tabela (entradas)
    base_ent = [35, 115, 65, 165, 45, 45, 45, 55]  # Nº, Operador, Tipo, Evento, Pauta, Início, Fim, Anormalidade?
    scale_ent = page_width / sum(base_ent)
    colw_ent = [w * scale_ent for w in base_ent]

    for idx, sessao in enumerate(sessoes):
        sala_txt = str(sessao.get("sala") or "--")
        data_txt = _fmt_date(sessao.get("data"))
        autor_txt = str(sessao.get("autor") or "--")

        verific_raw = sessao.get("verificacao")
        verific_txt = str(verific_raw).strip() if verific_raw is not None and str(verific_raw).strip() != "" else "--"
        verific_norm = verific_txt.lower()
        verific_color = colors.green if verific_norm == "realizado" else colors.HexColor("#64748b")

        em_raw = sessao.get("em_aberto")
        em_txt = str(em_raw).strip() if em_raw is not None and str(em_raw).strip() != "" else "--"
        em_norm = em_txt.lower()
        em_color = colors.HexColor("#2563eb") if em_norm == "sim" else colors.HexColor("#0f172a")

        # Header (repetido antes de cada sessão, igual ao relatório de Checklists)
        hdr_tbl = Table(hdr_master, colWidths=colw_master)
        hdr_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

        # Linha principal (sessão)
        master = [[
            Paragraph(f"<b>{_txt(sala_txt)}</b>", normal),
            Paragraph(f"<b>{_txt(data_txt)}</b>", normal),
            Paragraph(f"<b>{_txt(autor_txt)}</b>", normal),
            Paragraph(f'<font color="{_hex(verific_color)}"><b>{_txt(verific_txt)}</b></font>', normal),
            Paragraph(f'<font color="{_hex(em_color)}"><b>{_txt(em_txt)}</b></font>', normal),
        ]]
        master_tbl = Table(master, colWidths=colw_master)
        master_tbl.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#f8fafc")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
            ("LEFTPADDING", (0, 0), (-1, -1), 4),
            ("RIGHTPADDING", (0, 0), (-1, -1), 4),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

        details_bar = Table(
            [[Paragraph("<b>Entradas da Operação:</b>", small_bold)]],
            colWidths=[page_width],
        )
        details_bar.setStyle(TableStyle([
            ("BACKGROUND", (0, 0), (-1, -1), colors.HexColor("#e0f2fe")),
            ("BOX", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("LEFTPADDING", (0, 0), (-1, -1), 6),
            ("RIGHTPADDING", (0, 0), (-1, -1), 6),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ]))

        ent_header = [
            Paragraph("<b>Nº</b>", small_header),
            Paragraph("<b>Operador</b>", small_header),
            Paragraph("<b>Tipo</b>", small_header),
            Paragraph("<b>Evento</b>", small_header),
            Paragraph("<b>Pauta</b>", small_header),
            Paragraph("<b>Início</b>", small_header),
            Paragraph("<b>Fim</b>", small_header),
            Paragraph("<b>Anormalidade?</b>", small_header),
        ]
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
                    Paragraph(_txt(_fmt_time(ent.get("pauta"))), small),
                    Paragraph(_txt(_fmt_time(ent.get("inicio"))), small),
                    Paragraph(_txt(_fmt_time(ent.get("fim"))), small),
                    Paragraph(f'<font color="{_hex(anom_color)}"><b>{_txt(anom_txt)}</b></font>', small),
                ])
        else:
            ent_rows.append([
                Paragraph("<i>Nenhuma entrada registrada nesta sessão.</i>", small),
                Paragraph("", small),
                Paragraph("", small),
                Paragraph("", small),
                Paragraph("", small),
                Paragraph("", small),
                Paragraph("", small),
                Paragraph("", small),
            ])

        ent_tbl = Table(ent_rows, colWidths=colw_ent, repeatRows=1)
        style_cmds = [
            ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#bfdbfe")),
            ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
            ("VALIGN", (0, 0), (-1, -1), "TOP"),
            ("LEFTPADDING", (0, 0), (-1, -1), 5),
            ("RIGHTPADDING", (0, 0), (-1, -1), 5),
            ("TOPPADDING", (0, 0), (-1, -1), 4),
            ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
            ("ALIGN", (0, 0), (0, -1), "CENTER"),
            ("ALIGN", (4, 0), (6, -1), "CENTER"),
            ("ALIGN", (7, 0), (7, -1), "CENTER"),
        ]
        if not entradas:
            style_cmds.append(("SPAN", (0, 1), (-1, 1)))
            style_cmds.append(("ALIGN", (0, 1), (-1, 1), "LEFT"))
        ent_tbl.setStyle(TableStyle(style_cmds))

        story.append(KeepTogether([hdr_tbl, Spacer(1, 6), master_tbl, Spacer(1, 4), details_bar]))
        story.append(ent_tbl)

        if idx < len(sessoes) - 1:
            story.append(Spacer(1, 12))

    _append_total_row(story, total=len(sessoes), page_width=page_width, text_style=normal)
    return _merge_with_template(_build_content_pdf(story), template_path)


def gerar_relatorio_operacoes_entradas(
    entradas: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """
    Relatório no formato LISTA PLANA (igual ao de Anormalidades):
      - Uma linha por entrada (sem sublinhas)
    """
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=8, leading=10)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))

    story: List[Any] = []
    story.append(Paragraph("Registros de Operação (Sessões)", title_style))

    if not entradas:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    base = [80, 60, 110, 70, 170, 45, 45, 45, 70]  # Local, Data, Operador, Tipo, Evento, Pauta, Início, Fim, Anormalidade?
    scale = page_width / sum(base)
    colw = [w * scale for w in base]

    data: List[List[Any]] = [[
        Paragraph("<b>Local</b>", header_style),
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>Operador</b>", header_style),
        Paragraph("<b>Tipo</b>", header_style),
        Paragraph("<b>Evento</b>", header_style),
        Paragraph("<b>Pauta</b>", header_style),
        Paragraph("<b>Início</b>", header_style),
        Paragraph("<b>Fim</b>", header_style),
        Paragraph("<b>Anormalidade?</b>", header_style),
    ]]

    for r in entradas:
        anom = bool(r.get("anormalidade"))
        anom_txt = "SIM" if anom else "Não"
        anom_color = colors.red if anom else colors.green

        data.append([
            Paragraph(f"<b>{_txt(r.get('sala') or '--')}</b>", normal),
            Paragraph(_txt(_fmt_date(r.get("data"))), normal),
            Paragraph(_txt(r.get("operador") or "--"), normal),
            Paragraph(_txt(r.get("tipo") or "--"), normal),
            Paragraph(_txt(r.get("evento") or "--"), normal),
            Paragraph(_txt(_fmt_time(r.get("pauta"))), normal),
            Paragraph(_txt(_fmt_time(r.get("inicio"))), normal),
            Paragraph(_txt(_fmt_time(r.get("fim"))), normal),
            Paragraph(f'<font color="{_hex(anom_color)}"><b>{anom_txt}</b></font>', normal),
        ])

    tbl = Table(data, colWidths=colw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "TOP"),
        ("LEFTPADDING", (0, 0), (-1, -1), 5),
        ("RIGHTPADDING", (0, 0), (-1, -1), 5),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("ALIGN", (5, 0), (7, -1), "CENTER"),
        ("ALIGN", (8, 0), (8, -1), "CENTER"),
    ]))

    story.append(tbl)
    _append_total_row(story, total=len(entradas), page_width=page_width, text_style=normal)
    return _merge_with_template(_build_content_pdf(story), template_path)


def gerar_relatorio_meus_checklists(
    checklists: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """
    Relatório PDF simplificado para o operador: 4 colunas.
    Sala | Data | Qtde. OK | Qtde. Falha
    """
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=10, leading=12)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))

    story: List[Any] = []
    story.append(Paragraph("Verificação de Salas", title_style))

    if not checklists:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    base = [180, 80, 100, 100]  # Sala, Data, Qtde. OK, Qtde. Falha
    scale = page_width / sum(base)
    colw = [w * scale for w in base]

    data: List[List[Any]] = [[
        Paragraph("<b>Sala</b>", header_style),
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>Qtde. OK</b>", header_style),
        Paragraph("<b>Qtde. Falha</b>", header_style),
    ]]

    for chk in checklists:
        qtde_ok = int(chk.get("qtde_ok") or 0)
        qtde_falha = int(chk.get("qtde_falha") or 0)

        falha_color = colors.red if qtde_falha > 0 else colors.HexColor("#334155")
        ok_color = colors.green if qtde_ok > 0 else colors.HexColor("#334155")

        data.append([
            Paragraph(f"<b>{_txt(chk.get('sala_nome') or '')}</b>", normal),
            Paragraph(_txt(_fmt_date(chk.get("data"))), normal),
            Paragraph(f'<font color="{_hex(ok_color)}"><b>{qtde_ok}</b></font>', normal),
            Paragraph(f'<font color="{_hex(falha_color)}"><b>{qtde_falha}</b></font>', normal),
        ])

    tbl = Table(data, colWidths=colw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("ALIGN", (2, 0), (3, -1), "CENTER"),
    ]))

    story.append(tbl)
    _append_total_row(story, total=len(checklists), page_width=page_width, text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)


def gerar_relatorio_minhas_operacoes(
    operacoes: Sequence[Dict[str, Any]],
    template_path: Optional[Path] = None,
) -> bytes:
    """
    Relatório PDF simplificado para o operador: 5 colunas.
    Sala | Data | Início Operação | Fim Operação | Anormalidade?
    """
    styles = getSampleStyleSheet()
    title_style = ParagraphStyle("title", parent=styles["Heading2"], alignment=TA_LEFT, spaceAfter=10)
    normal = ParagraphStyle("normal", parent=styles["Normal"], fontSize=9, leading=11)
    header_style = ParagraphStyle("hdr", parent=normal, textColor=colors.HexColor("#0f172a"))

    story: List[Any] = []
    story.append(Paragraph("Registros de Operação de Áudio", title_style))

    if not operacoes:
        story.append(Paragraph("Nenhum registro encontrado para os filtros aplicados.", normal))
        return _merge_with_template(_build_content_pdf(story), template_path)

    page_width = A4[0] - LEFT_MARGIN - RIGHT_MARGIN

    base = [150, 70, 90, 90, 80]  # Sala, Data, Início Operação, Fim Operação, Anormalidade?
    scale = page_width / sum(base)
    colw = [w * scale for w in base]

    data: List[List[Any]] = [[
        Paragraph("<b>Sala</b>", header_style),
        Paragraph("<b>Data</b>", header_style),
        Paragraph("<b>Início Operação</b>", header_style),
        Paragraph("<b>Fim Operação</b>", header_style),
        Paragraph("<b>Anormalidade?</b>", header_style),
    ]]

    for op in operacoes:
        anom = op.get("anormalidade")
        if anom:
            anom_txt = f'<font color="{_hex(colors.red)}"><b>SIM</b></font>'
        else:
            anom_txt = f'<font color="{_hex(colors.green)}"><b>Não</b></font>'

        data.append([
            Paragraph(f"<b>{_txt(op.get('sala') or '')}</b>", normal),
            Paragraph(_txt(_fmt_date(op.get("data"))), normal),
            Paragraph(_txt(_fmt_time(op.get("inicio_operacao"))), normal),
            Paragraph(_txt(_fmt_time(op.get("fim_operacao"))), normal),
            Paragraph(anom_txt, normal),
        ])

    tbl = Table(data, colWidths=colw, repeatRows=1)
    tbl.setStyle(TableStyle([
        ("BACKGROUND", (0, 0), (-1, 0), colors.HexColor("#dbeafe")),
        ("GRID", (0, 0), (-1, -1), 0.5, colors.HexColor("#cbd5e1")),
        ("VALIGN", (0, 0), (-1, -1), "MIDDLE"),
        ("LEFTPADDING", (0, 0), (-1, -1), 6),
        ("RIGHTPADDING", (0, 0), (-1, -1), 6),
        ("TOPPADDING", (0, 0), (-1, -1), 4),
        ("BOTTOMPADDING", (0, 0), (-1, -1), 4),
        ("ALIGN", (2, 0), (4, -1), "CENTER"),
    ]))

    story.append(tbl)
    _append_total_row(story, total=len(operacoes), page_width=page_width, text_style=normal)

    return _merge_with_template(_build_content_pdf(story), template_path)