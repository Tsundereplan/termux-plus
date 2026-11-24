#!/usr/bin/env python3
"""Render docs/termux-plus-guide.html into Termux-Plus-Guide.pdf at the repo root.

Used by .github/workflows/render-guide.yml. Chromium (driven by Playwright)
prints the HTML at a 720x1020 CSS-pixel page size with backgrounds enabled,
then pikepdf stamps the document metadata. The page geometry comes from the
`@page { size: 720px 1020px; margin: 0 }` rule inside the HTML itself
(prefer_css_page_size=True), which yields 540 x 765 pt PDF pages.

Fonts (Inter + JetBrains Mono) are pulled from Google Fonts at render time,
so the output is self-contained and identical on any machine.
"""

from pathlib import Path

import pikepdf
from playwright.sync_api import sync_playwright

DOCS_DIR = Path(__file__).resolve().parent
HTML_PATH = DOCS_DIR / "termux-plus-guide.html"
PDF_PATH = DOCS_DIR.parent / "Termux-Plus-Guide.pdf"


def main() -> None:
    with sync_playwright() as p:
        browser = p.chromium.launch()
        page = browser.new_page(viewport={"width": 720, "height": 1020})
        page.goto(HTML_PATH.as_uri(), wait_until="networkidle")
        page.evaluate("document.fonts.ready")  # wait until webfonts are loaded
        page.wait_for_timeout(400)  # small settle buffer
        page.pdf(
            path=str(PDF_PATH),
            width="720px",
            height="1020px",
            print_background=True,
            prefer_css_page_size=True,
        )
        browser.close()

    with pikepdf.open(PDF_PATH, allow_overwriting_input=True) as pdf:
        with pdf.open_metadata() as meta:
            meta["dc:title"] = "Termux Plus - User Guide"
            meta["dc:creator"] = ["Tsundereplan"]
            meta["dc:description"] = (
                "Installation and customization guide for the "
                "Termux Plus Android terminal build"
            )
            meta["xmp:CreatorTool"] = "Z.ai"
        pdf.docinfo["/Title"] = "Termux Plus - User Guide"
        pdf.docinfo["/Author"] = "Tsundereplan"
        pdf.docinfo["/Subject"] = (
            "Installation and customization guide for the "
            "Termux Plus Android terminal build"
        )
        pdf.docinfo["/Creator"] = "Z.ai"
        pdf.save(PDF_PATH)

    print(f"Rendered {PDF_PATH} ({PDF_PATH.stat().st_size} bytes)")


if __name__ == "__main__":
    main()
