import os
from backend.services.stories_service import _load_stories
from typing import Optional, Any, List, Dict
from pathlib import Path


# 尝试导入 sentence-transformers
try:
    from sentence_transformers import SentenceTransformer
    SENTENCE_TRANSFORMER_AVAILABLE = True
except ImportError:
    SENTENCE_TRANSFORMER_AVAILABLE = False
    SentenceTransformer = Any  # 占位符，避免 NameError
    print("警告: sentence-transformers 未安装，向量搜索功能将被禁用。如需使用，请执行：pip install sentence-transformers faiss-cpu")

# 尝试导入 faiss
try:
    import faiss
    FAISS_AVAILABLE = True
except ImportError:
    FAISS_AVAILABLE = False
    faiss = Any  # 占位符
    print("警告: faiss 未安装，向量搜索功能将被禁用。如需使用，请执行：pip install faiss-cpu")

# 路径配置
PROJECT_ROOT = Path(__file__).resolve().parents[2]
MODEL_PATH = PROJECT_ROOT / "models" / "paraphrase-multilingual-MiniLM-L12-v2"

_model: Optional[SentenceTransformer] = None
_index: Optional[Any] = None
_stories: List[Dict[str, Any]] = []

def _get_model() -> Optional[SentenceTransformer]:
    global _model
    if not SENTENCE_TRANSFORMER_AVAILABLE:
        return None
    if _model is None:
        if not MODEL_PATH.exists():
            _model = SentenceTransformer("paraphrase-multilingual-MiniLM-L12-v2", cache_folder=str(MODEL_PATH.parent))
            _model.save(str(MODEL_PATH))
        else:
            _model = SentenceTransformer(str(MODEL_PATH))
    return _model

def _extract_content(story: Dict[str, Any]) -> str:
    parts: List[str] = []
    title = story.get("title")
    if isinstance(title, str) and title.strip():
        parts.append(title.strip())
    intro = story.get("intro")
    if isinstance(intro, str) and intro.strip():
        parts.append(intro.strip())
    content = story.get("content")
    if isinstance(content, dict):
        zh = content.get("zh") or content.get("ZH") or content.get("cn") or content.get("CN")
        if isinstance(zh, str) and zh.strip():
            parts.append(zh.strip())
    elif isinstance(content, str) and content.strip():
        parts.append(content.strip())
    else:
        for key in ("chinese_text", "yi_text"):
            val = story.get(key)
            if isinstance(val, str) and val.strip():
                parts.append(val.strip())
                break
    return "\n".join(parts) if parts else ""

def _build_index() -> None:
    global _index, _stories
    if not (SENTENCE_TRANSFORMER_AVAILABLE and FAISS_AVAILABLE):
        print("⚠️ 向量搜索依赖缺失，跳过索引构建")
        _index = None
        _stories = []
        return

    _index = None
    _stories = []
    all_stories = _load_stories()  # 确保这个函数存在（原文件已有）
    texts: List[str] = []
    kept_stories: List[Dict[str, Any]] = []
    print(f"========== RAG 索引构建 ==========")
    print(f"共加载 {len(all_stories)} 个故事")
    for story in all_stories:
        text = _extract_content(story)
        if not text:
            print(f"  ⚠️ 跳过（无有效文本）: {story.get('title', '未知标题')}")
            continue
        print(f"  ✅ 索引: {story.get('title', '未知标题')} (文本长度: {len(text)})")
        texts.append(text)
        kept_stories.append(story)
    if not texts:
        _index = None
        _stories = []
        print("⚠️ 没有可用文本，未构建索引")
        return
    model = _get_model()
    if model is None:
        print("⚠️ 模型不可用，无法构建索引")
        _index = None
        _stories = []
        return
    embeddings = model.encode(texts, convert_to_numpy=True, normalize_embeddings=True)
    dim = embeddings.shape[1]
    index = faiss.IndexFlatIP(dim)
    index.add(embeddings)
    _index = index
    _stories = kept_stories
    print(f"✅ 索引构建完成，共 {len(texts)} 个故事向量，维度: {dim}")
    print("===================================")

def search_similar_stories(question: str, top_k: int = 3) -> List[Dict[str, Any]]:
    if not (SENTENCE_TRANSFORMER_AVAILABLE and FAISS_AVAILABLE):
        print("⚠️ 向量搜索不可用：缺少 sentence-transformers 或 faiss")
        return []
    _build_index()
    if _index is None or not _stories:
        return []
    model = _get_model()
    if model is None:
        return []
    query_embedding = model.encode([question], convert_to_numpy=True, normalize_embeddings=True)
    k = min(top_k, len(_stories))
    scores, indices = _index.search(query_embedding, k)
    SIMILARITY_THRESHOLD = 0.3
    result: List[Dict[str, Any]] = []
    for rank, idx in enumerate(indices[0]):
        score = float(scores[0][rank])
        if score < SIMILARITY_THRESHOLD:
            print(f"  🔇 过滤低相似度: {_stories[int(idx)].get('title', '未知')} (score={score:.3f})")
            continue
        story = _stories[int(idx)]
        story_with_score = dict(story)
        story_with_score["_score"] = score
        result.append(story_with_score)
    print("========== RAG 检索日志 ==========")
    for i, story in enumerate(result):
        try:
            print(f"Top{i+1}:", story.get("title", "未知标题"))
        except Exception:
            print(f"Top{i+1}: 无法读取标题")
    print("===================================")
    return result