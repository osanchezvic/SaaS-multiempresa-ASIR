from fastapi import FastAPI, Header, HTTPException, Request
import subprocess
import os

app = FastAPI()

# Simple token-based auth
API_TOKEN = os.getenv("API_TOKEN", "supersecrettoken")

def verify_token(token: str = Header(...)):
    if token != API_TOKEN:
        raise HTTPException(status_code=403, detail="Invalid token")

@app.post("/deploy/{company}/{service}")
async def deploy(company: str, service: str, token: str = Header(...)):
    verify_token(token)
    # Trigger the deploy script
    # We assume deploy.sh is in /workspaces/SaaS-multiempresa-ASIR/scripts/deploy.sh
    result = subprocess.run(["/workspaces/SaaS-multiempresa-ASIR/scripts/deploy.sh", company, service], capture_output=True, text=True)
    return {"stdout": result.stdout, "stderr": result.stderr, "returncode": result.returncode}

@app.get("/status/{company}")
async def status(company: str, token: str = Header(...)):
    verify_token(token)
    # List services for company (using ls or similar to check directory)
    path = f"/workspaces/SaaS-multiempresa-ASIR/data/{company}"
    if not os.path.exists(path):
        return {"error": "Company not found"}
    services = os.listdir(path)
    return {"company": company, "services": services}
