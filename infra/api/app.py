from fastapi import FastAPI, Header, HTTPException, Request
import subprocess
import os

app = FastAPI()

# Simple token-based auth
API_TOKEN = os.getenv("API_TOKEN", "supersecrettoken")
PROJECT_ROOT = os.getenv("PROJECT_ROOT", "/home/oscar/SaaS-multiempresa-ASIR")

def verify_token(token: str = Header(...)):
    if token != API_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid token")

@app.post("/deploy/{company}/{service}")
async def deploy(company: str, service: str, token: str = Header(...)):
    verify_token(token)
    # Trigger the deploy script
    deploy_script = os.path.join(PROJECT_ROOT, "scripts/deploy.sh")
    result = subprocess.run([deploy_script, company, service], capture_output=True, text=True)
    return {"stdout": result.stdout, "stderr": result.stderr, "returncode": result.returncode}

@app.get("/status/{company}")
async def status(company: str, token: str = Header(...)):
    verify_token(token)
    # List services for company (using ls or similar to check directory)
    path = os.path.join(PROJECT_ROOT, f"data/{company}")
    if not os.path.exists(path):
        return {"error": "Company not found"}
    services = os.listdir(path)
    return {"company": company, "services": services}
