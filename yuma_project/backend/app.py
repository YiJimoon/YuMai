from pathlib import Path

from fastapi import FastAPI
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles

from backend.routes.root import router as root_router
from backend.routes.stories import router as stories_router
from backend.routes.ask import router as ask_router
from backend.routes.tts import router as tts_router
#from backend.routes.stt import router as stt_router


app = FastAPI()

# 静态文件服务（封面图片）
_static_dir = Path(__file__).resolve().parent / "static"
_static_dir.mkdir(exist_ok=True)
app.mount("/static", StaticFiles(directory=str(_static_dir)), name="static")

# 开发阶段允许所有来源跨域，便于 Flutter Web 调用 API
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

app.include_router(root_router)
app.include_router(stories_router)
app.include_router(ask_router)
app.include_router(tts_router)
#app.include_router(stt_router)
