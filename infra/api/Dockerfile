FROM python:3.9-slim
WORKDIR /app
RUN apt-get update && apt-get install -y docker.io
COPY requirements.txt .
RUN pip install -r requirements.txt
COPY app.py .
CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
