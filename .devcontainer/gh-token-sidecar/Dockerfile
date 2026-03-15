FROM python:3.14-alpine

RUN python -m venv /app/venv
ENV PATH="/app/venv/bin:$PATH"

RUN pip install --no-cache-dir PyJWT cryptography

COPY server.py /app/server.py

EXPOSE 80

CMD ["python", "/app/server.py"]
