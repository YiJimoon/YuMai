[README_V3.md](https://github.com/user-attachments/files/26507852/README_V3.md)
# 语脉 (YUMAI) v3.0 — 多语言非遗故事阅读与 AI 问答平台

> 整合版（主版本 + A同学语言模块 + B同学离线模块）
> 日期：2026-04-06

---

## 一、项目简介

**语脉（YUMAI）** 是一款中国少数民族语言（非遗）故事阅读与 AI 问答平台，支持汉语、藏语、彝语三种语言。

### 解决什么问题

1. **语言保护**：少数民族传统故事以汉语、藏语（博伽梵）、彝语三语形式存储，帮助传承濒危语言文化
2. **智能阅读**：提供沉浸式阅读器，支持三语切换、字体大小调节
3. **AI 问答**：基于 RAG（检索增强生成）技术，用户可针对故事内容提问，AI 用对应语言回答
4. **离线阅读**：下载故事到本地，无网络也能阅读
5. **语音支持**：文字转语音（TTS）、语音转文字（STT）功能

---

## 二、系统架构

```
┌─────────────────────────────────────────────────────┐
│                    Flutter 前端                       │
│  (yumai_app/lib/)                                   │
│                                                      │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐ │
│  │HomeScreen│ │StoryList│ │StoryDet│ │ AI Chat  │ │
│  └─────────┘ └─────────┘ └─────────┘ └──────────┘ │
│  ┌─────────┐ ┌─────────┐ ┌─────────┐ ┌──────────┐ │
│  │Bookshelf │ │History  │ │Downloads│ │ Profile  │ │
│  └─────────┘ └─────────┘ └─────────┘ └──────────┘ │
│         ↑        ↑         ↑         ↑              │
│    LanguageProvider (全局语言状态)                 │
│    OfflineStorageService (离线存储)                 │
└──────────────────┬──────────────────────────────────┘
                   │ HTTP/REST API
                   ▼
┌──────────────────────────────────────────────────────┐
│                  Python FastAPI 后端                  │
│              (yuma_project/backend/)                  │
│                                                      │
│  ┌──────────────────────────────────────────────┐   │
│  │ routes/                                      │   │
│  │  ask.py  stories.py  tts.py  stt.py        │   │
│  └──────────────────────────────────────────────┘   │
│  ┌──────────────────────────────────────────────┐   │
│  │ services/                                    │   │
│  │  agent.py (DeepSeek 大模型 + RAG)            │   │
│  │  rag_service.py (向量检索 FAISS)              │   │
│  │  ask_service.py (问答逻辑)                   │   │
│  │  stories_service.py (故事数据)               │   │
│  └──────────────────────────────────────────────┘   │
└──────────────────────┬───────────────────────────────┘
                       │
                       ▼
┌──────────────────────────────────────────────────────┐
│                   数据层                              │
│  data/stories.json (多语言故事数据)                 │
│  data/vector.index (FAISS 向量索引)                 │
│  models/paraphrase-multilingual-MiniLM-L12-v2/      │
│  (Sentence-Transformers 多语言Embedding模型)        │
└──────────────────────────────────────────────────────┘
```

---

## 三、功能说明

### 3.1 多语言系统

**做什么**：支持汉语（zh）、藏语（bo）、彝语（ii）三语切换

**怎么用**：

- 首页右上角点击语言切换按钮
- 全局生效，所有页面同步语言
- AI 问答也使用对应语言回答

**技术实现**：

- `LanguageProvider`：全局语言状态管理（ChangeNotifier）
- `translations.dart`：三语翻译字符串集中管理
- `buildLanguageSwitcher`：统一的语言切换下拉组件
- 后端 `agent.py` 的 `lang` 参数控制 AI 回答语言

### 3.2 AI 问答（RAG）

**做什么**：用户输入关于故事的问题，AI 基于故事内容回答

**怎么用**：

- 在故事详情页，向下滚动到问答区输入问题
- 或进入"问答"Tab，进行全局对话
- 支持多轮对话上下文记忆
- AI 自动用当前选择的语言回答

**技术实现**：

- 前端 `ApiService.askQuestion()` 调用后端 `/ask` 接口
- 后端 `rag_service.py` 用 Sentence-Transformers 编码问题，FAISS 向量检索相似故事
- `agent.py` 调用 DeepSeek Chat API 生成回答
- 支持 `lang` 参数（zh/bo/ii）控制回答语言
- `suggestions` 字段返回"猜你想问"建议

### 3.3 离线阅读

**做什么**：下载故事到本地，零流量阅读

**怎么用**：

- 故事详情页点击下载图标（↓）
- 进入"我的 → 下载"查看已下载故事
- 点击已下载故事直接阅读，无需网络
- 长按可删除下载

**技术实现**：

- `OfflineStorageService`：基于 SharedPreferences 的离线存储
- 存储结构：story JSON + 下载时间戳
- 下载屏幕用 GridView 展示所有下载故事

### 3.4 沉浸式阅读器

**做什么**：全屏阅读故事内容，支持字体大小调节

**怎么用**：

- 故事详情页点击"进入阅读"按钮
- 可调节字体大小（设置图标）
- 记录阅读位置，关闭后重新打开会提示继续

**技术实现**：

- `ReaderScreen`：独立阅读页面
- 阅读位置保存到 `SharedPreferences`（history key）
- 支持藏文（Noto Serif Tibetan）、彝文（Noto Sans Yi）字体

### 3.5 语音功能

**做什么**：

- **TTS**：文字转语音，播放故事音频（调用后端 Edge TTS）
- **STT**：语音转文字，录入用户语音问题

**技术实现**：

- `ApiService.getTtsAudio()` → 后端 `GET /tts/{story_id}` → Edge TTS MP3 流
- `ApiService.speechToText()` → 后端 `POST /stt` → Whisper 模型

### 3.6 书架与历史

**做什么**：

- 收藏故事到书架（书签图标）
- 自动记录浏览历史

**技术实现**：

- 书架：`SharedPreferences` key = `yumai_bookshelf`
- 历史：`SharedPreferences` key = `yumai_history`

---

## 四、技术栈说明


| 技术                      | 用途           | 说明                                      |
| ------------------------- | -------------- | ----------------------------------------- |
| **Flutter**               | 前端跨平台框架 | 多平台输出（iOS/Android/Web）             |
| **Dart**                  | 前端语言       | Flutter 专用语言                          |
| **Provider**              | 状态管理       | 全局语言状态广播                          |
| **FastAPI**               | 后端 Web 框架  | 高性能 Python ASGI                        |
| **Python**                | 后端语言       | 服务端逻辑                                |
| **DeepSeek Chat**         | 大模型 API     | AI 问答生成（base_url: api.deepseek.com） |
| **FAISS**                 | 向量检索       | RAG 语义搜索加速                          |
| **Sentence-Transformers** | 文本 Embedding | 多语言语义向量编码                        |
| **Edge TTS**              | 文字转语音     | 微软在线 TTS 服务                         |
| **Whisper**               | 语音转文字     | OpenAI 离线语音识别                       |
| **SharedPreferences**     | 本地存储       | 前端键值存储（离线/设置）                 |
| **JSON**                  | 数据格式       | stories.json 故事数据                     |

---

## 五、项目结构说明

```
yumai/                              # 项目根目录
│
├── CLAUDE.md                       # Claude Code 指导文件
├── README_V3.md                    # 本文档（v3.0整合版）
│
├── yuma_project/                   # ========== Python 后端 ==========
│   ├── backend/
│   │   ├── app.py                  # FastAPI 入口，CORS 中间件，静态文件挂载
│   │   ├── routes/
│   │   │   ├── ask.py             # POST /ask — AI 问答（lang参数）
│   │   │   ├── stories.py         # GET /stories, /story/{id}, /stories/search
│   │   │   ├── tts.py             # GET /tts/{story_id} — 文字转语音
│   │   │   └── stt.py             # POST /stt — 语音转文字
│   │   └── services/
│   │   │   ├── agent.py           # DeepSeek 大模型调用 + 语言指令
│   │   │   ├── ask_service.py     # 问答入口（RAG/自由对话路由）
│   │   │   ├── rag_service.py     # FAISS 向量检索（相对路径）
│   │   │   └── stories_service.py # 故事数据加载
│   │
│   ├── data/
│   │   ├── stories.json           # ⭐ B版本更新数据（藏/彝/汉三语）
│   │   ├── stories.json.v2.bak    # 主版本旧数据备份
│   │   ├── vector.index           # FAISS 向量索引
│   │   └── vector_meta.json       # 向量索引元数据
│   │
│   └── models/
│       └── paraphrase-multilingual-MiniLM-L12-v2/
│           └── ...                  # Sentence-Transformers 多语言模型
│
└── yumai_app/                      # ========== Flutter 前端 ==========
    ├── lib/
    │   ├── main.dart              # App 入口，MaterialApp
    │   │
    │   ├── models/
    │   │   └── story.dart         # Story 数据模型（多格式 JSON 兼容）
    │   │
    │   ├── screen/                # 7 个页面
    │   │   ├── home_screen.dart       # 首页
    │   │   ├── story_list_screen.dart # 故事列表 + 搜索
    │   │   ├── story_detail_screen.dart# 故事详情 + 问答 + 下载
    │   │   ├── reader_screen.dart     # 沉浸式阅读器
    │   │   ├── ai_chat_screen.dart     # AI 全局问答（支持语音）
    │   │   ├── bookshelf_screen.dart   # 书架
    │   │   ├── history_screen.dart     # 历史浏览
    │   │   ├── downloads_screen.dart    # 离线下载管理
    │   │   └── profile_screen.dart     # 个人中心
    │   │
    │   ├── services/
    │   │   ├── api_services.dart          # HTTP 客户端（lang参数 + detectLanguage）
    │   │   ├── language_provider.dart      # 全局语言状态管理
    │   │   ├── translations.dart            # 三语翻译字符串（zh/bo/ii）
    │   │   └── offline_storage_service.dart# 离线存储服务
    │   │
    │   ├── theme/
    │   │   ├── app_theme.dart         # 颜色/语义颜色定义
    │   │   └── theme_provider.dart    # 主题（亮/暗）管理
    │   │
    │   └── widgets/
    │       └── common_widgets.dart    # 通用组件（LoadingOverlay/buildLanguageSwitcher等）
    │
    ├── pubspec.yaml                 # Flutter 依赖配置
    └── ...
```

---

## 六、环境配置

### 6.1 Python 环境

- **Python 版本**：3.10 ~ 3.13
- **推荐**：在项目根目录创建虚拟环境

```bash
cd yuma_project

# 创建虚拟环境（推荐）
python -m venv venv
source venv/bin/activate   # Linux/Mac
# venv\Scripts\activate    # Windows

# 安装依赖
pip install fastapi uvicorn edge-tts openai-whisper python-dotenv openai sentence-transformers faiss-cpu
```

### 6.2 .env 配置文件

在后端根目录 `yuma_project/` 创建 `.env` 文件：

```env
OPENAI_API_KEY=你的DeepSeek_API密钥
```

> 注意：如果不创建 .env 文件，AI 问答功能报错，其他功能（故事列表/阅读/下载）不受影响

### 6.3 Flutter 环境

- **Flutter 版本**：3.x（建议 3.10+）
- **Dart 版本**：随 Flutter 捆绑

```bash
cd yumai_app

# 安装依赖
flutter pub get

# 检查环境
flutter doctor
```

### 6.4 Android 配置（如需 Android）

`android/app/src/main/AndroidManifest.xml` 需包含：

```xml
<uses-permission android:name="android.permission.INTERNET"/>
```

已配置，无需修改。

---

## 七、启动教程

### 7.1 启动后端

```bash
cd yuma_projectcd yuma_project

# 激活虚拟环境（如已激活可跳过）
# Linux/Mac: source venv/bin/activate
# Windows: venv\Scripts\activate

# 启动后端（本地，只允许本机访问）
uvicorn backend.app:app --reload

# 启动后端（允许局域网访问，用于手机真机调试）
uvicorn backend.app:app --reload --host 0.0.0.0 --port 8000
```

验证后端是否启动：

```bash
curl http://127.0.0.1:8000/
# 应返回 {"message": "YUMAI API Running"}
```

### 7.2 启动前端

```bash
cd yumai_app

# Web 开发（Chrome）
flutter run -d chrome

# Android 模拟器（自动使用 10.0.2.2:8000 访问后端）
flutter run -d android

# iOS 模拟器
flutter run -d ios

# 真机调试（需在同一局域网，后端启动时用 --host 0.0.0.0）
flutter run --dart-define=API_BASE_URL=http://你的电脑IP:8000 -d android
```

---

## 八、测试指南

### 8.1 基础功能测试


| 步骤 | 操作                                       | 期望结果                               |
| ---- | ------------------------------------------ | -------------------------------------- |
| 1    | 启动后端`uvicorn backend.app:app --reload` | 无报错，显示 "Uvicorn running"         |
| 2    | 启动前端`flutter run -d chrome`            | 浏览器打开 APP 首页                    |
| 3    | 点击故事卡片                               | 进入故事详情页，显示标题/简介/正文预览 |
| 4    | 点击右上角语言切换                         | 语言切换为藏语/彝语，页面翻译变化      |
| 5    | 点击"进入阅读"                             | 打开沉浸式阅读器                       |
| 6    | 调节字体大小                               | 阅读字体大小变化                       |

### 8.2 AI 问答测试


| 步骤 | 操作                           | 期望结果                                 |
| ---- | ------------------------------ | ---------------------------------------- |
| 1    | 在故事详情页滚动到问答区       | 显示输入框和"向 AI 提问..."提示          |
| 2    | 输入问题："这个故事讲了什么？" | AI 回复内容（如果配置了 OPENAI_API_KEY） |
| 3    | 切换语言为藏语，输入藏语问题   | AI 用藏语回复                            |
| 4    | 继续追问（如"主角是谁？"）     | AI 结合上一轮对话回答                    |

### 8.3 离线功能测试


| 步骤 | 操作               | 期望结果                   |
| ---- | ------------------ | -------------------------- |
| 1    | 进入故事详情页     | 右上角有下载图标           |
| 2    | 点击下载图标       | 显示"已下载"提示           |
| 3    | 关闭网络           | 断开网络连接               |
| 4    | 进入"我的 → 下载" | 显示已下载故事（无需网络） |
| 5    | 点击已下载故事     | 正常打开阅读（离线可用）   |

### 8.4 书架与历史测试


| 步骤 | 操作                           | 期望结果                   |
| ---- | ------------------------------ | -------------------------- |
| 1    | 故事详情页点击书签图标         | 图标变为实心，显示"已收藏" |
| 2    | 进入"我的 → 书架"             | 显示收藏的故事             |
| 3    | 浏览故事后，进入"我的 → 历史" | 显示浏览过的故事           |

---

## 九、API 接口说明


| 方法 | 路径                        | 说明                                                                |
| ---- | --------------------------- | ------------------------------------------------------------------- |
| GET  | `/stories`                  | 获取故事列表                                                        |
| GET  | `/stories/search?query=xxx` | 搜索故事                                                            |
| GET  | `/story/{story_id}`         | 获取故事详情                                                        |
| POST | `/ask`                      | AI 问答（body 包含 question, story_id?, use_rag?, history?, lang?） |
| GET  | `/tts/{story_id}`           | 获取 TTS 音频流（MP3）                                              |
| POST | `/stt`                      | 语音转文字（multipart audio）                                       |

### `/ask` 请求体示例

```json
{
  "story_id": 1,
  "question": "这个故事的主角是谁？",
  "use_rag": true,
  "lang": "zh",
  "history": [
    {"role": "user", "content": "之前的问题"},
    {"role": "assistant", "content": "之前的回答"}
  ]
}
```

### `/ask` 响应示例

```json
{
  "answer": "格萨尔王是藏族古代英雄史诗《格萨尔王传》的主角...",
  "source": "格萨尔王传",
  "rag_sources": [{"title": "格萨尔王传", "score": 0.87}],
  "suggestions": ["格萨尔王有什么主要事迹？", "格萨尔王传是哪个民族的故事？"]
}
```

---

## 十、常见问题 + 解决方案

### Q1: AI 问答报 "OPENAI_API_KEY 未设置"

**原因**：未创建 `.env` 文件或未配置 API Key
**解决**：在后端目录创建 `.env` 文件，写入 `OPENAI_API_KEY=你的密钥`

### Q2: 后端启动报错 "Module not found"

**原因**：未安装 Python 依赖
**解决**：`pip install fastapi uvicorn edge-tts openai-whisper python-dotenv openai sentence-transformers faiss-cpu`

### Q3: 前端报网络错误，无法连接后端

**原因**：后端未启动，或 API_BASE_URL 配置错误
**解决**：

- 确认后端已启动：`curl http://127.0.0.1:8000/`
- 真机调试需使用电脑局域网 IP，而非 127.0.0.1

### Q4: 藏语/彝语显示为方块（缺少字体）

**原因**：系统未安装 Noto Serif Tibetan / Noto Sans Yi 字体
**解决**：

- Android：fonts 目录下放入字体文件，pubspec.yaml 配置
- Web：Google Fonts 自动加载
- iOS：系统自带部分字体支持

### Q5: 语音输入/输出不工作

**原因**：

- TTS：后端 Edge TTS 需要网络
- STT：Whisper 模型较大，首次加载慢
  **解决**：确保网络畅通，等待模型加载完成

### Q6: 离线下载的故事打不开

**原因**：故事数据格式与离线存储不兼容
**解决**：清除应用数据，重新下载（v3.0 已修复存储结构）

---

## 十一、注意事项

1. **API Key 安全**：`.env` 文件不要提交到代码仓库，已加入 `.gitignore`
2. **网络要求**：首次启动需要网络下载模型；TTS/AI 问答需要持续网络连接
3. **手机调试**：真机调试时后端需用 `--host 0.0.0.0` 启动，前端用 `--dart-define=API_BASE_URL=http://<手机IP>:8000`
4. **向量模型**：首次运行 RAG 检索会下载/加载 Sentence-Transformers 模型（约 470MB），请耐心等待
5. **数据备份**：替换 `stories.json` 前会备份到 `stories.json.v2.bak`

---

## 十二、v3.0 更新说明

### 整合来源

- **主版本**（yumai）：基础框架，多语言架构，离线存储基础
- **A版本**（nongcaibin）：语言模块（lang参数），`buildLanguageSwitcher` 组件，AI 强化语言指令
- **B版本**（likexin）：离线存储服务（`OfflineStorageService`），`downloads_screen`，最新故事数据

### 主要新增


| 功能                          | 来源  | 说明                                                                       |
| ----------------------------- | ----- | -------------------------------------------------------------------------- |
| `lang` 参数支持               | A版本 | 后端`/ask` 接口支持 `lang=zh/bo/ii`，AI 用对应语言回答                     |
| RAG 相对路径                  | A版本 | `rag_service.py` 使用 `Path(__file__).resolve().parents[2]` 而非硬编码路径 |
| `buildLanguageSwitcher`       | A版本 | 统一语言切换下拉组件，所有页面复用                                         |
| `OfflineStorageService`       | B版本 | 离线下载服务，SharedPreferences 存储                                       |
| `downloads_screen`            | B版本 | 离线下载管理页面，GridView 展示                                            |
| `detectLanguage`              | A版本 | 根据文字内容自动检测语言                                                   |
| AI 强化语言指令               | A版本 | 非汉语模式下，system prompt 多语言约束                                     |
| `askPrompt` / `examplePrompt` | A版本 | 翻译补全，故事详情页问答引导                                               |
| 最新故事数据                  | B版本 | `stories.json` 更新为 B 版本                                               |
| 矢量索引更新                  | B版本 | `vector.index` + `vector_meta.json` 同步更新                               |

### 代码清理

- 删除未使用的字段/方法（`_showNovelNav`, `_novelPageIndex`, `_novelPages`, `_downloadStory`, `_splitIntoPages`, `_playTtsAudio`, `_isAudioLoading`, `_contentLang` 等）
- 修复下载按钮：旧版本仅显示测试消息，现已连接 `OfflineStorageService`
- 所有路径使用相对路径，无绝对路径硬编码

---

## 十三、验收报告


| 检查项              | 状态 | 备注                                  |
| ------------------- | ---- | ------------------------------------- |
| 后端可启动          | ✅   | 无报错，所有模块加载成功              |
| 前端可运行          | ✅   | Flutter analyze 0 errors              |
| `/ask` 接口正常     | ✅   | 支持 lang 参数                        |
| lang 参数有效       | ✅   | zh/bo/ii 三语言支持                   |
| AI 回答语言正确     | ✅   | system prompt + 用户消息双重语言约束  |
| 所有页面正常打开    | ✅   | 7个页面 + 阅读器                      |
| 全局语言切换正常    | ✅   | LanguageProvider 广播通知             |
| 各页面语言同步      | ✅   | Consumer 模式自动重建                 |
| 问答语言与正文一致  | ✅   | lang 参数传递到 API                   |
| 可下载故事          | ✅   | OfflineStorageService                 |
| 离线可查看          | ✅   | downloads_screen                      |
| 可删除下载          | ✅   | 离线管理页支持                        |
| stories.json 已更新 | ✅   | B版本，v2.bak 备份                    |
| 语言切换按钮统一    | ✅   | buildLanguageSwitcher 复用            |
| 无本地绝对路径      | ✅   | Path(__file__) 相对路径               |
| 无写死 IP           | ✅   | baseUrl 自动检测 + --dart-define 覆盖 |

---

## 十四、潜在风险提示

1. **Whisper 模型**：STT 使用 openai-whisper，首次运行需下载模型（约 150MB）
2. **向量检索性能**：每次检索重新构建 FAISS 索引（设计如此，保证数据最新），大量故事时首次检索较慢
3. **离线存储容量**：SharedPreferences 有容量限制，大量离线故事可能达上限（建议清理旧下载）
4. **DeepSeek API 费用**：AI 问答调用产生 API 费用，注意配额限制
5. **藏语/彝语字体**：部分平台可能无法渲染少数民族文字，需要额外配置字体

---

*文档版本：v3.0 | 整合日期：2026-04-06 | 面向用户：新手可独立运行*
