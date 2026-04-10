from fastapi import APIRouter,Query
from backend.services.stories_service import list_stories, get_story_by_id, get_all_stories

router = APIRouter()

def adapt_language(story: dict, lang: str) -> dict:
    new_story = story.copy()
    title_obj = new_story.get("title")
    if isinstance(title_obj, dict):
        # 兼容 yi 和 ii 两种键名
        if lang == 'ii':
            lang = 'yi'   # 将前端传来的 ii 映射为 yi
        new_story["title"] = title_obj.get(lang, title_obj.get("zh", ""))
    return new_story

def get_title_for_search(story: dict) -> str:
    """获取用于搜索的标题文本（始终使用中文）"""
    title = story.get("title", "")
    if isinstance(title, dict):
        return title.get("zh", "")
    return title

@router.get("/stories")
def get_stories(lang: str = Query("zh")):
    stories = list_stories()  # 原始数据列表
    return [adapt_language(s, lang) for s in stories]

@router.get("/stories/search")
async def search_stories(query: str = "", lang: str = Query("zh")):
    """按 title / ethnic / keywords 搜索故事，返回与 /stories 相同结构，支持多语言标题。"""
    if not query:
        return []
    q = query.lower()
    results = []
    for story in get_all_stories():
        if "id" not in story or "title" not in story:
            continue
        # 搜索始终基于中文标题
        title_for_search = get_title_for_search(story)
        hit = (
            q in title_for_search.lower()
            or q in story.get("ethnic", "").lower()
            or any(q in kw.lower() for kw in story.get("keywords", []))
        )
        if hit:
            # 先适配语言再添加到结果，避免修改原始数据
            adapted = adapt_language(story, lang)
            results.append(adapted)
    return list_stories(stories=results)

@router.get("/story/{story_id}")
def get_story(story_id: int, lang: str = Query("zh")):
    """返回完整故事对象，支持多语言标题。"""
    story = get_story_by_id(story_id)
    if story is None:
        return {"error": "story not found"}
    # 适配语言（不修改原始缓存）
    return adapt_language(story, lang)