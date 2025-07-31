import os
import io
from fastapi import FastAPI, HTTPException
from fastapi.responses import FileResponse
import fitz  # PyMuPDF
from pdf2image import convert_from_path
import pytesseract
from PIL import Image

app = FastAPI(title="PDF Preview Service")

UPLOAD_DIR = "uploads"

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/preview/pdf-text")
def extract_pdf_text(filename: str):
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")

    try:
        doc = fitz.open(path)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to open PDF: {e}")

    text = "".join(page.get_text("text") for page in doc)

    if not text.strip():
        # fallback to OCR
        text_parts = []
        for page in doc:
            pix = page.get_pixmap()
            img = Image.frombytes("RGB", [pix.width, pix.height], pix.samples)
            text_parts.append(pytesseract.image_to_string(img))
        text = "\n".join(text_parts)
    return {"text": text}

@app.get("/preview/thumbnail")
def get_pdf_thumbnail(filename: str, page: int = 0, dpi: int = 150):
    path = os.path.join(UPLOAD_DIR, filename)
    if not os.path.exists(path):
        raise HTTPException(status_code=404, detail="File not found")
    try:
        images = convert_from_path(path, dpi=dpi, first_page=page+1, last_page=page+1)
    except Exception as e:
        raise HTTPException(status_code=500, detail=f"Failed to render page: {e}")
    if not images:
        raise HTTPException(status_code=500, detail="Page not found")
    img_path = f"/tmp/{filename}_page{page}.png"
    images[0].save(img_path, "PNG")
    return FileResponse(img_path, media_type="image/png")