FROM python:3.14-slim

WORKDIR /app

COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt

COPY server.py .

ARG APP_VERSION=1.0.0
ENV APP_VERSION=${APP_VERSION}
EXPOSE 5000

CMD ["flask", "--app", "server", "run", "--host=0.0.0.0"]
