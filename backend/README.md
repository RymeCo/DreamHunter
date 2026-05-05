# DreamHunter Backend (FastAPI)

## Deployment to Render.com

1. **Create Web Service**: Link your GitHub repo to a new Web Service on Render.
2. **Root Directory**: Set to `backend`.
3. **Environment Variables**:
   - `FIREBASE_SERVICE_ACCOUNT_JSON`: Paste the entire content of your Firebase Service Account JSON key.
   - `PYTHON_VERSION`: `3.11.0`
4. **Build & Start**:
   - Build Command: `pip install -r requirements.txt`
   - Start Command: `uvicorn main:app --host 0.0.0.0 --port $PORT`

## Local Development (Optional)
If you want to run it locally for testing later:
1. `cd backend`
2. `pip install -r requirements.txt`
3. Place your `serviceAccountKey.json` in the `backend/` folder.
4. `uvicorn main:app --reload`
