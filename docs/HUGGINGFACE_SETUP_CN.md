# HuggingFace 模型下载配置

MemPalace 的 Embedding 模型托管在 HuggingFace，国内直连速度慢，需要配置镜像和 Token。

---

## 1. 配置镜像加速（国内必须）

```bash
echo 'export HF_ENDPOINT=https://hf-mirror.com' >> ~/.zshrc
source ~/.zshrc
```

## 2. 配置 HuggingFace Token（提升速率）

1. 注册/登录 https://huggingface.co
2. 打开 https://huggingface.co/settings/tokens
3. 点 **New token**，权限选 **Read**
4. 复制 token，执行：

```bash
echo 'export HF_TOKEN=你的token' >> ~/.zshrc
source ~/.zshrc
```

## 3. 验证

```bash
echo $HF_ENDPOINT   # 应输出 https://hf-mirror.com
echo $HF_TOKEN       # 应输出 hf_xxx...
```

---

## 模型缓存

- 缓存位置：`~/.cache/huggingface/hub/`
- 每个模型只下载一次，切换模型不会重复下载
- 切换模型后需要重建 palace（向量维度不同，不兼容）：

```bash
rm -rf ~/.mempalace/palace
mempalace init <dir>
mempalace mine <dir>
```

## 清理旧模型缓存

```bash
# 查看缓存大小
du -sh ~/.cache/huggingface/hub/

# 删除特定模型缓存
rm -rf ~/.cache/huggingface/hub/models--sentence-transformers--paraphrase-multilingual-MiniLM-L12-v2
rm -rf ~/.cache/huggingface/hub/models--sentence-transformers--paraphrase-multilingual-mpnet-base-v2
```
