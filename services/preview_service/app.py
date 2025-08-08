import os
import signal
from flask import Flask, request, jsonify
from werkzeug.utils import secure_filename
from werkzeug.exceptions import RequestEntityTooLarge
import fitz  # PyMuPDF
from pdf2image import convert_from_path
import pytesseract
from PIL import Image
import docx
import chardet
import magic
from tika import parser
from langdetect import detect, LangDetectException

UPLOAD_DIR = "/data"
MAX_CONTENT_LENGTH = 50 * 1024 * 1024  # 50MB
PROCESS_TIMEOUT = 30  # seconds

os.environ.setdefault("TIKA_SERVER_JAR", "/opt/tika/tika.jar")

app = Flask(__name__)
app.config["UPLOAD_FOLDER"] = UPLOAD_DIR
app.config["MAX_CONTENT_LENGTH"] = MAX_CONTENT_LENGTH


class TimeoutError(Exception):
    pass


def _timeout_handler(signum, frame):
    raise TimeoutError("processing timed out")


def run_with_timeout(func, *args, **kwargs):
    signal.signal(signal.SIGALRM, _timeout_handler)
    signal.alarm(PROCESS_TIMEOUT)
    try:
        return func(*args, **kwargs)
    finally:
        signal.alarm(0)


@app.errorhandler(RequestEntityTooLarge)
def handle_file_too_large(e):
    return jsonify({"error": "file too large"}), 413


@app.get("/health")
def health():
    return {"status": "ok"}


def detect_language(text: str) -> str:
    try:
        return detect(text) if text.strip() else "unknown"
    except LangDetectException:
        return "unknown"


def extract_pdf(path: str) -> str:
    doc = fitz.open(path)
    text = "".join(page.get_text() for page in doc)
    if text.strip():
        return text
    images = convert_from_path(path)
    ocr_text = []
    for img in images:
        ocr_text.append(pytesseract.image_to_string(img, lang="ces+eng"))
    return "\n".join(ocr_text)


def extract_docx(path: str) -> str:
    document = docx.Document(path)
    return "\n".join([p.text for p in document.paragraphs])


def extract_txt(path: str) -> str:
    with open(path, "rb") as f:
        raw = f.read()
    enc = chardet.detect(raw).get("encoding")
    if enc:
        try:
            return raw.decode(enc)
        except Exception:
            pass
    # fallback to tika
    parsed = parser.from_file(path)
    return parsed.get("content", "")


def extract_image(path: str) -> str:
    image = Image.open(path)
    return pytesseract.image_to_string(image, lang="ces+eng")


def process_file(path: str):
    mime = magic.from_file(path, mime=True)
    if mime == "application/pdf":
        file_type = "pdf"
        text = extract_pdf(path)
    elif mime in (
        "application/vnd.openxmlformats-officedocument.wordprocessingml.document",
        ):
        file_type = "docx"
        text = extract_docx(path)
    elif mime.startswith("text"):
        file_type = "txt"
        text = extract_txt(path)
    elif mime.startswith("image"):
        file_type = "image"
        text = extract_image(path)
    else:
        file_type = "unknown"
        text = ""
    return file_type, text


@app.post("/extract")
def extract():
    if "file" not in request.files:
        return jsonify({"error": "no file provided"}), 400
    file = request.files["file"]
    if file.filename == "":
        return jsonify({"error": "empty filename"}), 400

    filename = secure_filename(file.filename)
    os.makedirs(app.config["UPLOAD_FOLDER"], exist_ok=True)
    temp_path = os.path.join(app.config["UPLOAD_FOLDER"], filename)
    file.save(temp_path)
    try:
        file_type, text = run_with_timeout(process_file, temp_path)
        language = detect_language(text)
        return jsonify({
            "text": text,
            "language": language,
            "type": file_type,
            "filename": filename,
        })
    except TimeoutError:
        return jsonify({"error": "processing timeout"}), 408
    except Exception as e:
        return jsonify({"error": str(e)}), 500
    finally:
        try:
            os.remove(temp_path)
        except OSError:
            pass


if __name__ == "__main__":
    app.run(host="0.0.0.0", port=5001)
