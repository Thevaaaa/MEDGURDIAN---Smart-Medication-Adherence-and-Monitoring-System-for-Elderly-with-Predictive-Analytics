FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY features.py generate_dose_dataset.py train_model.py main.py ./
# build the dose-level dataset and train inside the image so the model always matches the installed scikit-learn
RUN python generate_dose_dataset.py && python train_model.py --quick
ENV PORT=8080
CMD exec uvicorn main:app --host 0.0.0.0 --port ${PORT}
