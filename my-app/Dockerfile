FROM python:3.10-slim


WORKDIR /app

RUN useradd -m appuser && chown -R appuser:appuser /app

COPY requirements.txt /app/
RUN pip install --no-cache-dir -r requirements.txt

COPY app.py /app/

RUN chown -R appuser:appuser /app

USER appuser

EXPOSE 8080

CMD ["python", "app.py"]
