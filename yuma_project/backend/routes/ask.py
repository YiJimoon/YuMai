from fastapi import APIRouter
from pydantic import BaseModel
from typing import Optional
from typing import List
from backend.services.ask_service import answer_question

router = APIRouter()


class HistoryMessage(BaseModel):
    role: str
    content: str


class AskRequest(BaseModel):
    story_id: Optional[int] = None
    question: str
    use_rag: bool = True
    history: Optional[List[HistoryMessage]] = None
    lang: str = 'zh'   # 问答语言：zh/bo/ii


@router.post("/ask")
def ask_question(data: AskRequest):
    try:
        # 转换 history 格式
        history = None
        if data.history:
            history = [{"role": m.role, "content": m.content} for m in data.history]
        answer = answer_question(data.story_id, data.question, data.use_rag, history, lang=data.lang)
        return answer
    except Exception as e:
        print("ERROR:", e)
        import traceback
        traceback.print_exc()
        return {"error": str(e)}
