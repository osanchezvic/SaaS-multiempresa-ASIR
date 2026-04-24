from fastapi import FastAPI, Header, HTTPException, Request
import subprocess
import os
import logging

# Configurar logging
logging.basicConfig(level=logging.INFO)
logger = logging.getLogger(__name__)

app = FastAPI()

# Simple token-based auth
API_TOKEN = os.getenv("API_TOKEN", "supersecrettoken")
PROJECT_ROOT = os.getenv("PROJECT_ROOT", "/app")

def verify_token(token: str = Header(...)):
    if token != API_TOKEN:
        logger.warning(f"Intento de acceso con token inválido: {token}")
        raise HTTPException(status_code=403, detail="Invalid token")

@app.post("/deploy/{company}/{service}")
async def deploy(company: str, service: str, token: str = Header(...)):
    verify_token(token)
    logger.info(f"Iniciando despliegue: {company}/{service}")
    
    deploy_script = os.path.join(PROJECT_ROOT, "scripts/deploy.sh")
    
    if not os.path.exists(deploy_script):
        logger.error(f"Script no encontrado: {deploy_script}")
        raise HTTPException(status_code=500, detail="Deployment script not found")

    try:
        # Ejecutar el script capturando la salida
        result = subprocess.run(
            [deploy_script, company, service], 
            capture_output=True, 
            text=True,
            env={**os.environ, "FORCE_MODE": "1"}
        )
        
        if result.returncode != 0:
            logger.error(f"Error en el script de despliegue (Code {result.returncode}): {result.stderr}")
            return {
                "status": "error",
                "message": "Deployment failed",
                "stdout": result.stdout,
                "stderr": result.stderr,
                "returncode": result.returncode
            }
            
        logger.info(f"Despliegue completado con éxito: {company}/{service}")
        return {
            "status": "success",
            "stdout": result.stdout,
            "returncode": result.returncode
        }
    except Exception as e:
        logger.error(f"Excepción durante el despliegue: {str(e)}")
        raise HTTPException(status_code=500, detail=str(e))

@app.get("/status/{company}")
async def status(company: str, token: str = Header(...)):
    verify_token(token)
    path = os.path.join(PROJECT_ROOT, f"data/{company}")
    if not os.path.exists(path):
        return {"error": "Company not found"}
    services = os.listdir(path)
    return {"company": company, "services": services}
