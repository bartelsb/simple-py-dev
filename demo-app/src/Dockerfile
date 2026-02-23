FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

ENV APP_VERSION=1.0.0

EXPOSE 5000

CMD ["flask", "--app", "server", "run", "--host=0.0.0.0"]
